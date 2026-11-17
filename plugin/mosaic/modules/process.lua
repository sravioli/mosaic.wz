---@module "mosaic.modules.process"
---@author sravioli
---@license GNU-GPLv2

---Foreground process of the active pane (basename), with an icon per
---process. Options: `icons` (merged over the built-in map; `false` drops a
---glyph), `icon_only`.

local cell = require "mosaic.modules.cell"
local config = require "mosaic.engine.config"
local icons = require "mosaic.engine.icons"
local fs = require("mosaic.engine.deps").warp.filesystem

return function(_, pane)
  local ok, path = pcall(pane.get_foreground_process_name, pane)
  if not ok or not path or path == "" then
    return { enabled = false }
  end
  local opts = config.option "process"
  local name = fs.basename(path):gsub("%.exe$", "")
  local spec = cell("Process", name)
  local glyph = icons.process(name, opts.icons)
  spec.icon.enabled = glyph ~= nil and glyph ~= ""
  spec.icon.value = glyph or ""
  if opts.icon_only and spec.icon.enabled then
    spec.text.enabled = false
    spec.icon.padding = 0
  end
  return spec
end
