---PaneInformation / TabInformation as WezTerm hands them to Lua: every real
---field present, and reading any other field raises, so code that probes
---for methods on them fails here as it does in WezTerm.

local M = {}

local PANE = {
  pane_id = 0,
  pane_index = 0,
  is_active = true,
  is_zoomed = false,
  left = 0,
  top = 0,
  width = 80,
  height = 24,
  pixel_width = 800,
  pixel_height = 480,
  title = "",
  user_vars = {},
  progress = "None",
  foreground_process_name = "",
  current_working_dir = nil,
  has_unseen_output = false,
  domain_name = "local",
  tty_name = nil,
}

local TAB = {
  tab_id = 0,
  tab_index = 0,
  is_active = false,
  is_last_active = false,
  active_pane = nil,
  panes = nil,
  window_id = 0,
  window_title = "",
  tab_title = "",
}

---@param  fields table
---@param  known  table
---@param  kind   string
---@return table
local function lock(fields, known, kind)
  for k in pairs(fields) do
    assert(
      known[k] ~= nil
        or k == "current_working_dir"
        or k == "tty_name"
        or k == "active_pane"
        or k == "panes",
      kind .. " has no field " .. k
    )
  end
  local out = {}
  for k, v in pairs(known) do
    out[k] = v
  end
  for k, v in pairs(fields) do
    out[k] = v
  end
  return setmetatable(out, {
    __index = function(_, k)
      if known[k] == nil and k ~= "current_working_dir" and k ~= "tty_name" then
        error("attempt to get an unknown field '" .. tostring(k) .. "'", 2)
      end
      return nil
    end,
  })
end

---@param  fields? table
---@return table PaneInformation
function M.pane(fields)
  fields = fields or {}
  local copy = {}
  for k, v in pairs(fields) do
    copy[k] = v
  end
  copy.user_vars = copy.user_vars or {}
  return lock(copy, PANE, "PaneInformation")
end

---@param  fields table must hold active_pane; panes defaults to { active_pane }
---@return table TabInformation
function M.tab(fields)
  local copy = {}
  for k, v in pairs(fields) do
    copy[k] = v
  end
  copy.panes = copy.panes or { copy.active_pane }
  return lock(copy, TAB, "TabInformation")
end

return M
