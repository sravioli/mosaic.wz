---@module "mosaic.modules.zoomed"
---@author sravioli
---@license GNU-GPLv2

---Shows ZOOM while the active pane is zoomed.

local wezterm = require "wezterm"

return {
  enabled = true,
  cond = function(window)
    local tab = window:active_tab()
    if not tab then
      return false
    end
    for _, info in ipairs(tab:panes_with_info()) do
      if info.is_zoomed then
        return true
      end
    end
    return false
  end,
  padding = { left = 1 },
  icon = {
    enabled = true,
    value = wezterm.nerdfonts.md_arrow_expand_all,
  },
  text = {
    enabled = true,
    value = "ZOOM",
    padding = { left = 1, right = 1 },
    style = { attributes = "i" },
    trim = false,
  },
}
