---@module "mosaic.presets.powerline"
---@author sravioli
---@license GNU-GPLv2

---Coloured pills on the left, a powerline gradient on the right, and slanted
---tabs with a numbered index.

local mosaic = require "mosaic.api"

---@param  ctx Mosaic.TabContext
---@return table[] segments
local function tab(ctx)
  local icons = mosaic.icons()
  local idx = ctx.tab.tab_index
  local seps = icons.Sep.tb
  local s = mosaic.palette.tab(ctx, {
    colors = {
      active = 5,
      hover = function(t)
        return ((t.tab_bar or {}).inactive_tab_hover or {}).bg_color or t.ansi[5]
      end,
      inactive = 9,
    },
    separators = {
      left = idx == 0 and seps.leftmost or seps.left,
      right = icons.Sep.block .. seps.right,
    },
    index = "icon",
    unseen = icons.Notification,
  })
  local bg, fg = s.bar, s.fill
  local text = s.text or bg
  local head = s.index ~= "" and s.index .. " " or ""
  local title = ctx.title(ctx.max_width - mosaic.width(s.left .. " " .. head .. s.right))
  return {
    { bg, fg, s.left },
    { fg, fg, " " },
    { fg, text, head },
    { fg, text, title },
    { bg, fg, s.right },
  }
end

---Left side: rounded pills in each module's colour. Right side: a gradient
---from `ansi[5]` by position, each segment opening with an arrow in the
---previous segment's colour. `style.colors` overrides a module's colour and
---`style.separators` the glyphs (`left`: before a right-side segment,
---`right`: closing a left-side pill).
---@param  spec table module spec (content only)
---@param  ctx  table decorate context
---@return table
local function decorate(spec, ctx)
  local icons = mosaic.icons()
  local seps = ctx.style.separators or {}
  local colors = ctx.style.colors or {}
  local out = mosaic.copy(spec)

  if ctx.side ~= "right" then
    local bg = mosaic.palette.color(ctx, spec)
    local text = mosaic.palette.pick(ctx, "text", "background")
    out.style = function()
      return { bg = bg, fg = text }
    end
    out.sep = {
      enabled = true,
      value = { right = seps.left or icons.Sep.ws.right, left = seps.right or icons.Sep.ws.left },
      -- The caps sit on the bar, not on the pill's text colour.
      style = function(t, parent)
        return { bg = mosaic.palette.bar_bg(t, ctx.config), fg = parent.bg }
      end,
    }
    return out
  end

  local stops, text_fg = mosaic.palette.stops(ctx.theme, ctx.count, ctx.style.gradient)
  text_fg = mosaic.palette.pick(ctx, "text", text_fg)
  local names = ctx.names or { ctx.name }
  local specs = ctx.specs or { spec }
  local function segment(i)
    local tint = specs[i] and specs[i].tint
    if tint ~= nil then
      return mosaic.palette.resolve(ctx.theme, tint)
    end
    local c = colors[names[i]]
    if c == nil then
      return stops[i]
    end
    return type(c) == "number" and ctx.theme.ansi[c] or c
  end
  local bg = segment(ctx.index)
  local prev = ctx.index > 1 and segment(ctx.index - 1) or nil

  out.style = function()
    return { bg = bg, fg = text_fg }
  end
  out.sep = {
    enabled = true,
    value = { right = seps.left or icons.Sep.sb.right },
    style = function(t, parent)
      return { bg = prev or mosaic.palette.bar_bg(t, ctx.config), fg = parent.bg }
    end,
  }
  return out
end

---@param  ctx { theme: table, config: table, hover: boolean, style: table }
---@return table[] segments
local function new_tab(ctx)
  local seps = mosaic.icons().Sep.tb
  local function button(t)
    return (t.tab_bar or {})[ctx.hover and "new_tab_hover" or "new_tab"] or {}
  end
  local s = mosaic.palette.tab(ctx, {
    colors = {
      hover = function(t)
        return button(t).bg_color or t.ansi[5]
      end,
      inactive = function(t)
        return button(t).bg_color or t.brights[1]
      end,
      text = function(t)
        return button(t).fg_color or t.background
      end,
    },
    separators = { left = seps.right, right = seps.left },
  })
  return {
    { s.fill, s.bar, s.left },
    { s.fill, s.text, " " .. s.label .. " " },
    { s.fill, s.bar, s.right },
  }
end

return {
  decorate = decorate,
  tabs = { format = tab, new_tab = new_tab },
  layout = {
    left = { "leader", "zoomed", "workspace", "mode" },
    right = { "notice", "hints", { "cwd", "hostname", "clock", "battery" } },
  },
  modules = {},
}
