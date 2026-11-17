---@module "mosaic.engine.icons"
---@author sravioli
---@license GNU-GPLv2

---Glyph maps shared by the `process` / `domain` modules and the tab
---components. Users merge their own over these with an `icons` option.

local M = {}

---A sigil symbol by dotted path, or `fallback` (default `""`) when this sigil
---has no such path, e.g. an older cached clone.
---@param  path      string
---@param  fallback? string
---@return string
function M.symbol(path, fallback)
  local glyph = require("mosaic.engine.deps").sigil().symbol(path)
  if type(glyph) ~= "string" then
    return fallback or ""
  end
  return glyph
end

---Domain name prefix -> sigil symbol path, tried longest first.
M.DOMAIN = {
  local_ = "Domain.local",
  SSH = "Domain.ssh",
  SSHMUX = "Domain.ssh",
  WSL = "Domain.wsl",
  docker = "Domain.docker",
  unix = "Domain.unix",
}

---Glyphs for `M.DOMAIN`, resolved through sigil at call time.
---@return table
local function domain_glyphs()
  local out = {}
  for prefix, path in pairs(M.DOMAIN) do
    out[prefix] = M.symbol(path)
  end
  return out
end

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
  local defaults = domain_glyphs()
  local exact = M.lookup(defaults, user, name == "local" and "local_" or name)
  if exact or (user and user[name] == false) then
    return exact
  end
  local best, len = nil, 0
  for i, map in ipairs { defaults, user or {} } do
    for prefix, glyph in pairs(map) do
      -- The user's map wins ties.
      local longer = #prefix > len or (i == 2 and #prefix == len)
      if longer and name:sub(1, #prefix) == prefix then
        best, len = glyph, #prefix
      end
    end
  end
  return best or M.symbol "Domain.default"
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
  return M.lookup({}, user, name, M.symbol "Process")
end

return M
