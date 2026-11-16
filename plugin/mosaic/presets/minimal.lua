---@module "mosaic.presets.minimal"
---@author sravioli
---@license GNU-GPLv2

---Accent-coloured text on the bar background, no separators.

local mosaic = require "mosaic.api"

---Each module's colour as text on the bar's own surface. Separators only
---when the user sets `style.separators` (`left` before, `right` after).
---@param  spec table module spec (content only)
---@param  ctx  table decorate context
---@return table
local function decorate(spec, ctx)
  local out = mosaic.copy(spec)
  local fg = mosaic.palette.color(ctx, spec)
  local style = function()
    return { fg = fg }
  end
  out.style = style
  out.padding = { left = 1, right = 1 }
  local seps = ctx.style.separators
  if seps and (seps.left or seps.right) then
    out.sep = { enabled = true, value = { right = seps.left, left = seps.right }, style = style }
  else
    out.sep = nil
  end
  return out
end

---@param  ctx Mosaic.TabContext
---@return table[] segments
local function tab(ctx)
  local s = mosaic.palette.tab(ctx, {
    colors = { active = 5, hover = "foreground", inactive = 9 },
  })
  local head = " " .. s.index .. " "
  local title = ctx.title(ctx.max_width - mosaic.width(s.left .. head .. s.right) - 1)
  return {
    { s.bar, s.fill, s.left .. head },
    { s.bar, s.fill, title .. " " .. s.right },
  }
end

---@param  ctx { theme: table, config: table, hover: boolean, style: table }
---@return table[] segments
local function new_tab(ctx)
  local s = mosaic.palette.tab(ctx, { colors = { hover = "foreground", inactive = 9 } })
  return { { s.bar, s.fill, s.left .. " " .. s.label .. " " .. s.right } }
end

return {
  decorate = decorate,
  tabs = { format = tab, new_tab = new_tab },
  layout = {
    left = { "mode", "leader", "workspace", "zoomed" },
    right = { "notice", "hints", { "process", "cwd", "cpu", "ram", "clock", "battery" } },
  },
}
