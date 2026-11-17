---@module "mosaic.modules.cpu"
---@author sravioli
---@license GNU-GPLv2

---CPU utilisation; the first sample on Linux shows `--%`. Refreshed every 3s; hidden on Windows.

local cell = require "mosaic.modules.cell"
local system = require "mosaic.engine.system"

return function()
  if not system.supported() then
    return { enabled = false }
  end
  return cell("Status.cpu", system.percent(system.cpu()), { interval = 3 })
end
