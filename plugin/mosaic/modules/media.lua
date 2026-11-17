---@module "mosaic.modules.media"
---@author sravioli
---@license GNU-GPLv2

---Now playing: `playerctl` on Linux (or the players' MPRIS D-Bus interface
---through systemd's `busctl` when playerctl is not installed), Music or
---Spotify through `osascript` on macOS. The player is asked from a timer (every `interval` seconds, default
---5), where WezTerm can wait on a process without freezing the window; the
---module itself only reads the last answer from `wezterm.GLOBAL`. Hidden
---when nothing plays.
---
---Options: `interval`, `players` (playerctl `--player` list), `format`
---(`"{artist} - {title}"`), `paused = true` (show paused tracks too),
---`max_length`.
---
---shortcut: Windows is unsupported until a non-blocking source exists.

local wezterm = require "wezterm"

local config = require "mosaic.engine.config"
local paths = require "mosaic.engine.paths"
local store = require "mosaic.engine.store"
local system = require "mosaic.engine.system"
local process = require("mosaic.engine.deps").warp.process

local KEY = "__mosaic:media"
local GEN = "__mosaic:media:gen"

-- `setup` bumps the generation on every config evaluation; a chain stops at
-- its next tick once the generation it started under is gone, and the module
-- starts a new one on its next draw.
local chain

local OSASCRIPT = [[
on track_of(appname)
  if application appname is running then
    tell application appname
      return (player state as string) & tab & (artist of current track) & tab & (name of current track)
    end tell
  end if
  return ""
end track_of
set t to track_of("Spotify")
if t is "" or t does not start with "playing" then
  set m to track_of("Music")
  if m is not "" then set t to m
end if
return t
]]

local MPRIS = "org.mpris.MediaPlayer2."

---@param  text string|nil
---@return any|nil
local function json(text)
  if not text or text == "" then
    return nil
  end
  local decode = wezterm.json_parse or (wezterm.serde and wezterm.serde.json_decode)
  local ok, value = pcall(decode, text)
  return ok and value or nil
end

---Whether bus name `name` belongs to one of `players` (playerctl names such
---as "spotify" or "firefox"); every player without the option.
---@param  name    string
---@param  players string[]|nil
---@return boolean
local function wanted(name, players)
  if not players then
    return true
  end
  local short = name:sub(#MPRIS + 1)
  for _, p in ipairs(players) do
    if short:sub(1, #p) == p then
      return true
    end
  end
  return false
end

---`status \t artist \t title` of the first playing MPRIS player (else the
---first paused one), read with busctl.
---@param  opts table
---@return boolean ok, string out
local function busctl(opts)
  local ok, out = process.run { "busctl", "--user", "--no-legend", "list" }
  if not ok then
    return false, ""
  end
  local best
  for line in out:gmatch "[^\n]+" do
    local name = line:match "^(%S+)"
    if name and name:sub(1, #MPRIS) == MPRIS and wanted(name, opts.players) then
      local pok, props = process.run {
        "busctl",
        "--user",
        "--json=short",
        "get-property",
        name,
        "/org/mpris/MediaPlayer2",
        "org.mpris.MediaPlayer2.Player",
        "PlaybackStatus",
        "Metadata",
      }
      local status_line, meta_line = (pok and props or ""):match "^([^\n]*)\n([^\n]*)"
      local status = json(status_line)
      local meta = json(meta_line)
      status = type(status) == "table" and status.data or nil
      meta = type(meta) == "table" and type(meta.data) == "table" and meta.data or {}
      local title = type(meta["xesam:title"]) == "table" and meta["xesam:title"].data or ""
      local artists = type(meta["xesam:artist"]) == "table" and meta["xesam:artist"].data or {}
      local artist = type(artists) == "table" and table.concat(artists, ", ") or tostring(artists)
      if status and title ~= "" then
        local track = ("%s\t%s\t%s"):format(status, artist, title)
        if status == "Playing" then
          return true, track
        end
        best = best or track
      end
    end
  end
  return best ~= nil, best or ""
end

local warned = false

---Ask the player once; store `{ status, artist, title }` or false.
---@param opts table
local function poll(opts)
  local os_name = system.os
  local ok, out
  if os_name == "linux" then
    if process.which "playerctl" then
      local argv = { "playerctl" }
      if opts.players then
        argv[#argv + 1] = "--player=" .. table.concat(opts.players, ",")
      end
      for _, a in ipairs { "metadata", "--format", "{{status}}\t{{artist}}\t{{title}}" } do
        argv[#argv + 1] = a
      end
      ok, out = process.run(argv)
    elseif process.which "busctl" then
      ok, out = busctl(opts)
    elseif not warned then
      warned = true
      wezterm.log_warn "[mosaic] media: install playerctl (or systemd's busctl) to show what plays"
    end
  elseif os_name == "macos" then
    ok, out = process.run { "osascript", "-e", OSASCRIPT }
  end
  local status, artist, title = (ok and out or ""):match "^([^\t]*)\t([^\t]*)\t([^\r\n]*)"
  if not status or title == "" then
    store.set(KEY, false)
    return
  end
  store.set(KEY, {
    status = status:lower(),
    artist = paths.clean(artist),
    title = paths.clean(title),
  })
end

---@param gen  any generation the chain started under
local function tick(gen)
  if store.value(GEN) ~= gen then
    return
  end
  local opts = config.option "media"
  local ok, err = pcall(poll, opts)
  if not ok then
    wezterm.log_warn("[mosaic] media: " .. tostring(err))
  end
  -- At least a second: 0 would respawn the player query in a tight loop.
  wezterm.time.call_after(math.max(tonumber(opts.interval) or 5, 1), function()
    tick(gen)
  end)
end

return function()
  if not system.supported() then
    return { enabled = false }
  end
  local gen = store.value(GEN)
  if chain ~= gen then
    chain = gen
    wezterm.time.call_after(0, function()
      tick(gen)
    end)
  end
  local track = store.get(KEY, { "status", "artist", "title" })
  local opts = config.option "media"
  if type(track) ~= "table" or (track.status ~= "playing" and not opts.paused) then
    return { enabled = false }
  end
  local fmt = opts.format or "{artist} - {title}"
  local text = fmt
    :gsub("{(%w+)}", function(field)
      return track[field] or ""
    end)
    :gsub("^%s*%-%s*", "")
  if opts.max_length then
    text = paths.shorten(text, { max_length = opts.max_length })
  end
  local nf = wezterm.nerdfonts
  return {
    enabled = true,
    cond = true,
    can_hide = true,
    padding = { left = 1 },
    icon = {
      enabled = true,
      value = (track.status == "playing" and nf.md_music or nf.md_pause) or "",
      padding = { right = 1 },
    },
    text = { enabled = true, value = text, variants = { track.title } },
  }
end
