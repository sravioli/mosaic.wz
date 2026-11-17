---@module "mosaic.engine.deps"
---@author sravioli
---@license GNU-GPLv2

---Dependency loader. Prefers modules already on `package.path` (local dev
---checkouts, specs) and falls back to `wezterm.plugin.require`.
---
---The engine needs warp, log, warden and ribbon. sigil is only needed by the
---built-in modules and presets, so it is loaded on first use.

local wezterm = require "wezterm"

---@class Mosaic.Deps
---@field warp   Warp.Api
---@field log    table
---@field warden Warden
---@field ribbon table
local M = {}

local URL = "https://github.com/sravioli/%s.wz"

---@param module string
---@param name   string
---@return table
local function require_plugin(module, name)
  local ok, plugin = pcall(require, module)
  if ok and plugin then
    return plugin
  end

  ok, plugin = pcall(wezterm.plugin.require, URL:format(name))
  if ok and plugin then
    return plugin
  end

  error(("[mosaic] unable to load dependency %s: %s"):format(name, tostring(plugin)))
end

M.warp = require_plugin("warp.api", "warp")
M.log = require_plugin("log.api", "log")
M.warden = require_plugin("warden.api", "warden")
M.ribbon = require_plugin("ribbon.api", "ribbon")

local sigil, sigil_symbols

---The sigil plugin (program icons and symbols), loaded on first call.
---@return table
function M.sigil()
  if not sigil then
    sigil = require_plugin("sigil.api", "sigil")
  end
  return sigil
end

---Whether sigil has been loaded (a layout named a built-in or a preset ran).
---@return boolean
function M.icons_loaded()
  return sigil ~= nil
end

---Icon table from sigil, loaded on first call.
---@return table
function M.icons()
  if not sigil_symbols then
    sigil_symbols = M.sigil().symbols()
  end
  return sigil_symbols
end

return M
