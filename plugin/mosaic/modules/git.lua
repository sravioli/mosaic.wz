---@module "mosaic.modules.git"
---@author sravioli
---@license GNU-GPLv2

---Branch of the repository the pane's directory is in (the short commit when
---HEAD is detached). Reads `.git/HEAD` only, no git process, so it never
---blocks; re-read when the directory changes and every `interval` seconds.
---Options: `interval` (default 5), `detached = false` (hide detached HEADs).

local icons = require "mosaic.engine.icons"

local config = require "mosaic.engine.config"
local paths = require "mosaic.engine.paths"

local M = {}

---@param  file string
---@return string|nil
local function read(file)
  local f = io.open(file, "r")
  if not f then
    return nil
  end
  local ok, text = pcall(f.read, f, "*a")
  f:close()
  return ok and text or nil
end

---Path of the HEAD file of the repository containing `dir`.
---@param  dir string
---@return string|nil
function M.head_file(dir)
  local path = dir
  while path and path ~= "" do
    local base = path:gsub("[/\\]+$", "")
    if base == "" then
      base = "/"
    end
    local sep = base:sub(-1) == "/" and "" or "/"
    if read(base .. sep .. ".git/HEAD") then
      return base .. sep .. ".git/HEAD"
    end
    -- Worktrees and submodules: `.git` is a file naming the git dir.
    local gitfile = read(base .. sep .. ".git")
    local gitdir = gitfile and gitfile:match "gitdir:%s*([^\r\n]+)"
    if gitdir then
      if not gitdir:match "^/" and not gitdir:match "^%a:" then
        gitdir = base .. sep .. gitdir
      end
      return gitdir .. "/HEAD"
    end
    local parent = paths.parent(base)
    if not parent or parent == base then
      break
    end
    path = parent ~= "" and parent or "/"
  end
  return nil
end

---Branch name, or the short sha for a detached HEAD.
---@param  dir string
---@return string|nil name, boolean|nil detached
function M.branch(dir)
  local head = M.head_file(dir)
  local text = head and read(head)
  if not text then
    return nil
  end
  local ref = text:match "^ref:%s*refs/heads/([^\r\n]+)"
  if ref then
    return ref, false
  end
  local sha = text:match "^(%x+)"
  return sha and sha:sub(1, 7) or nil, true
end

return function(_, pane)
  local cwd = paths.cwd(pane)
  if not cwd then
    return { enabled = false }
  end
  local opts = config.option "git"
  local name, detached = M.branch(cwd)
  if not name or (detached and opts.detached == false) then
    return { enabled = false }
  end
  return {
    enabled = true,
    cond = true,
    can_hide = true,
    update = {
      key = function(_, p)
        return paths.cwd(p)
      end,
      interval = opts.interval or 5,
    },
    padding = { left = 1 },
    icon = {
      enabled = true,
      value = detached and icons.symbol "Git.commit" or icons.symbol "Git.branch",
      padding = { right = 1 },
    },
    text = { enabled = true, value = name },
  }
end
