---@module "mosaic.modules.notice"
---@author sravioli
---@license GNU-GPLv2

---The latest `mosaic.notify` message while it lasts; hidden otherwise.

local icons = require "mosaic.engine.icons"

local notice = require "mosaic.engine.notice"

return function(window)
  local msg = notice.current(window)
  if not msg then
    return { enabled = false }
  end
  local icon = msg.icon
  if icon == nil then
    icon = icons.symbol "Status.info"
  end
  return {
    enabled = true,
    cond = true,
    accent = msg.accent,
    padding = { left = 1 },
    icon = { enabled = icon ~= false and icon ~= "", value = icon or "", padding = { right = 1 } },
    text = { enabled = true, value = msg.text },
  }
end
