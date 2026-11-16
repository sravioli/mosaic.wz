local wezterm = require "wezterm"

local scenarios = dofile "spec/support/scenarios.lua"

local theme = scenarios.theme

local function fresh()
  for k in pairs(package.loaded) do
    if k:match "^mosaic" then
      package.loaded[k] = nil
    end
  end
  wezterm._reset()
  return require "mosaic.api"
end

---Content-only module, like an integration returns.
local function content(text, accent)
  return { enabled = true, cond = true, accent = accent, text = { enabled = true, value = text } }
end

local function render(opts)
  local mosaic = fresh()
  mosaic.setup(opts)
  local window, pane = scenarios.build(scenarios.list[16]) -- idle@240
  mosaic.refresh(window, pane)
  return window._left, window._right
end

local function bg(color)
  return "Background={Color=" .. color .. "}"
end

local function fg(color)
  return "Foreground={Color=" .. color .. "}"
end

local function has(s, needle)
  return s:find(needle, 1, true) ~= nil
end

describe("preset decoration", function()
  describe("powerline", function()
    it("turns a content-only left module into a pill in its accent colour", function()
      local left = render {
        preset = "powerline",
        layout = { left = { "x.y" } },
        modules = { ["x.y"] = content("X", 3) },
      }
      assert.is_true(has(left, bg(theme.ansi[3])))
      assert.is_true(has(left, fg(theme.background)))
    end)

    it("draws the left pill's caps on the bar colour", function()
      local left = render {
        preset = "powerline",
        layout = { left = { "x" } },
        modules = { x = content("X", 3) },
      }
      assert.is_true(has(left, bg(theme.tab_bar.background) .. "}\27{" .. fg(theme.ansi[3])), left)
    end)

    it("puts a right-side group of any modules on one gradient", function()
      local _, right = render {
        preset = "powerline",
        layout = { right = { { "a", "b", "c", "d", "e", "f" } } },
        modules = {
          a = content "A",
          b = content "B",
          c = content "C",
          d = content "D",
          e = content "E",
          f = content "F",
        },
      }
      local mosaic = require "mosaic.api"
      local stops = mosaic.palette.stops(theme, 6)
      assert.equal(6, #stops)
      for i = 1, 6 do
        assert.is_true(has(right, bg(stops[i])), "stop " .. i)
      end
      -- each arrow sits on the previous segment's colour, drawn in its own
      for i = 2, 6 do
        assert.is_true(has(right, bg(stops[i - 1]) .. "}\27{" .. fg(stops[i])), "arrow " .. i)
      end
    end)

    it("keeps the classic four stops for four modules", function()
      local mosaic = fresh()
      local four = mosaic.palette.stops(theme, 4)
      assert.equal(theme.ansi[5] .. "-d0.15", four[1])
      assert.equal(theme.ansi[5], four[2])
      assert.equal(theme.ansi[5] .. "+l0.15", four[3])
      assert.equal(theme.ansi[5] .. "+l0.25", four[4])
    end)

    it("skips disabled modules when assigning stops", function()
      local _, right = render {
        preset = "powerline",
        layout = { right = { { "a", "off", "b" } } },
        modules = { a = content "A", off = { enabled = false }, b = content "B" },
      }
      local mosaic = require "mosaic.api"
      local stops = mosaic.palette.stops(theme, 2)
      local third = mosaic.palette.stops(theme, 3)[3]
      assert.is_true(has(right, bg(stops[1]) .. "}\27{" .. fg(stops[2])))
      assert.is_false(has(right, bg(third)))
    end)
  end)

  for _, preset in ipairs {
    "minimal",
    "bubbles",
    "slanted",
    "slanted-inverted",
    "blocks",
    "brackets",
    "pure",
  } do
    it(preset .. " colours a content-only module by its accent", function()
      local _, right = render {
        preset = preset,
        layout = { right = { "x.y" } },
        modules = { ["x.y"] = content("X", 4) },
      }
      assert.is_true(has(right, fg(theme.ansi[4])) or has(right, bg(theme.ansi[4])))
    end)
  end

  for _, preset in ipairs { "slanted", "slanted-inverted", "blocks", "brackets", "pure" } do
    it(preset .. " paints every cell, gaps included, on the bar colour", function()
      local left, right = render {
        preset = preset,
        layout = { left = { "a" }, right = { "b", "c" } },
        modules = { a = content("A", 3), b = content("B", 4), c = content "C" },
      }
      for _, side in ipairs { left, right } do
        assert.is_false(has(side, "Color=none"), preset .. ": " .. side)
        assert.is_true(has(side, bg(theme.tab_bar.background)), preset)
      end
    end)
  end

  for _, preset in ipairs { "slanted", "slanted-inverted" } do
    it(preset .. " keeps the outermost edges flat", function()
      local left, right = render {
        preset = preset,
        layout = { left = { "off", "a", "b" }, right = { "c", { "d", "e" }, "off" } },
        modules = {
          off = { enabled = false },
          a = content "A",
          b = content "B",
          c = content "C",
          d = content "D",
          e = content "E",
        },
      }
      local function glyphs(s)
        return select(2, s:gsub("\u{E000}", ""))
      end
      -- a: close only (first visible on the left), b: open + close
      assert.equal(3, glyphs(left), left)
      -- c, d: open + close, e: open only (last visible on the right)
      assert.equal(5, glyphs(right), right)
    end)
  end

  it("pads content inside the block, in the block's colour", function()
    local _, right = render {
      preset = "blocks",
      layout = { right = { "a" } },
      modules = { a = content("A", 3) },
    }
    assert.is_true(
      has(right, bg(theme.ansi[3]) .. "}\27{" .. fg(theme.background) .. "} A "),
      right
    )
  end)

  it("resets text attributes before the closing separator", function()
    local module = content "A"
    module.text.style = { attributes = "i" }
    local _, right =
      render { preset = "brackets", layout = { right = { "a" } }, modules = { a = module } }
    local text = right:gsub("\27{[BF][^}]*}}", "")
    assert.is_truthy(text:find("A \27{ResetAttributes}]", 1, true), text)
  end)

  it("uses the titlebar colour for the fancy bar, following focus", function()
    local mosaic = fresh()
    local cfg = {
      use_fancy_tab_bar = true,
      window_frame = { active_titlebar_bg = "#aaaaaa", inactive_titlebar_bg = "#bbbbbb" },
    }
    mosaic.palette.focused = true
    assert.equal("#aaaaaa", mosaic.palette.bar_bg(theme, cfg))
    mosaic.palette.focused = false
    assert.equal("#bbbbbb", mosaic.palette.bar_bg(theme, cfg))
    assert.equal(
      theme.tab_bar.background,
      mosaic.palette.bar_bg(theme, { use_fancy_tab_bar = false })
    )
    mosaic.palette.focused = true
  end)

  it("accepts a colour string as the accent hint", function()
    local _, right = render {
      preset = "minimal",
      layout = { right = { "m" } },
      modules = { m = content("M", "#00ff00") },
    }
    assert.is_true(has(right, fg "#00ff00"))
  end)

  describe("user style", function()
    it("overrides a module's colour by name (ansi index or colour)", function()
      local left = render {
        preset = "bubbles",
        layout = { left = { "a", "b" } },
        modules = { a = content("A", 3), b = content "B" },
        style = { colors = { a = 2, b = "#abcdef" } },
      }
      assert.is_true(has(left, bg(theme.ansi[2])))
      assert.is_true(has(left, bg "#abcdef"))
      assert.is_false(has(left, bg(theme.ansi[3])))
    end)

    it("overrides a right-side gradient segment", function()
      local _, right = render {
        preset = "powerline",
        layout = { right = { { "a", "b" } } },
        modules = { a = content "A", b = content "B" },
        style = { colors = { b = "#123456" } },
      }
      assert.is_true(has(right, bg "#123456"))
    end)

    it("replaces the preset's separators", function()
      for _, preset in ipairs {
        "powerline",
        "minimal",
        "bubbles",
        "slanted",
        "blocks",
        "brackets",
        "pure",
      } do
        local left = render {
          preset = preset,
          -- Two modules: slanted keeps the outermost edge flat.
          layout = { left = { "z", "a" } },
          modules = { z = content "Z", a = content "A" },
          style = { separators = { left = "<<", right = ">>" } },
        }
        local text = left:gsub("\27%b{}", "")
        assert.is_true(has(text, "<<") and has(text, ">>"), preset .. ": " .. text)
      end
    end)

    it("draws modules listed in raw as plain text in their colour", function()
      for _, preset in ipairs {
        "powerline",
        "minimal",
        "bubbles",
        "slanted",
        "blocks",
        "brackets",
        "pure",
      } do
        local _, right = render {
          preset = preset,
          layout = { right = { "a" } },
          modules = { a = content("A", 3) },
          style = { raw = { "a" }, separators = { left = "<<", right = ">>" } },
        }
        assert.is_true(has(right, fg(theme.ansi[3])), preset)
        assert.is_true(has(right, bg(theme.tab_bar.background)), preset)
        assert.is_false(has(right, "Color=none"), preset)
        assert.is_false(has(right, "<<"), preset)
        assert.is_true(has(right:gsub("\27%b{}", ""), " A "), preset)
      end
    end)

    it("merges over the preset's own style", function()
      local mosaic = fresh()
      local live = mosaic.setup { preset = "powerline", style = { colors = { a = 1 } } }
      assert.same({ a = 1 }, live.style.colors)
      assert.same({}, live.style.separators)
      assert.same({}, live.style.raw)
    end)

    it("accepts a custom decorate function", function()
      local seen
      local _, right = render {
        layout = { right = { "a" } },
        modules = { a = content "A" },
        decorate = function(spec, ctx)
          seen = ctx
          local out = {}
          for k, v in pairs(spec) do
            out[k] = v
          end
          out.style = function()
            return { fg = "#000001" }
          end
          return out
        end,
      }
      assert.is_true(has(right, fg "#000001"))
      assert.equal("right", seen.side)
      assert.equal("a", seen.name)
    end)
  end)

  it("leaves modules that style themselves alone", function()
    local styled = content "S"
    styled.style = function()
      return { bg = "#0a0b0c", fg = "#0d0e0f" }
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
      local left = render {
        preset = preset,
        layout = { left = { "s" } },
        modules = { s = styled },
        style = { colors = { s = 1 } },
      }
      assert.is_true(has(left, bg "#0a0b0c"), preset)
      assert.is_false(has(left, bg(theme.ansi[1])), preset)
    end
  end)

  it("does not modify the module tables it decorates", function()
    local module = content("A", 2)
    render { preset = "powerline", layout = { left = { "a" } }, modules = { a = module } }
    assert.is_nil(module.style)
    assert.is_nil(module.sep)
  end)
end)
