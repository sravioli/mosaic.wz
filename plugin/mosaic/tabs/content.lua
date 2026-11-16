---@module "mosaic.tabs.content"
---@author sravioli
---@license GNU-GPLv2

---Tab text composed from components (`tabs.content`) and per-tab rules
---(`tabs.rules`). Components read TabInformation / PaneInformation fields
---only, so nothing here blocks the GUI thread.
---
---shortcut: content is plain text drawn in the preset's title colours, no
---per-component colours (the preset owns the cell); add segment output if
---users ask for coloured parts.

local wezterm = require "wezterm"

local icons = require "mosaic.engine.icons"
local paths = require "mosaic.engine.paths"
local str = require("mosaic.engine.deps").warp.string

local nf = wezterm.nerdfonts

local M = {}

---@param  tab table TabInformation
---@return table PaneInformation
local function pane_of(tab)
  return tab.active_pane or {}
end

---@param  pane table PaneInformation
---@return string
local function process_name(pane)
  local path = pane.foreground_process_name or ""
  return (paths.basename(path):gsub("%.exe$", ""))
end

---@param  tab table
---@return string|nil
local function cwd_of(tab)
  return paths.info_cwd(pane_of(tab))
end

---Component name -> fun(tab, opts, ctx): string|nil
M.COMPONENTS = {
  process = function(tab, opts)
    local name = process_name(pane_of(tab))
    if name == "" then
      return nil
    end
    local glyph = icons.process(name, opts.icons)
    if opts.icon_only then
      return glyph or name
    end
    if opts.icon == false or not glyph or glyph == "" then
      return name
    end
    return glyph .. " " .. name
  end,
  cwd = function(tab, opts)
    local cwd = cwd_of(tab)
    if not cwd or cwd == "" then
      return nil
    end
    if opts.full then
      return paths.shorten(
        cwd,
        { home = opts.home or "~", aliases = opts.aliases, max_length = opts.max_length }
      )
    end
    return paths.shorten(paths.basename(cwd), { max_length = opts.max_length })
  end,
  parent = function(tab, opts)
    local parent = paths.parent(cwd_of(tab))
    if not parent or parent == "" then
      return nil
    end
    return paths.shorten(paths.basename(parent), { max_length = opts.max_length })
  end,
  zoomed = function(tab, opts)
    if not pane_of(tab).is_zoomed then
      return nil
    end
    return opts.icon or nf.md_magnify_plus_outline or "Z"
  end,
  output = function(tab, opts)
    for _, pane in ipairs(tab.panes or {}) do
      if pane.has_unseen_output then
        return opts.icon or nf.md_bell_ring_outline or "!"
      end
    end
    return opts.idle
  end,
  panes = function(tab, opts)
    local n = #(tab.panes or {})
    if n <= 1 then
      return nil
    end
    return (opts.icon or nf.md_view_split_vertical or "#") .. n
  end,
  progress = function(tab, opts)
    local ok, raw = pcall(function()
      return pane_of(tab).progress
    end)
    local p = ok and require("mosaic.engine.progress").read(raw) or nil
    if not p then
      return nil
    end
    local progress = require "mosaic.engine.progress"
    local text = progress.text(p)
    if opts.icon == false then
      return text ~= "" and text or nil
    end
    if opts.icon_only or text == "" then
      return progress.glyph(p)
    end
    return progress.glyph(p) .. " " .. text
  end,
  domain = function(tab, opts)
    local name = pane_of(tab).domain_name
    if not name or (name == "local" and not opts.show_local) then
      return nil
    end
    local glyph = icons.domain(name, opts.icons)
    if opts.icon_only then
      return glyph or name
    end
    return glyph and (glyph .. " " .. name) or name
  end,
  icon = function(_, opts, ctx)
    return ctx.icon or opts.default
  end,
}

---Normalize one `tabs.content` item.
---@param  item any
---@return { kind: string, name?: string, opts: table, value?: any }
local function parse(item)
  if type(item) == "function" then
    return { kind = "fn", opts = {}, value = item }
  end
  if type(item) == "table" then
    return { kind = "component", name = item[1], opts = item }
  end
  if M.COMPONENTS[item] or item == "title" then
    return { kind = "component", name = item, opts = {} }
  end
  return { kind = "literal", opts = {}, value = tostring(item) }
end

