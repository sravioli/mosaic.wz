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

local function right(window)
  return (window._right or ""):gsub("\27%b{}", "")
end

describe("notice", function()
  local now = os.time()
  local real_time = os.time

  before_each(function()
    os.time = function()
      return now
    end
  end)

  after_each(function()
    os.time = real_time
  end)

  it("shows a message while it lasts, then hides", function()
    local mosaic = fresh { preset = "minimal", layout = { right = { "notice" } } }
    local window, pane = scenarios.build(scenarios.list[16])
    function window:active_pane()
      return pane
    end
    mosaic.notify(window, "session saved", { seconds = 2 })
    assert.is_truthy(right(window):find("session saved", 1, true), right(window))
    assert.equal(1, #wezterm._timers)
    now = now + 3
    wezterm._run_timers()
    assert.is_falsy(right(window):find("session saved", 1, true), right(window))
  end)

  it("is in every preset's layout and hidden without a message", function()
    for _, preset in ipairs {
      "powerline",
      "minimal",
      "bubbles",
      "slanted",
      "blocks",
      "brackets",
      "pure",
    } do
      local live = fresh { preset = preset }
      assert.equal("notice", live.setup({ preset = preset }).layout.right[1], preset)
    end
  end)

  it("listens to mosaic-notify, for plugins that do not depend on mosaic", function()
    fresh { preset = "minimal", layout = { right = { "notice" } } }
    local window, pane = scenarios.build(scenarios.list[16])
    function window:active_pane()
      return pane
    end
    wezterm.emit("mosaic-notify", window, pane, "from a plugin", { icon = false })
    assert.is_truthy(right(window):find("from a plugin", 1, true), right(window))
  end)

  it("wires an integration's notices", function()
    package.preload["demo.mosaic.saver"] = function()
      return {
        api = 1,
        notices = {
          ["demo-saved"] = function(_, name)
            return "saved " .. name
          end,
        },
        new = function()
          return { enabled = false }
        end,
      }
    end
    fresh { preset = "minimal", layout = { right = { "notice", "demo.saver" } } }
    local window, pane = scenarios.build(scenarios.list[16])
    function window:active_pane()
      return pane
    end
    wezterm.emit("demo-saved", window, "work")
    assert.is_truthy(right(window):find("saved work", 1, true), right(window))
    package.preload["demo.mosaic.saver"] = nil
    package.loaded["demo.mosaic.saver"] = nil
  end)
end)
