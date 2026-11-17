local function visible_width(value)
  value = tostring(value or ""):gsub("\27%[[\32-\63]*[\64-\126]", "")
  local width = 0
  for codepoint in value:gmatch "[^\128-\191][\128-\191]*" do
    width = width + (codepoint == "中" and 2 or 1)
  end
  return width
end

local Ribbon = {}
Ribbon.__index = Ribbon

function Ribbon.new()
  return setmetatable({ items = {} }, Ribbon)
end

function Ribbon:clear()
  self.items = {}
  return self
end

function Ribbon:append(_, _, text)
  self.items[#self.items + 1] = text or ""
  return self
end

function Ribbon:format()
  return table.concat(self.items)
end

describe("status-bar renderer", function()
  local module_names = {
    "mosaic.engine.config",
    "mosaic.engine.renderer",
    "mosaic.engine.render.state",
    "mosaic.engine.render.resolve",
    "mosaic.engine.render.decorate",
    "mosaic.engine.render.cell",
    "mosaic.engine.render.fit",
    "mosaic.engine.budget",
    "mosaic.engine.conditions",
    "mosaic.engine.deps",
    "mosaic.engine.logger",
    "wezterm",
  }
  local saved, opts, renderer, window, pane, config, theme

  before_each(function()
    saved = {}
    for _, name in ipairs(module_names) do
      saved[name] = package.loaded[name]
      package.loaded[name] = nil
    end

    package.loaded.wezterm = {
      column_width = visible_width,
      format = function(items)
        local output = {}
        for _, item in ipairs(items) do
          if type(item) == "string" then
            output[#output + 1] = item
          elseif item.Text then
            output[#output + 1] = item.Text
          end
        end
        return table.concat(output)
      end,
    }
    local ribbon = {
      new = function()
        return Ribbon.new()
      end,
    }
    local warp = {
      string = {
        width = visible_width,
        -- Same contract as warp.string.truncate_right: keep the left side in
        -- whole display columns, then an ellipsis.
        truncate_right = function(value, budget)
          if visible_width(value) <= budget then
            return value
          end
          local out, used = {}, 0
          for cp in value:gmatch "[^\128-\191][\128-\191]*" do
            local w = visible_width(cp)
            if used + w + 1 > budget then
              break
            end
            out[#out + 1], used = cp, used + w
          end
          return table.concat(out) .. "…"
        end,
        pad = function(value, padding)
          value = tostring(value or "")
          local left, right
          if type(padding) == "table" then
            left, right = padding.left or 0, padding.right or 0
          else
            left, right = padding or 1, padding or 1
          end
          return string.rep(" ", left) .. value .. string.rep(" ", right)
        end,
      },
      table = {
        merge = function(_, ...)
          local result = {}
          for i = 1, select("#", ...) do
            for key, value in pairs(select(i, ...)) do
              result[key] = value
            end
          end
          return result
        end,
      },
    }
    package.loaded["mosaic.engine.deps"] = { ribbon = ribbon, warp = warp }
    package.loaded["mosaic.engine.logger"] = { debug = function() end, warn = function() end }
    package.loaded["mosaic.engine.budget"] = {
      set_screen_width = function() end,
      set_tab_max_width = function() end,
      set_left_used = function() end,
      set_new_tab_button = function() end,
      right_available = function()
        return 120
      end,
    }

    opts = { flexible = true, fit = "exhaustive", modules = {} }
    package.loaded["mosaic.engine.config"] = { live = opts }
    renderer = require "mosaic.engine.renderer"
    window = {
      get_dimensions = function()
        return { pixel_width = 120 }
      end,
    }
    pane = {
      get_dimensions = function()
        return { cols = 120, pixel_width = 120 }
      end,
    }
    config = { tab_max_width = 30 }
    theme = { foreground = "#fff", background = "#000" }
  end)

  after_each(function()
    for _, name in ipairs(module_names) do
      package.loaded[name] = saved[name]
    end
  end)

  local function make_module(icon, text, options)
    options = options or {}
    return {
      enabled = true,
      cond = true,
      can_hide = options.can_hide ~= false,
      priority = options.priority or 0,
      padding = options.padding or 0,
      icon = { enabled = true, value = icon, padding = 0 },
      text = {
        enabled = true,
        value = text,
        padding = 0,
        variants = options.variants,
        trim = options.trim,
      },
    }
  end

  local function render(names, width, fit, scheme)
    opts.fit = fit or "exhaustive"
    pane.get_dimensions = function()
      return { cols = width, pixel_width = 120 }
    end
    renderer.init(config, window, pane, theme, scheme)
    return renderer.render_layout { names }
  end

  it("uses the full candidate when every module fits", function()
    opts.modules.first = make_module("A", "alpha")
    opts.modules.second = make_module("B", "bravo")

    assert.equal("AalphaBbravo", render({ "first", "second" }, 40))
  end)

  it("keeps exhaustive layouts within the available width", function()
    opts.modules.first = make_module("A", "alpha", {
      variants = { "al", "a" },
    })
    opts.modules.second = make_module("B", "bravo", {
      variants = { "br", "b" },
    })
    opts.modules.third = make_module("C", "charlie", {
      variants = { "ch", "c" },
    })

    for width = 0, 30 do
      local result = render({ "first", "second", "third" }, width)
      assert.is_true(visible_width(result) <= width, "width " .. width)
    end
  end)

  it("truncates long Unicode text by display columns", function()
    opts.modules.unicode = make_module("", string.rep("中", 8))

    local result = render({ "unicode" }, 5)
    assert.equal("中中…", result)
    assert.equal(5, visible_width(result))
  end)

  it("keeps the balanced hide and grow result inside its budget", function()
    opts.modules.first = make_module("A", "alpha", { priority = 3 })
    opts.modules.second = make_module("B", "bravo", { priority = 2 })
    opts.modules.third = make_module("C", "charlie", { priority = 1 })

    for width = 0, 12 do
      local result = render({ "first", "second", "third" }, width, "balanced")
      assert.is_true(visible_width(result) <= width, "width " .. width)
    end
  end)

  describe("update caching", function()
    local calls, now, real_time

    before_each(function()
      calls = 0
      now = 1000
      real_time = os.time
      os.time = function() -- luacheck: ignore 122
        return now
      end
    end)

    after_each(function()
      os.time = real_time -- luacheck: ignore 122
    end)

    local function counting(update)
      return function()
        calls = calls + 1
        local m = make_module("X", "x" .. calls)
        m.update = update
        return m
      end
    end

    it("calls modules without update every frame", function()
      opts.modules.m = counting(nil)
      render({ "m" }, 40)
      render({ "m" }, 40)
      assert.equal(2, calls)
    end)

    it("reuses the spec until the interval passes", function()
      opts.modules.m = counting { interval = 5 }
      assert.equal("Xx1", render({ "m" }, 40))
      now = 1004
      assert.equal("Xx1", render({ "m" }, 40))
      now = 1005
      assert.equal("Xx2", render({ "m" }, 40))
      assert.equal(2, calls)
    end)

    it("accepts a bare number interval", function()
      opts.modules.m = counting(3)
      render({ "m" }, 40)
      render({ "m" }, 40)
      assert.equal(1, calls)
    end)

    it("reuses the spec while the key is unchanged", function()
      local key = "a"
      opts.modules.m = counting(function()
        return key
      end)
      render({ "m" }, 40)
      render({ "m" }, 40)
      assert.equal(1, calls)
      key = "b"
      assert.equal("Xx2", render({ "m" }, 40))
    end)

    it("still fits a cached spec to the current width", function()
      opts.modules.m = function()
        calls = calls + 1
        local m = make_module("X", "longtext")
        m.update = { interval = 60 }
        return m
      end
      assert.equal("Xlongtext", render({ "m" }, 40))
      assert.is_true(visible_width(render({ "m" }, 5)) <= 5)
      assert.equal(1, calls)
    end)

    it("invalidates on colour scheme change", function()
      opts.modules.m = counting { interval = 60 }
      render({ "m" }, 40, nil, "dark")
      render({ "m" }, 40, nil, "dark")
      render({ "m" }, 40, nil, "light")
      assert.equal(2, calls)
    end)

    it("invalidates when the module function is replaced", function()
      opts.modules.m = counting { interval = 60 }
      render({ "m" }, 40)
      opts.modules.m = counting { interval = 60 }
      render({ "m" }, 40)
      assert.equal(2, calls)
    end)

    it("keeps separate caches per window id", function()
      opts.modules.m = counting { interval = 60 }
      local id = 1
      window.window_id = function()
        return id
      end
      render({ "m" }, 40)
      id = 2
      render({ "m" }, 40)
      id = 1
      render({ "m" }, 40)
      assert.equal(2, calls)
    end)
  end)

  describe("exhaustive cap", function()
    it("falls back to balanced for oversized groups", function()
      local names = {}
      for i = 1, 8 do
        local name = "m" .. i
        names[i] = name
        opts.modules[name] = make_module("I", "text" .. i, { variants = { "t" .. i, "t" } })
      end
      for _, width in ipairs { 10, 20, 30 } do
        local balanced = render(names, width, "balanced")
        assert.equal(balanced, render(names, width, "exhaustive"), "width " .. width)
        assert.is_true(visible_width(balanced) <= width)
      end
    end)

    it("searches exhaustively below the cap", function()
      opts.modules.first = make_module("A", "alpha", { variants = { "al" } })
      opts.modules.second = make_module("B", "bravo", { variants = { "br" } })
      local result = render({ "first", "second" }, 8, "exhaustive")
      assert.is_true(visible_width(result) <= 8)
      assert.is_true(renderer.EXHAUSTIVE_CAP >= 4096)
    end)
  end)
end)
