---@module "mosaic.presets.bubbles"
---@author sravioli
---@license GNU-GPLv2

---Every module is a rounded pill in its accent colour.

local wezterm = require "wezterm"

local mosaic = require "mosaic.api"

local nf = wezterm.nerdfonts
---Every module a rounded pill in its colour. `style.separators` replaces
---the caps (`left` before, `right` after).
---@param  spec table module spec (content only)
---@param  ctx  table decorate context
---@return table
local function decorate(spec, ctx)
  local out = mosaic.copy(spec)
  local pill = mosaic.palette.color(ctx, spec)
  local seps = ctx.style.separators or {}
  out.padding = { left = 1, right = 0 }
  local text = mosaic.palette.pick(ctx, "text", "background")
  out.style = function()
    return { bg = pill, fg = text }
  end
  out.sep = {
    enabled = true,
    value = {
      right = seps.left or nf.ple_left_half_circle_thick or "",
      left = seps.right or nf.ple_right_half_circle_thick or "",
    },
    -- No background: the bar's own surface shows around the pill.
    style = function(_, parent)
      return { fg = parent.bg }
    end,
  }
  return out
end

local CAPS = {
  left = nf.ple_left_half_circle_thick or "",
  right = nf.ple_right_half_circle_thick or "",
}

---@param  ctx Mosaic.TabContext
---@return table[] segments
local function tab(ctx)
  local s = mosaic.palette.tab(ctx, {
    colors = { active = 5, hover = 7, inactive = 9, text = "background" },
    separators = CAPS,
  })
  local head = " " .. s.index .. " "
  local title = ctx.title(ctx.max_width - mosaic.width(" " .. s.left .. head .. s.right))
  return {
    { s.bar, nil, " " },
    { s.bar, s.fill, s.left },
    { s.fill, s.text, head .. title },
    { s.bar, s.fill, s.right },
  }
end

---@param  ctx { theme: table, config: table, hover: boolean, style: table }
---@return table[] segments
local function new_tab(ctx)
  local s = mosaic.palette.tab(ctx, {
    colors = { hover = 7, inactive = 9, text = "background" },
    separators = CAPS,
  })
  return {
    { s.bar, nil, " " },
    { s.bar, s.fill, s.left },
    { s.fill, s.text, s.label },
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
