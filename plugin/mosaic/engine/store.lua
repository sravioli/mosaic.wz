---@module "mosaic.engine.store"
---@author sravioli
---@license GNU-GPLv2

---Records in `wezterm.GLOBAL`. WezTerm hands a stored table back as a proxy
---userdata, not a Lua table, so `type(v) == "table"` checks fail on it. Read
---records through `get`, which copies the named fields into a plain table.

local wezterm = require "wezterm"

local M = {}

---@param  key    string
---@param  fields string[]
---@return table|nil record plain copy, or nil when nothing (or false) is stored
function M.get(key, fields)
  local v = wezterm.GLOBAL[key]
  local kind = type(v)
  if kind ~= "table" and kind ~= "userdata" then
    return nil
  end
  local out = {}
  for _, f in ipairs(fields) do
    local ok, x = pcall(function()
      return v[f]
    end)
    if ok then
      out[f] = x
    end
  end
  return out
end

---@param key    string
---@param record table|false|number|string|nil
function M.set(key, record)
  wezterm.GLOBAL[key] = record
end

---A scalar (number, string, boolean) stored under `key`.
---@param  key string
---@return any
function M.value(key)
  local v = wezterm.GLOBAL[key]
  local kind = type(v)
  if kind == "table" or kind == "userdata" then
    return nil
  end
  return v
end

---A record to read and write field by field, created empty when missing.
---Writes go through to `wezterm.GLOBAL`; never test it with `type`.
---@param  key string
---@return table|userdata
function M.record(key)
  local global = wezterm.GLOBAL
  if global == nil then
    return {}
  end
  if global[key] == nil then
    global[key] = {}
  end
  return global[key]
end

return M
