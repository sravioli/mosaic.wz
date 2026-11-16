---@module "mosaic.modules.window"
---@author sravioli
---@license GNU-GPLv2

---Title of the window (the active tab's title, else the active pane's).

local cell = require "mosaic.modules.cell"

return function(window, pane)
  local title
  local ok, mux = pcall(window.mux_window, window)
  if ok and mux then
    local tok, t = pcall(mux.get_title, mux)
    title = tok and t or nil
  end
  if not title or title == "" then
    title = pane and pane:get_title() or ""
  end
  if title == "" then
    return { enabled = false }
  end
  return cell("md_application_outline", title)
end
