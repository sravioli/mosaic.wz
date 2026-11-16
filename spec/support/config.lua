---A representative user config for the snapshot spec and the frame bench: the
---powerline preset, `exhaustive` fitting, and two custom modules fed by a
---key-hint provider (`spec/support/scenarios.lua`, `hints`):
---  * `mode`: a pill naming the active key table
---  * `hints`: a hint bar that fills the columns left on the right side

---@param mosaic table mosaic.api
---@param hints  table key-hint provider
return function(mosaic, hints)
  return {
    preset = "powerline",
    fit = "exhaustive",
    layout = {
      left = { "leader", "zoomed", "workspace", "mode" },
      right = { "hints", { "cwd", "hostname", "clock", "battery" } },
    },
    modules = {
      mode = function(window)
        local mode = hints.modes[window:active_key_table()]
        if not mode then
          return { enabled = false }
        end
        return {
          enabled = true,
          cond = true,
          padding = { left = 1 },
          style = function(t)
            return { bg = mode.bg, fg = t.background }
          end,
          icon = { enabled = true, value = mode.icon, padding = 1 },
          text = { enabled = true, value = mode.name, padding = { right = 1 } },
        }
      end,

      hints = function(window)
        local active = window:active_key_table()
        if not active and window:leader_is_active() then
          return {
            enabled = true,
            cond = true,
            layout = function()
              return hints.leader(mosaic.remaining_width())
            end,
          }
        end
        if not active or not hints.modes[active] then
          return { enabled = false }
        end
        return {
          enabled = true,
          cond = true,
          layout = function()
            return hints.layout(active, mosaic.remaining_width())
          end,
        }
      end,
    },
  }
end
