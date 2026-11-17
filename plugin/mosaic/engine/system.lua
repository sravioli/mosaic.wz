---@module "mosaic.engine.system"
---@author sravioli
---@license GNU-GPLv2

---System samplers for the cpu, ram, network and disk modules.
---
---`update-status` runs on the GUI thread, so nothing here may block:
---  * Linux reads `/proc` files directly (microseconds).
---  * macOS runs only fast commands (`ps`, `vm_stat`, `sysctl`, `netstat`,
---    `df`) with argument lists, never `top -l 2`.
---  * Windows is unsupported for now: PowerShell CIM queries take hundreds of
---    milliseconds, so the modules hide themselves there.
---Callers throttle through the module's `update` interval. Delta samples
---(cpu, network) live in `wezterm.GLOBAL` so they survive config reloads.
---Every sampler returns nil on failure instead of raising.

local log = require "mosaic.engine.logger"

local M = {}

local warp = require("mosaic.engine.deps").warp

-- mosaic's own names; warp says "mac" and "unknown".
M.os = ({ windows = "windows", mac = "macos" })[warp.filesystem.platform().os] or "linux"

-- ── IO (replaceable in specs) ──────────────────────────────────────────────

---@param  path string
---@return string|nil
function M.read_file(path)
  return warp.filesystem.read_file(path)
end

---warp resolves `ps`, `sysctl` and `df` even when a GUI launch leaves PATH short.
---@param  argv string[]
---@return string|nil stdout
function M.run(argv)
  local ok, stdout = warp.process.run(argv)
  if ok then
    return stdout
  end
  log:debug("%s failed", argv[1])
  return nil
end

---@return number seconds
function M.now()
  return os.time()
end

---@param  key string
---@return table
local function state(key)
  return require("mosaic.engine.store").record("mosaic_" .. key)
end

-- ── Parsers (pure) ─────────────────────────────────────────────────────────

