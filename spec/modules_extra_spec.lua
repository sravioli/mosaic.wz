local wezterm = require "wezterm"

local scenarios = dofile "spec/support/scenarios.lua"

local PRESETS = {
  "powerline",
  "minimal",
  "bubbles",
  "slanted",
  "slanted-inverted",
  "blocks",
  "brackets",
  "pure",
}

local function fresh(opts)
  for k in pairs(package.loaded) do
    if k:match "^mosaic" then
      package.loaded[k] = nil
    end
  end
  wezterm._reset()
  local mosaic = require "mosaic.api"
  mosaic.setup(opts)
  mosaic.apply_to_config {}
  return mosaic
end

---Render `opts` in the idle@240 scenario, `patch` adjusting the scenario.
local function bar(opts, patch)
  local mosaic = fresh(opts)
  local s = {}
  for k, v in pairs(scenarios.list[16]) do
    s[k] = v
  end
  for k, v in pairs(patch or {}) do
    s[k] = v
  end
  local window, pane = scenarios.build(s)
  if s.pane then
    for k, v in pairs(s.pane) do
      pane[k] = v
    end
  end
  if s.window then
    for k, v in pairs(s.window) do
      window[k] = v
    end
  end
  mosaic.refresh(window, pane)
  return window._left or "", window._right or "", window, pane, mosaic
end

local function plain(s)
  return (s or ""):gsub("\27%b{}", "")
end

local function has(s, needle)
  return s:find(needle, 1, true) ~= nil
end

local function tmpdir()
  local dir = os.tmpname()
  os.remove(dir)
  assert(os.execute("mkdir -p '" .. dir .. "'"))
  return dir
end

local function write(path, text)
  local f = assert(io.open(path, "w"))
  f:write(text)
  f:close()
end

describe("state colour (tint)", function()
  for _, preset in ipairs(PRESETS) do
    it(preset .. " paints a tinted module in its tint, inside a group too", function()
      local _, right = bar {
        preset = preset,
        layout = { right = { { "a", "b" } } },
        modules = {
          a = { enabled = true, cond = true, text = { enabled = true, value = "A" } },
          b = {
            enabled = true,
            cond = true,
            tint = "#ab0000",
            text = { enabled = true, value = "B" },
          },
        },
        style = { colors = { b = 4 } },
      }
      assert.is_true(has(right, "#ab0000"), preset .. ": " .. right)
    end)
  end
end)

describe("battery", function()
  local two = {
    { state_of_charge = 0.12, state = "Discharging", time_to_empty = 3600 + 13 * 60 },
    { state_of_charge = 0.8, state = "Charging", time_to_full = 600 },
  }

  it("shows every battery and the time left", function()
    local _, right = bar({
      preset = "minimal",
      layout = { right = { "battery" } },
      options = { battery = { all = true, time = true, cond = true } },
    }, { battery = two })
    assert.is_true(has(plain(right), "12% 1:13 80% 0:10"), plain(right))
  end)

  it("tints by charge level, the lowest threshold winning", function()
    local _, right = bar({
      preset = "powerline",
      layout = { right = { { "cwd", "battery" } } },
      options = { battery = { levels = { [15] = "#ff0000", [50] = "#ffff00" }, cond = true } },
    }, { battery = two })
    assert.is_true(has(right, "#ff0000"), right)
    assert.is_false(has(right, "#ffff00"), right)
  end)
end)

describe("battery charging", function()
  it("shows the plugged-in glyph when full and survives unknown states", function()
    local opts = {
      preset = "minimal",
      layout = { right = { "battery" } },
      options = { battery = { cond = true } },
    }
    local _, full = bar(opts, { battery = { { state_of_charge = 1, state = "Full" } } })
    local _, unknown = bar(opts, { battery = { { state_of_charge = 0.02, state = "Unknown" } } })
    assert.is_true(has(plain(full), "100%"), plain(full))
    assert.is_true(has(plain(unknown), "2%"), plain(unknown))
  end)

  it("takes the charging colour over levels while charging", function()
    local opts = {
      preset = "powerline",
      layout = { right = { { "cwd", "battery" } } },
      options = { battery = { levels = { [50] = "#ff0000" }, charging = "#00ff00", cond = true } },
    }
    local _, charging = bar(opts, { battery = { { state_of_charge = 0.2, state = "Charging" } } })
    local _, draining =
      bar(opts, { battery = { { state_of_charge = 0.2, state = "Discharging" } } })
    assert.is_true(has(charging, "#00ff00") and not has(charging, "#ff0000"), charging)
    assert.is_true(has(draining, "#ff0000") and not has(draining, "#00ff00"), draining)
  end)
end)

