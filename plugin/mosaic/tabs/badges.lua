---@module "mosaic.tabs.badges"
---@author sravioli
---@license GNU-GPLv2

---Badges for tabs that need you: a bell, unseen output, or a state written to
---a pane user var by any script or agent hook:
---
---```sh
---printf '\e]1337;SetUserVar=badge=%s\a' "$(printf done | base64)"
---```
---
---Bell marks and var changes live in `wezterm.GLOBAL` per pane, so they
---survive config reloads. A non-sticky state shows on an inactive tab until
---you focus it; a sticky one (working, waiting) shows while it is set.

local config = require "mosaic.engine.config"
local icons = require "mosaic.engine.icons"

local M = {}

local DEFAULTS

---Default badges, built on first use so sigil loads only when badges are on.
---@return table
function M.defaults()
  DEFAULTS = DEFAULTS
    or {
      var = "badge",
      bell = { icon = icons.symbol "Badge.bell", color = 4 },
      output = false,
      states = {
        working = { icon = icons.symbol "Badge.working", color = 6, sticky = true },
        done = { icon = icons.symbol "Badge.done", color = 3 },
        waiting = { icon = icons.symbol "Badge.waiting", color = 2, sticky = true },
      },
    }
  return DEFAULTS
end

---Resolved `tabs.badges`, or nil when off. `true` takes the defaults.
---@return table|nil
function M.options()
  local tabs = config.live.tabs
  local user = type(tabs) == "table" and tabs.badges
  if not user then
    return nil
  end
  local defaults = M.defaults()
  if user == true then
    return defaults
  end
  local out = {}
  for k, v in pairs(defaults) do
    out[k] = v
  end
  for k, v in pairs(user) do
    out[k] = v
  end
  if out.bell == true then
    out.bell = defaults.bell
  end
  if out.output == true then
    out.output = { icon = icons.symbol "Badge.output", color = 5 }
  end
  return out
end

---@param  id integer pane id
---@return string
local function key(id)
  return "__mosaic:badge:" .. tostring(id)
end

---@param  id integer
---@return table
local function load(id)
  local saved = require("mosaic.engine.store").get(key(id), { "seq", "seen", "bell" })
  if not saved then
    return { seq = 0, seen = 0, bell = false }
  end
  return { seq = saved.seq or 0, seen = saved.seen or -1, bell = saved.bell == true }
end

-- shortcut: a pane closed while its badge is unseen keeps its record (WezTerm
-- has no pane-closed event); a few values each, drop it if that ever grows.
---@param id    integer
---@param state table
local function save(id, state)
  require("mosaic.engine.store").set(
    key(id),
    { seq = state.seq, seen = state.seen, bell = state.bell }
  )
end

---`bell` handler: mark the pane.
---@param pane table Pane
function M.on_bell(pane)
  local id = pane:pane_id()
  local state = load(id)
  state.bell = true
  save(id, state)
end

---`user-var-changed` handler: a new value of the badge var is a new
---event, even when it equals the previous one after a focus.
---@param  pane table Pane
---@param  name string
---@return boolean changed it was the badge var
function M.on_var(pane, name)
  local opts = M.options()
  if not opts or name ~= opts.var then
    return false
  end
  local id = pane:pane_id()
  local state = load(id)
  state.seq = state.seq + 1
  save(id, state)
  return true
end

---Pane view: { id, vars, unseen } from a PaneInformation or a Pane.
---@param  pane table
---@return { id: integer, vars: table, unseen: boolean }
local function view(pane)
  if type(pane.pane_id) == "function" then
    local ok_v, vars = pcall(pane.get_user_vars, pane)
    local ok_u, unseen = pcall(pane.has_unseen_output, pane)
    return { id = pane:pane_id(), vars = ok_v and vars or {}, unseen = ok_u and unseen == true }
  end
  return { id = pane.pane_id, vars = pane.user_vars or {}, unseen = pane.has_unseen_output == true }
end

---Badge for a set of panes, or nil: a var state first, then a bell, then
---unseen output. With `focused`, clears bells and marks states seen.
---@param  panes   table[] PaneInformation or Pane
---@param  focused boolean
---@return { icon: string, color: any, name: string }|nil
function M.badge(panes, focused)
  local opts = M.options()
  if not opts then
    return nil
  end
  local views = {}
  for i, p in ipairs(panes) do
    views[i] = view(p)
  end
  if focused then
    for _, v in ipairs(views) do
      local state = load(v.id)
      if state.bell or state.seen ~= state.seq then
        -- Nothing pending is the default record: keep none per seen pane.
        require("mosaic.engine.store").set(key(v.id), nil)
      end
    end
    return nil
  end
  for _, v in ipairs(views) do
    local value = opts.var and v.vars[opts.var]
    local st = value and (opts.states or {})[value]
    if st then
      local state = load(v.id)
      if st.sticky or state.seq > state.seen then
        return { icon = st.icon, color = st.color, name = value }
      end
    end
  end
  if opts.bell then
    for _, v in ipairs(views) do
      if load(v.id).bell then
        return { icon = opts.bell.icon, color = opts.bell.color, name = "bell" }
      end
    end
  end
  if opts.output then
    for _, v in ipairs(views) do
      if v.unseen then
        return { icon = opts.output.icon, color = opts.output.color, name = "output" }
      end
    end
  end
  return nil
end

---Style for a badged tab: its colour on the inactive / hover fill and its
---icon in place of the index.
---@param  badge table
---@return table tabs.style patch
function M.style(badge)
  local icon = badge.icon or "!"
  return {
    colors = badge.color ~= nil and { inactive = badge.color, hover = badge.color } or nil,
    index = function()
      return icon
    end,
    unseen = icon,
  }
end

---Tabs of `window` (other than the active one) that have a badge.
---@param  window table
---@return table[] badges
function M.pending(window)
  local out = {}
  local ok, mux = pcall(window.mux_window, window)
  if not ok or not mux then
    return out
  end
  for _, info in ipairs(mux:tabs_with_info()) do
    if not info.is_active then
      local pok, panes = pcall(info.tab.panes, info.tab)
      local badge = pok and M.badge(panes, false)
      if badge then
        out[#out + 1] = badge
      end
    end
  end
  return out
end

return M
