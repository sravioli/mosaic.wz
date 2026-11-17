---@module "mosaic.modules.tabs"
---@author sravioli
---@license GNU-GPLv2

---Active tab position and tab count, e.g. `2/5`.

local cell = require "mosaic.modules.cell"

return function(window)
  local tabs = window:mux_window():tabs_with_info()
  for _, info in ipairs(tabs) do
    if info.is_active then
      return cell("Status.tab", ("%d/%d"):format(info.index + 1, #tabs))
    end
  end
  return { enabled = false }
end
