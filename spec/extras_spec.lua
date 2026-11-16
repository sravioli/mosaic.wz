local wezterm = require "wezterm"

local scenarios = dofile "spec/support/scenarios.lua"
local strict = dofile "spec/support/strict.lua"
local tabs = dofile "spec/support/tabs.lua"

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
  return mosaic, wezterm._handlers["format-tab-title"] and wezterm._handlers["format-tab-title"][1]
end

local function build(patch)
  local s = {}
  for k, v in pairs(scenarios.list[16]) do -- idle@240
    s[k] = v
  end
  for k, v in pairs(patch or {}) do
    s[k] = v
  end
  return scenarios.build(s)
end

local function plain(s)
  return (s or ""):gsub("\27%b{}", "")
end

local function has(s, needle)
  return s:find(needle, 1, true) ~= nil
end

local function m(text)
  return { enabled = true, cond = true, text = { enabled = true, value = text } }
end

describe("layout function", function()
  it("chooses the layout per window on every frame", function()
    local mosaic = fresh {
      preset = "minimal",
      modules = { a = m "WORK", b = m "HOME" },
      layout = function(window)
        return { right = { window:active_workspace() == "work" and "a" or "b" } }
      end,
    }
    local work, wp = build { workspace = "work" }
    local home, hp = build { workspace = "default" }
    mosaic.refresh(work, wp)
    mosaic.refresh(home, hp)
    assert.is_true(has(plain(work._right), "WORK"), plain(work._right))
    assert.is_true(has(plain(home._right), "HOME"), plain(home._right))
  end)

  it("falls back to the preset's layout when it fails, logging once", function()
    local errors = 0
    local real = wezterm.log_error
    wezterm.log_error = function()
      errors = errors + 1
    end
    local mosaic = fresh {
      preset = "minimal",
      layout = function()
        error "boom"
      end,
    }
    local window, pane = build()
    mosaic.refresh(window, pane)
    mosaic.refresh(window, pane)
    wezterm.log_error = real
    assert.is_true(#plain(window._right) > 0) -- the preset's modules
    assert.is_true(errors <= 1)
  end)
end)

describe("progress", function()
  it("shows the active pane's percentage and hides without progress", function()
    local mosaic = fresh { preset = "minimal", layout = { right = { "progress" } } }
    local window, pane = build { progress = { Percentage = 42 } }
    mosaic.refresh(window, pane)
    assert.is_true(has(plain(window._right), "42%"), plain(window._right))
    window, pane = build { progress = "None" }
    mosaic.refresh(window, pane)
    assert.equal("", plain(window._right))
  end)

  it("tints errors, even inside a powerline gradient", function()
    local mosaic = fresh {
      preset = "powerline",
      layout = { right = { { "cwd", "progress" } } },
      options = { progress = { error_color = "#ee0000" } },
    }
    local window, pane = build { progress = { Error = 70 } }
    mosaic.refresh(window, pane)
    assert.is_true(has(window._right, "#ee0000"), window._right)
  end)

  it("hides on WezTerm builds without get_progress", function()
    local mosaic = fresh { preset = "minimal", layout = { right = { "progress" } } }
    local window, pane = build()
    local mt = getmetatable(pane)
    rawset(pane, "get_progress", nil)
    setmetatable(pane, {
      __index = function(_, k)
        if k == "get_progress" then
          error "attempt to get an unknown field 'get_progress'"
        end
        return mt.__index(pane, k)
      end,
    })
    mosaic.refresh(window, pane)
    assert.equal("", plain(window._right))
  end)

  it("is a tab component", function()
    local _, format = fresh { preset = "minimal", tabs = { content = { "title", "progress" } } }
    local info = strict.pane { pane_id = 1, title = "make", progress = { Percentage = 75 } }
    local t = strict.tab { active_pane = info }
    local out = plain(format(t, { t }, nil, tabs.config, false, 30))
    assert.is_true(has(out, "make") and has(out, "75%"), out)
    info = strict.pane { pane_id = 1, title = "make", progress = "Indeterminate" }
    t = strict.tab { active_pane = info }
    out = plain(format(t, { t }, nil, tabs.config, false, 30))
    assert.is_false(has(out, "%"), out)
  end)
end)

describe("doctor", function()
  it("reports dependencies, programs, issues, resolution and frame cost", function()
    local mosaic = fresh {
      preset = "minimal",
      layout = {
        left = { "workspace" },
        center = { "notice" },
        right = { "slot", "nope", "demo.missing" },
      },
      modules = { slot = "clock" },
      options = { clok = { format = "%H" } },
      fit = "sideways",
    }
    local window = build()
    local report = require("mosaic.engine.doctor").report(window)
    for _, needle in ipairs {
      "mosaic ",
      "dependencies: warp ok, log ok, warden ok, ribbon ok",
      "programs:",
      "options: ",
      "[fit]",
      "workspace",
      "built-in",
      "slot",
      "-> clock (built-in)",
      "nope",
      "UNKNOWN",
      "demo.missing",
      "integration FAILED",
      "typo?): clok",
      "frame: ",
    } do
      assert.is_true(has(report, needle), needle .. " in:\n" .. report)
    end
  end)

  it("works without a window", function()
    local mosaic = fresh { preset = "minimal" }
    local logged = {}
    local real = wezterm.log_info
    wezterm.log_info = function(line)
      logged[#logged + 1] = line
    end
    assert.is_nil(mosaic.doctor())
    wezterm.log_info = real
    assert.is_true(#logged > 3)
    for _, line in ipairs(logged) do
      assert.is_nil(line:find("\n", 1, true), line)
    end
    assert.is_true(has(table.concat(logged, "\n"), "no window to measure"))
  end)
end)

describe("colour schemes", function()
  local function with_scheme(name, schemes)
    local window, pane = build()
    local real = window.effective_config
    function window:effective_config()
      local c = real(self)
      c.color_scheme, c.color_schemes = name, schemes
      return c
    end
    return window, pane
  end

  it("draws with WezTerm's built-in scheme of that name", function()
    local mosaic = fresh { preset = "powerline" }
    local color = wezterm.color
    color.get_builtin_schemes = function()
      return { ["Builtin Dark"] = scenarios.theme }
    end
    local window, pane = with_scheme("Builtin Dark", {})
    mosaic.refresh(window, pane)
    color.get_builtin_schemes = nil
    assert.is_true(#plain(window._right) > 0)
  end)

  it("falls back to WezTerm's default colours without a scheme", function()
    local mosaic = fresh { preset = "powerline" }
    local color = wezterm.color
    color.get_builtin_schemes = function()
      return {}
    end
    color.get_default_colors = function()
      return scenarios.theme
    end
    local window, pane = with_scheme(nil, nil)
    mosaic.refresh(window, pane)
    color.get_builtin_schemes, color.get_default_colors = nil, nil
    assert.is_true(#plain(window._right) > 0)
  end)
end)

describe("several windows", function()
  it("keep their own tab widths", function()
    local mosaic, format = fresh { preset = "minimal", layout = { right = { "clock" } } }
    local budget = mosaic.budget
    local function tabs_of(window_id, n)
      local list = {}
      for i = 1, n do
        list[i] = strict.tab {
          tab_index = i - 1,
          window_id = window_id,
          active_pane = strict.pane { pane_id = window_id * 10 + i, title = "shell" },
        }
      end
      for _, t in ipairs(list) do
        format(t, list, nil, tabs.config, false, 30)
      end
    end
    tabs_of(1, 5)
    budget.use(1)
    local five = budget.total_width()
    tabs_of(2, 1)
    budget.use(2)
    local one = budget.total_width()
    budget.use(1)
    assert.equal(five, budget.total_width())
    assert.is_true(five > one)
  end)

  it("push a status only when it changed, per window", function()
    local mosaic = fresh { preset = "minimal", layout = { right = { "clock" } } }
    local window, pane = build()
    mosaic.refresh(window, pane)
    local pushes = 0
    function window:set_right_status(s)
      pushes = pushes + 1
      self._right = s
    end
    mosaic.refresh(window, pane)
    assert.equal(0, pushes)
  end)
end)
