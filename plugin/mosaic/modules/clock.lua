---@module "mosaic.modules.clock"
---@author sravioli
---@license GNU-GPLv2

---Date and time with shorter fallbacks. Options: `format` (strftime),
---`variants` (shorter strftime forms, longest first) and `icons` (`false`, or
---`{ ["00"] = glyph, ... }` by 24-hour hour, replacing the clock faces).

local wezterm = require "wezterm"

local cond = require "mosaic.engine.conditions"
local config = require "mosaic.engine.config"
local deps = require "mosaic.engine.deps"

local icons = deps.icons()

local VARIANTS = { "%b %-d %H:%M", "%a %H:%M", "%H:%M" }

return function()
  local opts = config.option "clock"
  local timefmt = wezterm.strftime
  local hour_24 = tonumber(timefmt "%H")
  local hour_12 = timefmt "%I"
  local mode = (hour_24 >= 6 and hour_24 < 18) and "day" or "night"
  local glyph = icons.Clock[mode][hour_12]
  if opts.icons == false then
    glyph = nil
  elseif type(opts.icons) == "table" then
    glyph = opts.icons[timefmt "%H"] or glyph
  end

  local variants = {}
  for i, fmt in ipairs(opts.variants or VARIANTS) do
    variants[i] = timefmt(fmt)
  end

  return {
    enabled = true,
    cond = cond.hints_inactive,
    icon = {
      enabled = glyph ~= nil,
      value = glyph or "",
      position = "right",
      padding = 1,
    },
    text = {
      enabled = true,
      value = timefmt(opts.format or "%a %b %-d %H:%M"),
      -- shorter forms tried before dropping to icon-only (longest first)
      variants = variants,
      trim = false,
      padding = { left = 1 },
    },
  }
end
