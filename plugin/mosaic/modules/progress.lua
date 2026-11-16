---@module "mosaic.modules.progress"
---@author sravioli
---@license GNU-GPLv2

---Progress the active pane's program reports (OSC 9;4, WezTerm nightly), e.g.
---a build or a download; hidden without any. Errors take `error_color`
---(default red, `2`). Options: `error_color`, `icon = false`.

local config = require "mosaic.engine.config"
local progress = require "mosaic.engine.progress"

return function(_, pane)
  local ok, raw = pcall(function()
    return pane:get_progress()
  end)
  local p = ok and progress.read(raw) or nil
  if not p then
    return { enabled = false }
  end
  local opts = config.option "progress"
  local text = progress.text(p)
  local icon = opts.icon ~= false
  return {
    enabled = true,
    cond = true,
    can_hide = true,
    tint = p.kind == "error" and (opts.error_color or 2) or nil,
    padding = { left = 1 },
    icon = {
      enabled = icon,
      value = progress.glyph(p),
      padding = { right = text ~= "" and 1 or 0 },
    },
    text = { enabled = text ~= "", value = text },
  }
end
