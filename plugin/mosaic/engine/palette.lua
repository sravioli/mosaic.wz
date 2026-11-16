---@module "mosaic.engine.palette"
---@author sravioli
---@license GNU-GPLv2

---Colour helpers shared by the built-in modules and presets.

local wezterm = require "wezterm"

---Colour helpers shared by the built-in modules and presets.
---@class Mosaic.Palette
local M = {
  ---Focus of the window being drawn, set each frame (fancy titlebar colour).
  focused = true,
}

---`theme.ansi` index used as each built-in's accent colour.
M.ACCENTS = {
  badges = 2,
  battery = 3,
  clock = 7,
  cpu = 3,
  cwd = 5,
  disk = 4,
  domain = 5,
  hostname = 6,
  git = 3,
  kube = 5,
  media = 3,
  panes = 7,
  window = 8,
  leader = 2,
  mode = 3,
  network = 7,
  notice = 4,
  parent = 5,
  process = 4,
  progress = 5,
  ram = 6,
  ssh = 2,
  tabs = 7,
  title = 8,
  username = 6,
  workspace = 6,
  zoomed = 4,
}

---Colour from a user or preset value: `1`-`8` are `theme.ansi`, `9`-`16`
---`theme.brights`, `"foreground"` / `"background"` the scheme's own, a
---function is called with the theme, and any other string is a colour.
---@param  theme table
---@param  v     integer|string|function|nil
---@return string|nil
function M.resolve(theme, v)
  if type(v) == "number" then
    if v > 8 then
      return (theme.brights or {})[v - 8]
    end
    return (theme.ansi or {})[v]
  end
  if type(v) == "function" then
    return v(theme)
  end
  if v == "foreground" or v == "background" then
    return theme[v]
  end
  return v
end

---`ctx.style[key]` resolved (`style.text`, `style.dim`, ...), else `default`.
---@param  ctx     table decorate context
---@param  key     string
---@param  default integer|string|function
---@return string|nil
function M.pick(ctx, key, default)
  local v = ctx.style and ctx.style[key]
  if v == nil then
    v = default
  end
  return M.resolve(ctx.theme, v)
end

local _key, _bg_key, _n, _offsets, _palette, _text_fg

-- The classic four stops; longer groups stretch evenly over the same range.
local FOUR = { -0.15, 0, 0.15, 0.25 }

---`n`-stop gradient, darkest first. `gradient.base` is the colour it starts
---from (default `ansi[5]`) and `gradient.stops` the lighten (+) / darken (-)
---offsets. Groups longer than the offsets stretch over their range. Cached on
---the inputs, so modules that call this on every repaint share one
---computation.
---@param  theme     table
---@param  n?        integer stops wanted (default 4)
---@param  gradient? { base?: integer|string, stops?: number[] }
---@return string[] palette
---@return string   text_fg foreground for text inside palette cells
function M.stops(theme, n, gradient)
  n = n or 4
  gradient = gradient or {}
  local offsets = gradient.stops or FOUR
  local key = M.resolve(theme, gradient.base or 5)
  local bg_key = M.bar_bg(theme) or theme.background
  if key == _key and bg_key == _bg_key and n == _n and offsets == _offsets then
    return _palette, _text_fg
  end
  local fg = wezterm.color.parse(tostring(key))
  local first, last = offsets[1] or 0, offsets[#offsets] or 0
  _palette = {}
  for i = 1, n do
    local offset = offsets[i]
    if n > #offsets then
      offset = n == 1 and first or first + (last - first) * (i - 1) / (n - 1)
    end
    if offset < 0 then
      _palette[i] = tostring(fg:darken(-offset))
    elseif offset > 0 then
      _palette[i] = tostring(fg:lighten(offset))
    else
      _palette[i] = tostring(fg)
    end
  end
  _text_fg = tostring(bg_key)
  _key, _bg_key, _n, _offsets = key, bg_key, n, offsets
  return _palette, _text_fg
end

---Colour for a module being decorated. The first one that is set wins, in
---this order:
---
--- - its `tint`, a state colour such as a low battery
--- - the user's `style.colors[name]`
--- - the module's `accent` hint
--- - the built-in default for its name
---Values are read by `M.resolve`.
---@param  ctx  table decorate context
---@param  spec table module spec
---@return string
function M.color(ctx, spec)
  if spec.tint ~= nil then
    return M.resolve(ctx.theme, spec.tint)
  end
  local c = ctx.style.colors and ctx.style.colors[ctx.name]
  if c == nil then
    c = spec.accent or M.ACCENTS[ctx.name] or 5
  end
  return M.resolve(ctx.theme, c)
end

---Tab look for a preset's `format` / `new_tab`: the user's `tabs.style`
---over the preset's `defaults`.
---
---Returns a table with these keys:
---
--- - `fill`: the colour for the tab's state
--- - `text`, `bar`, and every other `colors` key, resolved under the same name
--- - `left` / `right`: the edge glyphs
--- - `index`: the tab's index text, or the unseen marker
--- - `label`: the new-tab button text
---@param  ctx      table tab or new-tab context
---@param  defaults { colors: table, separators?: table, index?: any, unseen?: string|false, new_tab?: string }
---@return table
function M.tab(ctx, defaults)
  local user = ctx.style or {}
  local theme = ctx.theme
  local colors = {}
  for k, v in pairs(defaults.colors or {}) do
    colors[k] = v
  end
  for k, v in pairs(user.colors or {}) do
    colors[k] = v
  end
  local out = {}
  for k, v in pairs(colors) do
    out[k] = M.resolve(theme, v)
  end
  local state = ctx.state or (ctx.hover and "hover" or "inactive")
  out.fill = out[state]
  out.bar = M.bar_bg(theme, ctx.config)
  local dseps, useps = defaults.separators or {}, user.separators or {}
  out.left = useps.left or dseps.left or ""
  out.right = useps.right or dseps.right or ""
  local label = user.new_tab
  if label == nil then
    label = defaults.new_tab or "+"
  end
  out.label = label

  if ctx.tab then
    local unseen = user.unseen
    if unseen == nil then
      unseen = defaults.unseen or "*"
    end
    local index = user.index
    if index == nil then
      index = defaults.index or "number"
    end
    local i = ctx.tab.tab_index + 1
    if ctx.unseen and unseen then
      out.index = unseen
    elseif index == "number" then
      out.index = tostring(i)
    elseif index == "number0" then
      out.index = tostring(i - 1)
    elseif index == "icon" then
      out.index = (require("mosaic.engine.deps").icons().Nums or {})[i] or tostring(i)
    elseif type(index) == "function" then
      out.index = tostring(index(ctx.tab, ctx) or "")
    else
      out.index = ""
    end
  end
  return out
end

local builtin

---WezTerm's built-in schemes, fetched once: building the table (about
---1100 schemes) takes over 10 ms, too slow to repeat per frame or per tab.
---@return table
local function builtins()
  builtin = builtin or wezterm.color.get_builtin_schemes()
  return builtin
