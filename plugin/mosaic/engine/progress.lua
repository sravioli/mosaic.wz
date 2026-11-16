---@module "mosaic.engine.progress"
---@author sravioli
---@license GNU-GPLv2

---Progress reported by programs with the ConEmu OSC (`ESC ] 9 ; 4 ; st ; pr
---ST`), as WezTerm exposes it: `pane:get_progress()` and
---`PaneInformation.progress` (WezTerm nightly). Older builds have neither, so
---callers read it defensively and treat a failure as no progress.

local wezterm = require "wezterm"

local M = {}

---@alias Mosaic.Progress { kind: "percent"|"error"|"indeterminate", value: number }

---Normalise a WezTerm progress value; nil for `"None"` or anything else.
---@param  raw any
---@return Mosaic.Progress|nil
function M.read(raw)
  if raw == "Indeterminate" then
    return { kind = "indeterminate", value = 0 }
  end
  local ok, pct, err = pcall(function()
    return raw.Percentage, raw.Error
  end)
  if not ok then
    return nil
  end
  if type(pct) == "number" then
    return { kind = "percent", value = math.max(0, math.min(100, pct)) }
  end
  if type(err) == "number" then
    return { kind = "error", value = math.max(0, math.min(100, err)) }
  end
  return nil
end

---Glyph for `p`: an eighth-step circle for a percentage, an alert for an
---error, an hourglass while indeterminate.
---@param  p Mosaic.Progress
---@return string
function M.glyph(p)
  local nf = wezterm.nerdfonts
  if p.kind == "error" then
    return nf.md_alert_circle or "!"
  elseif p.kind == "indeterminate" then
    return nf.md_timer_sand or "~"
  end
  local step = math.floor(p.value / 12.5 + 0.5)
  if step <= 0 then
    return nf.md_circle_outline or "o"
  elseif step >= 8 then
    return nf.md_circle_slice_8 or "o"
  end
  return nf["md_circle_slice_" .. step] or "o"
end

---Text for `p`: `42%`, or empty while indeterminate.
---@param  p Mosaic.Progress
---@return string
function M.text(p)
  if p.kind == "indeterminate" then
    return ""
  end
  return ("%d%%"):format(math.floor(p.value + 0.5))
end

return M
