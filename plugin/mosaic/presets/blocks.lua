---@module "mosaic.presets.blocks"
---@author sravioli
---@license GNU-GPLv2

---Flat blocks in each accent colour, one column apart, with no separator
---glyphs.

local mosaic = require "mosaic.api"

---Every module a flat block in its colour. `style.separators` adds edges
---drawn in the block colour (`left` before, `right` after).
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
  out.sep = {
    enabled = true,
    -- The gap lives in the separator: module padding is drawn unstyled, and an
    -- unset bg is transparent, which shows the terminal background, not the bar.
    value = { right = " " .. (seps.left or ""), left = seps.right },
    style = function(t, parent)
      return { bg = mosaic.palette.bar_bg(t, ctx.config), fg = parent.bg }
    end,
  }
  return out
end

local DEFAULTS = { colors = { active = 5, hover = 7, inactive = 9, text = "background" } }

---@param  ctx Mosaic.TabContext
---@return table[] segments
local function tab(ctx)
  local s = mosaic.palette.tab(ctx, DEFAULTS)
  local head = " " .. s.index .. " "
  local title = ctx.title(ctx.max_width - mosaic.width(" " .. s.left .. head .. " " .. s.right))
  return {
    { s.bar, nil, " " },
    { s.bar, s.fill, s.left },
    { s.fill, s.text, head .. title .. " " },
    { s.bar, s.fill, s.right },
  }
end

---@param  ctx { theme: table, config: table, hover: boolean, style: table }
---@return table[] segments
local function new_tab(ctx)
  local s = mosaic.palette.tab(ctx, DEFAULTS)
  return {
    { s.bar, nil, " " },
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
