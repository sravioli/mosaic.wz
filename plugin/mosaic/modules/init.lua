---@module "mosaic.modules"
---@author sravioli
---@license GNU-GPLv2

---Built-in module registry. Modules load on first lookup, so sigil and the
---module code are only pulled in when a layout names them.
---
---```lua
---local clock = mosaic.modules.clock -- wrap a builtin instead of rewriting it
---```

local integrations = require "mosaic.engine.integrations"
local log = require "mosaic.engine.logger"

local BUILTINS = {
  badges = true,
  battery = true,
  clock = true,
  cpu = true,
  cwd = true,
  disk = true,
  domain = true,
  git = true,
  hints = true,
  hostname = true,
  kube = true,
  leader = true,
  media = true,
  mode = true,
  notice = true,
  network = true,
  panes = true,
  parent = true,
  process = true,
  progress = true,
  ram = true,
  ssh = true,
  tabs = true,
  title = true,
  username = true,
  window = true,
  workspace = true,
  zoomed = true,
}

local warned = {}

---@type table<string, Mosaic.Module|function>
return setmetatable({}, {
  __index = function(registry, name)
    -- `<plugin>.<module>`: another plugin's integration, cached there (its
    -- instance depends on the options passed to setup()).
    if integrations.parse(name) then
      return integrations.get(name)
    end
    if not BUILTINS[name] then
      if not warned[name] then
        warned[name] = true
        log:warn("unknown module %q", tostring(name))
      end
      return nil
    end
    local module = require("mosaic.modules." .. name)
    rawset(registry, name, module)
    return module
  end,
})
