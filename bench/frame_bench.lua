-- Per-frame cost of the update-status handler, one case per scenario.
-- Usage (from the repo root): chrono
local chrono = require "chrono"

local wezterm = dofile "spec/mocks/wezterm.lua"
package.path = "plugin/?.lua;plugin/?/init.lua;" .. package.path
local scenarios = dofile "spec/support/scenarios.lua"
local config = dofile "spec/support/config.lua"

local mosaic = require "mosaic.api"

-- A 10-module group under `exhaustive`: exercises the combination cap.
local big =
  { "process", "cwd", "hostname", "cpu", "ram", "network", "disk", "clock", "battery", "username" }
for _, cols in ipairs { 100, 240 } do
  scenarios.list[#scenarios.list + 1] = {
    name = "big@" .. cols,
    cols = cols,
    tabs = { 22, 18, 25 },
    opts = { fit = "exhaustive", layout = { right = { big } } },
  }
end

local function find(name)
  for _, s in ipairs(scenarios.list) do
    if s.name == name then
      return s
    end
  end
  error("unknown scenario " .. name)
end

local suite = chrono.suite("mosaic frame", { iterations = 5000, warmup = 200 })

-- mosaic's state is global, so each case sets up on its first (warmup) call.
local current
for _, name in ipairs { "idle@240", "mode@240", "idle@100", "big@100", "big@240" } do
  local s = find(name)
  local window, pane
  suite:add(name, function()
    if current ~= name then
      current = name
      wezterm._handlers = {}
      mosaic.setup(s.opts or config(mosaic, scenarios.hints))
      window, pane = scenarios.build(s)
      for i, w in ipairs(s.tabs) do
        mosaic.budget.record(i - 1, w)
      end
      mosaic.budget.set_count(#s.tabs)
    end
    mosaic.refresh(window, pane)
  end)
end

return suite
