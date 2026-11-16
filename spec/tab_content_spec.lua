local wezterm = require "wezterm"

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

local function render(format, s, cfg)
  return format(s.tab, { s.tab, {}, {} }, nil, cfg or tabs.config, s.hover, s.width)
end

local strict = dofile "spec/support/strict.lua"

---A tab with one pane built from `fields`, as strict as WezTerm's
---PaneInformation / TabInformation (unknown fields raise).
local function tab(fields, extra)
  local pane = {
    pane_id = 1,
    title = "zsh",
    foreground_process_name = "/usr/bin/nvim",
    current_working_dir = { file_path = "/home/mock/source/mosaic" },
    domain_name = "local",
    user_vars = {},
  }
  for k, v in pairs(fields or {}) do
    pane[k] = v
  end
  local info = strict.pane(pane)
  local t = { tab_index = 0, is_active = false, tab_title = "", active_pane = info }
  for k, v in pairs(extra or {}) do
    t[k] = v
  end
  return strict.tab(t)
end

local function draw(opts, t, width)
  local _, format = fresh(opts)
  return format(t, { t }, nil, tabs.config, false, width or 40)
end

describe("tabs.content", function()
  local nf = wezterm.nerdfonts

  it("composes components, literals and functions", function()
    local out = plain(draw({
      preset = "minimal",
      tabs = {
        content = {
          "process",
          "parent",
          "/",
          "cwd",
          function(t)
            return "#" .. t.tab_index
          end,
        },
      },
    }, tab()))
    assert.is_true(has(out, nf.custom_neovim .. " nvim source/mosaic #0"), out)
  end)

  it("uses the active and inactive lists by state", function()
    local opts =
      { preset = "minimal", tabs = { content = { active = { "cwd" }, inactive = { "process" } } } }
    assert.is_true(has(plain(draw(opts, tab(nil, { is_active = true }))), "mosaic"))
    local inactive = plain(draw(opts, tab()))
    assert.is_true(has(inactive, "nvim"), inactive)
    assert.is_false(has(inactive, "mosaic"), inactive)
  end)

  it("takes per-component options", function()
    local out = plain(draw({
      preset = "minimal",
      tabs = { content = { { "process", icons = { nvim = "N" }, icon_only = true } } },
    }, tab()))
    assert.is_true(has(out, " N "), out)
    assert.is_false(has(out, "nvim"), out)
  end)

  it("shows zoomed, output, panes and domain only when they apply", function()
    local opts = {
      preset = "minimal",
      tabs = { content = { "title", "zoomed", "output", "panes", "domain" } },
    }
    local quiet = plain(draw(opts, tab()))
    assert.equal(" 1 zsh ", quiet)
    local busy = tab { is_zoomed = true, domain_name = "SSH:box" }
    busy.panes = { busy.active_pane, { pane_id = 2, has_unseen_output = true } }
    local out = plain(draw(opts, busy))
    for _, part in ipairs { "zsh", "SSH:box", "2" } do
      assert.is_true(has(out, part), part .. " in " .. out)
    end
  end)

  it("drops components from the right, then cuts the title", function()
    local opts = { preset = "minimal", tabs = { content = { "title", "process", "cwd" } } }
    local t = tab { title = "a rather long pane title" }
    local out = plain(draw(opts, t, 20))
    assert.is_true(wezterm.column_width(out) <= 20, out)
    assert.is_false(has(out, "mosaic"), out) -- cwd went first
    assert.is_true(has(out, "a rather"), out)
  end)

  for _, preset in ipairs(PRESETS) do
    it(preset .. " fits max_width with content", function()
      local _, format =
        fresh { preset = preset, tabs = { content = { "process", "cwd", "title" } } }
      for _, s in ipairs(tabs.list) do
        local width = wezterm.column_width(plain(render(format, s)))
        assert.is_true(width <= s.width, ("%s %s: %d > %d"):format(preset, s.name, width, s.width))
      end
    end)
  end

  it("pads the title with tabs.style.padding", function()
    local out = plain(draw({ preset = "minimal", tabs = { style = { padding = 2 } } }, tab()))
    assert.equal(" 1   zsh   ", out)
  end)

  it("counts from zero with index = number0", function()
    local out = plain(draw({ preset = "minimal", tabs = { style = { index = "number0" } } }, tab()))
    assert.is_true(has(out, " 0 "), out)
  end)
end)

