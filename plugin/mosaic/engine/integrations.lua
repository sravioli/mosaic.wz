---@module "mosaic.engine.integrations"
---@author sravioli
---@license GNU-GPLv2

---Modules shipped by other plugins, resolved by name.
---
---A layout name `<plugin>.<module>` maps to the Lua module
---`<plugin>.mosaic.<module>` (file `plugin/<plugin>/mosaic/<module>.lua` in
---that plugin). The file is required only when a layout names it, so an
---integration the user does not use is never read. It must return:
---
---```lua
---return {
---  api = 1,                       -- mosaic.INTEGRATION_API
---  events = { "my-plugin-event" }, -- optional: refresh the bar on these
---  new = function(opts, mosaic) return module end,
---}
---```
---
---Failures (unloaded plugin, bad descriptor, `new` raising) are logged once
---and leave only that slot empty.

local wezterm = require "wezterm"

local deps = require "mosaic.engine.deps"
local log = require "mosaic.engine.logger"

local w = deps.warden

local M = {}

M.API = 1

local descriptor_schema = w.object({
  api = w.number():refine(function(v)
    return v == M.API
  end, ("Expected integration api %d"):format(M.API)),
  new = w.any():refine(function(v)
    return type(v) == "function"
  end, "Expected function"),
  events = w.array(w.string():not_empty()):optional(),
  -- event -> message (or fun(...): message) shown with mosaic.notify
  notices = w.map(
    w.string():not_empty(),
    w.union {
      w.string(),
      w.any():refine(function(v)
        return type(v) == "function"
      end, "Expected function"),
    }
  ):optional(),
}):unknown "warn"

local options = {} ---@type table<string, table>
local cache = {} ---@type table<string, Mosaic.Module|function|false>
local wired = {} ---@type table<string, true>

---Split `<plugin>.<module>`; nil for anything else.
---@param  name string
---@return string|nil plugin, string|nil module
function M.parse(name)
  if type(name) ~= "string" then
    return nil
  end
  return name:match "^([%w_]+)%.([%w_]+)$"
end

---Forget instances and set the per-integration options (from `setup`).
---@param opts? table<string, table>
function M.configure(opts)
  options = opts or {}
  cache = {}
end

---@param event string
local function wire(event)
  if wired[event] then
    return
  end
  wired[event] = true
  wezterm.on(event, function(window, pane)
    require("mosaic.engine.status").update(window, pane)
  end)
end

---Show `message` (or what `message(...)` returns) with mosaic.notify on
---`event`, whose first argument must be the window.
---@param event   string
---@param message string|function
local function wire_notice(event, message)
  local id = "notice:" .. event
  if wired[id] then
    return
  end
  wired[id] = true
  wezterm.on(event, function(window, ...)
    local text = message
    if type(message) == "function" then
      local ok, out = pcall(message, window, ...)
      text = ok and out or nil
    end
    if text ~= nil and text ~= "" then
      require("mosaic.engine.notice").notify(window, text)
    end
  end)
end

---Require and validate the descriptor behind `name`.
---@param  name string
---@return table|nil
local function load(name)
  local plugin, module = M.parse(name)
  if not plugin then
    log:error("invalid integration name %q: expected <plugin>.<module>", tostring(name))
    return nil
  end
  local path = plugin .. ".mosaic." .. module
  local ok, descriptor = pcall(require, path)
  if not ok then
    if tostring(descriptor):find(("module '%s' not found"):format(path), 1, true) then
      log:error("integration %s: no %s on package.path (is %s loaded?)", name, path, plugin)
    else
      log:error("integration %s failed to load: %s", name, tostring(descriptor))
    end
    return nil
  end
  local result = descriptor_schema:safe_parse(descriptor)
  if not result.ok then
    result:log()
    log:error("integration %s: invalid descriptor", name)
    return nil
  end
  return descriptor
end

---The module behind `name`, built once per `configure()`.
---@param  name string
---@return Mosaic.Module|function|nil
function M.get(name)
  local cached = cache[name]
  if cached ~= nil then
    return cached or nil
  end
  cache[name] = false

  local descriptor = load(name)
  if not descriptor then
    return nil
  end
  local ok, module = pcall(descriptor.new, options[name] or {}, require "mosaic.api")
  if not ok then
    log:error("integration %s: new() failed: %s", name, tostring(module))
    return nil
  end
  if type(module) ~= "table" and type(module) ~= "function" then
    log:error("integration %s: new() must return a module, got %s", name, type(module))
    return nil
  end
  for _, event in ipairs(descriptor.events or {}) do
    wire(event)
  end
  for event, message in pairs(descriptor.notices or {}) do
    wire_notice(event, message)
  end
  cache[name] = module
  return module
end

---Names of the integrations that loaded plugins ship, without reading them.
---Scans each `<dir>/?.lua` entry of `package.path`, which is where loaded
---plugins (clones and local checkouts alike) put their modules.
---@return string[]
function M.discover()
  local names, seen = {}, {}
  for entry in package.path:gmatch "[^;]+" do
    local dir = entry:match "^(.-)%?%.lua$"
    local gok, files = false, nil
    if dir and dir ~= "" and dir ~= "./" then
      gok, files = pcall(wezterm.glob, dir .. "*/mosaic/*.lua")
    end
    for _, file in ipairs(gok and files or {}) do
      local plugin, module = file:gsub("\\", "/"):match "([%w_]+)/mosaic/([%w_]+)%.lua$"
      local name = plugin and (plugin .. "." .. module)
      if name and not seen[name] then
        seen[name] = true
        names[#names + 1] = name
      end
    end
  end
  table.sort(names)
  return names
end

return M