end

---The colour scheme called `name`: the config's own, else WezTerm's built-in
---one, else (no or unknown name) WezTerm's default colours.
---@param  cfg  table|nil config (for `color_schemes`)
---@param  name string|nil
---@return table|nil
function M.scheme(cfg, name)
  local own = name and cfg and cfg.color_schemes and cfg.color_schemes[name]
  if own then
    return own
  end
  local found = name and builtins()[name]
  if found then
    return found
  end
  local ok, colors = pcall(wezterm.color.get_default_colors)
  return ok and colors or nil
end

local _composite = {}

---`theme` with its colours taken from the `scheme` option, which is another
---scheme's name or a scheme table. Its `tab_bar` is kept, so the bar surface
---still matches the strip WezTerm paints. Without the option, `theme` itself.
---@param  theme table|nil active colour scheme
---@param  cfg?  table     effective config (for `color_schemes`)
---@return table|nil
function M.composite(theme, cfg)
  local want = require("mosaic.engine.config").live.scheme
  if not want or not theme then
    return theme
  end
  local src = want
  if type(want) == "string" then
    src = cfg and cfg.color_schemes and cfg.color_schemes[want]
    if not src then
      src = builtins()[want]
    end
  end
  if type(src) ~= "table" then
    return theme
  end
  local bar = theme.tab_bar
  local key = tostring(want) .. "|" .. tostring(bar and bar.background)
  local hit = _composite[key]
  if hit and hit.src == src then
    return hit.out
  end
  local out = {}
  for k, v in pairs(src) do
    out[k] = v
  end
  out.tab_bar = bar
  _composite[key] = { src = src, out = out }
  return out
end

---Background of the bar surface left of the first right-status cell.
---@param  theme  table
---@param  config table|nil
---@return string|nil nil when the scheme does not set it
function M.bar_bg(theme, config)
  local frame = config and config.use_fancy_tab_bar and config.window_frame
  if frame then
    -- The fancy bar is the titlebar, which follows window focus.
    local bg = M.focused == false and frame.inactive_titlebar_bg or frame.active_titlebar_bg
    if bg then
      return tostring(bg)
    end
  end
  local bg = (theme.tab_bar or {}).background
  return bg and tostring(bg)
end

---Plain style: `theme.ansi[index]` text with no background. The cell then
---shows the bar's real surface. The scheme's `tab_bar.background` can differ
---from what WezTerm draws, which would box the text.
---@param  index integer
---@return fun(theme: table): table
function M.accent(index)
  return function(theme)
    return { fg = theme.ansi[index] }
  end
end

return M
