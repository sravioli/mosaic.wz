---@module "mosaic.modules.cell"
---@author sravioli
---@license GNU-GPLv2

---Shared constructor for the content-only built-ins: icon + text, hideable
---when space runs out. The preset's `decorate` styles them.

local wezterm = require "wezterm"

---@param  glyph   string  nerdfonts name
---@param  text    string
---@param  update? any     forwarded as the spec's `update`
---@return Mosaic.Module
return function(glyph, text, update)
  return {
    enabled = true,
    cond = true,
    can_hide = true,
    update = update,
    padding = { left = 1 },
    icon = { enabled = true, value = wezterm.nerdfonts[glyph] or "", padding = { right = 1 } },
    text = { enabled = true, value = text },
  }
end
