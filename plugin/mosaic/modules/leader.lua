---@module "mosaic.modules.leader"
---@author sravioli
---@license GNU-GPLv2

---Leader indicator, shown while the leader key is active.

local cond = require "mosaic.engine.conditions"
local icons = require("mosaic.engine.deps").icons()

return {
  enabled = true,
  cond = cond.leader_active,
  padding = { left = 1 },
  icon = {
    enabled = true,
    value = icons.Leader,
  },
}
