---@module "mosaic.presets.pure"
---@author sravioli
---@license GNU-GPLv2

---Quiet text in the spirit of the pure prompt: dim text, each module's icon
---in its accent colour, no backgrounds and no separator glyphs.

local mosaic = require "mosaic.api"

---Dim text on the bar with the icon in the module's colour (the text, for
---modules without an icon). `style.separators`
---adds dim glyphs (`left` before, `right` after).
---@param  spec table module spec (content only)
---@param  ctx  table decorate context
---@return table
local function decorate(spec, ctx)
  local out = mosaic.pad_inside(spec)
  local accent = mosaic.palette.color(ctx, spec)
  local seps = ctx.style.separators or {}
  -- Explicit bar colour: an unset bg is transparent, which shows the terminal
  -- background instead of the bar.
  -- Without an icon the text carries the accent, so the module keeps its colour.
  local has_icon = out.icon and out.icon.enabled ~= false
  local dim = mosaic.palette.pick(ctx, "dim", 9)
  out.style = function(t)
    return { fg = has_icon and dim or accent, bg = mosaic.palette.bar_bg(t, ctx.config) }
  end
  if has_icon then
    local icon = mosaic.copy(out.icon)
    icon.style = function(_, parent)
      return { fg = accent, bg = parent.bg }
    end
    out.icon = icon
  end
  if seps.left or seps.right then
    out.sep = { enabled = true, value = { right = seps.left, left = seps.right } }
  else
    out.sep = nil
  end
  return out
end

---@param  ctx Mosaic.TabContext
---@return table[] segments
local function tab(ctx)
  local s = mosaic.palette.tab(ctx, {
    colors = { active = "foreground", hover = 5, inactive = 9, head = 6, dim = 9 },
  })
  local head = " " .. s.index .. " "
  local title = ctx.title(ctx.max_width - mosaic.width(s.left .. head .. s.right) - 1)
  return {
    { s.bar, ctx.state == "active" and s.head or s.dim, s.left .. head },
    { s.bar, s.fill, title .. " " .. s.right },
  }
end

---@param  ctx { theme: table, config: table, hover: boolean, style: table }
---@return table[] segments
local function new_tab(ctx)
  local s = mosaic.palette.tab(ctx, { colors = { hover = 5, inactive = 9 } })
  return { { s.bar, s.fill, s.left .. " " .. s.label .. " " .. s.right } }
end

return {
  decorate = decorate,
  tabs = { format = tab, new_tab = new_tab },
  layout = {
    left = { "mode", "leader", "workspace", "zoomed" },
    right = { "notice", "hints", { "process", "cwd", "clock", "battery" } },
  },
}
