local wezterm = require "wezterm"

local scenarios = dofile "spec/support/scenarios.lua"
local strict = dofile "spec/support/strict.lua"
local tabs = dofile "spec/support/tabs.lua"

-- Handlers refresh the bar, which needs a real window.
local WINDOW

local function fresh(opts)
  WINDOW = nil
  for k in pairs(package.loaded) do
    if k:match "^mosaic" then
      package.loaded[k] = nil
    end
  end
  wezterm._reset()
  local mosaic = require "mosaic.api"
  mosaic.setup(opts)
  mosaic.apply_to_config {}
  WINDOW = scenarios.build(scenarios.list[16])
  return mosaic, wezterm._handlers["format-tab-title"] and wezterm._handlers["format-tab-title"][1]
end

local function has(s, needle)
  return s:find(needle, 1, true) ~= nil
end

---A Pane object (as handlers receive) and its PaneInformation view.
local function pane(id, vars)
  local p = { _vars = vars or {} }
  function p:pane_id()
    return id
  end
  function p:get_user_vars()
    return self._vars
  end
  function p:has_unseen_output()
    return false
  end
  -- What the bar refresh reads from a real pane.
  function p:get_dimensions()
    return { cols = 240, pixel_width = 2400 }
  end
  function p:get_current_working_dir()
    return "file://devbox.local/home/mock"
  end
  function p:get_title()
    return "zsh"
  end
  function p:get_foreground_process_name()
    return "/usr/bin/zsh"
  end
  function p:get_domain_name()
    return "local"
  end
  function p:info(extra)
    local info = { pane_id = id, user_vars = self._vars, title = "zsh" }
    for k, v in pairs(extra or {}) do
      info[k] = v
    end
    return strict.pane(info)
  end
  return p
end

local function tab(p, active, extra)
  local info = p:info(extra)
  return strict.tab { tab_index = 1, is_active = active == true, active_pane = info }
end

local OPTS = {
  preset = "blocks",
  tabs = {
    badges = {
      states = {
        done = { icon = "D", color = "#00ff00" },
        waiting = { icon = "W", color = "#ff0000", sticky = true },
      },
    },
  },
}

local function draw(format, t)
  return format(t, { t }, nil, tabs.config, false, 30)
end

local function set_var(p, value)
  p._vars.badge = value
  for _, fn in ipairs(wezterm._handlers["user-var-changed"] or {}) do
    fn(WINDOW, p, "badge", value)
  end
end

describe("tabs.badges", function()
  it("registers bell and user-var handlers only when configured", function()
    fresh { preset = "blocks" }
    assert.is_nil(wezterm._handlers.bell)
    assert.is_nil(wezterm._handlers["user-var-changed"])
    fresh(OPTS)
    assert.equal(1, #wezterm._handlers.bell)
    assert.equal(1, #wezterm._handlers["user-var-changed"])
  end)

  it("badges an inactive tab with a var state, in its colour", function()
    local _, format = fresh(OPTS)
    local p = pane(7)
    set_var(p, "done")
    local out = draw(format, tab(p))
    assert.is_true(has(out, "#00ff00"), out)
    assert.is_true(has(out:gsub("\27%b{}", ""), "D"), out)
  end)

  it("clears a non-sticky state once the tab is focused, and shows a repeat", function()
    local _, format = fresh(OPTS)
    local p = pane(8)
    set_var(p, "done")
    assert.is_true(has(draw(format, tab(p)), "#00ff00"))
    draw(format, tab(p, true)) -- focus
    assert.is_false(has(draw(format, tab(p)), "#00ff00"))
    set_var(p, "working") -- not a configured state
    set_var(p, "done")
    assert.is_true(has(draw(format, tab(p)), "#00ff00"))
  end)

  it("redraws only for the badge var", function()
    local mosaic = fresh(OPTS)
    local calls = 0
    local status = require "mosaic.engine.status"
    local real = status.update
    status.update = function()
      calls = calls + 1
    end
    local p = pane(30)
    wezterm._handlers["user-var-changed"][1](WINDOW, p, "WEZTERM_PROG", "ls")
    assert.equal(0, calls)
    wezterm._handlers["user-var-changed"][1](WINDOW, p, "badge", "done")
    assert.equal(1, calls)
    status.update = real
    assert.is_table(mosaic)
  end)

  it("keeps a sticky state after focus", function()
    local _, format = fresh(OPTS)
    local p = pane(9)
    set_var(p, "waiting")
    draw(format, tab(p, true))
    assert.is_true(has(draw(format, tab(p)), "#ff0000"))
  end)

  it("marks a bell until the tab is focused", function()
    local _, format = fresh(OPTS)
    local p = pane(10)
    wezterm._handlers.bell[1](WINDOW, p)
    local theme = tabs.config.color_schemes.test
    assert.is_true(has(draw(format, tab(p)), theme.ansi[4]))
    draw(format, tab(p, true))
    assert.is_false(has(draw(format, tab(p)), "Color=" .. theme.ansi[4]))
  end)

  it("prefers a var state over a bell, and a bell over output", function()
    local _, format = fresh {
      preset = "blocks",
      tabs = {
        badges = { output = true, states = { done = { icon = "D", color = "#00ff00" } } },
      },
    }
    local p = pane(11)
    wezterm._handlers.bell[1](WINDOW, p)
    set_var(p, "done")
    assert.is_true(has(draw(format, tab(p, false, { has_unseen_output = true })), "#00ff00"))
    local q = pane(12)
    wezterm._handlers.bell[1](WINDOW, q)
    local theme = tabs.config.color_schemes.test
    assert.is_true(has(draw(format, tab(q, false, { has_unseen_output = true })), theme.ansi[4]))
  end)

  it("takes the defaults with badges = true", function()
    local _, format = fresh { preset = "blocks", tabs = { badges = true } }
    local p = pane(13)
    set_var(p, "waiting")
    local theme = tabs.config.color_schemes.test
    assert.is_true(has(draw(format, tab(p)), theme.ansi[2]))
  end)

  it("counts tabs that need you in the badges module", function()
    local mosaic = fresh {
      preset = "minimal",
      layout = { right = { "badges" } },
      tabs = OPTS.tabs,
    }
    local window, active = scenarios.build(scenarios.list[16])
    local a, b = pane(20, { badge = "waiting" }), pane(21)
    function window:mux_window()
      return {
        tabs = function()
          return { {}, {} }
        end,
        tabs_with_info = function()
          return {
            {
              is_active = false,
              tab = {
                panes = function()
                  return { a }
                end,
              },
            },
            {
              is_active = false,
              tab = {
                panes = function()
                  return { b }
                end,
              },
            },
          }
        end,
      }
    end
    mosaic.refresh(window, active)
    local text = window._right:gsub("\27%b{}", "")
    assert.is_true(has(text, "W 1"), text)
    assert.is_true(has(window._right, "#ff0000"), window._right)
  end)
end)
