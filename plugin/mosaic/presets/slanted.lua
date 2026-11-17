---@module "mosaic.presets.slanted"
---@author sravioli
---@license GNU-GPLv2

---Every module and tab is a block in its accent colour with slanted edges
---(`/ … /`); `slanted-inverted` leans the other way (`\ … \`). The outermost
---module on each side keeps a flat edge against the window.

local mosaic = require "mosaic.api"

local tri = mosaic.icons().Sep.triangle or {}

---@param  open  string glyph before a block
---@param  close string glyph after a block
---@return table preset
local function build(open, close)
  ---Every module a slanted block in its colour. `style.separators` replaces
  ---the edges (`left` before, `right` after).
  ---@param  spec table module spec (content only)
  ---@param  ctx  table decorate context
  ---@return table
  local function decorate(spec, ctx)
    local out = mosaic.pad_inside(spec)
    local block = mosaic.palette.color(ctx, spec)
    local seps = ctx.style.separators or {}
    local text = mosaic.palette.pick(ctx, "text", "background")
    out.style = function()
      return { bg = block, fg = text }
    end
    -- Neighbouring edges touch: one slant between two blocks, no gap.
    local before = seps.left or open
    local after = seps.right or close
    if ctx.side == "left" and ctx.first then
      before = nil
    elseif ctx.side == "right" and ctx.last then
      after = nil
    end
    out.sep = {
      enabled = true,
      value = { right = before, left = after },
      style = function(t, parent)
        return { bg = mosaic.palette.bar_bg(t, ctx.config), fg = parent.bg }
      end,
    }
    return out
  end

  local defaults = {
    colors = { active = 5, hover = 7, inactive = 9, text = "background" },
    separators = { left = open, right = close },
  }

  ---@param  ctx Mosaic.TabContext
  ---@return table[] segments
  local function tab(ctx)
    local s = mosaic.palette.tab(ctx, defaults)
    local head = " " .. s.index .. " "
    -- Neighbouring tabs touch: one slant between them, no gap.
    local title = ctx.title(ctx.max_width - mosaic.width(s.left .. head .. " " .. s.right))
    return {
      { s.bar, s.fill, s.left },
      { s.fill, s.text, head .. title .. " " },
      { s.bar, s.fill, s.right },
    }
  end

  ---@param  ctx { theme: table, config: table, hover: boolean, style: table }
  ---@return table[] segments
  local function new_tab(ctx)
    local s = mosaic.palette.tab(ctx, defaults)
    return {
      { s.bar, s.fill, s.left },
      { s.fill, s.text, " " .. s.label .. " " },
      { s.bar, s.fill, s.right },
    }
  end

  return {
    decorate = decorate,
    tabs = { format = tab, new_tab = new_tab },
    layout = {
      left = { "mode", "leader", "workspace", "zoomed" },
      right = { "notice", "hints", { "cwd", "cpu", "ram", "clock", "battery" } },
    },
  }
end

local preset = build(tri.lower_right or "", tri.upper_left or "")
-- Not a preset field: `slanted-inverted` returns it.
preset.inverted = build(tri.upper_right or "", tri.lower_left or "")
return preset
