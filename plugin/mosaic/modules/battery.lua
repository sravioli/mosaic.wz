---@module "mosaic.modules.battery"
---@author sravioli
---@license GNU-GPLv2

---Charge of the first battery; disabled when there is none. Options:
---  - `all = true`: every battery's charge, e.g. `47% 80%`;
---  - `time = true`: time to empty / full after the charge, e.g. `47% 2:13`;
---  - `levels = { [15] = 2, [40] = 4 }`: state colour (`tint`) at or below a
---    charge, the lowest matching threshold winning;
---  - `charging = colour`: state colour while charging or full, over `levels`.

local wezterm = require "wezterm"

local cond = require "mosaic.engine.conditions"
local config = require "mosaic.engine.config"
local deps = require "mosaic.engine.deps"

local maths = deps.warp.maths
local icons = deps.icons()
local floor = math.floor

---@param  seconds number|nil
---@return string|nil
local function duration(seconds)
  if not seconds or seconds <= 0 then
    return nil
  end
  local minutes = floor(seconds / 60 + 0.5)
  return ("%d:%02d"):format(floor(minutes / 60), minutes % 60)
end

---@param  bat  table BatteryInfo
---@param  time boolean
---@return string
local function label(bat, time)
  local text = tostring(floor(bat.state_of_charge * 100 + 0.5)) .. "%"
  local left = time and duration(bat.state == "Charging" and bat.time_to_full or bat.time_to_empty)
  return left and (text .. " " .. left) or text
end

---Glyph for a battery state and a charge rounded to tens. `Full` (plugged
---in, full) takes the charging glyph, so being on power shows; states
---without a set of their own (`Empty`, `Unknown`) take the discharging one.
---@param  state  string
---@param  tens   integer 0-100
---@return string
local function glyph(state, tens)
  local key = tens <= 0 and "00" or tostring(tens)
  local set = icons.Bat[state == "Full" and "Charging" or state] or icons.Bat.Discharging
  return set[key] or icons.Bat.Discharging[key] or ""
end

---@param  levels table|nil
---@param  charge number 0-100
---@return any colour
local function level_tint(levels, charge)
  local best
  for threshold in pairs(levels or {}) do
    if charge <= threshold and (best == nil or threshold < best) then
      best = threshold
    end
  end
  return best and levels[best]
end

return function()
  local all = wezterm.battery_info()
  local bat = all[1]
  if not bat then
    return { enabled = false }
  end
  local opts = config.option "battery"

  local charge = bat.state_of_charge * 100
  local charge_r = floor(maths.round_to(charge, 10))
  local text = label(bat, opts.time)
  if opts.all and #all > 1 then
    local parts = {}
    for i, b in ipairs(all) do
      parts[i] = label(b, opts.time)
    end
    text = table.concat(parts, " ")
  end

  return {
    enabled = true,
    cond = cond.hints_inactive,
    can_hide = true,
    update = 5,
    tint = (opts.charging ~= nil and (bat.state == "Charging" or bat.state == "Full"))
        and opts.charging
      or level_tint(opts.levels, charge),
    icon = {
      enabled = true,
      value = glyph(bat.state, charge_r),
      position = "right",
      padding = 1,
    },
    text = {
      enabled = true,
      value = text,
      -- without the time first, then the first battery alone
      variants = (opts.time or (opts.all and #all > 1)) and { label(bat, false) } or nil,
      padding = { left = 1, right = 0 },
    },
  }
end
