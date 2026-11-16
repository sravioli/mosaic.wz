---@module "mosaic.engine.render.cell"
---@author sravioli
---@license GNU-GPLv2

---One module's cell: widths, node styles, separators, render modes and
---assembly into a Ribbon.

local conditions = require "mosaic.engine.conditions"
local deps = require "mosaic.engine.deps"
local wt = require "wezterm" ---@class Wezterm
local ribbon = deps.ribbon
local warp = deps.warp
local merge = warp.table.merge
local str = warp.string ---@class Warp.String

-- Direct binding to the Rust function. This bypasses the ANSI-stripping regex in
-- str.width, which is safe here because this layer only measures plain text:
-- icons, separators, padding, and resolved node values. Use str.width for
-- strings that may contain ANSI codes, such as resolve_layout output.
local raw_cw = wt.column_width
local find = string.find

-- Live options table; `mosaic.config.setup()` updates it in place.
local Opts = require("mosaic.engine.config").live ---@class Mosaic.Options
local log = require "mosaic.engine.logger"

local M = require "mosaic.engine.render.state"

-- Reusable Ribbon cell for assemble_cell. It avoids one Ribbon allocation per
-- cell render and is cleared with :clear() before each use.
local _cell = ribbon:new "Cell"

-- ---------------------------------------------------------------------------
-- Width utilities
-- ---------------------------------------------------------------------------

---@param s string
---@return integer
local function visible_width(s)
  if not s or s == "" then
    return 0
  end
  return raw_cw(s)
end