describe("cwd and parent", function()
  it("shorten the home directory, apply aliases and cut long paths", function()
    local fs = require("mosaic.engine.deps").warp.filesystem
    local home = fs.home
    fs.home = "/home/mock" -- warp reads HOME, not the mock's home_dir
    finally(function()
      fs.home = home
    end)
    local cwd = "file://devbox.local/home/mock/work/deep/nested/project"
    local _, right = bar({
      preset = "minimal",
      layout = { right = { "cwd" } },
      options = { cwd = { git_root = false, home = "~", cond = true } },
    }, { cwd = cwd })
    assert.is_true(has(plain(right), "~/work/deep/nested/project"), plain(right))
    fs.home = home
    _, right = bar({
      preset = "minimal",
      layout = { right = { "cwd" } },
      options = {
        cwd = {
          git_root = false,
          aliases = { { pattern = "^/home/mock/work", replacement = "W" } },
          cond = true,
        },
      },
    }, { cwd = cwd })
    assert.is_true(has(plain(right), "W/deep/nested/project"), plain(right))
    _, right = bar({
      preset = "minimal",
      layout = { right = { "cwd" } },
      options = { cwd = { git_root = false, max_length = 10, cond = true } },
    }, { cwd = cwd })
    assert.is_true(has(plain(right), "…d/project"), plain(right))
  end)
end)

describe("mode", function()
  it("takes text, icon and colour per key table", function()
    local _, right = bar({
      preset = "powerline",
      layout = { right = { { "cwd", "mode" } } },
      options = {
        mode = { modes = { copy_mode = { text = "YANK", icon = "Y", color = "#00aa00" } } },
      },
    }, { key_table = "copy_mode" })
    assert.is_true(has(plain(right), "Y YANK"), plain(right))
    assert.is_true(has(right, "#00aa00"), right)
  end)
end)

describe("process and domain", function()
  it("map processes and domains to icons the user can extend", function()
    local _, right = bar({
      preset = "minimal",
      layout = { right = { "process", "domain" } },
      options = { process = { icons = { nvim = "V" } }, domain = { icons = { SSH = "S" } } },
    }, {
      pane = {
        get_foreground_process_name = function()
          return "/usr/bin/nvim"
        end,
        get_domain_name = function()
          return "SSH:box"
        end,
      },
    })
    local text = plain(right)
    assert.is_true(has(text, "V nvim"), text)
    assert.is_true(has(text, "S SSH:box"), text)
  end)
end)

describe("git", function()
  it("reads the branch, and the short commit when detached", function()
    local root = tmpdir()
    assert(os.execute("mkdir -p '" .. root .. "/.git' '" .. root .. "/sub/dir'"))
    write(root .. "/.git/HEAD", "ref: refs/heads/feat/x\n")
    local _, right = bar(
      { preset = "minimal", layout = { right = { "git" } } },
      { cwd = "file://host" .. root .. "/sub/dir" }
    )
    assert.is_true(has(plain(right), "feat/x"), plain(right))
    write(root .. "/.git/HEAD", "0123456789abcdef\n")
    _, right = bar(
      { preset = "minimal", layout = { right = { "git" } } },
      { cwd = "file://host" .. root }
    )
    assert.is_true(has(plain(right), "0123456"), plain(right))
    os.execute("rm -rf '" .. root .. "'")
  end)

  it("follows a worktree's gitdir file and hides outside a repository", function()
    local root, gitdir = tmpdir(), tmpdir()
    write(gitdir .. "/HEAD", "ref: refs/heads/wt\n")
    write(root .. "/.git", "gitdir: " .. gitdir .. "\n")
    local _, right = bar(
      { preset = "minimal", layout = { right = { "git" } } },
      { cwd = "file://host" .. root }
    )
    assert.is_true(has(plain(right), "wt"), plain(right))
    local outside = tmpdir()
    _, right = bar(
      { preset = "minimal", layout = { right = { "git" } } },
      { cwd = "file://host" .. outside }
    )
    assert.equal("", plain(right))
    os.execute("rm -rf '" .. root .. "' '" .. gitdir .. "' '" .. outside .. "'")
  end)
end)

