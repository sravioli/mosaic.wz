-- Minimal WezTerm config for `scripts/screenshots.sh`: one small window with
-- the bar of the preset named by $MOSAIC_PRESET, in the Kanagawa scheme named
-- by $MOSAIC_KANAGAWA ("wave" dark, "lotus" light). Settings come from the
-- environment so the script stays the only place that knows the defaults.
local wezterm = require "wezterm"

local repo = assert(os.getenv "MOSAIC_REPO", "MOSAIC_REPO is not set")
local cwd = os.getenv "MOSAIC_CWD" or wezterm.home_dir -- a short path leaves room for the modules
for _, name in ipairs { "warp", "log", "warden", "sigil", "ribbon" } do
  local base = repo .. "/../" .. name .. ".wz/plugin/"
  package.path = base .. "?.lua;" .. base .. "?/init.lua;" .. package.path
end
package.path = repo .. "/plugin/?.lua;" .. repo .. "/plugin/?/init.lua;" .. package.path

wezterm.plugin.require "https://github.com/kanagawa-community/wezterm"

local mosaic = require "mosaic.api"
mosaic.setup { preset = assert(os.getenv "MOSAIC_PRESET"), position = "top" }

-- The cpu module shows `--%` until it has two samples, and an idle window
-- redraws rarely: take the first one now, while the config loads.
require("mosaic.engine.system").cpu()

local config = wezterm.config_builder()
config.font_size = tonumber(os.getenv "MOSAIC_FONT_SIZE") or 16
config.initial_cols = tonumber(os.getenv "MOSAIC_COLS") or 140
config.initial_rows = 1 -- the bar plus one row; the script keeps only the bar
config.enable_wayland = false -- KDE ignores `window_decorations = "NONE"` on Wayland
config.window_decorations = "NONE"
config.window_padding = { left = 0, right = 0, top = 0, bottom = 0 }
config.enable_scroll_bar = false
config.use_fancy_tab_bar = false
config.hide_tab_bar_if_only_one_tab = false
config.tab_max_width = 24
config.check_for_updates = false
-- The scheme first: mosaic draws the new-tab button in the scheme set when it
-- is applied.
require("kanagawa.api").apply_to_config(config, { scheme = os.getenv "MOSAIC_KANAGAWA" or "wave" })
mosaic.apply_to_config(config)

-- Three tabs, so the preset's active, inactive and hover looks all show.
wezterm.on("gui-startup", function()
  local mux = wezterm.mux
  local tab, _, window = mux.spawn_window { cwd = cwd }
  tab:set_title "mosaic"
  for _, title in ipairs { "notes", "build" } do
    local t = window:spawn_tab { cwd = cwd }
    t:set_title(title)
  end
  window:tabs()[1]:activate()
end)

return config
