---@module "mosaic.engine.status"
---@author sravioli
---@license GNU-GPLv2

---The `update-status` handler: renders left, publishes its width, renders
---right, and only pushes strings to the window when they changed.

local wezterm = require "wezterm"

local budget = require "mosaic.engine.budget"
local config = require "mosaic.engine.config"
local renderer = require "mosaic.engine.renderer"

local M = {}

---`right` with the centre modules in front of it, followed by the gap that
---moves them to their column. The right modules keep priority: the centre
---fits into what they leave.
---@param  opts  table live options
---@param  right string formatted right status
---@return string
local function with_center(opts, right, center_layout)
  local layout = center_layout
  if not layout or #layout == 0 then
    return right
  end
  local deps = require "mosaic.engine.deps"
  local width = deps.warp.string.width
  local center = require "mosaic.engine.center"
  local place = opts.center or center.DEFAULTS
  local screen = budget.screen_width()
  -- The renderer's own count (escape sequences excluded) of what it drew.
  local function drawn(s)
    return opts.flexible and renderer.get_used_width() or width(s)
  end
  local free_end = screen - drawn(right)
  local free_start = screen - budget.right_available(renderer.tabs_width)
  local margin = place.margin or center.DEFAULTS.margin
  renderer.width.available = math.max(0, free_end - free_start - 2 * margin)
  renderer.width.used = 0
  local text = renderer.render_layout(layout, "center")
  local text_w = drawn(text)
  local c0 = center.place(screen, free_start, free_end, text_w, place)
  if not c0 then
    return right
  end
  local gap = free_end - c0 - text_w
  local cell = deps.ribbon:new "MosaicCenterGap"
  if gap > 0 then
    -- On the bar colour: an unset bg would show the terminal background.
    cell:append(renderer.surface(), nil, (" "):rep(gap))
  end
  return text .. cell:format() .. right
end

-- Last strings pushed, by window id: window objects are fresh per event.
local window_status = {}

---Forget the windows that no longer exist. Run when a window is first seen,
---so closed ones cost nothing per frame. Skipped when WezTerm lists none.
local function prune()
  local ok, all = pcall(function()
    return wezterm.gui.gui_windows()
  end)
  if not ok or type(all) ~= "table" or #all == 0 then
    return
  end
  local alive = {}
  for _, w in ipairs(all) do
    alive[w:window_id()] = true
  end
  for id in pairs(window_status) do
    if not alive[id] then
      window_status[id] = nil
      budget.forget(id)
      renderer.forget(id)
      require("mosaic.engine.notice").forget(id)
    end
  end
end

---@param window table
---@param pane   table
local function render(window, pane)
  local opts = config.live
  local id = window:window_id()
  local status = window_status[id]
  if not status then
    prune()
    status = {}
    window_status[id] = status
  end

  if not opts.enabled then
    if not status.cleared then
      window:set_left_status ""
      window:set_right_status ""
      status.left = ""
      status.right = ""
      status.cleared = true
    end
    return
  end
  status.cleared = nil

  -- `doctor` sets `renderer.profile`: time what runs outside the modules.
  local prof = renderer.profile
  local t0 = prof and os.clock()
  local cfg = window:effective_config()
  local t1 = prof and os.clock()
  local overrides = window:get_config_overrides() or {}
  local scheme = overrides.color_scheme or cfg.color_scheme
  local palette = require "mosaic.engine.palette"
  local theme = palette.composite(palette.scheme(cfg, scheme), cfg)
  if prof then
    prof["(effective_config)"] = t1 - t0
    prof["(overrides, scheme)"] = os.clock() - t1
  end

  -- Seed the tab count so the cold-start estimator in `budget.total_width()`
  -- has the real count even if `format-tab-title` hasn't fired yet.
  local count = #window:mux_window():tabs()
  budget.use(id)
  budget.set_count(count)
  -- Read now, with no wait in between: later waits let another window's
  -- `format-tab-title` switch the live tab widths.
  renderer.tabs_width = budget.total_width()

  if not renderer.init(cfg, window, pane, theme, scheme) then
    return
  end
  local layout = config.layout_for(window, pane)
  local left = renderer.render_layout(layout.left, "left")
  -- Publishes the left width and recalculates the right-status budget.
  renderer.commit_left()
  local right = renderer.render_layout(layout.right, "right")
  right = with_center(opts, right, layout.center)
  local right_is_dynamic = (renderer.modes or {}).key_table ~= nil

  if status.left ~= left then
    window:set_left_status(left)
    status.left = left
  end
  -- Hosts may clear the right status directly while a key table is active.
  if right_is_dynamic or status.right_dynamic or status.right ~= right then
    window:set_right_status(right)
    status.right = right
  end
  status.right_dynamic = right_is_dynamic
end

-- WezTerm runs handlers as coroutines: one that waits on a GUI-thread call
-- (`window:effective_config()` and the like) lets another window's
-- update-status run in between, on the renderer's shared state (window, pane,
-- side). Overlapping updates drew a window with another's pane and the wrong
-- side, so a second one waits for the first (50 ms, not a busy loop).
local rendering = false
local deferred = {} -- window ids with a re-run already queued

---@param window table
---@param pane   table
function M.update(window, pane)
  if rendering then
    local ok, id = pcall(window.window_id, window)
    if ok and not deferred[id] then
      deferred[id] = true
      wezterm.time.call_after(0.05, function()
        deferred[id] = nil
        -- The window may have closed meanwhile.
        pcall(M.update, window, pane)
      end)
    end
    return
  end
  rendering = true
  local ok, err = pcall(render, window, pane)
  rendering = false
  renderer.modes = nil
  if not ok then
    error(err, 0)
  end
end

return M
