---@module "mosaic.api"
---@author sravioli
---@license GNU-GPLv2

---Public API for mosaic.wz.
---
---```lua
---local mosaic = wezterm.plugin.require "https://github.com/sravioli/mosaic.wz"
---mosaic.setup { preset = "powerline" }
---mosaic.apply_to_config(config)
---```

local wezterm = require "wezterm"

local config = require "mosaic.engine.config"
local deps = require "mosaic.engine.deps"
local renderer = require "mosaic.engine.renderer"
local status = require "mosaic.engine.status"

---Public API for mosaic.wz.
---@class Mosaic.Api
---@field VERSION string Plugin version.
---@field budget Mosaic.Budget Width accounting shared with `format-tab-title` handlers.
---@field cond Mosaic.Conditions Condition helpers for module `cond` fields.
---@field modules table<string, Mosaic.Options.Module|function> Built-in modules by name, loaded on first use.
---@field palette Mosaic.Palette Colour helpers used by the built-ins.
---@field INTEGRATION_API integer Version of the integration contract.
local M = {}

M.VERSION = "1.0.1"

---Width accounting shared with `format-tab-title` handlers.
M.budget = require "mosaic.engine.budget"
---Condition helpers for module `cond` fields.
M.cond = require "mosaic.engine.conditions"
---Built-in modules by name (lazy).
M.modules = require "mosaic.modules"
---Colour helpers used by the built-ins.
M.palette = require "mosaic.engine.palette"

local patched = renderer.merge

---Wrap a module and patch every spec it produces, e.g. to restyle a builtin:
---
---```lua
---modules = { clock = mosaic.extend(mosaic.modules.clock, { text = { variants = {} } }) }
---```
---
---`patch` is a table merged into the spec, or `fun(spec, window, pane, theme,
---config): spec` for changes that depend on the spec. Disabled specs pass
---through untouched.
---@param  module Mosaic.Module|function
---@param  patch  table|function
---@return function
function M.extend(module, patch)
  return function(window, pane, theme, cfg)
    local spec = module
    if type(module) == "function" then
      spec = module(window, pane, theme, cfg)
    end
    if type(spec) ~= "table" or spec.enabled == false then
      return spec
    end
    if type(patch) == "function" then
      return patch(spec, window, pane, theme, cfg)
    end
    return patched(spec, patch)
  end
end

---Configure mosaic. Safe to call on every config reload.
---@param  opts? table
---@return Mosaic.Options
function M.setup(opts)
  return config.setup(opts)
end

---Render the status bar for `window` now. Wire extra events to it:
---`wezterm.on("my-event", mosaic.refresh)`.
---@param window table
---@param pane   table
function M.refresh(window, pane)
  status.update(window, pane)
end

---Columns still free in the side being rendered. Valid inside module
---functions and `layout(ctx)` callbacks.
---@return integer
function M.remaining_width()
  return math.max(0, renderer.width.available - renderer.width.used)
end

---Visible width of `s` in columns (escape sequences ignored).
---@param  s string
---@return integer
function M.width(s)
  return deps.warp.string.width(s)
end

---Copy of a module padded by one column inside its icon/text, so the padding
---takes the module's style. For decorators whose shapes sit flush against
---the content. Module `padding` itself is drawn unstyled.
---@param  module table
---@return table
function M.pad_inside(module)
  return renderer.pad_inside(module)
end

---Draw the new-tab button in the preset's style into `cfg.tab_bar_style`.
---`apply_to_config` calls it. Call it again when the colour scheme changes.
---@param cfg   table
---@param theme table colour scheme
function M.set_new_tab_button(cfg, theme)
  require("mosaic.tabs").new_tab_button(cfg, theme)
end

