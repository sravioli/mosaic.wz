---@module "mosaic.presets.brackets"
---@author sravioli
---@license GNU-GPLv2

---Accent-coloured text in dim square brackets on the bar background, with
---ASCII separators.

local mosaic = require "mosaic.api"

---Each module's colour as text between dim brackets. `style.separators`
---replaces the brackets (`left` before, `right` after).
---@param  spec table module spec (content only)
---@param  ctx  table decorate context
---@return table
local function decorate(spec, ctx)
  local out = mosaic.pad_inside(spec)
  local fg = mosaic.palette.color(ctx, spec)
  local seps = ctx.style.separators or {}
  local dim = mosaic.palette.pick(ctx, "dim", 9)
  -- Explicit bar colour: an unset bg is transparent, which shows the terminal
  -- background instead of the bar.
  out.style = function(t)
    return { fg = fg, bg = mosaic.palette.bar_bg(t, ctx.config) }
  end
  out.sep = {
    enabled = true,
    -- The gap lives in the separator, since module padding is drawn unstyled.
    value = { right = " " .. (seps.left or "["), left = seps.right or "]" },
    style = function(t)
      return { fg = dim, bg = mosaic.palette.bar_bg(t, ctx.config) }
    end,
  }
  return out
end

local DEFAULTS = {
  colors = { active = 5, hover = "foreground", inactive = 9, dim = 9 },
  separators = { left = "[", right = "]" },
}

---@param  ctx Mosaic.TabContext
---@return table[] segments
local function tab(ctx)
  local s = mosaic.palette.tab(ctx, DEFAULTS)
  local edge = ctx.state == "active" and s.fill or s.dim
  local head = s.index ~= "" and s.index .. " " or ""
  local title = ctx.title(ctx.max_width - mosaic.width(" " .. s.left .. head .. s.right))
  return {
    { s.bar, nil, " " },
    { s.bar, edge, s.left },
    { s.bar, s.fill, head .. title },
    { s.bar, edge, s.right },
  }
end

---@param  ctx { theme: table, config: table, hover: boolean, style: table }
---@return table[] segments
local function new_tab(ctx)
  local s = mosaic.palette.tab(ctx, {
    colors = { hover = 5, inactive = 9, dim = 9 },
    separators = DEFAULTS.separators,
  })
  return {
    { s.bar, nil, " " },
    { s.bar, s.dim, s.left },
    { s.bar, s.fill, s.label },
    { s.bar, s.dim, s.right },
  }
end

return {
  decorate = decorate,
  tabs = { format = tab, new_tab = new_tab },
  layout = {
    left = { "mode", "leader", "workspace", "zoomed" },
    right = { "notice", "hints", { "process", "cwd", "cpu", "ram", "clock", "battery" } },
  },
}
