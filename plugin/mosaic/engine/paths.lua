---@module "mosaic.engine.paths"
---@author sravioli
---@license GNU-GPLv2

---Working directories for modules and tab components: read from a Pane or a
---PaneInformation without blocking, and shortened for display.

local wezterm = require "wezterm"

local M = {}

---Path of a cwd value: a Url object (`.file_path`), a `file://host/path`
---string, or a plain path.
---@param  value any
---@return string|nil
function M.from_url(value)
  if value == nil then
    return nil
  end
  if type(value) ~= "string" then
    local ok, path = pcall(function()
      return value.file_path
    end)
    return ok and path or nil
  end
  local path = value:match "^file://[^/]*(/.*)$" or value
  path = path:gsub("%%(%x%x)", function(hex)
    return string.char(tonumber(hex, 16))
  end)
  -- Windows: /C:/Users -> C:/Users
  return (path:gsub("^/(%a:)", "%1"))
end

---Working directory of a Pane object (`pane:get_current_working_dir()`).
---@param  pane table|nil Pane
---@return string|nil
function M.cwd(pane)
  if pane == nil then
    return nil
  end
  local ok, url = pcall(pane.get_current_working_dir, pane)
  return ok and M.from_url(url) or nil
end

---Working directory of a PaneInformation snapshot (`current_working_dir`).
---Separate from `M.cwd`: WezTerm raises on unknown PaneInformation fields,
---so the two kinds cannot be told apart by probing.
---@param  info table|nil PaneInformation
---@return string|nil
function M.info_cwd(info)
  if info == nil then
    return nil
  end
  local ok, url = pcall(function()
    return info.current_working_dir
  end)
  return ok and M.from_url(url) or nil
end

---`s` without control characters: titles come from programs (a web page's,
---through MPRIS or OSC) and must not smuggle escape sequences into the bar.
---@param  s any
---@return string
function M.clean(s)
  return (tostring(s):gsub("%c", ""))
end

---Last path component.
---@param  path string|nil
---@return string
function M.basename(path)
  if not path or path == "" then
    return ""
  end
  local trimmed = path:gsub("[/\\]+$", "")
  if trimmed == "" then
    return path:sub(1, 1)
  end
  return trimmed:match "([^/\\]+)$" or trimmed
end

---Parent directory of `path`.
---@param  path string|nil
---@return string|nil
function M.parent(path)
  if not path then
    return nil
  end
  local trimmed = path:gsub("[/\\]+$", "")
  return trimmed:match "^(.*)[/\\][^/\\]*$"
end

---`path` for display:
---  - `aliases` (`{ { pattern = "^/srv/www", replacement = "www" } }`) apply first;
---  - `home` replaces the home directory prefix (e.g. `"~"`; false keeps it);
---  - `max_length` cuts from the left, keeping the end, with a leading `…`.
---@param  path string
---@param  opts? { home?: string|false, aliases?: table[], max_length?: integer }
---@return string
function M.shorten(path, opts)
  opts = opts or {}
  for _, alias in ipairs(opts.aliases or {}) do
    if alias.pattern and path:find(alias.pattern) then
      path = path:gsub(alias.pattern, (tostring(alias.replacement or ""):gsub("%%", "%%%%")), 1)
      break
    end
  end
  local home = wezterm.home_dir
  if opts.home and home and home ~= "" and path:sub(1, #home) == home then
    local rest = path:sub(#home + 1)
    if rest == "" or rest:match "^[/\\]" then
      path = opts.home .. rest
    end
  end
  local max = tonumber(opts.max_length)
  if max and max > 0 then
    -- By display width, so wide (CJK, emoji) text is cut correctly.
    path = require("mosaic.engine.deps").warp.string.truncate("left", path, max)
  end
  return path
end

return M
