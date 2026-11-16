---@module "mosaic.engine.budget"
---@author sravioli
---@license GNU-GPLv2
---
--- Central budget oracle for the tab bar and status bar.
---
--- Tracks three categories of column consumption so that every module can
--- query how much space remains without duplicating measurement logic:
---
---   1. Tab cells: per-tab rendered widths published by `format-tab-title`
---      via `record()` / `set_count()`.
---   2. Left status: columns consumed by the left-status render pass,
---      published by `Renderer.commit_left()` via `set_left_used()`.
---   3. New-tab button: the columns of the button as drawn (0 when hidden),
---      published by `Renderer.commit_left()` via `set_new_tab_button()`.
---
--- The total screen width (`_total_screen_width`) is set once per render
--- cycle by `Renderer.init()` (the first, unconstrained call). It is never
--- overwritten by subsequent renderer operations, guaranteeing that
--- `right_available()` always computes from the true terminal width.
---
--- On the very first frame, `format-tab-title` may not have fired yet.
--- `total_width()` detects this (no real per-tab data) and returns a
--- conservative upper-bound estimate using `_tab_max_width` so the right
--- status never overflows.

local warp = require("mosaic.engine.deps").warp
local str = warp.string ---@class Warp.String

---@class Mosaic.Budget
local M = {
  -- ── Per-tab widths (set by format-tab-title) ─────────────────────────────
  _widths = {}, ---@type table<integer, integer>  zero-based index → columns
  _count = 0, ---@type integer
  _total_cached = 0, ---@type integer  running sum of all per-tab widths
  _has_real_data = false, ---@type boolean  true after the first `record()` call

  -- ── Layout-wide metrics ──────────────────────────────────────────────────

  --- True terminal width in columns.
  --- Set once per cycle by `Renderer.init()` (without `available_cols`).
  _total_screen_width = 0, ---@type integer

  --- Columns consumed by the left-status render pass.
  --- Set by `Renderer.commit_left()` before the right-status render.
  _left_used = 0, ---@type integer

  --- Columns of the new-tab button as drawn (0 when hidden).
  --- Set by `Renderer.commit_left()`, which has access to `config`.
  _new_tab_button = 0, ---@type integer

  --- `config.tab_max_width` (default 30).  Used only for the first-frame
  --- cold-start estimate when `format-tab-title` hasn't published real data.
  _tab_max_width = 30, ---@type integer
}

-- Tab widths of the other windows, by window id: each window has its own tabs.
-- Entries of closed windows are dropped by `forget`, which `status` calls when
-- it first sees a new window.
local windows, current = {}, nil

---Switch the per-tab fields to window `id`'s, keeping the current window's.
---The first window adopts the fields as they are. A nil id changes nothing.
---@param id integer|nil window id
function M.use(id)
  if id == nil or id == current then
    return
  end
  if current ~= nil then
    windows[current] = { M._widths, M._count, M._total_cached, M._has_real_data }
    local s = windows[id] or { {}, 0, 0, false }
    M._widths, M._count, M._total_cached, M._has_real_data = s[1], s[2], s[3], s[4]
  end
  current = id
end

---Drop what is kept for a closed window.
---@param id integer
function M.forget(id)
  windows[id] = nil
  -- The current window's fields are live, not in `windows`: reset them, or
  -- the next `use` saves them under the closed id.
  if id == current then
    M._widths, M._count, M._total_cached, M._has_real_data = {}, 0, 0, false
    current = nil
  end
end

---Record the column-width for one tab cell.
---
---Accepts either a pre-computed numeric width (fastest) or the raw rendered
---string (ANSI codes are stripped automatically).  Prefer passing a number
---when the caller already knows the width from its own layout math.
---
---@param index           integer         zero-based tab index
---@param width_or_rendered integer|string  column count or raw `cell:format()` output
function M.record(index, width_or_rendered)
  local new_w
  if type(width_or_rendered) == "number" then
    new_w = width_or_rendered
  else
    new_w = str.width(width_or_rendered)
  end

  local old_w = M._widths[index] or 0
  M._widths[index] = new_w
  M._total_cached = M._total_cached - old_w + new_w
  M._has_real_data = true
end

---Persist the current number of tabs and prune any stale entries left over
---from a layout with more tabs.
---@param count integer
function M.set_count(count)
  if count == M._count then
    return
  end
  for i = count, M._count - 1 do
    local w = M._widths[i] or 0
    M._total_cached = M._total_cached - w
    M._widths[i] = nil
  end
  M._count = count
end

---Total columns consumed by all tab cells in the last render pass.  O(1).
---
---On the first frame, before `format-tab-title` has published real widths,
---returns a conservative upper-bound estimate (`_count * _tab_max_width`) so
---the right status never overflows.  Once real data arrives the cached running
---total is returned directly.
---@return integer
function M.total_width()
  if M._count > 0 and not M._has_real_data then
    return M._count * M._tab_max_width
  end
  return M._total_cached
end

---Set the true terminal width for the current render cycle.
---Called once by `Renderer.init()` (the first, unconstrained call).
---@param cols integer
function M.set_screen_width(cols)
  M._total_screen_width = cols
end

---Bar width of the current render cycle.
---@return integer
function M.screen_width()
  return M._total_screen_width
end

---Set the column count consumed by the left-status render pass.
---Called by `Renderer.commit_left()` before the right-status render.
---@param cols integer
function M.set_left_used(cols)
  M._left_used = cols
end

---Set the reservation for the new-tab button (0 when hidden, 8 when shown).
---Called by `Renderer.commit_left()`, which has access to `config`.
---@param cols integer
function M.set_new_tab_button(cols)
  M._new_tab_button = cols
end

---Set the per-tab max width from config (used for cold-start estimation).
---Called by `Renderer.init()`.
---@param cols integer
function M.set_tab_max_width(cols)
  M._tab_max_width = cols
end

---Columns available for the right-status bar in the current render cycle.
---
---```text
---  right_available = total_screen_width
---                  − tab_cells
---                  − left_status
---                  − new_tab_button
---```
---
---All inputs are guaranteed current-cycle when called during the right-status
---render pass (after `Renderer.commit_left()`). Pass `tabs` when you read the tab
---columns earlier in the render. A render waits on the GUI thread, and another
---window's `format-tab-title` can switch the live widths meanwhile.
---
---@param  tabs? integer tab columns read earlier in this render (default: now).
---@return integer
function M.right_available(tabs)
  return math.max(
    0,
    M._total_screen_width - (tabs or M.total_width()) - M._left_used - M._new_tab_button
  )
end

return M
