---@module "mosaic.engine.render.fit"
---@author sravioli
---@license GNU-GPLv2

---Group fitting: the greedy, balanced and exhaustive strategies.

-- Live options table. `mosaic.config.setup()` updates it in place.
local Opts = require("mosaic.engine.config").live ---@class Mosaic.Options
local log = require "mosaic.engine.logger"

local M = require "mosaic.engine.render.state"
require "mosaic.engine.render.cell"
require "mosaic.engine.render.decorate"

local visible_width, truncate = M.visible_width, M.truncate
local RENDER_MODES = M.RENDER_MODES
local resolve_cell_parts, build_cell_from_parts = M.resolve_cell_parts, M.build_cell_from_parts
local build_cell_sep_only, assemble_cell = M.build_cell_sep_only, M.assemble_cell
local enabled_group = M.enabled_group
--- For a group of module names, greedily pick the widest representation of
--- each module that fits within the remaining budget (left-to-right).
--- O(n × m) where n = modules and m = render modes, instead of O(m^n).
---
---@param  names      string[]
---@param  avail_cols integer
---@return string     formatted
---@return integer    consumed
local function render_group_greedy(names, avail_cols)
  local remaining = avail_cols
  local components = {}
  local total_used = 0

  for _, item in ipairs(enabled_group(names)) do
    local module = item.module
    do
      local parts = resolve_cell_parts(module)
      local best_fmt, best_w = "", -1

      -- Try modes from widest to narrowest; first fit wins.
      for _, mode in ipairs(RENDER_MODES) do
        local result, w = build_cell_from_parts(module, parts, mode, remaining)
        if w >= 0 then
          best_fmt, best_w = result, w
          break
        end
      end

      -- can_hide fallback: separator only
      if best_w < 0 and module.can_hide then
        best_fmt, best_w = build_cell_sep_only(module, parts)
      end

      if best_w >= 0 then
        components[#components + 1] = best_fmt
        remaining = remaining - best_w
        total_used = total_used + best_w
      end
    end
  end

  if #components == 0 then
    log:debug("[group] nothing fits in %d cols", avail_cols)
    return "", 0
  end

  log:debug("[group] greedy fit  used: %d/%d", total_used, avail_cols)
  return table.concat(components), total_used
end

-- ── Group fitting: balanced / exhaustive ─────────────────────────────────────

local DEFAULT_MIN_TEXT = 5
local INFO_EPS = 1e-6
-- A truncated text is worth less than its length suggests (the ellipsis and the
-- cut-off part hide the identity of the value).
local TRIM_PENALTY = 0.25

---@param  t    integer shown text columns (ellipsis included)
---@param  full integer full text columns
---@return number
local function trim_info(t, full)
  return math.max(0, (t - 1) / full - TRIM_PENALTY)
end

---@class GroupCandidate
---@field fmt   string
---@field w     integer  total columns
---@field texty boolean  shows (part of) the text
---@field info  number   fraction of the full text conveyed (0..1)

---@class GroupTrim
---@field base integer  columns used by everything except the text
---@field min  integer  minimum text columns
---@field max  integer  maximum text columns (one less than the full text)
---@field full integer  full text columns

---@class GroupEntry
---@field name     string
---@field module   Mosaic.Module
---@field parts    table
---@field icon     string
---@field text     string
---@field index    integer
---@field priority number
---@field cands    GroupCandidate[]  fixed-width forms, widest first
---@field trim     GroupTrim|nil     variable-width truncated form
---@field min      GroupCandidate
---@field hidden   GroupCandidate
---@field cur      GroupCandidate
---@field visible  boolean

--- Resolve `text.variants` (shorter alternatives, longest first) to padded strings.
---@param  node Mosaic.Module.Text|nil
---@return string[]
local function resolve_variants(node)
  local out = {}
  if not node or not node.enabled or type(node.variants) ~= "table" then
    return out
  end
  for _, v in ipairs(node.variants) do
    local s = M.resolve_node { enabled = true, value = v, padding = node.padding }
    if type(s) == "string" and s ~= "" then
      out[#out + 1] = s
    end
  end
  return out
end

---@param  e GroupEntry
---@param  t integer text columns
---@return GroupCandidate
local function build_trim(e, t)
  local text = truncate(e.text, t)
  return {
    icon = e.icon,
    text = text,
    w = e.trim.base + visible_width(text),
    texty = true,
    info = trim_info(t, e.trim.full),
  }
end

--- Resolve every enabled module of a group into its candidate forms: full,
--- shorter `text.variants`, icon-only, a variable-width truncation (unless
--- `text.trim == false`) and hidden.
---@param  names string[]
---@return GroupEntry[]
local function collect_entries(names)
  local entries = {}
  for _, item in ipairs(enabled_group(names)) do
    local idx, name, module = item.idx, item.name, item.module
    do
      local parts = resolve_cell_parts(module)
      local icon = type(parts.icon_val) == "string" and parts.icon_val or ""
      local text = type(parts.text_val) == "string" and parts.text_val or ""
      local has_icon, has_text = icon ~= "", text ~= ""
      local full_w = visible_width(text)

      local cands = {}
      local function add(i, t, info)
        cands[#cands + 1] = {
          icon = i,
          text = t,
          w = parts.overhead + visible_width(i) + visible_width(t),
          texty = t ~= "",
          info = info,
        }
      end

      if has_text then
        add(icon, text, 1)
        for _, v in ipairs(resolve_variants(module.text)) do
          local vw = visible_width(v)
          if vw < full_w then
            add(icon, v, vw / full_w)
          end
        end
      end
      if has_icon or not has_text then
        add(icon, "", 0)
      end
      table.sort(cands, function(a, b)
        if a.w ~= b.w then
          return a.w > b.w
        end
        return a.info > b.info
      end)

      local trim
      local min_text = module.min_text or DEFAULT_MIN_TEXT
      if has_text and module.text.trim ~= false and full_w - 1 >= min_text then
        trim = {
          base = parts.overhead + visible_width(icon),
          min = min_text,
          max = full_w - 1,
          full = full_w,
        }
      end

      local hidden
      if module.can_hide then
        local sep_only = parts.sep.left ~= nil or parts.sep.right ~= nil
        hidden = {
          fmt = not sep_only and "" or nil,
          sep_only = sep_only,
          w = sep_only and parts.overhead or 0,
          texty = false,
          info = 0,
        }
      else
        hidden = { fmt = "", w = 0, texty = false, info = 0 }
      end

      local entry = {
        name = name,
        module = module,
        parts = parts,
        icon = icon,
        text = text,
        index = idx,
        priority = module.priority or 0,
        cands = cands,
        trim = trim,
        min = cands[#cands],
        hidden = hidden,
        visible = true,
      }
      entry.cur = entry.min
      entry.has_text_candidate = has_text
      entries[#entries + 1] = entry
    end
  end
  return entries
end

---@param  entries GroupEntry[]
---@return integer
local function entries_width(entries)
  local total = 0
  for _, e in ipairs(entries) do
    total = total + e.cur.w
  end
  return total
end

--- Hand leftover columns to visible modules by priority (desc), then layout
--- order. Each module takes its widest form that fits: full, a shorter
--- variant, or a truncation showing at least `min_text` text columns.
---@param  entries  GroupEntry[]
---@param  leftover integer
---@return integer  leftover
local function grow_entries(entries, leftover)
  local order = {}
  for _, e in ipairs(entries) do
    if e.visible then
      order[#order + 1] = e
    end
  end
  table.sort(order, function(a, b)
    if a.priority ~= b.priority then
      return a.priority > b.priority
    end
    return a.index < b.index
  end)

  for _, e in ipairs(order) do
    if leftover <= 0 then
      break
    end
    local limit = e.cur.w + leftover
    local best = e.cur
    for _, c in ipairs(e.cands) do
      if c.w <= limit then
        if c.w > best.w then
          best = c
        end
        break
      end
    end
    if e.trim then
      local t = math.min(e.trim.max, limit - e.trim.base)
      if t >= e.trim.min and e.trim.base + t > best.w then
        best = build_trim(e, t)
      end
    end
    leftover = leftover - (best.w - e.cur.w)
    e.cur = best
  end
  return leftover
end

---@param  entries GroupEntry[]
---@return string
local function join_entries(entries)
  local out = {}
  for _, e in ipairs(entries) do
    local candidate = e.cur
    if candidate.fmt == nil then
      if candidate.sep_only then
        candidate.fmt = build_cell_sep_only(e.module, e.parts)
      else
        candidate.fmt = assemble_cell(
          e.module,
          candidate.icon,
          candidate.text,
          e.parts.icon_style,
          e.parts.text_style,
          e.parts.sep,
          e.parts.sep_style,
          e.parts.pad_left,
          e.parts.pad_right,
          e.parts.style
        )
      end
    end
    if candidate.fmt ~= "" then
      out[#out + 1] = candidate.fmt
    end
  end
  return table.concat(out)
end

--- Shrink every module to its minimum before hiding anything. Modules are
--- hidden only when all minimums still overflow: `can_hide` modules first,
--- then lowest priority, then rightmost. Leftover space is redistributed by
--- priority.
---@param  entries    GroupEntry[]
---@param  avail_cols integer
---@return string     formatted
---@return integer    consumed
local function fit_balanced(entries, avail_cols)
  local total = entries_width(entries)
  local hide_order = {}
  for _, entry in ipairs(entries) do
    hide_order[#hide_order + 1] = entry
  end
  table.sort(hide_order, function(a, b)
    local a_hideable, b_hideable = a.module.can_hide == true, b.module.can_hide == true
    if a_hideable ~= b_hideable then
      return a_hideable
    end
    if a.priority ~= b.priority then
      return a.priority < b.priority
    end
    return a.index > b.index
  end)

  for _, victim in ipairs(hide_order) do
    if total <= avail_cols then
      break
    end
    victim.visible = false
    total = total - victim.cur.w + victim.hidden.w
    victim.cur = victim.hidden
    log:debug("[group] hiding %s", victim.name)
  end

  grow_entries(entries, avail_cols - total)
  local used = entries_width(entries)
  log:debug("[group] balanced fit  used: %d/%d", used, avail_cols)
  return join_entries(entries), used
end

--- Compare two ascending-sorted info vectors lexicographically (leximin).
---@param  a number[]
---@param  b number[]
---@return integer  1 when `a` is fairer, -1 when `b` is, 0 when equal
local function leximin_cmp(a, b)
  for k = 1, math.max(#a, #b) do
    local x, y = a[k] or -1, b[k] or -1
    if math.abs(x - y) > INFO_EPS then
      return x > y and 1 or -1
    end
  end
  return 0
end

---@param  names      string[]
---@param  avail_cols integer
---@return string     formatted
---@return integer    consumed
local function render_group_balanced(names, avail_cols)
  return fit_balanced(collect_entries(names), avail_cols)
end

-- Above this many form combinations the exhaustive search falls back to
-- `balanced`, bounding the worst-case frame time for large groups.
local EXHAUSTIVE_CAP = 4096
M.EXHAUSTIVE_CAP = EXHAUSTIVE_CAP

--- Search every combination of candidate forms and keep the one preserving
--- the most information, compared in order:
---   1. visible modules
---   2. modules showing (part of) their text
---   3. fairness (leximin): the module showing the smallest fraction of its
---      text is compared first, then the next one, and so on - so cells grow
---      together instead of one filling up while another stays short
---   4. total width
--- Truncated forms absorb the leftover columns of each combination one column
--- at a time, always to the one currently showing the least.
---@param  names      string[]
---@param  avail_cols integer
---@return string     formatted
---@return integer    consumed
local function render_group_exhaustive(names, avail_cols)
  local entries = collect_entries(names)
  local n = #entries

  local full_width = 0
  for _, entry in ipairs(entries) do
    full_width = full_width + entry.cands[1].w
  end
  if full_width <= avail_cols then
    for _, entry in ipairs(entries) do
      entry.cur = entry.cands[1]
    end
    local used = entries_width(entries)
    return join_entries(entries), used
  end

  local combos = 1
  for _, entry in ipairs(entries) do
    -- Each module also has a truncated and a hidden form.
    combos = combos * (#entry.cands + 2)
    if combos > EXHAUSTIVE_CAP then
      return fit_balanced(entries, avail_cols)
    end
  end

  local pick, trims, infos = {}, {}, {}
  local best, best_alloc, best_vec
  local bv, bt, bw = -1, -1, -1
  local alloc, cur, vec = {}, {}, {}
  local upper_vectors = {}
  local suffix_text_candidates = {}
  suffix_text_candidates[n + 1] = 0
  for i = n, 1, -1 do
    suffix_text_candidates[i] = suffix_text_candidates[i + 1]
      + (entries[i].has_text_candidate and 1 or 0)
  end

  local function leaf(width, visible, texty)
    local leftover = avail_cols - width
    for i = #vec, 1, -1 do
      vec[i] = nil
    end
    for _, idx in ipairs(trims) do
      alloc[idx] = entries[idx].trim.min
      cur[idx] = trim_info(alloc[idx], entries[idx].trim.full)
    end
    while leftover > 0 do
      local low
      for _, idx in ipairs(trims) do
        if alloc[idx] < entries[idx].trim.max and (not low or cur[idx] < cur[low]) then
          low = idx
        end
      end
      if not low then
        break
      end
      alloc[low] = alloc[low] + 1
      cur[low] = trim_info(alloc[low], entries[low].trim.full)
      leftover = leftover - 1
    end
    local used = avail_cols - leftover

    for i = 1, n do
      if infos[i] then
        vec[#vec + 1] = infos[i]
      end
    end
    for _, idx in ipairs(trims) do
      vec[#vec + 1] = cur[idx]
    end
    table.sort(vec)

    local better
    if visible ~= bv then
      better = visible > bv
    elseif texty ~= bt then
      better = texty > bt
    else
      local c = leximin_cmp(vec, best_vec)
      better = c > 0 or (c == 0 and used > bw)
    end
    if better then
      bv, bt, bw = visible, texty, used
      best, best_alloc, best_vec = {}, {}, {}
      for i = 1, n do
        best[i] = pick[i]
      end
      for _, idx in ipairs(trims) do
        best_alloc[idx] = alloc[idx]
      end
      for i = 1, #vec do
        best_vec[i] = vec[i]
      end
    end
  end

  local function search(i, width, visible, texty)
    if width > avail_cols then
      return
    end
    if best then
      local max_visible = visible + n - i + 1
      if max_visible < bv then
        return
      end
      local max_texty = texty + suffix_text_candidates[i]
      if max_visible == bv and max_texty < bt then
        return
      end
      if max_visible == bv and max_texty == bt then
        local bound = upper_vectors[i]
        if not bound then
          bound = {}
          upper_vectors[i] = bound
        else
          for j = #bound, 1, -1 do
            bound[j] = nil
          end
        end
        for j = 1, i - 1 do
          local selected = pick[j]
          if selected == "trim" then
            local trim = entries[j].trim
            bound[#bound + 1] = trim_info(trim.max, trim.full)
          elseif type(selected) == "table" and selected.texty then
            bound[#bound + 1] = selected.info
          end
        end
        for j = i, n do
          if entries[j].has_text_candidate then
            bound[#bound + 1] = 1
          end
        end
        table.sort(bound)
        local comparison = leximin_cmp(bound, best_vec)
        if comparison < 0 or (comparison == 0 and avail_cols <= bw) then
          return
        end
      end
    end
    if i > n then
      return leaf(width, visible, texty)
    end
    local e = entries[i]
    for _, c in ipairs(e.cands) do
      pick[i], infos[i] = c, c.info
      search(i + 1, width + c.w, visible + 1, texty + (c.texty and 1 or 0))
    end
    if e.trim then
      pick[i], infos[i] = "trim", nil
      trims[#trims + 1] = i
      search(i + 1, width + e.trim.base + e.trim.min, visible + 1, texty + 1)
      trims[#trims] = nil
    end
    pick[i], infos[i] = e.hidden, nil
    search(i + 1, width + e.hidden.w, visible, texty)
    infos[i] = nil
  end

  search(1, 0, 0, 0)

  if not best then
    return render_group_balanced(names, avail_cols)
  end

  for i, e in ipairs(entries) do
    if best[i] == "trim" then
      e.cur, e.visible = build_trim(e, best_alloc[i]), true
    else
      e.cur, e.visible = best[i], best[i] ~= e.hidden
    end
  end
  local used = entries_width(entries)
  log:debug("[group] exhaustive fit  used: %d/%d", used, avail_cols)
  return join_entries(entries), used
end

local GROUP_STRATEGIES = {
  greedy = render_group_greedy,
  balanced = render_group_balanced,
  exhaustive = render_group_exhaustive,
}

---@param  names      string[]
---@param  avail_cols integer
---@return string     formatted
---@return integer    consumed
local function render_group(names, avail_cols)
  local strategy = GROUP_STRATEGIES[Opts.fit or "balanced"] or render_group_balanced
  return strategy(names, avail_cols)
end

M.render_group = render_group

return M
