---@module "mosaic.engine.logger"
---@author sravioli
---@license GNU-GPLv2

---Shared log.wz instance tagged `mosaic`.

local deps = require "mosaic.engine.deps"

---@class Mosaic.Logger
---@field debug fun(self: Mosaic.Logger, msg: string, ...: any)
---@field info  fun(self: Mosaic.Logger, msg: string, ...: any)
---@field warn  fun(self: Mosaic.Logger, msg: string, ...: any)
---@field error fun(self: Mosaic.Logger, msg: string, ...: any)
local log = deps.log.new("mosaic", true)

return log
