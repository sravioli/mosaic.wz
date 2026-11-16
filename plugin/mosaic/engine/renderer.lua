---@module "mosaic.engine.renderer"
---@author sravioli
---@license GNU-GPLv2

local budget = require "mosaic.engine.budget"
local deps = require "mosaic.engine.deps"
local wt = require "wezterm" ---@class Wezterm
local ribbon = deps.ribbon
local warp = deps.warp
local str = warp.string ---@class Warp.String

-- Live options table. `mosaic.config.setup()` updates it in place.
local Opts = require("mosaic.engine.config").live ---@class Mosaic.Options
local log = require "mosaic.engine.logger"

local M = require "mosaic.engine.render.state"
require "mosaic.engine.render.resolve"
require "mosaic.engine.render.decorate"
require "mosaic.engine.render.cell"
require "mosaic.engine.render.fit"

local decorate, edge_ctx, render_group = M.decorate, M.edge_ctx, M.render_group

-- Reusable context table for resolve_layout (avoids per-call allocation).
local _layout_ctx = {}

-- ---------------------------------------------------------------------------
-- Init
-- ---------------------------------------------------------------------------

---@param config table   effective config
---@param window table
---@param pane   table
---@param theme  table   resolved colour scheme
---@param scheme? string colour scheme name; a change invalidates `update` caches
---@return boolean ok false when the pane is already gone (nothing to draw)
function M.init(config, window, pane, theme, scheme)
  M.config, M.window, M.pane, M.theme = config, window, pane, theme
  M.frame = {}
  -- `style.by_mode[name]` merged over `style` while that key table (or the
  -- leader) is active.
  local style = Opts.style or {}
  M.style = style
  -- Key table and leader, asked once per frame: every `cond` and the style
  -- below read this instead of calling the window again.
  local ok, mode = pcall(window.active_key_table, window)
  local lok, leader = pcall(window.leader_is_active, window)
  M.modes = { key_table = ok and mode or nil, leader = lok and leader or nil }
  if style.by_mode then
    local patch = (M.modes.key_table and style.by_mode[M.modes.key_table])
      or (M.modes.leader and style.by_mode.leader)
    if patch then
      M.style = M.merge(style, patch)
    end
  end
  M.scheme = scheme
  M.window_id = window.window_id and window:window_id() or 0
  M.default_style = { fg = M.theme.foreground, bg = M.theme.background, attributes = nil }

  -- A pane closed since the event was queued is no longer in the mux.
  local dims_ok, pane_dimensions = pcall(pane.get_dimensions, pane)
  if not dims_ok then
    return false
  end
  local win_width = window:get_dimensions().pixel_width
  -- A pane without pixels yet (new or minimised window) has no columns.
  M.width.available = pane_dimensions.pixel_width > 0
      and math.floor((win_width * pane_dimensions.cols) / pane_dimensions.pixel_width)
    or 0
  if config.use_fancy_tab_bar then
    -- The fancy bar draws in the titlebar font, so count its columns instead.
    -- shortcut: scales by point size only; the title font's real advance width is not visible from Lua.
    local frame_size = (config.window_frame or {}).font_size or 12
    local term_size = config.font_size or 12
    M.width.available = math.floor(M.width.available * term_size / math.max(frame_size, 1))
  end
  M.width.used = 0
  require("mosaic.engine.palette").focused = not window.is_focused or window:is_focused()

  -- Publish total screen width once per cycle so that
  -- `budget.right_available()` always computes from the true terminal width.
  budget.set_screen_width(M.width.available)

  -- Seed tab_max_width for the cold-start estimator.
  budget.set_tab_max_width(config.tab_max_width or 30)
  return true
end

-- ---------------------------------------------------------------------------
-- Width publication helpers
-- ---------------------------------------------------------------------------

---Return the number of columns consumed by the most recent `render_layout` call.
---@return integer
function M.get_used_width()
  return M.width.used
end

---Transition from the left-status render phase to the right-status phase.
---
---This is the single synchronization point between the two halves of the
---status bar. It performs four updates atomically:
---
---  1. Publishes `_left_used` so `budget.right_available()` is accurate.
---  2. Publishes `_new_tab_button` (derived from `config`).
---  3. Recalculates `M.width.available` for the right render pass:
---     `right_budget = total_screen − left_used − tab_cells − new_tab_button`
---  4. Resets `M.width.used` to 0 for the right layout.
---
---```lua
----- update-status handler excerpt:
---Renderer.init(config, window, pane, theme)
---local left = Renderer.render_layout(Opts.layout.left)
---Renderer.commit_left()
---local right = Renderer.render_layout(Opts.layout.right)
---```
function M.commit_left()
  local left_used = M.width.used
  budget.set_left_used(left_used)

  -- The button as drawn (the preset's, else WezTerm's ` + `).
  local ntb = 0
  if M.config.show_new_tab_button_in_tab_bar then
    ntb = str.width((M.config.tab_bar_style or {}).new_tab or " + ")
  end
  budget.set_new_tab_button(ntb)

  -- Recalculate the budget for the right-status render pass.
  M.width.available = budget.right_available(M.tabs_width)
  M.width.used = 0
