---@module "mosaic.engine.config"
---@author sravioli
---@license GNU-GPLv2

---Option schema, preset resolution and the live options table.
---
---`M.live` keeps its identity across `setup()` calls: the renderer holds a
---reference to it and reads the current values on every frame.
---
---Invalid options never abort the WezTerm config: issues are logged and the
---offending top-level fields fall back to their defaults.

local deps = require "mosaic.engine.deps"
local log = require "mosaic.engine.logger"

local w = deps.warden

local M = {}

M.FITS = { "greedy", "balanced", "exhaustive" }

local function fn()
  return w.any():refine(function(v)
    return type(v) == "function"
  end, "Expected function")
end

local item = w.union { w.string():not_empty(), w.array(w.string():not_empty()) }

-- A colour: `theme.ansi` 1-8, `theme.brights` 9-16, "foreground" /
-- "background", a colour string, or fun(theme): colour.
local color = w.union { w.integer(), w.string():not_empty(), fn() }
local edges = w.object({
  left = w.string():optional(),
  right = w.string():optional(),
  between = w.string():optional(), -- between modules inside a group
}):optional()

M.schema = w.object({
  enabled = w.boolean():default(true),
  position = w.enum({ "top", "bottom" }):default "bottom",
  flexible = w.boolean():default(true),
  fit = w.enum(M.FITS):default "balanced",
  preset = w.string():not_empty():optional(),
  -- A table, or fun(window, pane): table to choose one per window, workspace,
  -- domain or key table on every frame.
  layout = w.union({
    w.object {
      left = w.array(item):optional(),
      center = w.array(item):optional(),
      right = w.array(item):optional(),
    },
    fn(),
  }):optional(),
  -- Where `layout.center` sits (see mosaic.engine.center).
  center = w.object({
    anchor = w.enum({ "window", "free" }):optional(),
    overflow = w.enum({ "shift", "hide" }):optional(),
    margin = w.integer():optional(),
  }):optional(),
  -- A string value aliases another module name, e.g. `hints = "chord.hints"`.
  modules = w.map(w.string():not_empty(), w.union { w.table(), fn(), w.string():not_empty() })
    :optional(),
  -- Per-module options by name: merged into the module's spec every frame
  -- (icon, text, padding, cond, ...) and passed to integrations and
  -- built-ins that read their own keys.
  options = w.map(w.string():not_empty(), w.table()):optional(),
  -- Colours and separators the preset's decorator applies to every module
  -- that does not style itself.
  style = w.object({
    colors = w.map(w.string():not_empty(), color):optional(),
    separators = edges,
    -- Module names drawn plain: their colour on the bar background, no separators.
    raw = w.array(w.string():not_empty()):optional(),
    text = color:optional(), -- text on filled modules
    dim = color:optional(), -- muted text and glyphs
    gradient = w.object({
      base = color:optional(),
      stops = w.array(w.number()):optional(),
    }):optional(),
    -- Key table name (or "leader") -> style merged in while it is active.
    by_mode = w.map(w.string():not_empty(), w.table()):optional(),
  }):optional(),
  -- Another colour scheme's palette for the bar (its name, or a scheme table).
  scheme = w.union({ w.string():not_empty(), w.table() }):optional(),
  decorate = fn():optional(),
  tabs = w.union({
    w.literal(false),
    w.object {
      format = fn():optional(),
      title = fn():optional(),
      new_tab = fn():optional(),
      -- Tab text from components; a list, or `{ active, inactive }` lists.
      content = w.table():optional(),
      -- `{ match = {...}, style = {...}, icon = "" }`, applied in order.
      rules = w.array(w.object {
        match = w.table(), -- required: a rule without one would match every tab
        style = w.table():optional(),
        icon = w.union({ w.string(), w.literal(false) }):optional(),
      }):optional(),
      -- Badges for tabs that need you (bell, output, a user var).
      badges = w.union({ w.literal(true), w.table() }):optional(),
      -- Read by the presets' tab and new-tab drawing.
      style = w.object({
        colors = w.map(w.string():not_empty(), color):optional(),
        separators = edges,
        index = w.union({ w.enum { "number", "number0", "icon" }, w.literal(false), fn() })
          :optional(),
        padding = w.union({ w.integer(), w.table() }):optional(),
        unseen = w.union({ w.string(), w.literal(false) }):optional(),
        new_tab = w.string():optional(),
      }):optional(),
    },
  }):optional(),
}):unknown "warn"

---@type Mosaic.Options
M.live = {
  enabled = true,
  position = "bottom",
  flexible = true,
  fit = "balanced",
  layout = { left = {}, center = {}, right = {} },
  tabs = {},
  options = {},
  modules = setmetatable({}, { __index = require "mosaic.modules" }),
}

local layout_failed = false

---The layout for `window`: the user's function's answer (sides it leaves
---out are empty), else the static layout. A failing function is logged once
---and the static layout used.
---@param  window table
---@param  pane   table
---@return { left: table, center: table, right: table }
function M.layout_for(window, pane)
  local live = M.live
  if not live.layout_fn then
    return live.layout
  end
  local ok, out = pcall(live.layout_fn, window, pane)
  if not ok or type(out) ~= "table" then
    if not ok and not layout_failed then
      layout_failed = true
      log:error("layout function failed: %s", tostring(out))
    end
    return live.layout
  end
  return { left = out.left or {}, center = out.center or {}, right = out.right or {} }