describe("kube", function()
  it("shows the current context and its namespace", function()
    local dir = tmpdir()
    write(
      dir .. "/config",
      table.concat({
        "apiVersion: v1",
        "contexts:",
        "- context:",
        "    cluster: a",
        "    namespace: other",
        "  name: dev",
        "- context:",
        "    cluster: b",
        "    namespace: web",
        "  name: prod",
        'current-context: "prod"',
        "kind: Config",
      }, "\n")
    )
    local _, right = bar {
      preset = "minimal",
      layout = { right = { "kube" } },
      options = { kube = { path = dir .. "/config" } },
    }
    assert.is_true(has(plain(right), "prod:web"), plain(right))
    _, right = bar {
      preset = "minimal",
      layout = { right = { "kube" } },
      options = { kube = { path = dir .. "/config", namespace = false } },
    }
    assert.is_true(has(plain(right), "prod"), plain(right))
    assert.is_false(has(plain(right), "web"), plain(right))
    os.execute("rm -rf '" .. dir .. "'")
  end)

  it("hides without a kubeconfig", function()
    local _, right = bar {
      preset = "minimal",
      layout = { right = { "kube" } },
      options = { kube = { path = "/nonexistent/config" } },
    }
    assert.equal("", plain(right))
  end)
end)

describe("media", function()
  local process = require("mosaic.engine.deps").warp.process
  local real_which = process.which
  local available

  before_each(function()
    available = { playerctl = true, busctl = true }
    process.which = function(name)
      return available[name] and ("/usr/bin/" .. name) or nil
    end
  end)

  after_each(function()
    process.which = real_which
  end)

  it("reads MPRIS through busctl without playerctl, preferring a playing player", function()
    available.playerctl = nil
    local _, _, window, pane, mosaic = bar { preset = "minimal", layout = { right = { "media" } } }
    wezterm._child = function(argv)
      if argv[#argv] == "list" then
        return true,
          "org.mpris.MediaPlayer2.firefox.instance_1 1 firefox\n"
            .. ":1.5 2 other\n"
            .. "org.mpris.MediaPlayer2.spotifast 3 spotifast\n",
          ""
      end
      local paused = argv[5]:find "firefox"
      local status = paused and "Paused" or "Playing"
      local title = paused and "Video" or "Song"
      return true,
        (
          '{"type":"s","data":"%s"}\n{"type":"a{sv}","data":{"xesam:title":{"type":"s","data":"%s"},'
          .. '"xesam:artist":{"type":"as","data":["A","B"]}}}\n'
        ):format(status, title),
        ""
    end
    wezterm._run_timers()
    mosaic.refresh(window, pane)
    assert.is_true(has(plain(window._right), "A, B - Song"), plain(window._right))
  end)

  it("only asks the players the user names", function()
    available.playerctl = nil
    local _, _, window, pane, mosaic = bar {
      preset = "minimal",
      layout = { right = { "media" } },
      options = { media = { players = { "firefox" } } },
    }
    local asked = {}
    wezterm._child = function(argv)
      if argv[#argv] == "list" then
        return true,
          "org.mpris.MediaPlayer2.firefox.i1 1 f\norg.mpris.MediaPlayer2.spotifast 2 s\n",
          ""
      end
      asked[#asked + 1] = argv[5]
      return true,
        '{"type":"s","data":"Playing"}\n{"type":"a{sv}","data":{"xesam:title":{"type":"s","data":"V"}}}\n',
        ""
    end
    wezterm._run_timers()
    mosaic.refresh(window, pane)
    assert.same({ "org.mpris.MediaPlayer2.firefox.i1" }, asked)
  end)

  it("warns once and stays hidden without playerctl or busctl", function()
    available = {}
    local warnings = {}
    local real_warn = wezterm.log_warn
    wezterm.log_warn = function(msg)
      warnings[#warnings + 1] = msg
    end
    local _, right = bar { preset = "minimal", layout = { right = { "media" } } }
    wezterm._run_timers()
    wezterm._run_timers()
    wezterm.log_warn = real_warn
    assert.equal("", plain(right))
    assert.equal(1, #warnings)
    assert.equal(0, #wezterm._child_calls)
  end)

  it("never runs a process while drawing, and shows what the timer found", function()
    local _, right, window, pane, mosaic = bar {
      preset = "minimal",
      layout = { right = { "media" } },
      options = { media = { interval = 5 } },
    }
    assert.equal("", plain(right))
    assert.equal(0, #wezterm._child_calls)
    wezterm._child = { ok = true, stdout = "Playing\tArtist\tSong\n", stderr = "" }
    wezterm._run_timers()
    assert.equal(1, #wezterm._child_calls)
    assert.equal("playerctl", wezterm._child_calls[1][1]:match "[^/]*$")
    mosaic.refresh(window, pane)
    assert.is_true(has(plain(window._right), "Artist - Song"), plain(window._right))
    assert.equal(1, #wezterm._child_calls) -- drawing again asked nothing
  end)

  it("stops the chain once a reload drops media from the layout", function()
    local _, _, _, _, mosaic = bar { preset = "minimal", layout = { right = { "media" } } }
    wezterm._child = { ok = true, stdout = "Playing\tA\tB\n", stderr = "" }
    mosaic.setup { preset = "minimal", layout = { right = { "clock" } } }
    wezterm._run_timers()
    assert.equal(0, #wezterm._child_calls)
    assert.equal(0, #wezterm._timers)
  end)

  it("restarts its chain after setup runs again with media kept", function()
    local _, _, window, pane, mosaic = bar { preset = "minimal", layout = { right = { "media" } } }
    mosaic.setup { preset = "minimal", layout = { right = { "media" } } }
    mosaic.refresh(window, pane)
    wezterm._child = { ok = true, stdout = "Playing\tA\tB\n", stderr = "" }
    wezterm._run_timers()
    assert.equal(1, #wezterm._child_calls) -- the old chain stopped, the new one ran
  end)

  it("cuts wide titles by display width", function()
    local _, _, window, pane, mosaic = bar {
      preset = "minimal",
      layout = { right = { "media" } },
      options = { media = { max_length = 6 } },
    }
    wezterm.GLOBAL["__mosaic:media"] =
      { status = "playing", artist = "宇多田ヒカル", title = "初恋" }
    mosaic.refresh(window, pane)
    local text = plain(window._right)
    assert.is_true(has(text, "…"), text)
  end)

  it("hides paused tracks unless paused = true", function()
    local _, _, window, pane, mosaic = bar { preset = "minimal", layout = { right = { "media" } } }
    wezterm.GLOBAL["__mosaic:media"] = { status = "paused", artist = "A", title = "B" }
    mosaic.refresh(window, pane)
    assert.equal("", plain(window._right))
    mosaic.setup {
      preset = "minimal",
      layout = { right = { "media" } },
      options = { media = { paused = true } },
    }
    mosaic.refresh(window, pane)
    assert.is_true(has(plain(window._right), "A - B"), plain(window._right))
  end)
end)

describe("panes and window", function()
  it("count panes above one and show the window title", function()
    local _, right = bar({ preset = "minimal", layout = { right = { "panes", "window" } } }, {
      window = {
        active_tab = function()
          return {
            panes = function()
              return { {}, {}, {} }
            end,
          }
        end,
        mux_window = function()
          return {
            tabs = function()
              return { {} }
            end,
            get_title = function()
              return "my window"
            end,
          }
        end,
      },
    })
    local text = plain(right)
    assert.is_true(has(text, "3"), text)
    assert.is_true(has(text, "my window"), text)
  end)
end)

describe("engine options", function()
  it("keeps a spec while its key holds and the interval has not passed", function()
    local now, calls, key = os.time(), 0, "a"
    local real = os.time
    os.time = function()
      return now
    end
    local _, _, window, pane, mosaic = bar {
      preset = "minimal",
      layout = { right = { "k" } },
      modules = {
        k = function()
          calls = calls + 1
          return {
            enabled = true,
            cond = true,
            update = {
              key = function()
                return key
              end,
              interval = 10,
            },
            text = { enabled = true, value = "K" },
          }
        end,
      },
    }
    mosaic.refresh(window, pane)
    assert.equal(1, calls)
    key = "b"
    mosaic.refresh(window, pane)
    assert.equal(2, calls)
    now = now + 11
    mosaic.refresh(window, pane)
    assert.equal(3, calls)
    os.time = real
  end)

  it("formats grouped modules in a narrow window", function()
    local narrow = nil
    for _, sc in ipairs(scenarios.list) do
      if sc.name == "idle@100" then
        narrow = sc
      end
    end
    local mosaic = fresh {
      preset = "powerline",
      layout = { right = { { "cwd", "clock", "battery" } } },
      options = { clock = { fmt = string.upper } },
    }
    local window, pane = scenarios.build(narrow)
    mosaic.refresh(window, pane)
    assert.is_string(window._right)
  end)

  it("formats text and its variants with fmt", function()
    local _, right = bar {
      preset = "minimal",
      layout = { right = { "m" } },
      modules = {
        m = {
          enabled = true,
          cond = true,
          text = { enabled = true, value = "hello", variants = { "hi" } },
        },
      },
      options = { m = { fmt = string.upper } },
    }
    assert.is_true(has(plain(right), "HELLO"), plain(right))
    local mosaic = require "mosaic.engine.renderer"
    local spec = mosaic.resolve_module "m"
    assert.equal("HI", spec.text.variants[1]())
  end)

  for _, preset in ipairs(PRESETS) do
    it(preset .. " colours the icon with icon.color", function()
      local _, right = bar {
        preset = preset,
        layout = { right = { "m" } },
        modules = {
          m = {
            enabled = true,
            cond = true,
            icon = { enabled = true, value = "I" },
            text = { enabled = true, value = "T" },
          },
        },
        options = { m = { icon = { color = "#0b0b0b" } } },
      }
      assert.is_true(has(right, "Foreground={Color=#0b0b0b}"), preset .. ": " .. right)
    end)
  end

  it("merges style.by_mode while a key table is active", function()
    local opts = {
      preset = "minimal",
      layout = { right = { "m" } },
      modules = { m = { enabled = true, cond = true, text = { enabled = true, value = "M" } } },
      style = {
        colors = { m = "#111111" },
        by_mode = { copy_mode = { colors = { m = "#222222" } } },
      },
    }
    local _, idle = bar(opts)
    local _, copy = bar(opts, { key_table = "copy_mode" })
    assert.is_true(has(idle, "#111111"), idle)
    assert.is_true(has(copy, "#222222"), copy)
  end)

  it("draws separators.between inside groups and counts them", function()
    local m = function(t)
      return { enabled = true, cond = true, text = { enabled = true, value = t } }
    end
    local _, right = bar {
      preset = "minimal",
      layout = { right = { { "a", "b", "c" } } },
      modules = { a = m "A", b = m "B", c = m "C" },
      style = { separators = { between = "|" } },
    }
    local text = plain(right)
    assert.equal(2, select(2, text:gsub("|", "")), text)
    assert.is_false(text:match "^%s*|" ~= nil, text)
  end)

  it("takes the palette from another scheme, keeping the bar colour", function()
    local other = {
      foreground = "#eeeeee",
      background = "#000000",
      ansi = {
        "#100000",
        "#200000",
        "#300000",
        "#400000",
        "#500000",
        "#600000",
        "#700000",
        "#800000",
      },
      brights = { "#900000" },
    }
    local _, right = bar {
      preset = "minimal",
      scheme = other,
      layout = { right = { "m" } },
      modules = {
        m = { enabled = true, cond = true, accent = 3, text = { enabled = true, value = "M" } },
      },
    }
    assert.is_true(has(right, "#300000"), right)
    assert.is_true(has(right, scenarios.theme.tab_bar.background), right)
  end)
end)
