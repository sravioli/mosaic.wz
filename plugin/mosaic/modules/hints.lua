---@module "mosaic.modules.hints"
---@author sravioli
---@license GNU-GPLv2

---Slot for key hints from another plugin. Every preset places it first on the
---right side; it renders nothing until you define `modules.hints`, e.g. a
---`layout` that fills `mosaic.remaining_width()` with the active key table's
---bindings.

return { enabled = false }
