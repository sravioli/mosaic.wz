---Byte-for-byte regression check: renders every scenario with the example
---config and compares against spec/fixtures/snapshots.lua (styles included).

local wezterm = require "wezterm"

local expected = dofile "spec/fixtures/snapshots.lua"
local scenarios = dofile "spec/support/scenarios.lua"
local config = dofile "spec/support/config.lua"

local function fresh()
  for k in pairs(package.loaded) do
    if k:match "^mosaic" then
      package.loaded[k] = nil
    end
  end
  wezterm._handlers = {}
  local mosaic = require "mosaic.api"
  mosaic.setup(config(mosaic, scenarios.hints))
  mosaic.apply_to_config {}
  return mosaic, wezterm._handlers["update-status"][1]
end

describe("snapshot", function()
  for _, s in ipairs(scenarios.list) do
    it(s.name .. " matches the recorded snapshot", function()
      local mosaic, handler = fresh()
      local window, pane = scenarios.build(s)
      for i, w in ipairs(s.tabs) do
        mosaic.budget.record(i - 1, w)
      end
      mosaic.budget.set_count(#s.tabs)
      handler(window, pane)
      assert.are.equal(expected[s.name].left, window._left)
      assert.are.equal(expected[s.name].right, window._right)
    end)
  end
end)
