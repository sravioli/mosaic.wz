---Fixed windows, panes and themes for the snapshot spec. Each scenario is
---rendered through the real `update-status` handler; the captured left/right
---strings are compared byte-for-byte against `spec/fixtures/snapshots.lua`.

local wezterm = require "wezterm"

local M = {}

M.theme = {
  foreground = "#dcd7ba",
  background = "#1f1f28",
  ansi = { "#090618", "#c34043", "#76946a", "#c0a36e", "#7e9cd8", "#957fb8", "#6a9589", "#c8c093" },
  brights = {
    "#727169",
    "#e82424",
    "#98bb6c",
    "#e6c384",
    "#7fb4ca",
    "#938aa9",
    "#7aa89f",
    "#dcd7ba",
  },
  tab_bar = { background = "#16161d" },
}

---Key-hint provider used by the custom modules in `spec/support/config.lua`:
---one mode and width-dependent hint text.
M.hints = {
  modes = { normal_mode = { icon = "N", name = "NORMAL", bg = "#76946a" } },
  layout = function(active, width)
    return { { Text = (active .. " hints "):rep(20):sub(1, math.max(0, width)) } }
  end,
  leader = function(width)
    return { { Text = ("leader hints "):rep(20):sub(1, math.max(0, width)) } }
  end,
}

-- Methods real WezTerm Window / Pane objects have. Reading any other name
-- raises like WezTerm does; a real method the mock does not define raises
-- too, so a gap in the mock fails a spec instead of passing by accident.
local REAL = {
  Window = {
    "active_key_table",
    "active_pane",
    "active_tab",
    "active_workspace",
    "composition_status",
    "copy_to_clipboard",
    "current_event",
    "effective_config",
    "focus",
    "get_appearance",
    "get_config_overrides",
    "get_dimensions",
    "get_selection_escapes_for_pane",
    "get_selection_text_for_pane",
    "is_focused",
    "keyboard_modifiers",
    "leader_is_active",
    "maximize",
    "mux_window",
    "perform_action",
    "restore",
    "set_config_overrides",
    "set_inner_size",
    "set_left_status",
    "set_position",
    "set_right_status",
    "toast_notification",
    "toggle_fullscreen",
    "window_id",
  },
  Pane = {
    "activate",
    "get_current_working_dir",
    "get_cursor_position",
    "get_dimensions",
    "get_domain_name",
    "get_foreground_process_info",
    "get_foreground_process_name",
    "get_lines_as_escapes",
    "get_lines_as_text",
    "get_logical_lines_as_text",
    "get_metadata",
    "get_progress",
    "get_semantic_zone_at",
    "get_semantic_zones",
    "get_text_from_region",
    "get_text_from_semantic_zone",
    "get_title",
    "get_tty_name",
    "get_user_vars",
    "has_unseen_output",
    "inject_output",
    "is_alt_screen_active",
    "move_to_new_tab",
    "move_to_new_window",
    "mux_pane",
    "pane_id",
    "paste",
    "send_paste",
    "send_text",
    "split",
    "tab",
    "window",
  },
}

---@param  obj  table
---@param  kind "Window"|"Pane"
---@return table
function M.strict(obj, kind)
  local known = {}
  for _, name in ipairs(REAL[kind]) do
    known[name] = true
  end
  return setmetatable(obj, {
    __index = function(_, k)
      if type(k) == "string" and k:sub(1, 1) == "_" then
        return nil -- spec bookkeeping (_left, _right, _vars)
      end
      if known[k] then
        error(("mock %s lacks %s"):format(kind, tostring(k)), 2)
      end
      error(("attempt to get an unknown field '%s'"):format(tostring(k)), 2)
    end,
  })
end

---@param s table scenario
local function make_pane(s)
  return M.strict({
    get_dimensions = function()
      return { cols = s.cols, pixel_width = s.cols * 10 }
    end,
    get_current_working_dir = function()
      return s.cwd or "file://devbox.local/home/mock/source/project"
    end,
    get_title = function()
      return s.title or "zsh"
    end,
    get_foreground_process_name = function()
      return s.process or "/usr/bin/zsh"
    end,
    get_domain_name = function()
      return s.domain or "local"
    end,
    get_user_vars = function()
      return s.user_vars or {}
    end,
    get_progress = function()
      return s.progress or "None"
    end,
    pane_id = function()
      return s.pane_id or 1
    end,
    has_unseen_output = function()
      return false
    end,
  }, "Pane")
end

---@param s table scenario
---@param pane table
local function make_window(s, pane)
  local tabs = {}
  for i = 1, #s.tabs do
    tabs[i] = {}
  end
  local window = {
    _left = nil,
    _right = nil,
  }
  function window:window_id()
    return s.id or 1
  end
  function window:get_dimensions()
    return { pixel_width = s.cols * 10 }
  end
  function window:effective_config()
    return {
      color_scheme = "test",
      color_schemes = { test = M.theme },
      tab_max_width = 30,
      show_new_tab_button_in_tab_bar = true,
      use_fancy_tab_bar = false,
    }
  end
  function window:get_config_overrides()
    return nil
  end
  function window:mux_window()
    return {
      tabs = function()
        return tabs
      end,
      tabs_with_info = function()
        local out = {}
        for i, t in ipairs(tabs) do
          out[i] = { index = i - 1, is_active = i == 1, tab = t }
        end
        return out
      end,
      get_title = function()
        return s.title or "zsh"
      end,
    }
  end
  function window:active_tab()
    return {
      panes_with_info = function()
        return { { is_zoomed = s.zoomed == true, pane = pane } }
      end,
      panes = function()
        return { pane }
      end,
    }
  end
  function window:active_pane()
    return pane
  end
  function window:active_workspace()
    return s.workspace or "default"
  end
  function window:leader_is_active()
    return s.leader == true
  end
  function window:active_key_table()
    return s.key_table
  end
  function window:is_focused()
    return s.focused ~= false
  end
  function window:set_left_status(v)
    self._left = v
  end
  function window:set_right_status(v)
    self._right = v
  end
  return M.strict(window, "Window")
end

---Build window + pane for a scenario and apply global mock state.
---@param s table
---@return table window, table pane
function M.build(s)
  wezterm._battery = s.battery or { { state_of_charge = 0.47, state = "Discharging" } }
  wezterm.hostname = function()
    return "devbox"
  end
  local pane = make_pane(s)
  return make_window(s, pane), pane
end

local base_tabs = { 22, 18, 25 }

M.list = {}
for _, cols in ipairs { 60, 100, 160, 240 } do
  for _, state in ipairs {
    { name = "idle" },
    { name = "leader", leader = true },
    { name = "mode", key_table = "normal_mode" },
    { name = "zoomed", zoomed = true, workspace = "work" },
    { name = "nobattery", battery = {} },
  } do
    local s = { name = state.name .. "@" .. cols, cols = cols, tabs = base_tabs }
    for k, v in pairs(state) do
      if k ~= "name" then
        s[k] = v
      end
    end
    M.list[#M.list + 1] = s
  end
end
M.list[#M.list + 1] = {
  name = "manytabs@160",
  cols = 160,
  tabs = { 30, 30, 30, 30, 30 },
}

return M
