---@module "mosaic.modules.parent"
---@author sravioli
---@license GNU-GPLv2

---Name of the parent of the current directory. Options as `cwd`'s
---`home`, `aliases` and `max_length`, plus `full = true` for the whole
---parent path.

local cell = require "mosaic.modules.cell"
local config = require "mosaic.engine.config"
local paths = require "mosaic.engine.paths"
local warp = require("mosaic.engine.deps").warp

return function(_, pane)
  local cwd = warp.filesystem.get_cwd(pane)
  local parent = cwd ~= "" and warp.path.dirname(cwd) or nil
  if not parent or parent == "." then
    return { enabled = false }
  end
  local opts = config.option "parent"
  local text = parent == "/" and "/" or warp.filesystem.basename(parent)
  if opts.full then
    text = paths.shorten(parent, opts)
  elseif opts.max_length then
    text = paths.shorten(text, { max_length = opts.max_length })
  end
  return cell("md_folder_open", text)
end
