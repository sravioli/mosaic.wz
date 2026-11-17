---@module "mosaic.modules.ram"
---@author sravioli
---@license GNU-GPLv2

---Memory in use. Refreshed every 3s; hidden on Windows.

local cell = require "mosaic.modules.cell"
local system = require "mosaic.engine.system"

return function()
  if not system.supported() then
    return { enabled = false }
  end
  return cell("Status.ram", system.percent(system.ram()), { interval = 3 })
end
