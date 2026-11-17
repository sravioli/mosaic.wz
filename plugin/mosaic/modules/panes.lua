---@module "mosaic.modules.panes"
---@author sravioli
---@license GNU-GPLv2

---Number of panes in the active tab; hidden with a single pane.

local cell = require "mosaic.modules.cell"

return function(window)
  local ok, tab = pcall(window.active_tab, window)
  if not ok or not tab then
    return { enabled = false }
  end
  local n = #tab:panes()
  if n <= 1 then
    return { enabled = false }
  end
  return cell("Status.panes", tostring(n))
end
