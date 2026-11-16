--- Hand-written wezterm mock for mosaic specs.
--- Also puts sibling plugin checkouts (warp, log, warden, sigil, ribbon) on
--- package.path so mosaic runs against its real dependencies.

if package.loaded["wezterm"] then
  return package.loaded["wezterm"]
end

-- selene: allow(incorrect_standard_library_use)
local sep = package.config:sub(1, 1)
local is_win = sep == "\\"

for _, name in ipairs { "warp", "log", "warden", "sigil", "ribbon" } do
  local base = "../" .. name .. ".wz/plugin/"
  package.path = base .. "?.lua;" .. base .. "?/init.lua;" .. package.path
end

local M = {}

M._calls = {}
M._handlers = {}
M._emitted = {}
M._timers = {}

local function record(name)
  return function(...)
    M._calls[#M._calls + 1] = { fn = name, args = { ... } }
  end
end

M.log_info = record "log_info"
M.log_warn = record "log_warn"
M.log_error = record "log_error"

M.GLOBAL = {}
M.home_dir = is_win and "C:\\Users\\mock" or "/home/mock"
M.config_dir = is_win and "C:\\mock\\config" or "/mock/config"
M.executable_dir = is_win and "C:\\mock\\bin" or "/mock/bin"
M.target_triple = is_win and "x86_64-pc-windows-msvc" or "x86_64-unknown-linux-gnu"
M.version = "20240203-110809-5046fc22"

function M.to_string(v)
  return tostring(v)
end

local function ulen(s)
  local _, n = s:gsub("[^\128-\191]", "")
  return n
end

function M.column_width(s)
  return ulen(s)
end

-- Column-based like the real API (one column per codepoint here).
local function codepoints(s)
  local cps = {}
  for cp in s:gmatch "[^\128-\191][\128-\191]*" do
    cps[#cps + 1] = cp
  end
  return cps
end

function M.truncate_right(s, n)
  local cps = codepoints(s)
  return table.concat(cps, "", 1, math.min(#cps, math.max(0, n)))
end

function M.truncate_left(s, n)
  local cps = codepoints(s)
  return table.concat(cps, "", math.max(1, #cps - math.max(0, n) + 1), #cps)
end

function M.pad_right(s, n)
  return s .. string.rep(" ", math.max(0, n - ulen(s)))
end

function M.pad_left(s, n)
  return string.rep(" ", math.max(0, n - ulen(s))) .. s
end

-- ── JSON (enough for round trips in specs) ─────────────────────────────────

local function is_array(t)
  local n = 0
  for _ in pairs(t) do
    n = n + 1
  end
  for i = 1, n do
    if t[i] == nil then
      return false
    end
  end
  return true
end

local function encode(v)
  local tv = type(v)
  if tv == "nil" then
    return "null"
  elseif tv == "boolean" or tv == "number" then
    return tostring(v)
  elseif tv == "string" then
    return '"'
      .. v:gsub('[%c"\\]', function(c)
        local map =
          { ['"'] = '\\"', ["\\"] = "\\\\", ["\n"] = "\\n", ["\r"] = "\\r", ["\t"] = "\\t" }
        return map[c] or string.format("\\u%04x", c:byte())
      end)
      .. '"'
  elseif tv == "table" then
    local parts = {}
    if next(v) ~= nil and is_array(v) then
      for i = 1, #v do
        parts[i] = encode(v[i])
      end
      return "[" .. table.concat(parts, ",") .. "]"
    end
    local keys = {}
    for k in pairs(v) do
      keys[#keys + 1] = tostring(k)
    end
    table.sort(keys)
    for _, k in ipairs(keys) do
      local val = v[k]
      if val == nil then
        val = v[tonumber(k)]
      end
      parts[#parts + 1] = encode(k) .. ":" .. encode(val)
    end
    return "{" .. table.concat(parts, ",") .. "}"
  end
  error("cannot encode " .. tv)
end

local function decode(s)
  local pos = 1
  local function ws()
    pos = s:find("[^%s]", pos) or #s + 1
  end
  local value
  local function str()
    local out = {}
    pos = pos + 1
    while true do
      local c = s:sub(pos, pos)
      if c == "" then
        error "unterminated string"
      elseif c == '"' then
        pos = pos + 1
        return table.concat(out)
      elseif c == "\\" then
        local e = s:sub(pos + 1, pos + 1)
        local map = { n = "\n", r = "\r", t = "\t", ['"'] = '"', ["\\"] = "\\", ["/"] = "/" }
        if e == "u" then
          out[#out + 1] = string.char(tonumber(s:sub(pos + 2, pos + 5), 16) % 256)
          pos = pos + 6
        else
          out[#out + 1] = map[e] or e
          pos = pos + 2
        end
      else
        out[#out + 1] = c
        pos = pos + 1
      end
    end
  end
  function value()
    ws()
    local c = s:sub(pos, pos)
    if c == "{" then
      local t = {}
      pos = pos + 1
      ws()
      if s:sub(pos, pos) == "}" then
        pos = pos + 1
        return t
      end
      while true do
        ws()
        local k = str()
        ws()
        pos = pos + 1 -- :
        t[k] = value()
        ws()
        local d = s:sub(pos, pos)
        pos = pos + 1
        if d == "}" then
          return t
        end
      end
    elseif c == "[" then
      local t = {}
      pos = pos + 1
      ws()
      if s:sub(pos, pos) == "]" then
        pos = pos + 1
        return t
      end
      while true do
        t[#t + 1] = value()
        ws()
        local d = s:sub(pos, pos)
        pos = pos + 1
        if d == "]" then
          return t
        end
      end
    elseif c == '"' then
      return str()
    elseif s:sub(pos, pos + 3) == "true" then
      pos = pos + 4
      return true
    elseif s:sub(pos, pos + 4) == "false" then
      pos = pos + 5
      return false
    elseif s:sub(pos, pos + 3) == "null" then
      pos = pos + 4
      return nil
    end
    local num = s:match("^-?%d+%.?%d*[eE]?[-+]?%d*", pos)
    if not num or num == "" then
      error("unexpected json at " .. pos)
    end
    pos = pos + #num
    return tonumber(num)
  end
  return value()
end

M.serde = {
  json_encode = encode,
  json_decode = decode,
}
M.json_encode = encode
M.json_parse = decode

-- ── time ───────────────────────────────────────────────────────────────────

M.time = {
  now = function()
    local ts = os.time()
    return setmetatable({}, {
      __index = {
        format = function(_, fmt)
          if fmt == "%s" then
            return tostring(ts)
          end
          return os.date((fmt:gsub("%%.3f", ".000")), ts)
        end,
      },
    })
  end,
  call_after = function(secs, fn)
    M._timers[#M._timers + 1] = { secs = secs, fn = fn }
  end,
}

---Run queued timers once (those queued while running are kept for later).
function M._run_timers()
  local q = M._timers
  M._timers = {}
  for _, t in ipairs(q) do
    t.fn()
  end
end

-- ── events / actions / format ──────────────────────────────────────────────

function M.on(name, fn)
  M._handlers[name] = M._handlers[name] or {}
  table.insert(M._handlers[name], fn)
end

function M.emit(name, ...)
  M._emitted[#M._emitted + 1] = { name = name, args = { ... } }
  for _, fn in ipairs(M._handlers[name] or {}) do
    fn(...)
  end
  return true
end

M.action = setmetatable({}, {
  __index = function(_, name)
    return setmetatable({ _action = name }, {
      __call = function(self, args)
        return { action = self._action, args = args }
      end,
    })
  end,
})

function M.action_callback(fn)
  return { action = "EmitEvent", callback = fn }
end

---Serialize every item (styles included) so snapshots catch colour changes.
local function fmt_value(v)
  if type(v) ~= "table" then
    return tostring(v)
  end
  local keys = {}
  for k in pairs(v) do
    keys[#keys + 1] = tostring(k)
  end
  table.sort(keys)
  local parts = {}
  for _, k in ipairs(keys) do
    parts[#parts + 1] = k .. "=" .. fmt_value(v[k] == nil and v[tonumber(k)] or v[k])
  end
  return "{" .. table.concat(parts, ",") .. "}"
end

function M.format(items)
  local out = {}
  for _, it in ipairs(items) do
    if it == "ResetAttributes" then
      out[#out + 1] = "\27{ResetAttributes}"
    elseif type(it) == "string" then
      out[#out + 1] = it
    elseif it.Text then
      out[#out + 1] = it.Text
    else
      out[#out + 1] = "\27" .. fmt_value(it)
    end
  end
  return table.concat(out)
end

-- Glyph per name: one column wide, stable across runs.
M.nerdfonts = setmetatable({}, {
  __index = function()
    return "\u{E000}"
  end,
})

-- ── colour / time / battery ────────────────────────────────────────────────

local Color = {}
Color.__index = Color
Color.__tostring = function(c)
  return c.hex
end
function Color:darken(f)
  return setmetatable({ hex = self.hex .. "-d" .. f }, Color)
end
function Color:lighten(f)
  return setmetatable({ hex = self.hex .. "+l" .. f }, Color)
end
M.color = {
  parse = function(hex)
    return setmetatable({ hex = tostring(hex) }, Color)
  end,
}

M._now = os.time { year = 2026, month = 11, day = 15, hour = 14, min = 5, sec = 0 }
-- os.date rejects the GNU `%-d` flag; expand it by hand.
function M.strftime(fmt)
  fmt = fmt:gsub("%%%-d", tostring(tonumber(os.date("%d", M._now))))
  return os.date(fmt, M._now)
end

M._battery = {}
function M.battery_info()
  return M._battery
end

-- ── fs / process ───────────────────────────────────────────────────────────

M._dirs = {}
function M.read_dir(p)
  local entries = M._dirs[p]
  if not entries then
    error("no such dir: " .. tostring(p))
  end
  return entries
end

M._child = { ok = false, stdout = "", stderr = "mock" }
M._child_calls = {}
function M.run_child_process(argv)
  M._child_calls[#M._child_calls + 1] = argv
  local r = M._child
  if type(r) == "function" then
    return r(argv)
  end
  return r.ok, r.stdout, r.stderr
end

M._globs = {}
function M.glob(pattern)
  return M._globs[pattern] or {}
end

function M.background_child_process(argv)
  M._child_calls[#M._child_calls + 1] = argv
end

function M.background_task(fn)
  fn()
end

M.plugin = {
  list = function()
    return {}
  end,
  require = function(url)
    error("plugin.require disabled in specs: " .. url)
  end,
}

-- ── mux ────────────────────────────────────────────────────────────────────

M._active_workspace = "default"
M._workspaces = { "default" }
M._domains = {}
M.mux = {
  get_active_workspace = function()
    return M._active_workspace
  end,
  set_active_workspace = function(n)
    M._active_workspace = n
  end,
  get_workspace_names = function()
    return M._workspaces
  end,
  all_windows = function()
    return {}
  end,
  all_domains = function()
    return M._domains
  end,
  get_domain = function(name)
    for _, d in ipairs(M._domains) do
      if d:name() == name then
        return d
      end
    end
    return nil
  end,
}

---Reset all recorded state between tests.
function M._reset()
  M._calls, M._handlers, M._emitted, M._timers = {}, {}, {}, {}
  M._dirs, M._child_calls, M._globs = {}, {}, {}
  M._child = { ok = false, stdout = "", stderr = "mock" }
  M._active_workspace, M._workspaces, M._domains = "default", { "default" }, {}
  for k in pairs(M.GLOBAL) do
    M.GLOBAL[k] = nil
  end
end

package.loaded["wezterm"] = M
_G.wezterm = M
return M
