---@module "mosaic.engine.render.resolve"
---@author sravioli
---@license GNU-GPLv2

---Module lookup: alias resolution, per-window `update` caching, and the
---user's `options[name]` merged into each spec.

-- Live options table. `mosaic.config.setup()` updates it in place.
local Opts = require("mosaic.engine.config").live ---@class Mosaic.Options

local log = require "mosaic.engine.logger"

local M = require "mosaic.engine.render.state"
local failed = {} -- module names already logged as failing
-- Specs returned by function modules that declare `update`, keyed by window
-- id then module name. Window objects are fresh per event, ids are stable.
local spec_cache = {}

---Drop what is cached for a closed window.
---@param id integer window id
function M.forget(id)
  spec_cache[id] = nil
end

---@param  entry table
---@return boolean
local function still_fresh(entry)
  if entry.key_fn then
    -- A raising key (a pane that just closed) means stale, not a dead bar.
    local ok, key = pcall(entry.key_fn, M.window, M.pane)
    if not ok or entry.key ~= key then
      return false
    end
  end
  return entry.expires == nil or os.time() < entry.expires
end

---Copy of `base` with `patch` merged in recursively. Neither is modified,
---so shared module tables stay intact.
---@param  base  table
---@param  patch table
---@return table
function M.merge(base, patch)
  local out = {}
  for k, v in pairs(base) do
    out[k] = v
  end
  for k, v in pairs(patch) do
    if type(v) == "table" and type(out[k]) == "table" then
      out[k] = M.merge(out[k], v)
    else
      out[k] = v
    end
  end
  return out
end

-- `options[name]` keys merged into every spec of that module. Other keys are
-- for the module itself (a built-in's format, an integration's options).
local SPEC_KEYS = {
  accent = true,
  can_hide = true,
  cond = true,
  enabled = true,
  icon = true,
  min_text = true,
  padding = true,
  priority = true,
  sep = true,
  style = true,
  text = true,
}

local with_fmt

-- Patched specs by source spec, so cached and static specs merge once.
local patched = setmetatable({}, { __mode = "k" })

---Spec patch from a module's options: `icon`/`text` may be `false` (hide)
---or a string (the value) as well as a table.
---@param  opts table
---@return table|nil
local function spec_patch(opts)
  local patch
  for k, v in pairs(opts) do
    if SPEC_KEYS[k] then
      if (k == "icon" or k == "text") and type(v) ~= "table" then
        v = v == false and { enabled = false } or { enabled = true, value = v }
      end
      patch = patch or {}
      patch[k] = v
    end
  end
  return patch
end

---A text value passed through `fmt(text, window, pane)`.
---@param  value any string or fun(window, pane)
---@param  fmt   function
---@return function
local function fmt_value(value, fmt)
  return function(window, pane)
    local text = value
    if type(value) == "function" then
      text = value(window, pane)
    end
    return tostring(fmt(tostring(text or ""), window, pane) or "")
  end
end

---Copy of `spec` whose text and variants go through `fmt`, so every form
---the fitter tries is formatted.
---@param  spec table
---@param  fmt  function
---@return table
with_fmt = function(spec, fmt)
  if type(spec.text) ~= "table" or spec.text.value == nil then
    return spec
  end
  local text = M.merge(spec.text, {})
  text.value = fmt_value(spec.text.value, fmt)
  if type(spec.text.variants) == "table" then
    text.variants = {}
    for i, v in ipairs(spec.text.variants) do
      text.variants[i] = fmt_value(v, fmt)
    end
  end
  local out = M.merge(spec, {})
  out.text = text
  return out
end

