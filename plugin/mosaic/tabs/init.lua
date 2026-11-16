---@module "mosaic.tabs"
---@author sravioli
---@license GNU-GPLv2

---The `format-tab-title` handler. The preset (or user) `tabs.format` builds
---the cell as segments; this module formats them, reports the cell width to
---the budget, and supplies the title through `tabs.title`.

local badges = require "mosaic.tabs.badges"
local budget = require "mosaic.engine.budget"
local config = require "mosaic.engine.config"
local content = require "mosaic.tabs.content"
local deps = require "mosaic.engine.deps"
local palette = require "mosaic.engine.palette"
local paths = require "mosaic.engine.paths"

local ribbon = deps.ribbon
local str = deps.warp.string

local M = {}

---Default title: the tab title, else the active pane title, cut to fit.
---@param  tab        table   TabInformation
---@param  max_cells  integer
---@return string
function M.default_title(tab, max_cells)
  local title = (tab.tab_title and #tab.tab_title > 0) and tab.tab_title
    or (tab.active_pane and tab.active_pane.title)
    or ""
  title = paths.clean(title)
  if str.fits(title, max_cells) then
    return title
  end
  if max_cells <= 1 then
    return ""
  end
  return str.truncate("right", title, max_cells)
end

---@param tab       table
---@param tabs      table[]
---@param _panes    table[]
---@param cfg       table   effective config
---@param hover     boolean
---@param max_width integer
---@return string|nil
function M.format(tab, tabs, _panes, cfg, hover, max_width)
  local opts = config.live.tabs
  if not opts or not opts.format or cfg.enable_tab_bar == false then
    return nil
  end
  budget.use(tab.window_id)
  local unseen = false
  for _, p in ipairs(tab.panes or {}) do
    if p.has_unseen_output then
      unseen = true
      break
    end
  end

  local title_fn = opts.title or M.default_title
  local style, icon = content.apply_rules(opts.rules, tab, opts.style or {})
  local badge = badges.badge(tab.panes or { tab.active_pane }, tab.is_active)
  if badge then
    style = content.merge(style, badges.style(badge))
  end
  ---@class Mosaic.TabContext
  local ctx = {
    tab = tab,
    tabs = tabs,
    theme = palette.composite(palette.scheme(cfg, cfg.color_scheme), cfg),
    config = cfg,
    hover = hover,
    max_width = max_width,
    state = tab.is_active and "active" or hover and "hover" or "inactive",
    unseen = unseen,
    badge = badge, -- badge of an inactive tab, if any
    style = style, -- `tabs.style` with the matching `tabs.rules`, read by the presets
    icon = icon, -- from the matching rules, for the `icon` component
  }

  local list = opts.content
  if type(list) == "table" and (list.active or list.inactive) then
    list = tab.is_active and (list.active or list.inactive) or (list.inactive or list.active)
  end
  local function inner(max_cells)
    if type(list) == "table" then
      return content.compose(list, ctx, max_cells, title_fn)
    end
    return title_fn(tab, max_cells)
  end
  local pad_l, pad_r = 0, 0
  if type(style.padding) == "table" then
    pad_l, pad_r = style.padding.left or 0, style.padding.right or 0
  elseif type(style.padding) == "number" then
    pad_l, pad_r = style.padding, style.padding
  end
  ---@param  max_cells integer
  ---@return string
  function ctx.title(max_cells)
    max_cells = math.max(0, max_cells)
    if pad_l + pad_r == 0 then
      return inner(max_cells)
    end
    local body = inner(math.max(0, max_cells - pad_l - pad_r))
    return (" "):rep(pad_l) .. body .. (" "):rep(pad_r)
  end

  local segments = opts.format(ctx)
  local cell = ribbon:new "MosaicTab"
  local width = 0
  -- An unset bg is transparent in WezTerm: draw it on the bar instead.
  local bar = palette.bar_bg(ctx.theme, cfg)
  if cfg.use_fancy_tab_bar then
    return M.fancy(ctx, segments, bar)
  end
  for _, seg in ipairs(segments) do
    local text = seg[3] or ""
    cell:append(seg[1] or bar, seg[2], text, seg[4])
    width = width + str.width(text)
  end

  budget.record(tab.tab_index, width)
  budget.set_count(#tabs)
  return cell:format()
end

-- Columns the fancy tab chrome adds around a title (padding, close button).
local FANCY_CHROME = 4

---Fancy tab bar: WezTerm draws the tab and tints all of it from the first
---cell's colours, so the preset's shapes cannot apply. Keep its colours: the
---title in the colours of the preset's widest segment (its title), and
---report the width.
---@param  ctx      Mosaic.TabContext
---@param  segments table[] the preset's cell
---@param  bar      string|nil bar colour, for segments without a background
---@return string
function M.fancy(ctx, segments, bar)
  local main, widest = nil, -1
  for _, seg in ipairs(segments) do
    local w = str.width(seg[3] or "")
    if w > widest then
      main, widest = seg, w
    end
  end
  main = main or {}
  local title = " " .. ctx.title(ctx.max_width - 2) .. " "
  local cell = ribbon:new "MosaicFancyTab"
  cell:append(main[1] or bar, main[2], title, main[4])
  budget.record(ctx.tab.tab_index, str.width(title) + FANCY_CHROME)
  budget.set_count(#ctx.tabs)
  return cell:format()
end

---Set `cfg.tab_bar_style.new_tab` / `new_tab_hover` from `tabs.new_tab`, so
---the button follows the preset. A no-op without one, or with `tabs = false`.
---@param cfg   table  config being built
---@param theme table  colour scheme the button is drawn in
function M.new_tab_button(cfg, theme)
  local opts = config.live.tabs
  if not opts or not opts.new_tab or not theme then
    return
  end
  theme = palette.composite(theme, cfg)
  cfg.tab_bar_style = cfg.tab_bar_style or {}
  for state, hover in pairs { new_tab = false, new_tab_hover = true } do
    local cell = ribbon:new "MosaicNewTab"
    local ctx = {
      theme = theme,
      config = cfg,
      hover = hover,
      state = hover and "hover" or "inactive",
      style = opts.style or {},
    }
    for _, seg in ipairs(opts.new_tab(ctx)) do
      cell:append(seg[1] or palette.bar_bg(theme, cfg), seg[2], seg[3] or "", seg[4])
    end
    cfg.tab_bar_style[state] = cell:format()
  end
end

return M