---`/proc/stat` aggregate line → busy and total jiffies.
---@param  text string
---@return number|nil busy, number|nil total
function M.parse_proc_stat(text)
  local line = text and text:match "^cpu%s+([^\n]+)"
  if not line then
    return nil
  end
  local f = {}
  for n in line:gmatch "%d+" do
    f[#f + 1] = tonumber(n)
  end
  if #f < 4 then
    return nil
  end
  local total = 0
  for i = 1, math.min(#f, 8) do -- guest columns are already in user/nice
    total = total + f[i]
  end
  local idle = f[4] + (f[5] or 0)
  return total - idle, total
end

---`/proc/meminfo` → used fraction.
---@param  text string
---@return number|nil
function M.parse_meminfo(text)
  local total = text and tonumber(text:match "MemTotal:%s+(%d+)")
  local avail = text and tonumber(text:match "MemAvailable:%s+(%d+)")
  if not total or not avail or total == 0 then
    return nil
  end
  return 1 - avail / total
end

---Whether Linux interface `name` is virtual (tunnel, bridge, veth, dummy): its
---traffic also crosses a real card, so counting both would double it.
---@param  name string
---@return boolean
function M.is_virtual(name)
  local f = io.open("/sys/devices/virtual/net/" .. name)
  if f then
    f:close()
    return true
  end
  return false
end

---`/proc/net/dev` → rx, tx byte counters summed over non-loopback interfaces.
---@param  text  string
---@param  skip? fun(name: string): boolean interfaces to leave out
---@return number|nil rx, number|nil tx
function M.parse_net_dev(text, skip)
  if not text then
    return nil
  end
  local rx, tx, seen = 0, 0, false
  for name, rest in text:gmatch "\n%s*([^%s:]+):([^\n]*)" do
    if name ~= "lo" and not (skip and skip(name)) then
      local f = {}
      for n in rest:gmatch "%d+" do
        f[#f + 1] = tonumber(n)
      end
      if #f >= 9 then
        rx, tx, seen = rx + f[1], tx + f[9], true
      end
    end
  end
  if not seen then
    return nil
  end
  return rx, tx
end

---`netstat -ibn` (macOS) → rx, tx bytes over physical link rows (no loopback,
---tunnel, bridge or AirDrop interfaces, whose traffic is counted on a real one).
---@param  text string
---@return number|nil rx, number|nil tx
function M.parse_netstat(text)
  if not text then
    return nil
  end
  local rx, tx, seen = 0, 0, false
  for line in text:gmatch "[^\n]+" do
    local name, rest = line:match "^(%S+)%s+%d+%s+<Link#%d+>(.*)$"
    if
      name
      and not name:match "^lo"
      and not name:match "^utun"
      and not name:match "^bridge"
      and not name:match "^awdl"
      and not name:match "^llw"
      and not name:match "^ap%d"
    then
      local f = {}
      for n in rest:gmatch "%S+" do
        f[#f + 1] = n
      end
      -- With an address: Address Ipkts Ierrs Ibytes Opkts Oerrs Obytes Coll
      -- Without one the Address column is absent.
      local off = (#f >= 8) and 1 or 0
      local ib, ob = tonumber(f[off + 3]), tonumber(f[off + 6])
      if ib and ob then
        rx, tx, seen = rx + ib, tx + ob, true
      end
    end
  end
  if not seen then
    return nil
  end
  return rx, tx
end

---`vm_stat` + `hw.memsize` (macOS) → used fraction (active + wired + compressed).
---@param  text    string
---@param  memsize number bytes
---@return number|nil
function M.parse_vm_stat(text, memsize)
  if not text or not memsize or memsize <= 0 then
    return nil
  end
  local page = tonumber(text:match "page size of (%d+) bytes")
  local function pages(label)
    return tonumber(text:match(label .. ":%s+(%d+)")) or 0
  end
  if not page then
    return nil
  end
  local used = pages "Pages active"
    + pages "Pages wired down"
    + pages "Pages occupied by compressor"
  return math.min(1, used * page / memsize)
end

---`ps -A -o %cpu` (macOS) → summed percentage.
---@param  text string
---@return number|nil
function M.parse_ps_cpu(text)
  if not text then
    return nil
  end
  local sum, seen = 0, false
  for n in text:gmatch "\n%s*([%d%.]+)" do
    sum, seen = sum + tonumber(n), true
  end
  return seen and sum or nil
end

---`df -kP <path>` → used fraction as `df` shows it: used / (used + available),
---so blocks reserved for root count as used.
---@param  text string
---@return number|nil
function M.parse_df(text)
  if not text then
    return nil
  end
  local used, avail = text:match "\n%S+%s+%d+%s+(%d+)%s+(%d+)"
  used, avail = tonumber(used), tonumber(avail)
  if not used or used + avail == 0 then
    return nil
  end
  return used / (used + avail)
end

-- ── Samplers ───────────────────────────────────────────────────────────────

---@return boolean
function M.supported()
  return M.os ~= "windows"
end

---CPU utilisation in [0, 1]. The first Linux sample has no delta: nil.
---@return number|nil
function M.cpu()
  if M.os == "linux" then
    local busy, total = M.parse_proc_stat(M.read_file "/proc/stat")
    if not busy then
      return nil
    end
    local s, now = state "cpu", M.now()
    local pb, pt = s.busy, s.total
    -- Another window sampled this second: its reading, not a delta over a
    -- few ticks.
    if s.t and now <= s.t and s.value then
      return s.value
    end
    s.busy, s.total, s.t = busy, total, now
    if not pb or total <= pt then
      return nil
    end
    s.value = (busy - pb) / (total - pt)
    return s.value
  elseif M.os == "macos" then
    local s = state "cpu"
    if not s.ncpu then
      s.ncpu = tonumber((M.run { "sysctl", "-n", "hw.ncpu" } or ""):match "%d+")
    end
    local sum = M.parse_ps_cpu(M.run { "ps", "-A", "-o", "%cpu" })
    if not sum or not s.ncpu then
      return nil
    end
    return math.min(1, sum / 100 / s.ncpu)
  end
  return nil
end

---Memory in use, [0, 1].
---@return number|nil
function M.ram()
  if M.os == "linux" then
    return M.parse_meminfo(M.read_file "/proc/meminfo")
  elseif M.os == "macos" then
    local s = state "ram"
    if not s.memsize then
      s.memsize = tonumber((M.run { "sysctl", "-n", "hw.memsize" } or ""):match "%d+")
    end
    return M.parse_vm_stat(M.run { "vm_stat" }, s.memsize)
  end
  return nil
end

---Network throughput in bytes/second since the previous call.
---@return number|nil down, number|nil up
function M.network()
  local rx, tx
  if M.os == "linux" then
    rx, tx = M.parse_net_dev(M.read_file "/proc/net/dev", M.is_virtual)
  elseif M.os == "macos" then
    rx, tx = M.parse_netstat(M.run { "netstat", "-ibn" })
  end
  if not rx then
    return nil
  end
  local s, now = state "net", M.now()
  local prx, ptx, pt = s.rx, s.tx, s.t
  -- Another window sampled this second: its rates, not a zero-length delta.
  if pt and now <= pt and s.down then
    return s.down, s.up
  end
  s.rx, s.tx, s.t = rx, tx, now
  if not prx or now <= pt or rx < prx or tx < ptx then
    return nil
  end
  local dt = now - pt
  s.down, s.up = (rx - prx) / dt, (tx - ptx) / dt
  return s.down, s.up
end

---Used fraction of the root (macOS: data) volume.
---@return number|nil
function M.disk()
  if M.os == "windows" then
    return nil
  end
  local path = M.os == "macos" and "/System/Volumes/Data" or "/"
  return M.parse_df(M.run { "df", "-kP", path })
end

-- ── Formatting ─────────────────────────────────────────────────────────────

---@param  fraction number|nil
---@return string
function M.percent(fraction)
  if not fraction then
    return "--%"
  end
  return ("%d%%"):format(math.floor(fraction * 100 + 0.5))
end

---@param  bytes number|nil bytes per second
---@return string
function M.rate(bytes)
  if not bytes then
    return "--"
  end
  local units = { "B", "K", "M", "G" }
  local i = 1
  while bytes >= 1000 and i < #units do
    bytes, i = bytes / 1024, i + 1
  end
  return (i == 1 or bytes >= 10) and ("%d%s"):format(math.floor(bytes + 0.5), units[i])
    or ("%.1f%s"):format(bytes, units[i])
end

return M