---Redraw a window's overridden new-tab button. Window overrides survive
---config reloads and win over the config. A button copied there (e.g. by a
---colour scheme switcher) would otherwise keep an old preset's look.
---@param window table
function M.refresh_new_tab_button(window)
  local overrides = window:get_config_overrides()
  local style = overrides and overrides.tab_bar_style
  if not (style and (style.new_tab or style.new_tab_hover)) then
    return
  end
  local cfg = window:effective_config()
  local theme = M.palette.scheme(cfg, cfg.color_scheme)
  local fresh = {}
  M.set_new_tab_button(fresh, theme)
  local drawn = fresh.tab_bar_style
  -- Unchanged: return, or setting the overrides would reload forever.
  if
    not drawn or (drawn.new_tab == style.new_tab and drawn.new_tab_hover == style.new_tab_hover)
  then
    return
  end
  style.new_tab, style.new_tab_hover = drawn.new_tab, drawn.new_tab_hover
  window:set_config_overrides(overrides)
end

---Shallow copy of a table, e.g. a module spec a decorator restyles.
---@param  t table
---@return table
function M.copy(t)
  return renderer.copy(t)
end

---Icon table from sigil (loaded on first call).
---@return table
function M.icons()
  return deps.icons()
end

---Version of the integration contract (`plugin/<name>/mosaic/<module>.lua`).
M.INTEGRATION_API = require("mosaic.engine.integrations").API

---Integration names shipped by installed plugins, e.g. `{ "chord.hints" }`.
---Lists files only. Nothing is read or executed.
---@return string[]
function M.discover()
  return require("mosaic.engine.integrations").discover()
end

---Resolve the integrations the layout names, so their events are wired
---while the config is evaluated. Unnamed integrations are never touched.
local function preload_integrations()
  local live = config.live
  local integrations = require "mosaic.engine.integrations"
  local function visit(name)
    local entry = rawget(live.modules, name)
    if type(entry) == "string" then
      name, entry = entry, rawget(live.modules, entry)
    end
    if entry == nil and integrations.parse(name) then
      integrations.get(name)
    end
  end
  -- A function layout's integrations load on first use instead.
  for _, side in ipairs { live.layout.left, live.layout.center, live.layout.right } do
    for _, item in ipairs(side) do
      if type(item) == "table" then
        for _, name in ipairs(item) do
          visit(name)
        end
      else
        visit(item)
      end
    end
  end
end

---Show `text` in the `notice` slot for `opts.seconds` (default 3). Plugins
---without a mosaic dependency emit `mosaic-notify` instead:
---`wezterm.emit("mosaic-notify", window, pane, text, opts)`.
---@param window table
---@param text   string
---@param opts?  { seconds?: number, icon?: string|false, accent?: any }
function M.notify(window, text, opts)
  require("mosaic.engine.notice").notify(window, text, opts)
end

---Log a report on dependencies, external programs, and option issues. It also
---shows where each layout name resolves and what each module costs per frame.
---Each line is one log entry, so the debug overlay shows it readably:
---`require("mosaic.api").doctor()`. Nothing is returned, because the overlay
---would print a returned string quoted, with `\n` escapes. The text itself is
---`require("mosaic.engine.doctor").report(window)`.
---@param window? table GUI window (default: the first one)
function M.doctor(window)
  local report = require("mosaic.engine.doctor").report(window)
  for line in report:gmatch "[^\n]+" do
    wezterm.log_info(line)
  end
end

local registered = false

---Register the `update-status` and, unless `tabs = false`, the
---`format-tab-title` handlers (once per config evaluation), and set the bar
---position.
---@param c table WezTerm config builder/table
function M.apply_to_config(c)
  c.tab_bar_at_bottom = config.live.position == "bottom"
  M.set_new_tab_button(c, M.palette.scheme(c, c.color_scheme))
  preload_integrations()
  if not registered then
    registered = true
    wezterm.on("update-status", status.update)
    wezterm.on("window-config-reloaded", M.refresh_new_tab_button)
    if config.live.tabs ~= false then
      wezterm.on("format-tab-title", require("mosaic.tabs").format)
    end
    wezterm.on("mosaic-notify", function(window, _, text, opts)
      M.notify(window, text, opts)
    end)
    local badges = require "mosaic.tabs.badges"
    if badges.options() then
      wezterm.on("bell", function(window, pane)
        badges.on_bell(pane)
        status.update(window, pane)
      end)
      wezterm.on("user-var-changed", function(window, pane, name)
        -- Shell integration sets vars on every prompt; redraw only for ours.
        if badges.on_var(pane, name) then
          status.update(window, pane)
        end
      end)
    end
  end
end

return M
