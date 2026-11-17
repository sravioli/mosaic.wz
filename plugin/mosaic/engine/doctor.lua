---@module "mosaic.engine.doctor"
---@author sravioli
---@license GNU-GPLv2

---A plain-text report on what mosaic sees: dependencies, external programs,
---option issues, where each layout name resolves, and what each module
---costs per frame. Meant for the debug overlay:
---
---```lua
---> require("mosaic.api").doctor()
---```

local wezterm = require "wezterm"

local config = require "mosaic.engine.config"
local deps = require "mosaic.engine.deps"
local integrations = require "mosaic.engine.integrations"

local M = {}

-- Program -> built-in modules needing it, per platform.
local PROGRAMS = {
  linux = {
    { "playerctl", { "media" }, "or busctl" },
    { "busctl", { "media" }, "fallback for playerctl" },
    { "df", { "disk" } },
  },
  macos = {
    { "osascript", { "media" } },
    { "ps", { "cpu" } },
    { "vm_stat", { "ram" } },
    { "sysctl", { "cpu", "ram" } },
    { "netstat", { "network" } },
    { "df", { "disk" } },
  },
}

---Every module name of a layout, in order.
---@param  layout table
---@return string[]
local function names_of(layout)
  local out = {}
  for _, side in ipairs { "left", "center", "right" } do
    for _, item in ipairs(layout[side] or {}) do
      for _, name in ipairs(type(item) == "table" and item or { item }) do
        out[#out + 1] = { side = side, name = name }
      end
    end
  end
  return out
end

---Where `name` resolves to.
---@param  name string
---@return string
function M.source(name)
  local modules = config.live.modules
  local own = rawget(modules, name)
  if type(own) == "string" then
    -- The renderer follows one hop only: a chain draws nothing.
    if type(rawget(modules, own)) == "string" then
      return "-> " .. own .. " (UNKNOWN: aliases do not chain)"
    end
    return "-> " .. own .. " (" .. M.source(own) .. ")"
  end
  if own ~= nil then
    return "custom"
  end
  if integrations.parse(name) then
    return integrations.get(name) and "integration" or "integration FAILED (see the log)"
  end
  local ok, builtin = pcall(function()
    return modules[name]
  end)
  if ok and builtin ~= nil then
    return "built-in"
  end
  return "UNKNOWN"
end

---@param  window? table GUI window (default: the first one)
---@return string report
function M.report(window)
  local lines = {}
  local function add(fmt, ...)
    lines[#lines + 1] = select("#", ...) > 0 and fmt:format(...) or fmt
  end

  local api = require "mosaic.api"
  add("mosaic %s on WezTerm %s", tostring(api.VERSION), tostring(wezterm.version))
  local loaded = {}
  for _, dep in ipairs { "warp", "log", "warden", "ribbon" } do
    loaded[#loaded + 1] = dep .. (deps[dep] and " ok" or " MISSING")
  end
  loaded[#loaded + 1] = "sigil " .. (deps.icons_loaded() and "ok" or "not loaded yet")
  add("dependencies: %s", table.concat(loaded, ", "))

  if not window then
    local ok, all = pcall(function()
      return wezterm.gui.gui_windows()
    end)
    window = ok and all and all[1] or nil
  end
  local pane = window and select(2, pcall(window.active_pane, window)) or nil
  local layout = (window and pane) and config.layout_for(window, pane) or config.live.layout
  local used = {}
  for _, entry in ipairs(names_of(layout)) do
    used[entry.name] = true
  end

  local system = require "mosaic.engine.system"
  local os_name = system.supported() and system.os or nil
  if os_name then
    local which = deps.warp.process.which
    local parts = {}
    for _, p in ipairs(PROGRAMS[os_name]) do
      local needed = false
      for _, module in ipairs(p[2]) do
        needed = needed or used[module] == true
      end
      parts[#parts + 1] = ("%s %s%s"):format(
        p[1],
        which(p[1]) and "found" or "missing",
        needed and (" (used by " .. table.concat(p[2], ", ") .. ")") or ""
      )
    end
    add("programs: %s", table.concat(parts, "; "))
  else
    add "programs: none on Windows (system modules and media hide themselves)"
  end

  local issues = config.issues or {}
  add("options: %s", #issues == 0 and "valid" or (#issues .. " issue(s)"))
  for _, issue in ipairs(issues) do
    add("  %s", issue)
  end

  add("layout%s:", config.live.layout_fn and " (from your function, for this window)" or "")
  for _, entry in ipairs(names_of(layout)) do
    add("  %-6s %-24s %s", entry.side, entry.name, M.source(entry.name))
  end
  local stray = {}
  for name in pairs(config.live.options or {}) do
    if not used[name] then
      local target = false
      for _, entry in ipairs(names_of(layout)) do
        target = target or rawget(config.live.modules, entry.name) == name
      end
      if not target then
        stray[#stray + 1] = name
      end
    end
  end
  table.sort(stray)
  if #stray > 0 then
    add("options for names not in the layout (typo?): %s", table.concat(stray, ", "))
  end

  if window and pane then
    local renderer = require "mosaic.engine.renderer"
    renderer.profile = {}
    local started = os.clock()
    local ok, err = pcall(require("mosaic.engine.status").update, window, pane)
    local total = os.clock() - started
    local profile = renderer.profile
    renderer.profile = nil
    if not ok then
      add("frame: FAILED: %s", tostring(err))
    else
      add("frame: %.2f ms (module functions below; cached ones did not run)", total * 1000)
      local rows = {}
      for name, t in pairs(profile) do
        rows[#rows + 1] = { name = name, t = t }
      end
      table.sort(rows, function(a, b)
        return a.t > b.t
      end)
      for _, row in ipairs(rows) do
        add("  %-24s %.3f ms", row.name, row.t * 1000)
      end
    end
  else
    add "frame: no window to measure (pass one: mosaic.doctor(window))"
  end
  return table.concat(lines, "\n")
end

return M
