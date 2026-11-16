---@module "mosaic.modules.workspace"
---@author sravioli
---@license GNU-GPLv2

---Active workspace name, hidden while a key table is active.

local cond = require "mosaic.engine.conditions"
local icons = require("mosaic.engine.deps").icons()

return {
  enabled = true,
  padding = { left = 1 },
  cond = cond.all(cond.has_workspace, cond.mode_inactive),
  icon = {
    enabled = true,
    value = icons.Workspace,
  },
  text = {
    enabled = true,
    padding = { left = 1 },
    value = function(window, _)
      return window:active_workspace()
    end,
    style = { attributes = "i" },
  },
}
