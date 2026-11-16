local wezterm = require "wezterm"

local scenarios = dofile "spec/support/scenarios.lua"
local tabs = dofile "spec/support/tabs.lua"

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
  return mosaic, wezterm._handlers["format-tab-title"] and wezterm._handlers["format-tab-title"][1]
end

local function bar(opts)
  local mosaic = fresh(opts)
  local window, pane = scenarios.build(scenarios.list[16]) -- idle@240
  mosaic.refresh(window, pane)
  return window._left, window._right
end

local function plain(s)
  return (s or ""):gsub("\27%b{}", "")
end

local function has(s, needle)
  return s:find(needle, 1, true) ~= nil
end

local function scenario(name)
  for _, s in ipairs(tabs.list) do
    if s.name == name then
      return s
    end
  end
  error("no tab scenario " .. name)
end

local function render(format, s)
  return format(s.tab, { s.tab, {}, {} }, nil, tabs.config, s.hover, s.width)
end

local function content(text)
  return { enabled = true, cond = true, text = { enabled = true, value = text } }
end

describe("module options", function()
  it("patch any module's spec by name, without touching the module", function()
    local module = {
      enabled = true,
      cond = true,
      icon = { enabled = true, value = "I" },
      text = { enabled = true, value = "T" },
    }
    local _, right = bar {
      preset = "minimal",
      layout = { right = { "m" } },
      modules = { m = module },
      options = { m = { icon = false, text = "NEW" } },
    }
    local text = plain(right)
    assert.is_true(has(text, "NEW"), text)
    assert.is_false(has(text, "I"), text)
    assert.equal("T", module.text.value)
    assert.is_true(module.icon.enabled)
  end)

  it("apply through an alias, target first then the layout name", function()
    local _, right = bar {
      preset = "minimal",
      layout = { right = { "slot" } },
      modules = { slot = "m", m = content "T" },
      options = { m = { text = "A" }, slot = { text = { value = "B" } } },
    }
    assert.is_true(has(plain(right), "B"))
  end)

  it("can hide a preset module and override its condition", function()
    local _, right = bar {
      preset = "minimal",
      layout = { right = { "a", "b" } },
      modules = {
        a = content "AAA",
        b = { enabled = true, cond = false, text = { enabled = true, value = "BBB" } },
      },
      options = { a = { enabled = false }, b = { cond = true } },
    }
    local text = plain(right)
    assert.is_false(has(text, "AAA"), text)
    assert.is_true(has(text, "BBB"), text)
  end)

  it("read built-in keys: clock format and variants", function()
    local _, right = bar {
      preset = "minimal",
      layout = { right = { "clock" } },
      options = { clock = { format = "<%H>", variants = {}, cond = true } },
    }
    assert.is_true(has(plain(right), "<"), plain(right))
  end)

  it("override a function module's update interval", function()
    local calls = 0
    local opts = {
      preset = "minimal",
      layout = { right = { "n" } },
      modules = {
        n = function()
          calls = calls + 1
          return content "N"
        end,
      },
      options = { n = { update = 60 } },
    }
    local mosaic = fresh(opts)
    local window, pane = scenarios.build(scenarios.list[16])
    mosaic.refresh(window, pane)
    mosaic.refresh(window, pane)
    assert.equal(1, calls)
  end)
end)

describe("module options over the preset", function()
  for _, preset in ipairs(PRESETS) do
    it(preset .. " keeps options padding", function()
      local function width(opts)
        local _, right = bar {
          preset = preset,
          layout = { right = { "a" } },
          modules = { a = content "A" },
          options = opts,
        }
        return wezterm.column_width(plain(right))
      end
      local wide = width { a = { padding = { left = 3, right = 0 } } }
      assert.equal(3, wide - width { a = { padding = { left = 0, right = 0 } } })
    end)

    it(preset .. " keeps options separators", function()
      local _, right = bar {
        preset = preset,
        layout = { right = { "z", "a" } },
        modules = { z = content "Z", a = content "A" },
        options = { a = { sep = { enabled = true, value = { right = "<<", left = ">>" } } } },
      }
      local text = plain(right)
      assert.is_true(has(text, "<<") and has(text, ">>"), text)
    end)
  end

  it("clears the workspace italic with an empty attributes string", function()
    local window, pane = scenarios.build(scenarios.list[16])
    local function left(opts)
      local mosaic = fresh(opts)
      mosaic.refresh(window, pane)
      return window._left
    end
    local base = { preset = "minimal", layout = { left = { "workspace" } } }
    assert.is_true(has(left(base), "Italic"), left(base))
    base.options = { workspace = { text = { style = { attributes = "" } } } }
    assert.is_false(has(left(base), "Italic"), left(base))
  end)

  it("reads update through an alias's target", function()
    local calls = 0
    local mosaic = fresh {
      preset = "minimal",
      layout = { right = { "slot" } },
      modules = {
        slot = "n",
        n = function()
          calls = calls + 1
          return content "N"
        end,
      },
      options = { n = { update = 60 } },
    }
    local window, pane = scenarios.build(scenarios.list[16])
    mosaic.refresh(window, pane)
    mosaic.refresh(window, pane)
    assert.equal(1, calls)
  end)
end)

