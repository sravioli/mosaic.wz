---@module "mosaic.engine.center"
---@author sravioli
---@license GNU-GPLv2

---Where the centre modules go. WezTerm's tab bar has a left status, the tabs
---and a right-aligned right status, but no centre: mosaic draws the centre
---modules at the start of the right status, followed by a gap that pushes
---them to the computed column.
---
---```
---| left | tabs | + |      ·free·      [ centre ]  gap  | right |
---0              free_start            c0              free_end   screen
---```

local M = {}

M.DEFAULTS = { anchor = "window", overflow = "shift", margin = 1 }

---Start column of a centre block `width` wide, or nil when it cannot show.
---  - `anchor = "window"`: centred on the whole bar; `"free"`: centred in the
---    space between the tabs and the right modules;
---  - when that spot would touch the tabs or the right modules,
---    `overflow = "shift"` slides it into the free space, `"hide"` drops it;
---  - `margin` columns stay clear on both sides of it.
---@param  screen     integer bar width
---@param  free_start integer first column after the tabs and new-tab button
---@param  free_end   integer first column of the right modules
---@param  width      integer centre block width
---@param  opts?      { anchor?: string, overflow?: string, margin?: integer }
---@return integer|nil c0
function M.place(screen, free_start, free_end, width, opts)
  opts = opts or {}
  local margin = opts.margin or M.DEFAULTS.margin
  local lo, hi = free_start + margin, free_end - margin
  if width <= 0 or width > hi - lo then
    return nil
  end
  local ideal
  if opts.anchor == "free" then
    ideal = lo + math.floor((hi - lo - width) / 2)
  else
    ideal = math.floor((screen - width) / 2)
  end
  local c0 = math.min(math.max(ideal, lo), hi - width)
  if c0 ~= ideal and opts.overflow == "hide" then
    return nil
  end
  return c0
end

return M
