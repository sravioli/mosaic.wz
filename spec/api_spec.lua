local wezterm = require "wezterm"

local scenarios = dofile "spec/support/scenarios.lua"

local function fresh()
  for k in pairs(package.loaded) do
    if k:match "^mosaic" then
      package.loaded[k] = nil
    end
  end
  wezterm._reset()
  return require "mosaic.api"
end

local function text_module(text)
  return { enabled = true, cond = true, text = { enabled = true, value = text } }
end

-- Text only, trimmed: without a preset the default (minimal) decoration
-- pads every module with a space on each side.
local function plain(s)
  return ((s or ""):gsub("\27%b{}", ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

describe("mosaic.api", function()
  local mosaic

  before_each(function()
    mosaic = fresh()
  end)

  describe("setup", function()
    it("keeps the live table identity across calls", function()
      local live = mosaic.setup {}
      assert.equal(live, mosaic.setup { fit = "greedy" })
      assert.equal("greedy", live.fit)
    end)

    it("defaults to balanced fit, bottom position, enabled", function()
      local live = mosaic.setup()
      assert.equal("balanced", live.fit)
      assert.equal("bottom", live.position)
      assert.is_true(live.enabled)
      assert.same({ left = {}, center = {}, right = {} }, live.layout)
    end)

    it("takes layout and modules from the preset", function()
      local live = mosaic.setup { preset = "powerline" }
      assert.same({ "leader", "zoomed", "workspace", "mode" }, live.layout.left)
    end)

    it("lets a user layout replace the preset layout", function()
      local live = mosaic.setup { preset = "minimal", layout = { left = { "clock" } } }
      assert.same({ "clock" }, live.layout.left)
      assert.same({}, live.layout.right)
    end)

    it("lets a user module replace a preset module by name", function()
      local mine = text_module "mine"
      local live = mosaic.setup { preset = "minimal", modules = { clock = mine } }
      assert.equal(mine, live.modules.clock)
      assert.is_function(live.modules.cwd) -- other preset modules kept
    end)

    it("falls back to builtins for names nobody defined", function()
      local live = mosaic.setup {}
      assert.equal(mosaic.modules.leader, live.modules.leader)
    end)

    it("drops invalid fields and keeps the rest", function()
      local live = mosaic.setup { fit = "bogus", flexible = false, layout = { left = { 1 } } }
      assert.equal("balanced", live.fit)
      assert.is_false(live.flexible)
      assert.same({}, live.layout.left)
    end)

    it("survives a non-table argument and an unknown preset", function()
      assert.equal("balanced", mosaic.setup("nope").fit)
      assert.same({}, mosaic.setup({ preset = "nope" }).layout.left)
      assert.same({}, mosaic.setup({ preset = "../../etc" }).layout.left)
    end)

    it("clears modules from a previous setup", function()
      mosaic.setup { modules = { gone = text_module "x" } }
      assert.is_nil(mosaic.setup({}).modules.gone)
    end)
  end)

  describe("apply_to_config", function()
    it("registers update-status once and sets the position", function()
      mosaic.setup { position = "top" }
      local c = {}
      mosaic.apply_to_config(c)
      mosaic.apply_to_config(c)
      assert.is_false(c.tab_bar_at_bottom)
      assert.equal(1, #wezterm._handlers["update-status"])
    end)
  end)

  describe("refresh", function()
    local function render(opts, s)
      mosaic.setup(opts)
      local window, pane = scenarios.build(s or scenarios.list[16])
      mosaic.refresh(window, pane)
      return window
    end

    it("renders both sides", function()
      local window = render {
        layout = { left = { "a" }, right = { "b" } },
        modules = {
          a = text_module "left",
          b = text_module "right",
        },
      }
      assert.equal("left", plain(window._left))
      assert.equal("right", plain(window._right))
    end)

    it("clears the bar once when disabled", function()
      mosaic.setup { enabled = false }
      local window, pane = scenarios.build(scenarios.list[16])
      local sets = 0
      window.set_left_status = function()
        sets = sets + 1
      end
      mosaic.refresh(window, pane)
      mosaic.refresh(window, pane)
      assert.equal(1, sets)
    end)

    it("exposes the remaining width to modules", function()
      local seen
      render {
        layout = { left = { "a", "b" } },
        modules = {
          a = text_module "1234",
          b = function()
            seen = mosaic.remaining_width()
            return { enabled = false }
          end,
        },
      }
      assert.equal(240 - 6, seen) -- "1234" plus the default padding
    end)
  end)

  describe("extend", function()
    it("patches without modifying the base module", function()
      local base = text_module "base"
      base.style = { fg = "red" }
      local wrapped = mosaic.extend(base, { text = { value = "patched" }, style = { bg = "blue" } })
      local spec = wrapped()
      assert.equal("patched", spec.text.value)
      assert.same({ fg = "red", bg = "blue" }, spec.style)
      assert.equal("base", base.text.value)
      assert.same({ fg = "red" }, base.style)
    end)

    it("calls function modules and function patches", function()
      local wrapped = mosaic.extend(function(_, _, theme)
        return text_module(theme.name)
      end, function(spec)
        spec.text.value = spec.text.value .. "!"
        return spec
      end)
      assert.equal("dark!", wrapped(nil, nil, { name = "dark" }).text.value)
    end)

    it("passes disabled specs through", function()
      local wrapped = mosaic.extend(function()
        return { enabled = false }
      end, { enabled = true })
      assert.is_false(wrapped().enabled)
    end)
  end)

  describe("presets", function()
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

    local function render_preset(name, s)
      mosaic = fresh()
      mosaic.setup { preset = name }
      local window, pane = scenarios.build(s)
      for i, w in ipairs(s.tabs) do
        mosaic.budget.record(i - 1, w)
      end
      mosaic.budget.set_count(#s.tabs)
      mosaic.refresh(window, pane)
      return window
    end

    for _, name in ipairs(PRESETS) do
      it(name .. " renders every scenario within the screen width", function()
        for _, s in ipairs(scenarios.list) do
          local window = render_preset(name, s)
          local width = wezterm.column_width(plain(window._left))
            + wezterm.column_width(plain(window._right))
          assert.is_true(width <= s.cols, ("%s %s: %d > %d"):format(name, s.name, width, s.cols))
        end
      end)

      it(name .. " places a user-defined hints module", function()
        mosaic = fresh()
        mosaic.setup {
          preset = name,
          modules = {
            hints = { enabled = true, cond = true, layout = { { Text = "HINTS" } } },
          },
        }
        local s = scenarios.list[18] -- mode@240
        local window, pane = scenarios.build(s)
        mosaic.refresh(window, pane)
        assert.is_truthy(plain(window._right):find("HINTS", 1, true))
      end)

      it(name .. " never leaves a cell transparent", function()
        -- An unset bg reaches WezTerm as transparent and shows the terminal
        -- background, which can be lighter than the bar.
        for _, s in ipairs(scenarios.list) do
          local window = render_preset(name, s)
          assert.is_nil(
            (window._left .. window._right):find("Background={Color=none}", 1, true),
            s.name
          )
        end
        local tabs = dofile "spec/support/tabs.lua"
        mosaic.apply_to_config {}
        local format = wezterm._handlers["format-tab-title"][1]
        for _, s in ipairs(tabs.list) do
          local out = format(s.tab, { s.tab, {}, {} }, nil, tabs.config, s.hover, s.width)
          assert.is_nil(out:find("Background={Color=none}", 1, true), s.name)
        end
      end)

      it(name .. " redraws a stale new-tab button kept in window overrides", function()
        mosaic = fresh()
        mosaic.setup { preset = name }
        mosaic.apply_to_config {}
        local window = scenarios.build(scenarios.list[16])
        local overrides =
          { tab_bar_style = { new_tab = "old", new_tab_hover = "old" }, font_size = 12 }
        local set
        function window:get_config_overrides()
          return overrides
        end
        function window:set_config_overrides(o)
          set = o
        end
        wezterm._handlers["window-config-reloaded"][1](window)
        assert.is_truthy(set, name)
        assert.are_not.equal("old", set.tab_bar_style.new_tab)
        assert.equal(12, set.font_size)
        -- Already current: no second write, so no reload loop.
        set = nil
        wezterm._handlers["window-config-reloaded"][1](window)
        assert.is_nil(set)
      end)

      it(name .. " uses only the public API", function()
        local f = assert(io.open("plugin/mosaic/presets/" .. name .. ".lua"))
        local src = f:read "*a"
        f:close()
        for mod in src:gmatch "require%s*%(?%s*[\"']([^\"']+)" do
          assert.is_true(
            mod == "wezterm" or mod == "mosaic.api" or mod:match "^mosaic%.presets%.[%w_-]+$" ~= nil,
            name .. " requires " .. mod
          )
        end
      end)
    end
  end)
end)

describe("mosaic.cond.is_default_workspace", function()
  local function window(name)
    return {
      active_workspace = function()
        return name
      end,
    }
  end

  it("matches WezTerm's default workspace name", function()
    local cond = require "mosaic.engine.conditions"
    local state = require "mosaic.engine.render.state"
    local saved = state.config
    state.config = nil
    assert.is_true(cond.is_default_workspace(window "default"))
    assert.is_false(cond.is_default_workspace(window "work"))
    state.config = { default_workspace = "main" }
    assert.is_true(cond.is_default_workspace(window "main"))
    state.config = saved
  end)
end)

describe("process icons", function()
  it("come from sigil's registry, with user overrides first", function()
    local icons = require "mosaic.engine.icons"
    local sigil = require("mosaic.engine.deps").sigil()
    assert.equal(sigil.icon("nvim", { fallback = false }), icons.process "nvim")
    assert.equal("N", icons.process("nvim", { nvim = "N" }))
    assert.is_nil(icons.process("nvim", { nvim = false }))
    assert.equal(icons.PROCESS_DEFAULT, icons.process "no-such-program")
  end)
end)

describe("invalid options", function()
  it("drop only the bad value, not the whole section", function()
    local config = require "mosaic.engine.config"
    config.setup {
      style = { colors = { cwd = "" }, separators = { left = "<" } },
    }
    assert.equal("<", config.live.style.separators.left)
    assert.is_nil(config.live.style.colors.cwd)
    assert.truthy(config.issues[1]:find("cwd", 1, true))
    config.setup {}
  end)
end)