end

-- ---------------------------------------------------------------------------
-- Layout rendering
-- ---------------------------------------------------------------------------

--- Resolve a `module.layout` value to a plain string.
---
--- Handles all four forms defined by `Mosaic.Module.Layout`:
---   • `string`  → returned as-is
---   • `Ribbon`  → calls `:format()`
---   • `table`   → passed to `wezterm.format()`
---   • `fun(ctx) → string|table|Ribbon`  → called first, result normalised
---
---@param  layout Mosaic.Module.Layout
---@return string
local function resolve_layout(layout)
  if type(layout) == "function" then
    _layout_ctx.layout = ribbon
    _layout_ctx.theme = M.theme
    _layout_ctx.warp = warp
    _layout_ctx.window = M.window
    _layout_ctx.pane = M.pane
    layout = layout(_layout_ctx)
  end

  if type(layout) == "string" then
    return layout
  end

  -- Ribbon instance: has a callable :format() method.
  if type(layout) == "table" and type(layout.format) == "function" then
    return layout:format()
  end

  -- Raw FormatItem array.
  if type(layout) == "table" then
    return wt.format(layout)
  end

  return ""
end

--- Render one module and append to `components` when it produces output.
---
--- Handles two rendering paths:
---   1. `module.layout`    - arbitrary Ribbon / string / table / function;
---                           rendered via `resolve_layout` and measured for
---                           the flexible-width budget.
---   2. `module.icon/text` - structured cell rendered by `format_cell` with
---                           the full fallback chain.
---
---@param name       string
---@param module     Mosaic.Module
---@param components string[]
local function render_module(name, module, components)
  local formatted = ""
  local consumed = 0

  if module.layout then
    formatted = resolve_layout(module.layout)
    consumed = str.width(formatted)

    -- Respect the budget. If the resolved layout is too wide and the module
    -- can be hidden, drop it instead of overflowing.
    if Opts.flexible then
      local avail = M.width.available - M.width.used
      if consumed > avail then
        if module.can_hide then
          return
        end
        log:warn("[%s] layout overflows by %d cols (no can_hide)", name, consumed - avail)
      end
    end
  elseif module.icon or module.text then
    local avail = Opts.flexible and (M.width.available - M.width.used) or nil
    formatted, consumed = M.format_cell(name, module, avail)
  end

  if formatted == "" then
    return
  end

  components[#components + 1] = formatted
  if Opts.flexible then
    M.width.used = M.width.used + consumed
  end
end

---@param layout table
---@param side?  "left"|"right" passed to the preset's `decorate`
M.render_layout = function(layout, side)
  M.side = side
  local components = {}

  -- The last entry with an enabled module (its module is outermost on the
  -- right). Found only when a decorator reads `ctx.last`, since it resolves
  -- later modules ahead of their turn.
  local last_live
  local function is_last(i)
    if last_live == nil then
      last_live = false
      for j = #layout, 1, -1 do
        local names = type(layout[j]) == "table" and layout[j] or { layout[j] }
        for _, name in ipairs(names) do
          if M.enabled(M.resolve_module(name)) then
            last_live = j
            break
          end
        end
        if last_live then
          break
        end
      end
    end
    return i == last_live
  end

  for i = 1, #layout do
    local entry = layout[i]
    -- `first`/`last` tell the decorator a module sits at the outer edge.
    local edge = {
      first = #components == 0,
      last = function()
        return is_last(i)
      end,
    }

    if type(entry) == "table" then
      -- ── Sub-layout group: fitted by `Opts.fit` strategy ─────────────────
      local avail = Opts.flexible and (M.width.available - M.width.used) or math.huge
      M.edge = edge
      local formatted, consumed = render_group(entry, avail)
      M.edge = nil
      if formatted ~= "" then
        components[#components + 1] = formatted
        if Opts.flexible then
          M.width.used = M.width.used + consumed
        end
      end
    else
      -- ── Single named module: existing path ───────────────────────────────
      local name = entry
      local module = M.resolve_module(name)

      if M.enabled(module) then
        module = decorate(
          module,
          name,
          edge_ctx(
            { side = side, group = false, index = 1, count = 1, first = edge.first },
            edge.last
          )
        )
        render_module(name, module, components)
      end
    end
  end

  return table.concat(components)
end

return M
