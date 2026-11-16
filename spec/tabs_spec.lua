local wezterm = require "wezterm"

local expected = dofile "spec/fixtures/tabs.lua"
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

local function plain(s)
  return (s or ""):gsub("\27%b{}", "")
end

local function scenario(name)
  for _, s in ipairs(tabs.list) do
    if s.name == name then
      return s
    end
  end
  error("no tab scenario " .. name)
end

local function render(format, s, config)
  return format(s.tab, { s.tab, {}, {} }, nil, config or tabs.config, s.hover, s.width)
end

describe("tabs", function()
  it("powerline matches the recorded snapshot", function()
    local _, format = fresh { preset = "powerline" }
    for _, s in ipairs(tabs.list) do
      assert.are.equal(expected[s.name], render(format, s), s.name)
    end
  end)

  for _, preset in ipairs {
    "powerline",
    "minimal",
    "bubbles",
    "slanted",
    "blocks",
    "brackets",
    "pure",
  } do
    it(preset .. " fits max_width and reports the rendered width", function()
      local mosaic, format = fresh { preset = preset }
      for _, s in ipairs(tabs.list) do
        local out = render(format, s)
        local width = wezterm.column_width(plain(out))
        assert.is_true(width <= s.width, ("%s %s: %d > %d"):format(preset, s.name, width, s.width))
        assert.equal(width, mosaic.budget._widths[s.tab.tab_index], s.name)
      end
      assert.equal(3, mosaic.budget._count)
    end)
  end

  for _, preset in ipairs { "slanted", "slanted-inverted", "blocks", "brackets", "pure" } do
    it(preset .. " draws tabs on the bar colour, never transparent", function()
      local _, format = fresh { preset = preset }
      for _, s in ipairs(tabs.list) do
        local out = render(format, s)
        assert.is_falsy(out:find("Background={Color=none}", 1, true), preset .. " " .. s.name)
      end
    end)
  end

  for _, preset in ipairs {
    "powerline",
    "minimal",
    "bubbles",
    "slanted",
    "blocks",
    "brackets",
    "pure",
  } do
    it(preset .. " draws the new-tab button and its hover state", function()
      local mosaic = fresh { preset = preset }
      local cfg = { color_scheme = "test", color_schemes = tabs.config.color_schemes }
      mosaic.apply_to_config(cfg)
      local style = cfg.tab_bar_style
      assert.is_truthy(plain(style.new_tab):find("+", 1, true), preset)
      assert.is_truthy(plain(style.new_tab_hover):find("+", 1, true), preset)
      assert.are_not.equal(style.new_tab, style.new_tab_hover, preset)
    end)
  end

  it("leaves the new-tab button alone with tabs = false", function()
    local mosaic = fresh { preset = "powerline", tabs = false }
    local cfg = {
      color_scheme = "test",
      color_schemes = tabs.config.color_schemes,
      tab_bar_style = { new_tab = "X" },
    }
    mosaic.apply_to_config(cfg)
    assert.equal("X", cfg.tab_bar_style.new_tab)
  end)

  it("passes the remaining columns to the title hook", function()
    local seen = {}
    local _, format = fresh {
      preset = "minimal",
      tabs = {
        title = function(tab, max_cells)
          seen[#seen + 1] = { tab = tab, max = max_cells }
          return "T"
        end,
      },
    }
    local s = tabs.list[1]
    local out = plain(render(format, s))
    assert.equal(s.tab, seen[1].tab)
    -- minimal: " <index> " + title + " "
    assert.equal(s.width - 4, seen[1].max)
    assert.equal(" 1 T ", out)
  end)

  it("never passes a negative budget", function()
    local seen
    local _, format = fresh {
      preset = "powerline",
      tabs = {
        title = function(_, max_cells)
          seen = max_cells
          return ""
        end,
      },
    }
    render(format, { tab = tabs.list[1].tab, width = 1 })
    assert.equal(0, seen)
  end)

  it("lets a user format replace the preset's", function()
    local _, format = fresh {
      preset = "powerline",
      tabs = {
        format = function(ctx)
          return { { nil, nil, "[" .. ctx.title(ctx.max_width - 2) .. "]" } }
        end,
      },
    }
    assert.equal("[htop]", plain(render(format, scenario "short/inactive/0@34")))
  end)

  it("reports state and unseen output", function()
    local states = {}
    local _, format = fresh {
      tabs = {
        format = function(ctx)
          states[#states + 1] = ctx.state .. (ctx.unseen and "+" or "")
          return {}
        end,
      },
    }
    for _, name in ipairs {
      "shell/active/0@34",
      "shell/hover/0@34",
      "shell/inactive/0@34",
      "shell/unseen/0@34",
    } do
      local s = scenario(name)
      render(format, s)
    end
    assert.same({ "active", "hover", "inactive", "inactive+" }, states)
  end)

  it("tints fancy tabs in the preset's colours and reports their width", function()
    local mosaic, format = fresh { preset = "powerline" }
    local fancy =
      { use_fancy_tab_bar = true, color_scheme = "test", color_schemes = tabs.config.color_schemes }
    local theme = tabs.config.color_schemes.test
    for _, s in ipairs(tabs.list) do
      local out = render(format, s, fancy)
      -- One run: WezTerm tints the whole fancy tab from the first cell.
      assert.equal(1, select(2, out:gsub("Background=", "")), s.name)
      if s.tab.is_active then
        assert.truthy(out:find("Background={Color=" .. theme.ansi[5] .. "}", 1, true), s.name)
      end
      local text = plain(out)
      assert.is_true(wezterm.column_width(text) <= s.width, s.name)
      assert.equal(wezterm.column_width(text) + 4, mosaic.budget._widths[s.tab.tab_index], s.name)
    end
  end)

  it("defers to wezterm without a format", function()
    local _, bare = fresh {}
    assert.is_nil(render(bare, tabs.list[1]))
  end)

  it("does not register format-tab-title with tabs = false", function()
    local mosaic, format = fresh { preset = "powerline", tabs = false }
    assert.is_nil(format)
    assert.is_false(mosaic.setup({ tabs = false }).tabs)
  end)

  it("truncates the default title to the budget", function()
    local title = require("mosaic.tabs").default_title
    local tab = { tab_title = "", active_pane = { title = "abcdefghij" } }
    assert.equal("abcdefghij", title(tab, 10))
    assert.is_true(wezterm.column_width(title(tab, 5)) <= 5)
    assert.equal("", title(tab, 1))
    assert.equal("renamed", title({ tab_title = "renamed", active_pane = { title = "x" } }, 10))
  end)
end)
