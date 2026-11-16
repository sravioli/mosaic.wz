---@module "mosaic.modules.hostname"
---@author sravioli
---@license GNU-GPLv2

---Short hostname of the pane.

local cond = require "mosaic.engine.conditions"
local deps = require "mosaic.engine.deps"

local fs = deps.warp.filesystem
local icons = deps.icons()

return function(_, pane)
  return {
    enabled = true,
    cond = cond.hints_inactive,
    can_hide = true,
    icon = {
      enabled = true,
      value = icons.Hostname,
      position = "right",
      padding = { right = 1 },
    },
    text = {
      enabled = true,
      value = fs.get_hostname(pane),
      padding = 1,
    },
  }
end
