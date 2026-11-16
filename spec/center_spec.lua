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

local function scenario(name)
  for _, s in ipairs(scenarios.list) do
    if s.name == name then
      return s
    end
  end
  error(name)
end

local function plain(s)
  return (s or ""):gsub("\27%b{}", "")
end

local function m(text)
  return { enabled = true, cond = true, text = { enabled = true, value = text } }
end

---Render and return the right status, the bar width and the free span.
local function draw(opts, name)
  local mosaic = fresh(opts)
  local window, pane = scenarios.build(scenario(name or "idle@240"))
  mosaic.refresh(window, pane)
  local budget = require "mosaic.engine.budget"
  local screen = budget.screen_width()
  return window._right or "", screen, screen - budget.right_available()
end

describe("center.place", function()
  local place = require("mosaic.engine.center").place

  it("centres on the window by default", function()
    assert.equal(45, place(100, 10, 90, 10))
  end)

  it("centres in the free space with anchor = free", function()
    -- free 40..90, margins 41..89: (48 - 10) / 2 = 19
    assert.equal(60, place(100, 40, 90, 10, { anchor = "free" }))
  end)

  it("shifts clear of the tabs, or hides with overflow = hide", function()
    assert.equal(61, place(100, 60, 95, 10))
    assert.is_nil(place(100, 60, 95, 10, { overflow = "hide" }))
    assert.equal(39, place(100, 10, 50, 10)) -- clear of the right modules
  end)

  it("hides what does not fit, keeping the margins", function()
    assert.is_nil(place(100, 40, 52, 11))
    assert.equal(41, place(100, 40, 52, 10))
    assert.is_nil(place(100, 40, 52, 0))
  end)
end)

describe("layout.center", function()
  it("draws the centre modules at the middle of the bar", function()
    local right, screen = draw {
      preset = "minimal",
      layout = { right = { "r" }, center = { "c" } },
      modules = { r = m "RIGHT", c = m "MIDDLE" },
    }
    local text = plain(right)
    assert.equal(screen, wezterm.column_width(text) + (screen - wezterm.column_width(text)))
    local start = screen - wezterm.column_width(text) -- right status start column
    local at = text:find("MIDDLE", 1, true) - 1
    local block = (" MIDDLE "):len()
    -- the block (with its padding) starts where a centred block would
    assert.equal(math.floor((screen - block) / 2), start + at - 1)
    assert.is_true(text:sub(-#" RIGHT "):find("RIGHT", 1, true) ~= nil)
  end)

  it("paints the gap on the bar colour", function()
    local right = draw {
      preset = "minimal",
      layout = { right = { "r" }, center = { "c" } },
      modules = { r = m "R", c = m "C" },
    }
    assert.is_false(right:find("Background={Color=none}", 1, true) ~= nil, right)
    assert.is_true(
      right:find("Background={Color=" .. scenarios.theme.tab_bar.background .. "}", 1, true) ~= nil
    )
  end)

  it("leaves the right status alone without centre modules", function()
    local opts =
      { preset = "minimal", layout = { right = { "r" } }, modules = { r = m "R", c = m "C" } }
    local plain_right = draw(opts)
    opts.layout.center = { "off" }
    opts.modules.off = { enabled = false }
    assert.equal(plain_right, (draw(opts)))
  end)

  it("gives the right modules priority and fits the centre into what is left", function()
    local right = draw({
      preset = "minimal",
      layout = { right = { "r" }, center = { { "c", "d" } } },
      modules = {
        r = m(("R"):rep(30)),
        c = {
          enabled = true,
          cond = true,
          can_hide = true,
          text = { enabled = true, value = ("C"):rep(40) },
        },
        d = m "D",
      },
    }, "idle@160")
    local text = plain(right)
    assert.is_true(text:find(("R"):rep(30), 1, true) ~= nil, text)
    assert.is_true(text:find("D", 1, true) ~= nil, text)
    assert.is_nil(text:find(("C"):rep(40), 1, true), text) -- hidden: no room left
    assert.is_true(wezterm.column_width(text) <= 160, text)
  end)

  it("shifts the centre clear of wide right modules, or hides it with overflow = hide", function()
    -- At 240 columns the centred spot (116) overlaps 120 columns of right
    -- modules, but the free space still has room further left.
    local function show(overflow)
      local right = draw {
        preset = "minimal",
        center = { overflow = overflow },
        layout = { right = { "r" }, center = { "c" } },
        modules = { r = m(("R"):rep(120)), c = m "MIDDLE" },
      }
      return plain(right):find("MIDDLE", 1, true) ~= nil
    end
    assert.is_true(show "shift")
    assert.is_false(show "hide")
  end)

  it("styles centre modules with the preset", function()
    local right = draw {
      preset = "bubbles",
      layout = { center = { "c" } },
      modules = {
        c = {
          enabled = true,
          cond = true,
          accent = "#123456",
          text = { enabled = true, value = "C" },
        },
      },
    }
    assert.is_true(right:find("#123456", 1, true) ~= nil, right)
  end)
end)