describe("tabs.rules", function()
  local function active_fill(opts, t)
    local out = draw(opts, t)
    return out
  end

  it("match a domain exactly, by pattern or by function", function()
    for _, want in ipairs {
      "SSH:prod",
      { pattern = "^SSH" },
      function(name)
        return name:find "prod" ~= nil
      end,
    } do
      local out = active_fill({
        preset = "blocks",
        tabs = {
          rules = { { match = { domain = want }, style = { colors = { inactive = "#123456" } } } },
        },
      }, tab { domain_name = "SSH:prod" })
      assert.is_true(has(out, "#123456"), out)
    end
  end)

  it("need every given key to match", function()
    local out = active_fill({
      preset = "blocks",
      tabs = {
        rules = {
          {
            match = { domain = "local", process = "vim" },
            style = { colors = { inactive = "#123456" } },
          },
        },
      },
    }, tab())
    assert.is_false(has(out, "#123456"), out)
  end)

  it("match cwd, process basename, title and user vars", function()
    for _, match in ipairs {
      { cwd = { pattern = "^/home/mock/source" } },
      { process = "nvim" },
      { title = "zsh" },
      { user_var = { name = "role", value = "prod" } },
    } do
      local out = active_fill({
        preset = "blocks",
        tabs = { rules = { { match = match, style = { colors = { inactive = "#123456" } } } } },
      }, tab { user_vars = { role = "prod" } })
      assert.is_true(has(out, "#123456"), next(match))
    end
  end)

  it("apply in order, later ones merging over earlier", function()
    local out = active_fill({
      preset = "blocks",
      tabs = {
        rules = {
          {
            match = { domain = { pattern = "^SSH" } },
            style = { colors = { inactive = "#111111", text = "#222222" } },
          },
          { match = { domain = "SSH:prod" }, style = { colors = { inactive = "#333333" } } },
        },
      },
    }, tab { domain_name = "SSH:prod" })
    assert.is_true(has(out, "#333333") and has(out, "#222222"), out)
    assert.is_false(has(out, "#111111"), out)
  end)

  it("feed the icon component", function()
    local out = plain(draw({
      preset = "minimal",
      tabs = {
        content = { "icon", "title" },
        rules = { { match = { domain = "local" }, icon = "L" } },
      },
    }, tab()))
    assert.is_true(has(out, "L zsh"), out)
  end)

  it("reach the fancy tab bar", function()
    local _, format = fresh {
      preset = "powerline",
      tabs = {
        rules = { { match = { process = "nvim" }, style = { colors = { active = "#abcdef" } } } },
      },
    }
    local t = tab(nil, { is_active = true })
    local fancy =
      { use_fancy_tab_bar = true, color_scheme = "test", color_schemes = tabs.config.color_schemes }
    assert.is_true(has(format(t, { t }, nil, fancy, false, 30), "#abcdef"))
  end)

  it("need a match", function()
    local mosaic = fresh {
      preset = "blocks",
      tabs = { rules = { { style = { colors = { inactive = "#123456" } } } } },
    }
    assert.is_nil(
      mosaic.setup({ preset = "blocks", tabs = { rules = { { style = {} } } } }).tabs.rules
    )
  end)

  it("leave tabs alone when nothing matches", function()
    local s = scenario "shell/inactive/0@34"
    local _, plain_format = fresh { preset = "powerline" }
    local _, ruled = fresh {
      preset = "powerline",
      tabs = {
        rules = {
          { match = { domain = "nowhere" }, style = { colors = { inactive = "#123456" } } },
        },
      },
    }
    assert.equal(render(plain_format, s), render(ruled, s))
  end)
end)
