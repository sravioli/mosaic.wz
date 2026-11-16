---@module "mosaic.modules.username"
---@author sravioli
---@license GNU-GPLv2

---User name: the shell-integration `WEZTERM_USER` user var when set (it
---follows ssh sessions), otherwise $USER / %USERNAME%.

local cell = require "mosaic.modules.cell"

return function(_, pane)
  local ok, vars = pcall(pane.get_user_vars, pane)
  local name = ok and vars and vars.WEZTERM_USER or os.getenv "USER" or os.getenv "USERNAME"
  if not name or name == "" then
    return { enabled = false }
  end
  return cell("md_account", name)
end
