---@module "mosaic.modules.badges"
---@author sravioli
---@license GNU-GPLv2

---How many other tabs have a badge (see `tabs.badges`), in the colour
---of the first one's badge; hidden at zero.

local wezterm = require "wezterm"

local badges = require "mosaic.tabs.badges"

return function(window)
  local pending = badges.pending(window)
  if #pending == 0 then
    return { enabled = false }
  end
  local first = pending[1]
  return {
    enabled = true,
    cond = true,
    can_hide = true,
    tint = first.color,
    padding = { left = 1 },
    icon = {
      enabled = true,
      value = first.icon or wezterm.nerdfonts.md_bell_ring or "",
      padding = { right = 1 },
    },
    text = { enabled = true, value = tostring(#pending) },
  }
end
