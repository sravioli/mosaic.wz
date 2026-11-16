---@module "mosaic.modules.disk"
---@author sravioli
---@license GNU-GPLv2

---Used space on the root volume (macOS: the data volume). Refreshed every 30s; hidden on Windows.

local cell = require "mosaic.modules.cell"
local system = require "mosaic.engine.system"

return function()
  if not system.supported() then
    return { enabled = false }
  end
  return cell("md_harddisk", system.percent(system.disk()), { interval = 30 })
end
