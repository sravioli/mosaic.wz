---@module "mosaic.modules.cwd"
---@author sravioli
---@license GNU-GPLv2

---Current working directory (git root when inside a repository, unless
---`git_root = false`). Options: `home = "~"` (replace the home directory),
---`aliases = { { pattern, replacement } }`, `max_length`.

local cond = require "mosaic.engine.conditions"
local config = require "mosaic.engine.config"
local deps = require "mosaic.engine.deps"

local paths = require "mosaic.engine.paths"

local fs = deps.warp.filesystem
local icons = deps.icons()

return function(_, pane)
  local opts = config.option "cwd"
  local cwd = fs.get_cwd(pane, opts.git_root ~= false)
  if opts.home or opts.aliases or opts.max_length then
    cwd = paths.shorten(cwd, opts)
  end
  return {
    enabled = true,
    cond = cond.hints_inactive,
    can_hide = true,
    -- The git-root walk opens a file per parent directory: redo it only when
    -- the pane's directory changes, or every few seconds (a `git init`).
    update = {
      key = function(_, p)
        return paths.cwd(p)
      end,
      interval = opts.interval or 5,
    },
    icon = {
      enabled = true,
      value = icons.Folder,
      position = "right",
      padding = { right = 1 },
    },
    text = {
      enabled = true,
      value = cwd,
      padding = 1,
    },
  }
end
