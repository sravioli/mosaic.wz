local wezterm = require "wezterm"

local scenarios = dofile "spec/support/scenarios.lua"

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

local function build(patch)
  local s = {}
  for k, v in pairs(scenarios.list[16]) do
    s[k] = v
  end
  for k, v in pairs(patch or {}) do
    s[k] = v
  end
  return scenarios.build(s)
end

describe("hardening", function()
  it("strips control characters from program-supplied text", function()
    fresh {}
    local paths = require "mosaic.engine.paths"
    assert.equal("a[31mb", paths.clean "a\27[31m\7b")
  end)

  it("draws nothing, without raising, for a pane with no pixels", function()
    local mosaic = fresh { preset = "minimal", layout = { right = { "clock" } } }
    local window, pane = build { cols = 0 }
    assert.has_no.errors(function()
      mosaic.refresh(window, pane)
    end)
  end)

  it("never polls media faster than once a second", function()
    local mosaic = fresh {
      preset = "minimal",
      layout = { right = { "media" } },
      options = { media = { interval = 0 } },
    }
    local window, pane = build()
    mosaic.refresh(window, pane)
    wezterm._run_timers()
    assert.equal(1, wezterm._timers[#wezterm._timers].secs)
  end)

  it("forgets the notice of a window that closed", function()
    local mosaic = fresh { preset = "minimal", layout = { right = { "notice" } } }
    local gone = build { id = 1 }
    local gone_pane = gone:active_pane()
    mosaic.notify(gone, "hi")
    mosaic.refresh(gone, gone_pane)
    assert.is_not_nil(wezterm.GLOBAL["__mosaic:notice:1"])
    local alive, alive_pane = build { id = 2 }
    wezterm.gui = {
      gui_windows = function()
        return { alive }
      end,
    }
    mosaic.refresh(alive, alive_pane)
    wezterm.gui = nil
    assert.is_nil(wezterm.GLOBAL["__mosaic:notice:1"])
  end)

  it("survives the redraw timer of a closed window", function()
    local mosaic = fresh { preset = "minimal", layout = { right = { "notice" } } }
    local window = build()
    mosaic.notify(window, "hi", { seconds = 1 })
    function window:active_pane()
      error "window is gone"
    end
    assert.has_no.errors(wezterm._run_timers)
  end)

  it("keeps no badge record for a pane that was seen", function()
    fresh { preset = "minimal", tabs = { badges = true } }
    local badges = require "mosaic.tabs.badges"
    local p = {
      pane_id = function()
        return 7
      end,
      get_user_vars = function()
        return {}
      end,
      has_unseen_output = function()
        return false
      end,
    }
    badges.on_bell(p)
    assert.is_not_nil(wezterm.GLOBAL["__mosaic:badge:7"])
    badges.badge({ p }, true)
    assert.is_nil(wezterm.GLOBAL["__mosaic:badge:7"])
  end)

  it("forgets the widths of a closed window that drew last", function()
    local budget = require "mosaic.engine.budget"
    budget.use(101)
    budget.record(0, 10)
    budget.set_count(1)
    budget.forget(101)
    budget.use(102)
    budget.use(101)
    assert.equals(0, budget.total_width())
  end)

  it("fetches WezTerm's built-in schemes once", function()
    local mosaic = fresh {}
    local calls = 0
    local color = wezterm.color
    color.get_builtin_schemes = function()
      calls = calls + 1
      return { X = scenarios.theme }
    end
    local palette = mosaic.palette
    palette.scheme({}, "X")
    palette.scheme({}, "X")
    color.get_builtin_schemes = nil
    assert.equals(1, calls)
  end)

  it("falls back to balanced for plain modules whose real search is too big", function()
    local mosaic = fresh { preset = "minimal", fit = "exhaustive" }
    local names = {}
    local modules = {}
    for i = 1, 10 do
      names[i] = "p" .. i
      modules[names[i]] = {
        enabled = true,
        cond = true,
        icon = { enabled = true, value = "I" },
        text = { enabled = true, value = "text" .. i .. "abcdef" },
      }
    end
    mosaic = fresh {
      preset = "minimal",
      fit = "exhaustive",
      modules = modules,
      layout = { right = { names } },
    }
    local window, pane = build { cols = 50 }
    local t = os.clock()
    mosaic.refresh(window, pane)
    assert.is_true(os.clock() - t < 0.2)
  end)

  it("hides a module that raises and keeps drawing the rest", function()
    local mosaic = fresh {
      layout = { right = { "boom", "clock" } },
      modules = {
        boom = function()
          error "kaput"
        end,
      },
    }
    local window, pane = build()
    assert.has_no.errors(function()
      mosaic.refresh(window, pane)
    end)
    assert.is_true(#window._right > 0)
  end)

  it("reports alias chains and cycles without recursing", function()
    fresh { modules = { a = "b", b = "a", c = "d", d = "clock" } }
    local doctor = require "mosaic.engine.doctor"
    assert.matches("UNKNOWN", doctor.source "a")
    assert.matches("UNKNOWN", doctor.source "c")
    assert.matches("built%-in", doctor.source "d")
  end)

  it("forgets the spec cache of a closed window", function()
    fresh {}
    local renderer = require "mosaic.engine.renderer"
    assert.has_no.errors(function()
      renderer.forget(12345)
    end)
  end)

  it("skips the frame when the pane is already gone", function()
    local mosaic = fresh { preset = "minimal", layout = { right = { "clock" } } }
    local window, pane = build()
    pane.get_dimensions = function()
      error "pane id 8 not found in mux"
    end
    assert.has_no.errors(function()
      mosaic.refresh(window, pane)
    end)
  end)

  it("defers an update that starts while another is rendering", function()
    local mosaic = fresh { preset = "minimal", layout = { right = { "probe" } } }
    local window, pane = build()
    local other_w, other_p = build()
    local nested
    local config = require "mosaic.engine.config"
    config.live.modules.probe = function()
      -- stands in for an async wait that lets another window's event run
      mosaic.refresh(other_w, other_p)
      nested = true
      return { enabled = false }
    end
    assert.has_no.errors(function()
      mosaic.refresh(window, pane)
    end)
    assert.is_true(nested)
    -- the overlapping update did not run inside the first one
    assert.is_nil(other_w._right)
  end)

  it("hides a module whose update key raises instead of freezing the bar", function()
    local mosaic = fresh { preset = "minimal", layout = { right = { "keyed", "clock" } } }
    local window, pane = build()
    local calls = 0
    require("mosaic.engine.config").live.modules.keyed = function()
      return {
        enabled = true,
        update = function()
          calls = calls + 1
          if calls > 1 then
            error "pane gone"
          end
          return 1
        end,
        text = { enabled = true, value = "x" },
      }
    end
    mosaic.refresh(window, pane)
    assert.has_no.errors(function()
      mosaic.refresh(window, pane)
    end)
  end)

  it("asks the window for its key table and leader once per frame", function()
    local mosaic = fresh {
      preset = "minimal",
      layout = { left = { "mode", "leader", "workspace" }, right = { "clock", "cwd" } },
    }
    local window, pane = build()
    local counts = { active_key_table = 0, leader_is_active = 0 }
    for name in pairs(counts) do
      local orig = window[name]
      window[name] = function(...)
        counts[name] = counts[name] + 1
        return orig(...)
      end
    end
    mosaic.refresh(window, pane)
    assert.equal(1, counts.active_key_table)
    assert.equal(1, counts.leader_is_active)
  end)

  it(
    "sizes the right status from its own window's tabs when another's are drawn mid-render",
    function()
      local mosaic = fresh { preset = "minimal", layout = { right = { "clock" } } }
      local window, pane = build()
      local id = window:window_id()
      mosaic.budget.use(id)
      mosaic.budget.record(0, 30)
      mosaic.budget.set_count(1)
      -- another window's format-tab-title runs while this render waits
      local get_dimensions = window.get_dimensions
      window.get_dimensions = function(...)
        mosaic.budget.use(id + 1000)
        mosaic.budget.record(0, 5)
        mosaic.budget.set_count(1)
        return get_dimensions(...)
      end
      mosaic.refresh(window, pane)
      assert.equal(30, require("mosaic.engine.renderer").tabs_width)
    end
  )
end)
