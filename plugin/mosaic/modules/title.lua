---@module "mosaic.modules.title"
---@author sravioli
---@license GNU-GPLv2

---Title of the active pane, truncated first when space is short.

local cell = require "mosaic.modules.cell"
local paths = require "mosaic.engine.paths"

return function(_, pane)
  local title = pane:get_title()
  title = title and paths.clean(title)
  if not title or title == "" then
    return { enabled = false }
  end
  return cell("Status.title", title)
end
