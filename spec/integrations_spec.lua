local wezterm = require "wezterm"

local scenarios = dofile "spec/support/scenarios.lua"

package.path = "spec/fixtures/plugins/?.lua;" .. package.path

local function fresh()
  for k in pairs(package.loaded) do
    if k:match "^mosaic" or k:match "^demo%." then
      package.loaded[k] = nil
    end
  end
  wezterm._reset()
  _G.DEMO_CALLS = {}
  _G.DEMO_READ = {}
  return require "mosaic.api"
end

-- Text only, trimmed: without a preset the default (minimal) decoration
-- pads every module with a space on each side.
local function plain(s)
  return ((s or ""):gsub("\27%b{}", ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function errors()
  local out = {}
  for _, c in ipairs(wezterm._calls) do
    if c.fn == "log_error" then
      out[#out + 1] = table.concat(
        (function()
          local t = {}
          for i, v in ipairs(c.args) do
            t[i] = tostring(v)
          end
          return t
        end)(),
        " "
      )
    end
  end
  return table.concat(out, "\n")
end

local function render(mosaic, opts)
  mosaic.setup(opts)
  mosaic.apply_to_config {}
  local window, pane = scenarios.build(scenarios.list[16]) -- idle@240
  mosaic.refresh(window, pane)
  return window
end

describe("integrations", function()
  local mosaic

  before_each(function()
    mosaic = fresh()
  end)

  it("renders a module named <plugin>.<module> in the layout", function()
    local window = render(mosaic, { layout = { right = { "demo.status" } } })
    assert.equal("DEMO", plain(window._right))
  end)

  it("passes per-integration options and the public API to new()", function()
    local window = render(mosaic, {
      layout = { right = { "demo.status" } },
      options = { ["demo.status"] = { label = "HI" } },
    })
    assert.equal("HI", plain(window._right))
    assert.equal(1, #_G.DEMO_CALLS)
    assert.equal(mosaic, _G.DEMO_CALLS[1].mosaic)
    assert.equal(1, mosaic.INTEGRATION_API)
  end)

  it("calls new() once across frames", function()
    render(mosaic, { layout = { right = { "demo.status" } } })
    local window, pane = scenarios.build(scenarios.list[16])
    mosaic.refresh(window, pane)
    mosaic.refresh(window, pane)
    assert.equal(1, #_G.DEMO_CALLS)
  end)

  it("never reads integrations the layout does not name", function()
    -- demo.mosaic.boom raises when required.
    render(mosaic, { layout = { right = { "clock" } } })
    mosaic.discover()
    assert.same({}, _G.DEMO_READ)
    assert.equal(0, #_G.DEMO_CALLS)
  end)

  it("loads named integrations while the config is evaluated", function()
    mosaic.setup { layout = { left = { { "demo.status" } } } }
    mosaic.apply_to_config {}
    assert.same({ status = true }, _G.DEMO_READ)
    assert.equal(1, #_G.DEMO_CALLS)
  end)

  it("wires declared events to a refresh, once", function()
    render(mosaic, { layout = { right = { "demo.status" } } })
    assert.equal(1, #wezterm._handlers["demo-changed"])
    -- Another window (a new id): the first one's status is already drawn.
    local s = setmetatable({ id = 2 }, { __index = scenarios.list[16] })
    local window, pane = scenarios.build(s)
    wezterm.emit("demo-changed", window, pane)
    assert.equal("DEMO", plain(window._right))
  end)

  it("fills a preset slot through a string alias", function()
    local window = render(mosaic, { preset = "powerline", modules = { hints = "demo.status" } })
    assert.is_truthy(plain(window._right):find("DEMO", 1, true))
    assert.equal(1, #_G.DEMO_CALLS)
  end)

  it("lets a user module shadow an integration name without reading it", function()
    local window = render(mosaic, {
      layout = { right = { "demo.boom" } },
      modules = {
        ["demo.boom"] = { enabled = true, cond = true, text = { enabled = true, value = "MINE" } },
      },
    })
    assert.equal("MINE", plain(window._right))
    assert.same({}, _G.DEMO_READ)
  end)

  it("does not follow alias chains", function()
    local window = render(mosaic, {
      layout = { right = { "a" } },
      modules = { a = "b", b = "a" },
    })
    assert.equal("", plain(window._right))
  end)

  for _, case in ipairs {
    { "demo.badapi", "api" },
    { "demo.nonew", "invalid descriptor" },
    { "demo.badevents", "invalid descriptor" },
    { "demo.badreturn", "must return a module" },
    { "demo.raises", "new() failed" },
    { "nothere.status", "is nothere loaded" },
  } do
    it("rejects " .. case[1] .. " and keeps the rest of the bar", function()
      local window = render(mosaic, {
        layout = { right = { case[1], "demo.status" } },
      })
      assert.equal("DEMO", plain(window._right))
      assert.is_truthy(errors():find(case[2], 1, true), errors())
    end)
  end

  it("treats path-like names as plain module names", function()
    local window = render(mosaic, { layout = { right = { "../demo.status", "demo/x.y" } } })
    assert.equal("", plain(window._right))
    assert.same({}, _G.DEMO_READ)
  end)

  it("logs a failing integration once", function()
    render(mosaic, { layout = { right = { "demo.badapi" } } })
    local window, pane = scenarios.build(scenarios.list[16])
    mosaic.refresh(window, pane)
    local _, count = errors():gsub("demo.badapi: invalid descriptor", "")
    assert.equal(1, count)
  end)

  it("discovers integration files without reading them", function()
    local saved = package.path
    package.path = "/p/chord/plugin/?.lua;/p/chord/plugin/?/init.lua;/p/demo/?.lua;./?.lua"
    wezterm._globs["/p/chord/plugin/*/mosaic/*.lua"] =
      { "/p/chord/plugin/chord/mosaic/hints.lua", "/p/chord/plugin/chord/mosaic/mode.lua" }
    wezterm._globs["/p/demo/*/mosaic/*.lua"] =
      { "/p/demo/demo/mosaic/boom.lua", "/p/demo/demo/mosaic/hints.lua" }
    local names = mosaic.discover()
    package.path = saved
    assert.same({ "chord.hints", "chord.mode", "demo.boom", "demo.hints" }, names)
    assert.same({}, _G.DEMO_READ)
  end)
end)
