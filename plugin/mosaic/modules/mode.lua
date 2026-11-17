---@module "mosaic.modules.mode"
---@author sravioli
---@license GNU-GPLv2

---Name of the active key table (`copy_mode` -> `COPY`), hidden otherwise.
---Options: `modes = { copy_mode = { text, icon, color } }` per key table,
---and `format = fun(name): string` for the default text.

local icons = require "mosaic.engine.icons"

local cond = require "mosaic.engine.conditions"
local config = require "mosaic.engine.config"

local function default_name(active)
  return (active:gsub("_mode$", ""):gsub("_", " "):upper())
end

return function(window)
  local active = cond.key_table(window)
  if not active then
    return { enabled = false }
  end
  local opts = config.option "mode"
  local per = (opts.modes or {})[active] or {}
  local name = per.text or (opts.format or default_name)(active)
  local icon = per.icon
  if icon == nil then
    icon = icons.symbol "Status.keyboard"
  end
  return {
    enabled = true,
    cond = true,
    tint = per.color, -- state colour: wins over the preset's position colours
    padding = { left = 1 },
    icon = { enabled = icon ~= false and icon ~= "", value = icon or "", padding = 1 },
    text = { enabled = true, value = name, padding = { right = 1 } },
  }
end