---`spec` with the user's options for `names` merged in (the alias target's
---first, then the layout name's).
---@param  spec  any
---@param  names string[]
---@return any
local function apply_options(spec, names)
  local all = Opts.options
  if type(spec) ~= "table" or spec.enabled == false or not all then
    return spec
  end
  local hit = patched[spec]
  if hit then
    local same = #hit.opts == #names
    for i, name in ipairs(names) do
      same = same and hit.opts[i] == all[name]
    end
    if same then
      return hit.out
    end
  end
  local out, used = spec, {}
  for i, name in ipairs(names) do
    local opts = all[name]
    used[i] = opts
    local patch = type(opts) == "table" and spec_patch(opts)
    if patch then
      out = M.merge(out, patch)
    end
  end
  for i = 1, #names do
    local opts = used[i]
    if type(opts) == "table" and type(opts.fmt) == "function" then
      out = with_fmt(out, opts.fmt)
    end
  end
  patched[spec] = { opts = used, out = out }
  return out
end

---Look up a module by name and, when it is a function, call it for the
---current window/pane, then merge in `options[name]`. Returns nil for
---unknown names.
---
---A function module may return a spec with `update`: a number or
---`{ interval = seconds }` reuses the spec until the interval passes, a
---`fun(window, pane): any` reuses it while the returned key is unchanged.
---`options[name].update` overrides it. Only the resolved spec is reused;
---fitting still runs every frame.
---@param  name string
---@return Mosaic.Module|nil
function M.resolve_module(name)
  local module = Opts.modules[name]
  local names = { name }
  if type(module) == "string" then
    -- One hop only, so alias cycles cannot loop.
    names = { module, name }
    module = Opts.modules[module]
    if type(module) == "string" then
      return nil
    end
  end
  return apply_options(M.call_module(name, module, names), names)
end

---The option names for layout name `name`: its alias target's, then its own.
---@param  name string
---@return string[]
function M.option_names(name)
  local target = Opts.modules[name]
  return type(target) == "string" and { target, name } or { name }
end

---@param  name   string
---@param  module any
---@param  names? string[] option names (default `{ name }`)
---@return any spec
function M.call_module(name, module, names)
  if type(module) ~= "function" then
    return module
  end

  local per_window = spec_cache[M.window_id]
  if not per_window then
    per_window = {}
    spec_cache[M.window_id] = per_window
  end
  local entry = per_window[name]
  if entry and entry.fn == module and entry.scheme == M.scheme and still_fresh(entry) then
    return entry.spec
  end
  -- Once per frame: edge detection looks ahead at later modules.
  local seen = M.frame[name]
  if seen and seen.fn == module then
    return seen.spec
  end

  local started = M.profile and os.clock()
  local ok, spec = pcall(module, M.window, M.pane, M.theme, M.config)
  if not ok then
    -- One failing module must not stop the whole bar: log it once, hide it.
    if not failed[name] then
      failed[name] = true
      log:error("module %q failed: %s", name, tostring(spec))
    end
    spec = { enabled = false }
  end
  if started then
    M.profile[name] = (M.profile[name] or 0) + (os.clock() - started)
  end
  M.frame[name] = { fn = module, spec = spec }
  local update = type(spec) == "table" and spec.update or nil
  for _, n in ipairs(names or { name }) do
    local opts = Opts.options and Opts.options[n]
    if type(opts) == "table" and opts.update ~= nil then
      update = opts.update -- false turns caching off
    end
  end
  if not update then
    per_window[name] = nil
    return spec
  end

  entry = { fn = module, scheme = M.scheme, spec = spec }
  -- `fun` keeps it while the key holds; `seconds` / `{ interval }` until it
  -- expires; `{ key, interval }` while both hold.
  local key_fn = type(update) == "function" and update or type(update) == "table" and update.key
  local interval = type(update) == "table" and update.interval or tonumber(update)
  if key_fn then
    entry.key_fn = key_fn
    local kok, key = pcall(key_fn, M.window, M.pane)
    entry.key = kok and key or nil
  end
  if interval or not key_fn then
    entry.expires = os.time() + (tonumber(interval) or 0)
  end
  per_window[name] = entry
  return spec
end

return M
