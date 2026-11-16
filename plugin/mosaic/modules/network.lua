---@module "mosaic.modules.network"
---@author sravioli
---@license GNU-GPLv2

---Download/upload rate over the physical interfaces (no loopback, tunnels or bridges). Refreshed every 2s;
---hidden on Windows.

local cell = require "mosaic.modules.cell"
local system = require "mosaic.engine.system"
local wezterm = require "wezterm"

return function()
  if not system.supported() then
    return { enabled = false }
  end
  local down, up = system.network()
  local text = ("%s %s %s"):format(
    system.rate(down),
    wezterm.nerdfonts.md_upload or "",
    system.rate(up)
  )
  local module = cell("md_download", text, { interval = 2 })
  module.text.variants = { system.rate(down) }
  return module
end