---Join evaluated pieces: one space between two components, none around
---literal strings, so `{ "parent", "/", "cwd" }` reads `src/mosaic`.
---@param  pieces { text: string, literal: boolean }[]
---@return string
local function join(pieces)
  local out = {}
  for i, p in ipairs(pieces) do
    local prev = pieces[i - 1]
    if prev and not prev.literal and not p.literal then
      out[#out + 1] = " "
    end
    out[#out + 1] = p.text
  end
  return table.concat(out)
end

---Compose the title text for a tab from `list`, within `max` columns.
---Components right of the title are dropped first, then the title is cut.
---@param  list     any[]   `tabs.content` items
---@param  ctx      table   tab context (`tab`, `icon`)
---@param  max      integer
---@param  title_fn fun(tab: table, max: integer): string
---@return string
function M.compose(list, ctx, max, title_fn)
  local pieces, title_at = {}, nil
  for _, raw in ipairs(list) do
    local item = parse(raw)
    if item.kind == "component" and item.name == "title" then
      pieces[#pieces + 1] = { text = "", literal = false, title = true }
      title_at = #pieces
    else
      local text
      if item.kind == "literal" then
        text = item.value
      elseif item.kind == "fn" then
        text = item.value(ctx.tab, ctx)
      elseif M.COMPONENTS[item.name] then
        text = M.COMPONENTS[item.name](ctx.tab, item.opts, ctx)
      end
      if text ~= nil and text ~= "" then
        pieces[#pieces + 1] = { text = tostring(text), literal = item.kind == "literal" }
      end
    end
  end

  local function width()
    return str.width(join(pieces))
  end
  -- Leave the title at least a few columns before giving up components.
  local reserve = title_at and math.min(4, max) or 0
  while width() > max - reserve and #pieces > (title_at and 1 or 0) do
    local drop
    for i = #pieces, 1, -1 do
      if not pieces[i].title then
        drop = i
        break
      end
    end
    if not drop then
      break
    end
    table.remove(pieces, drop)
  end

  for _, p in ipairs(pieces) do
    if p.title then
      p.text = "x" -- measure the rest with a one-column title
      local room = max - (width() - 1)
      p.text = room > 0 and title_fn(ctx.tab, room) or ""
      if p.text == "" then
        p.literal = true -- no stray separator around an empty title
      end
    end
  end
  local text = join(pieces)
  if str.width(text) > max then
    text = max > 1 and str.truncate("right", text, max) or ""
  end
  return text
end

-- ── Rules ───────────────────────────────────────────────────────────────────

---@param  want  any string (exact), { pattern = "" }, or fun(value): boolean
---@param  value string|nil
---@return boolean
local function test(want, value)
  if want == nil then
    return true
  end
  if value == nil then
    return false
  end
  if type(want) == "function" then
    return want(value) == true
  end
  if type(want) == "table" and want.pattern then
    return value:find(want.pattern) ~= nil
  end
  return value == want
end

---@param  match table
---@param  tab   table
---@return boolean
local function matches(match, tab)
  local pane = pane_of(tab)
  if not test(match.domain, pane.domain_name) then
    return false
  end
  if match.cwd ~= nil and not test(match.cwd, cwd_of(tab)) then
    return false
  end
  if match.process ~= nil and not test(match.process, process_name(pane)) then
    return false
  end
  if match.title ~= nil then
    local title = (tab.tab_title and #tab.tab_title > 0) and tab.tab_title or pane.title
    if not test(match.title, title) then
      return false
    end
  end
  local var = match.user_var
  if var ~= nil then
    local found = false
    for _, p in ipairs(tab.panes or { pane }) do
      local value = (p.user_vars or {})[var.name or var[1]]
      if
        value ~= nil
        and test(var.value or var[2] or function()
          return true
        end, value)
      then
        found = true
        break
      end
    end
    if not found then
      return false
    end
  end
  return true
end

local merge = require("mosaic.engine.render.resolve").merge
M.merge = merge

---The tab's style and icon after the rules that match it, in order.
---@param  rules table[]|nil
---@param  tab   table
---@param  style table
---@return table style, string|nil icon
function M.apply_rules(rules, tab, style)
  local icon
  for _, rule in ipairs(rules or {}) do
    if matches(rule.match or {}, tab) then
      if rule.style then
        style = merge(style, rule.style)
      end
      if rule.icon ~= nil then
        icon = rule.icon or nil
      end
    end
  end
  return style, icon
end

return M
