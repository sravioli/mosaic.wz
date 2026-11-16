---@module "mosaic.engine.render.decorate"
---@author sravioli
---@license GNU-GPLv2

---Preset decoration: the decorator call, the options that must win over it,
---edge context and group positions.

-- Live options table. `mosaic.config.setup()` updates it in place.
local Opts = require("mosaic.engine.config").live ---@class Mosaic.Options

local M = require "mosaic.engine.render.state"

---Shallow copy of a table.
---@param  t table
---@return table
function M.copy(t)
  local out = {}
  for k, v in pairs(t) do
    out[k] = v
  end
  return out
end

---Copy of `module` padded by one column inside its icon/text, styled like
---them, instead of by module padding, which is drawn unstyled (transparent).
---@param  module table
---@return table
function M.pad_inside(module)
  local out = M.copy(module)
  out.padding = nil
  local order = (module.icon and module.icon.position == "right") and { "text", "icon" }
    or { "icon", "text" }
  local shown = {}
  for _, key in ipairs(order) do
    local node = module[key]
    if node and node.enabled ~= false then
      shown[#shown + 1] = key
    end
  end
  for i, key in ipairs(shown) do
    local node = module[key]
    local l, r = M.get_padding(node.padding)
    local copy = M.copy(node)
    copy.padding = {
      left = math.max(l or 0, i == 1 and 1 or 0),
      right = math.max(r or 0, i == #shown and 1 or 0),
    }
    out[key] = copy
  end
  return out
end

---Let the preset (or user) style a module that does not style itself.
---Modules with their own `style` or a raw `layout` are left untouched.
---Modules in the user's `style.raw` skip the decorator: their colour as text
---on the bar's background, padded, without separators.
---@param  module Mosaic.Module
---@param  name   string
---@param  ctx    table  side, group, index and count among the group's
---                       enabled modules, names (those modules, in order),
---                       first/last (outermost enabled module on its side)
---@return Mosaic.Module
local decorate_with
local with_between

---The user's `options[name]` padding and separators, which the preset's
---decorator would otherwise replace, applied over its result.
---@param  module Mosaic.Module decorated
---@param  name   string
---@return Mosaic.Module
local function late_options(module, name)
  local out = module
  for _, n in ipairs(M.option_names(name)) do
    local opts = Opts.options and Opts.options[n]
    local icon_color = type(opts) == "table" and type(opts.icon) == "table" and opts.icon.color
    if type(opts) == "table" and (opts.padding ~= nil or opts.sep ~= nil or icon_color) then
      if out == module then
        out = M.copy(module)
      end
      if opts.padding ~= nil then
        out.padding = opts.padding
      end
      if icon_color and type(out.icon) == "table" then
        local icon = M.merge(out.icon, {})
        icon.style = function(theme, parent)
          return {
            fg = require("mosaic.engine.palette").resolve(theme, icon_color),
            bg = parent and parent.bg,
            attributes = parent and parent.attributes,
          }
        end
        out.icon = icon
      end
      if opts.sep == false then
        out.sep = nil
      elseif type(opts.sep) == "table" then
        out.sep = type(out.sep) == "table" and M.merge(out.sep, opts.sep) or opts.sep
      end
    end
  end
  return out
end

local function decorate(module, name, ctx)
  return late_options(decorate_with(module, name, ctx), name)
end

decorate_with = function(module, name, ctx)
  local fn = Opts.decorate
  local style = M.style or Opts.style or {}
  if not fn or module.style ~= nil or module.layout ~= nil then
    return module
  end
  ctx.name, ctx.theme, ctx.config, ctx.style = name, M.theme, M.config, style
  if (style.raw or {})[name] then
    local palette = require "mosaic.engine.palette"
    local out = M.copy(module)
    -- Explicit bar colour: an unset bg reaches WezTerm as transparent, which
    -- shows the lighter terminal background instead of the bar.
    local look = { fg = palette.color(ctx, module), bg = palette.bar_bg(M.theme, M.config) }
    out.style = function()
      return look
    end
    out.sep = nil
    return M.pad_inside(out)
  end
  return fn(module, ctx) or module
end
M.decorate = decorate

---Decorate context whose `last` is computed on first read, by `last_fn`.
---@param  ctx      table
---@param  last_fn? fun(): boolean
---@return table
local function edge_ctx(ctx, last_fn)
  return setmetatable(ctx, {
    __index = function(t, key)
      if key == "last" then
        local v = last_fn and last_fn() or false
        rawset(t, "last", v)
        return v
      end
    end,
  })
end

---Copy of a decorated module with `glyph` drawn before it: inside its
---leading separator when it has one, else as one in the dim colour on the
---bar, so the fitter counts its width.
---@param  module Mosaic.Module
---@param  glyph  string
---@return Mosaic.Module
with_between = function(module, glyph)
  local out = M.merge(module, {})
  local sep = type(module.sep) == "table" and module.sep.enabled ~= false and module.sep or nil
  if sep then
    local value = sep.value
    if type(value) == "string" then
      value = { right = value, left = value }
    end
    out.sep = M.merge(
      sep,
      { value = M.merge(value or {}, { right = glyph .. ((value or {}).right or "") }) }
    )
    return out
  end
  local palette = require "mosaic.engine.palette"
  local dim = palette.resolve(M.theme, (M.style or {}).dim or 9)
  out.sep = {
    enabled = true,
    value = { right = glyph },
    style = function(theme)
      return { fg = dim, bg = palette.bar_bg(theme, M.config) }
    end,
  }
  return out
end

---Enabled modules of a group, decorated with their position among them, so
---positional styles (a gradient, chained separators) skip disabled modules.
---@param  names string[]
---@return { idx: integer, name: string, module: Mosaic.Module }[]
local function enabled_group(names)
  local items = {}
  for idx, name in ipairs(names) do
    local module = M.resolve_module(name)
    if M.enabled(module) then
      items[#items + 1] = { idx = idx, name = name, module = module }
    end
  end
  local shown, specs = {}, {}
  for k, item in ipairs(items) do
    shown[k], specs[k] = item.name, item.module
  end
  local edge = M.edge or {}
  local between = ((M.style or {}).separators or {}).between
  for k, item in ipairs(items) do
    item.module = decorate(
      item.module,
      item.name,
      edge_ctx({
        side = M.side,
        group = true,
        index = k,
        count = #items,
        names = shown,
        specs = specs, -- undecorated, aligned with names
        first = edge.first == true and k == 1,
      }, k == #items and edge.last)
    )
    if between and k > 1 then
      item.module = with_between(item.module, between)
    end
  end
  return items
end

M.enabled_group = enabled_group
M.edge_ctx = edge_ctx

return M