end

---The user's `options[name]`, or an empty table. Built-ins read their own
---keys from it each frame.
---@param  name string
---@return table
function M.option(name)
  local opts = M.live.options and M.live.options[name]
  return type(opts) == "table" and opts or {}
end

---Validate `opts`, dropping only the values that fail. warden copies just the
---tables along a dropped path, so module tables keep their identity.
---@param  opts table
---@return table valid  validated scalars (layout/modules are taken from `opts` as-is)
---@return table raw    `opts` without the dropped values
local function validate(opts)
  local result = M.schema:safe_parse(opts, { drop_invalid = true })
  local dropped = result.dropped or {}
  -- Kept for mosaic.doctor().
  M.issues = {}
  for _, list in ipairs { dropped, result.issues or {}, result.warnings or {} } do
    for _, issue in ipairs(list) do
      M.issues[#M.issues + 1] = ("[%s] %s"):format(issue.path_text or "?", issue.message or "?")
    end
  end
  if #dropped > 0 or not result.ok or #result.warnings > 0 then
    result:log()
  end
  if not result.ok then
    log:error "invalid mosaic options; using defaults"
    return M.schema:safe_parse({}).value, {}
  end
  return result.value, result.input or opts
end

---Load a preset by name.
---@param  name string
---@return table|nil
local function load_preset(name)
  if not name:match "^[%w_-]+$" then
    log:error("unknown preset %q", name)
    return nil
  end
  local ok, preset = pcall(require, "mosaic.presets." .. name)
  if not ok or type(preset) ~= "table" then
    log:error("unknown preset %q", name)
    return nil
  end
  return preset
end

---Apply options to `M.live`. Safe to call on every config reload.
---
---Merge rule: the preset supplies `layout` and `modules`; `opts.modules[name]`
---replaces a module by name and `opts.layout` replaces the whole layout. Any
---other name falls back to the built-in module of that name.
---@param  opts? table
---@return Mosaic.Options live
function M.setup(opts)
  if opts ~= nil and type(opts) ~= "table" then
    log:error("setup() expects a table, got %s; using defaults", type(opts))
    opts = nil
  end
  local valid, raw = validate(opts or {})
  local preset = valid.preset and load_preset(valid.preset) or {}

  local live = M.live
  live.enabled = valid.enabled
  live.position = valid.position
  live.flexible = valid.flexible
  live.fit = valid.fit

  -- Uses `raw` (not the validated clone) so module tables keep their identity.
  local layout = raw.layout or preset.layout or {}
  -- A function layout is called per frame (`M.layout_for`); the preset's
  -- stands in for it when it fails or returns nothing.
  live.layout_fn = type(layout) == "function" and layout or nil
  if live.layout_fn then
    layout = preset.layout or {}
  end
  live.layout =
    { left = layout.left or {}, center = layout.center or {}, right = layout.right or {} }
  local center = raw.center or {}
  local defaults = require("mosaic.engine.center").DEFAULTS
  live.center = {
    anchor = center.anchor or defaults.anchor,
    overflow = center.overflow or defaults.overflow,
    margin = center.margin or defaults.margin,
  }

  -- `tabs = false` leaves tab formatting to the user; otherwise user fields
  -- override the preset's.
  if raw.tabs == false then
    live.tabs = false
  else
    local tabs = {}
    for k, v in pairs(preset.tabs or {}) do
      tabs[k] = v
    end
    for k, v in pairs(raw.tabs or {}) do
      tabs[k] = v
    end
    live.tabs = tabs
  end

  local modules = live.modules
  for k in pairs(modules) do
    modules[k] = nil
  end
  for k, v in pairs(preset.modules or {}) do
    modules[k] = v
  end
  for k, v in pairs(raw.modules or {}) do
    modules[k] = v
  end
  -- Styling: the preset's decorator (minimal's without a preset), with the
  -- user's colours and separators layered over the preset's.
  live.decorate = raw.decorate or preset.decorate or require("mosaic.presets.minimal").decorate
  local pstyle, ustyle = preset.style or {}, raw.style or {}
  local style = { colors = {}, separators = {} }
  for _, part in ipairs { "colors", "separators" } do
    for k, v in pairs(pstyle[part] or {}) do
      style[part][k] = v
    end
    for k, v in pairs(ustyle[part] or {}) do
      style[part][k] = v
    end
  end
  for _, key in ipairs { "text", "dim", "gradient", "by_mode" } do
    if ustyle[key] ~= nil then
      style[key] = ustyle[key]
    else
      style[key] = pstyle[key]
    end
  end
  style.raw = {}
  for _, name in ipairs(ustyle.raw or {}) do
    style.raw[name] = true
  end
  live.style = style

  -- A new config evaluation (or setup call) ends timer chains started under
  -- the previous one, even when the module is no longer in the layout.
  local store = require "mosaic.engine.store"
  store.set("__mosaic:media:gen", (tonumber(store.value "__mosaic:media:gen") or 0) + 1)
  live.options = raw.options or {}
  live.scheme = raw.scheme
  require("mosaic.engine.integrations").configure(live.options)
  return live
end

return M
