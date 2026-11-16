---@module "mosaic.modules.domain"
---@author sravioli
---@license GNU-GPLv2

---Multiplexer domain of the active pane; hidden for the local domain unless
---`show_local = true`. `icons` maps domain names or prefixes to glyphs.

local cell = require "mosaic.modules.cell"
local config = require "mosaic.engine.config"
local icons = require "mosaic.engine.icons"

return function(_, pane)
  local opts = config.option "domain"
  local ok, name = pcall(pane.get_domain_name, pane)
  if not ok or not name or (name == "local" and not opts.show_local) then
    return { enabled = false }
  end
  local spec = cell("md_server_network", name)
  local glyph = icons.domain(name, opts.icons)
  spec.icon.enabled = glyph ~= nil and glyph ~= ""
  spec.icon.value = glyph or ""
  return spec
end