describe("decorator style", function()
  local theme = scenarios.theme

  it("reads 1-8 as ansi and 9-16 as brights", function()
    local mosaic = fresh {}
    assert.equal(theme.ansi[3], mosaic.palette.resolve(theme, 3))
    assert.equal(theme.brights[1], mosaic.palette.resolve(theme, 9))
    assert.equal(theme.foreground, mosaic.palette.resolve(theme, "foreground"))
    assert.equal("#123456", mosaic.palette.resolve(theme, "#123456"))
  end)

  for _, preset in ipairs { "powerline", "bubbles", "slanted", "blocks" } do
    it(preset .. " takes style.text for text on filled modules", function()
      local left = bar {
        preset = preset,
        layout = { left = { "a" } },
        modules = { a = content "A" },
        style = { text = "#010203" },
      }
      assert.is_true(has(left, "Foreground={Color=#010203}"), left)
    end)
  end

  for _, preset in ipairs { "brackets", "pure" } do
    it(preset .. " takes style.dim for muted parts", function()
      local module = content "A"
      module.icon = { enabled = true, value = "I" }
      local _, right = bar {
        preset = preset,
        layout = { right = { "a" } },
        modules = { a = module },
        style = { dim = "#0a0b0c" },
      }
      assert.is_true(has(right, "Foreground={Color=#0a0b0c}"), right)
    end)
  end

  it("powerline takes the gradient base and stops", function()
    local _, right = bar {
      preset = "powerline",
      layout = { right = { { "a", "b" } } },
      modules = { a = content "A", b = content "B" },
      style = { gradient = { base = "#808080", stops = { 0, 0 } } },
    }
    assert.is_true(has(right, "Background={Color=#808080}"), right)
  end)
end)

describe("tabs.style", function()
  for _, preset in ipairs(PRESETS) do
    it(preset .. " colours the active tab from colors.active", function()
      local _, format =
        fresh { preset = preset, tabs = { style = { colors = { active = "#abcdef" } } } }
      local out = render(format, scenario "shell/active/0@34")
      assert.is_true(has(out, "Color=#abcdef"), out)
    end)

    it(preset .. " draws the index with tabs.style.index", function()
      local _, format = fresh {
        preset = preset,
        tabs = {
          style = {
            index = function(tab)
              return "#" .. tab.tab_index
            end,
          },
        },
      }
      assert.is_true(has(plain(render(format, scenario "shell/active/0@34")), "#0"))
    end)

    it(preset .. " drops the index with index = false", function()
      local _, format =
        fresh { preset = preset, tabs = { style = { index = false, unseen = false } } }
      local text = plain(render(format, scenario "shell/unseen/0@34"))
      assert.is_false(has(text, "1"), text)
      assert.is_false(has(text, "*"), text)
    end)

    it(preset .. " labels the new-tab button with tabs.style.new_tab", function()
      local mosaic = fresh { preset = preset, tabs = { style = { new_tab = "NEW" } } }
      local cfg = { color_scheme = "test", color_schemes = tabs.config.color_schemes }
      mosaic.apply_to_config(cfg)
      assert.is_true(has(plain(cfg.tab_bar_style.new_tab), "NEW"), preset)
      assert.is_true(has(plain(cfg.tab_bar_style.new_tab_hover), "NEW"), preset)
    end)

    it(preset .. " replaces tab edges with tabs.style.separators", function()
      local _, format =
        fresh { preset = preset, tabs = { style = { separators = { left = "<", right = ">" } } } }
      local text = plain(render(format, scenario "shell/active/0@34"))
      assert.is_true(has(text, "<") and has(text, ">"), text)
    end)

    it(preset .. " draws tabs for a scheme without tab_bar", function()
      local _, format = fresh { preset = preset }
      local scheme = {}
      for k, v in pairs(tabs.config.color_schemes.test) do
        scheme[k] = v
      end
      scheme.tab_bar = nil
      local s = scenario "shell/active/0@34"
      local cfg = { color_scheme = "bare", color_schemes = { bare = scheme } }
      assert.is_string(format(s.tab, { s.tab }, nil, cfg, false, s.width))
    end)
  end

  it("reaches the fancy tab bar", function()
    local _, format =
      fresh { preset = "powerline", tabs = { style = { colors = { active = "#abcdef" } } } }
    local s = scenario "shell/active/0@34"
    local fancy =
      { use_fancy_tab_bar = true, color_scheme = "test", color_schemes = tabs.config.color_schemes }
    local out = format(s.tab, { s.tab }, nil, fancy, false, s.width)
    assert.is_true(has(out, "Background={Color=#abcdef}"), out)
  end)
end)
