---@module "mosaic.modules.network"
---@author sravioli
---@license GNU-GPLv2

---Download/upload rate over the physical interfaces (no loopback, tunnels or bridges). Refreshed every 2s;
---hidden on Windows.

local cell = require "mosaic.modules.cell"
local icons = require "mosaic.engine.icons"
local system = require "mosaic.engine.system"

return function()
  if not system.supported() then
    return { enabled = false }
  end
  local down, up = system.network()
  local text = ("%s %s %s"):format(system.rate(down), icons.symbol "Status.upload", system.rate(up))
  local module = cell("Status.download", text, { interval = 2 })
  module.text.variants = { system.rate(down) }
  return module
end
