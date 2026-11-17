---@module "mosaic.engine.icons"
---@author sravioli
---@license GNU-GPLv2

---Glyph maps shared by the `process` / `domain` modules and the tab
---components. Users merge their own over these with an `icons` option.

local wezterm = require "wezterm"

local nf = wezterm.nerdfonts

local M = {}

---Programs sigil has no entry for; sigil's registry covers the rest.
M.PROCESS = {
  python3 = nf.dev_python,
  top = nf.md_chart_areaspline,
}

---Glyph for a program neither sigil nor `PROCESS` knows.
M.PROCESS_DEFAULT = nf.md_console

---Domain name prefix -> glyph, tried longest first.
M.DOMAIN = {
  local_ = nf.md_monitor,
  SSH = nf.md_ssh,
  SSHMUX = nf.md_ssh,
  WSL = nf.md_microsoft_windows,
  docker = nf.md_docker,
  unix = nf.cod_terminal_linux,
}

---Glyph for `name` from `defaults` overlaid by `user`; `fallback` otherwise.
---@param  defaults table
---@param  user     table|nil
---@param  name     string
---@param  fallback string|nil
---@return string|nil
function M.lookup(defaults, user, name, fallback)
  local glyph = user and user[name]
  if glyph == nil then
    glyph = defaults[name]
  end
  if glyph == nil then
    return fallback
  end
  return glyph or nil -- false: no glyph
end

---Glyph for a domain name: an exact name, else the longest matching prefix.
---@param  name string
---@param  user table|nil
---@return string|nil
function M.domain(name, user)
  local exact = M.lookup(M.DOMAIN, user, name == "local" and "local_" or name)
  if exact or (user and user[name] == false) then
    return exact
  end
  local best, len = nil, 0
  for i, map in ipairs { M.DOMAIN, user or {} } do
    for prefix, glyph in pairs(map) do
      -- The user's map wins ties.
      local longer = #prefix > len or (i == 2 and #prefix == len)
      if longer and name:sub(1, #prefix) == prefix then
        best, len = glyph, #prefix
      end
    end
  end
  return best or nf.md_server_network
end

---Glyph for a process basename.
---@param  name string
---@param  user table|nil
---@return string|nil
function M.process(name, user)
  if user == nil or user[name] == nil then
    local entry = require("mosaic.engine.deps").sigil().get(name, { fallback = false })
    if entry and entry.icon then
      return entry.icon
    end
  end
  return M.lookup(M.PROCESS, user, name, M.PROCESS_DEFAULT)
end

return M
