---@module "mosaic.modules.ssh"
---@author sravioli
---@license GNU-GPLv2

---Shown while the active pane is remote: an SSH domain, or `ssh` running
---in the foreground.

local cell = require "mosaic.modules.cell"
local fs = require("mosaic.engine.deps").warp.filesystem

return function(_, pane)
  local ok, domain = pcall(pane.get_domain_name, pane)
  if ok and domain and domain:match "^SSH" then
    local host = domain:gsub("^SSHMUX:", ""):gsub("^SSH:", "")
    return cell("md_lan_connect", host)
  end
  local pok, path = pcall(pane.get_foreground_process_name, pane)
  if pok and path and fs.basename(path) == "ssh" then
    return cell("md_lan_connect", "ssh")
  end
  return { enabled = false }
end
