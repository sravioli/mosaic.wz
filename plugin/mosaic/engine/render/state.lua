---@module "mosaic.engine.render.state"
---@author sravioli
---@license GNU-GPLv2

---State of the frame being drawn, shared by the render modules. The
---renderer and its parts (resolve, decorate, cell, fit) all hang their
---functions on this one table, so they reach each other at call time.

---@class Mosaic.Renderer
local M = {
  window = nil,
  pane = nil,
  theme = nil,
  config = nil,
  width = { used = 0, available = 0 },
  frame = {}, -- module specs resolved this frame, by name
}

return M
