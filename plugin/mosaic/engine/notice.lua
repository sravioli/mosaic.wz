---@module "mosaic.engine.notice"
---@author sravioli
---@license GNU-GPLv2

---Transient messages for the `notice` module, per window, kept in
---`wezterm.GLOBAL` so other plugins' events and reloads see them.

local wezterm = require "wezterm"

local M = {}

---@param  id integer window id
---@return string
local function key(id)
  return "__mosaic:notice:" .. tostring(id)
end

---Show `text` in the window's `notice` slot for `opts.seconds` (default 3).
---@param window table
---@param text   string
---@param opts?  { seconds?: number, icon?: string|false, accent?: any }
function M.notify(window, text, opts)
  if text == nil then
    return
  end
  if type(window) ~= "table" and type(window) ~= "userdata" then
    -- No window (e.g. the debug overlay's REPL): every GUI window.
    local ok, all = pcall(function()
      return wezterm.gui.gui_windows()
    end)
    for _, w in ipairs(ok and all or {}) do
      M.notify(w, text, opts)
    end
    return
  end
  opts = type(opts) == "table" and opts or {}
  local seconds = tonumber(opts.seconds) or 3
  require("mosaic.engine.store").set(key(window:window_id()), {
    text = tostring(text),
    icon = opts.icon,
    accent = opts.accent,
    expires = os.time() + seconds,
  })
  local status = require "mosaic.engine.status"
  local function redraw()
    -- The window may be gone by the time the timer fires.
    local ok, pane = pcall(window.active_pane, window)
    if ok and pane then
      pcall(status.update, window, pane)
    end
  end
  redraw()
  -- One second late: os.time() has one-second resolution.
  wezterm.time.call_after(seconds + 1, redraw)
end

---Drop a closed window's message.
---@param id integer window id
function M.forget(id)
  require("mosaic.engine.store").set(key(id), nil)
end

---The window's unexpired message, or nil.
---@param  window table
---@return table|nil
function M.current(window)
  local ok, id = pcall(window.window_id, window)
  local saved = ok
    and require("mosaic.engine.store").get(key(id), { "text", "icon", "accent", "expires" })
  if not saved or os.time() >= (saved.expires or 0) then
    return nil
  end
  return saved
end

return M