---@param s        string
---@param max_cols integer
---@param ellipsis? string
---@return string
local function truncate(s, max_cols, ellipsis)
  ellipsis = ellipsis or "…"
  if max_cols <= 0 then
    return ""
  end
  local width = (find(s, "\27", 1, true) or find(ellipsis, "\27", 1, true)) and str.width
    or visible_width
  if width(s) <= max_cols then
    return s
  end

  local ew = width(ellipsis)
  local result, w = {}, 0
  for cp in s:gmatch "[^\128-\191][\128-\191]*" do
    local cpw = width(cp)
    if w + cpw + ew > max_cols then
      break
    end
    result[#result + 1] = cp
    w = w + cpw
  end
  return table.concat(result) .. ellipsis
end

-- ---------------------------------------------------------------------------
-- Style / node helpers
-- ---------------------------------------------------------------------------

---@param mod Mosaic.Module|Mosaic.Module.Component|nil
---@return boolean
M.enabled = function(mod)
  return mod ~= nil
    and mod.enabled == true
    and conditions.predicate(mod.cond, M.window, M.pane) == true
end

M.style_node = function(node, parent_style)
  local style = parent_style or {}

  if node.invert_bg_fg then
    style = { fg = style.bg, bg = style.fg }
  end

  if not node.style then
    return style
  end

  local typ = type(node.style)
  if typ == "function" then
    return node.style(M.theme, style)
  end
  if typ == "table" then
    return merge({ behavior = "force", combine = true }, node.style, style)
  end
  return style
end

M.resolve_node = function(node)
  if not node or not node.enabled then
    return ""
  end

  local value = type(node.value) == "function" and node.value(M.window, M.pane) or node.value
  local typ = type(value)

  if typ == "table" then
    return value
  end
  return str.pad(value, node.padding or 0)
end

M.prepare_node = function(node, parent_style)
  node = node or ""
  return M.resolve_node(node), M.style_node(node, parent_style)
end

M.get_padding = function(padding)
  if type(padding) == "table" then
    return padding.left, padding.right
  end
  return padding, padding
end

---The bar's surface colour, for cells that set no background: an unset bg
---reaches WezTerm as transparent, which shows the terminal background (often
---lighter than the bar) instead of the bar.
---@return string
function M.surface()
  return require("mosaic.engine.palette").bar_bg(M.theme, M.config)
end

M.add_padding = function(cell, padding, _style)
  if padding then
    cell:append(M.surface(), nil, string.rep(" ", padding), nil)
  end
end

M.add_separator = function(cell, sep, style)
  if sep then
    cell:append(style.bg or M.surface(), style.fg, sep, style.attributes)
  end
end

-- ---------------------------------------------------------------------------
-- Sep normalisation
-- ---------------------------------------------------------------------------

--- Normalise a raw sep value into `{ left, right }`.
---@param raw any
---@return { left: string|nil, right: string|nil }
local function normalise_sep_value(raw)
  if type(raw) == "function" then
    raw = raw(M.window, M.pane)
  end
  if type(raw) == "table" then
    return { left = raw.left, right = raw.right }
  end
  return { left = raw or nil, right = nil }
end

---@param node Mosaic.Module.Sep|nil
---@param parent_style table
---@return { left: string|nil, right: string|nil }
---@return table style
M.prepare_sep = function(node, parent_style)
  local style = M.style_node(node or {}, parent_style)
  if not node or not node.enabled then
    return { left = nil, right = nil }, style
  end
  return normalise_sep_value(node.value), style
end

-- ---------------------------------------------------------------------------
-- Flexible cell rendering
-- ---------------------------------------------------------------------------

---@alias CellRenderMode "full"|"trim"|"text"|"icon"
local RENDER_MODES = { "full", "trim", "text", "icon" }

--- Per-mode content resolvers.
--- Each returns `(render_icon, render_text)` or `nil` when the mode is inapplicable/overflows.
-- luacheck: push ignore 631
---@type table<CellRenderMode, fun(icon:string, text:string, has_icon:boolean, has_text:boolean, avail_cols:integer|nil, overhead:integer): string|nil, string|nil>
local CONTENT_RESOLVERS = {
  -- luacheck: pop
  full = function(icon, text, _, _)
    return icon, text
  end,

  trim = function(icon, text, _, has_text, avail_cols, overhead)
    if not has_text then
      return icon, ""
    end
    local room = (avail_cols or math.huge) - overhead - visible_width(icon)
    local trimmed = truncate(text, room)
    if trimmed == "" then
      return nil
    end
    return icon, trimmed
  end,

  text = function(_, text, has_icon, has_text)
    if not has_icon or not has_text then
      return nil
    end
    return "", text
  end,

  icon = function(icon, _, has_icon, has_text)
    if not has_icon or not has_text then
      return nil
    end
    return icon, ""
  end,
}

--- Gather the raw icon/text strings and their styles for a module.
---@param module Mosaic.Module
---@param style  table
---@return string icon_val, table icon_style, string text_val, table text_style
local function resolve_module_content(module, style)
  local icon_val, icon_style = "", style
  local text_val, text_style = "", style
  if module.icon then
    icon_val, icon_style = M.prepare_node(module.icon, style)
  end
  if module.text then
    text_val, text_style = M.prepare_node(module.text, style)
  end
  return icon_val, icon_style, text_val, text_style
end

--- Compute the fixed overhead (padding + separators) for a module.
---@param module Mosaic.Module
---@param sep    { left: string|nil, right: string|nil }
---@return integer pad_left, integer pad_right, integer overhead
local function compute_overhead(module, sep)
  local pad_left, pad_right = M.get_padding(module.padding)
  local overhead = (pad_left or 0)
    + (pad_right or 0)
    + (sep.left and visible_width(sep.left) or 0)
    + (sep.right and visible_width(sep.right) or 0)
  return pad_left, pad_right, overhead
end

--- Assemble a Ribbon cell from pre-resolved content.
---
--- Uses the module-level `_cell` instance (cleared on each call) to avoid
--- allocating a new Ribbon per cell render.
---@param module       Mosaic.Module
---@param render_icon  string
---@param render_text  string
---@param icon_style   table
---@param text_style   table
---@param sep          { left: string|nil, right: string|nil }
---@param sep_style    table
---@param pad_left     integer|nil
---@param pad_right    integer|nil
---@param style        table
---@return string
local function assemble_cell(
  module,
  render_icon,
  render_text,
  icon_style,
  text_style,
  sep,
  sep_style,
  pad_left,
  pad_right,
  style
)
  _cell:clear()
  local icon_pos = (module.icon and module.icon.position) or "left"

  M.add_padding(_cell, pad_left, style)
  M.add_separator(_cell, sep.right, sep_style)

  ---@param value string
  ---@param st    table
  local function put(value, st)
    if value ~= "" then
      _cell:append(st.bg or M.surface(), st.fg, value, st.attributes)
      -- Attributes persist in WezTerm until reset, e.g. italic text would
      -- carry into the closing separator.
      if st.attributes then
        _cell:reset_attributes()
      end
    end
  end
  if icon_pos == "right" then
    put(render_text, text_style)
    put(render_icon, icon_style)
  else
    put(render_icon, icon_style)
    put(render_text, text_style)
  end

  M.add_separator(_cell, sep.left, sep_style)
  M.add_padding(_cell, pad_right, style)

  return _cell:format()
end

-- ---------------------------------------------------------------------------
-- Pre-resolved cell parts
-- ---------------------------------------------------------------------------

--- Pre-compute the mode-invariant parts of a module's cell rendering.
--- Called once per module; the result is passed to `build_cell_from_parts`
--- for each render-mode trial - avoiding redundant style / content / sep
--- resolution per mode.
---@param module Mosaic.Module
---@return table parts
local function resolve_cell_parts(module)
  local style = M.style_node(module, M.default_style)
  local icon_val, icon_style, text_val, text_style = resolve_module_content(module, style)
  local sep, sep_style = M.prepare_sep(module.sep, style)
  local pad_left, pad_right, overhead = compute_overhead(module, sep)
  return {
    style = style,
    has_icon = module.icon ~= nil,
    has_text = module.text ~= nil,
    icon_val = icon_val,
    icon_style = icon_style,
    text_val = text_val,
    text_style = text_style,
    sep = sep,
    sep_style = sep_style,
    pad_left = pad_left,
    pad_right = pad_right,
    overhead = overhead,
  }
end

--- Build a cell from pre-resolved parts for a specific render mode.
--- Returns `("", -1)` when the mode is inapplicable or exceeds the budget.
---@param module     Mosaic.Module
---@param parts      table
---@param mode       CellRenderMode
---@param avail_cols integer|nil
---@return string formatted
---@return integer width
local function build_cell_from_parts(module, parts, mode, avail_cols)
  local render_icon, render_text = CONTENT_RESOLVERS[mode](
    parts.icon_val,
    parts.text_val,
    parts.has_icon,
    parts.has_text,
    avail_cols,
    parts.overhead
  )

  if render_icon == nil then
    return "", -1
  end

  local total_w = parts.overhead + visible_width(render_icon) + visible_width(render_text)
  if avail_cols and total_w > avail_cols then
    return "", -1
  end

  local formatted = assemble_cell(
    module,
    render_icon,
    render_text,
    parts.icon_style,
    parts.text_style,
    parts.sep,
    parts.sep_style,
    parts.pad_left,
    parts.pad_right,
    parts.style
  )
  return formatted, total_w
end

-- ---------------------------------------------------------------------------

--- Render only the separator (and padding) for a module, with no icon or text.
--- Used as the last-resort candidate for `can_hide` modules so the colour
--- chain between adjacent cells is preserved even when content is dropped.
---
---@param  module Mosaic.Module
---@param  parts  table              pre-resolved cell parts
---@return string formatted
---@return integer width   0 when the module has no separator to show
local function build_cell_sep_only(module, parts)
  if not parts.sep.left and not parts.sep.right then
    return "", 0
  end

  local formatted = assemble_cell(
    module,
    "",
    "",
    parts.style,
    parts.style,
    parts.sep,
    parts.sep_style,
    parts.pad_left,
    parts.pad_right,
    parts.style
  )
  return formatted, parts.overhead
end

--- Attempt to build a cell for the given mode within `avail_cols`.
--- Convenience wrapper that resolves parts internally - use
--- `resolve_cell_parts` + `build_cell_from_parts` when calling in a loop.
---@param module     Mosaic.Module
---@param mode       CellRenderMode
---@param avail_cols integer|nil
---@return string formatted
---@return integer width
local function build_cell(module, mode, avail_cols)
  return build_cell_from_parts(module, resolve_cell_parts(module), mode, avail_cols)
end

--- Walk the fallback chain and return the first mode that fits.
--- Resolve cell parts once, then reuse them for every mode trial.
---@param name       string
---@param module     Mosaic.Module
---@param avail_cols integer
---@return string formatted
---@return integer width
local function build_cell_flexible(name, module, avail_cols)
  local parts = resolve_cell_parts(module)
  for _, mode in ipairs(RENDER_MODES) do
    local result, w = build_cell_from_parts(module, parts, mode, avail_cols)
    if w >= 0 then
      log:debug("[%s] mode: %-4s  used: %d/%d  cell: %s", name, mode, w, avail_cols, result)
      return result, w
    end
  end

  if module.can_hide then
    log:debug("[%s] hidden - no space remaining", name)
    return "", 0
  end

  -- Last resort: force icon-only even when it exceeds the budget.
  local result, w = build_cell_from_parts(module, parts, "icon", nil)
  log:debug("[%s] forced icon-only  width: %d  cell: %s", name, w, result)
  return result, math.max(w, 0)
end

--- Format a single cell.
--- When `Opts.flexible` and `avail_cols` are both set the fallback chain is
--- applied; otherwise the cell is rendered in "full" mode without a budget check.
---
---@param name       string
---@param module     Mosaic.Module
---@param avail_cols integer|nil
---@return string formatted
---@return integer width
M.format_cell = function(name, module, avail_cols)
  log:debug(
    "[%s] icon: %s\ttext: %s",
    name,
    module.icon and tostring(module.icon.value) or "-",
    module.text and tostring(module.text.value) or "-"
  )

  if not Opts.flexible or not avail_cols then
    local result, w = build_cell(module, "full", nil)
    log:debug("[%s] cell: %s", name, result)
    return result, w
  end

  return build_cell_flexible(name, module, avail_cols)
end

M.visible_width = visible_width
M.truncate = truncate
M.RENDER_MODES = RENDER_MODES
M.resolve_cell_parts = resolve_cell_parts
M.build_cell_from_parts = build_cell_from_parts
M.build_cell_sep_only = build_cell_sep_only
M.assemble_cell = assemble_cell

return M
