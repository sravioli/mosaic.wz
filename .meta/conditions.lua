---@meta mosaic.conditions
error "cannot require a meta file!"

-- luacheck: push ignore 631 (line is too long)

---Boolean condition functions for status bar visibility and key-table state.
---
---Provides composable logical combinators (`all`, `any`, `not_`) and concrete
---predicates for leader key state, active mode (key table), and workspace
---presence.
---
---@alias Mosaic.Conditions.Predicate  fun(window: table, pane: table): boolean
---@alias Mosaic.Conditions.Combinator fun(...: Mosaic.Conditions.Predicate): Mosaic.Conditions.Predicate
---@alias Mosaic.Conditions.Negator    fun(condition: Mosaic.Conditions.Predicate): Mosaic.Conditions.Predicate
---@alias Mosaic.Conditions.Evaluator  fun(cond: any, window: table, pane: table): any
---
---@class Mosaic.Conditions
---@field public always               Mosaic.Conditions.Predicate  Always returns true.
---@field public never                Mosaic.Conditions.Predicate  Always returns false.
---@field public all                  Mosaic.Conditions.Combinator Combine conditions with logical AND.
---@field public any                  Mosaic.Conditions.Combinator Combine conditions with logical OR.
---@field public not_                 Mosaic.Conditions.Negator    Invert a condition.
---@field public mode_active          Mosaic.Conditions.Predicate  True if a key table is active.
---@field public mode_inactive        Mosaic.Conditions.Predicate  True if no key table is active.
---@field public has_workspace        Mosaic.Conditions.Predicate  True if workspace name is non-empty.
---@field public is_default_workspace Mosaic.Conditions.Predicate  True if workspace name is empty.
---@field public leader_active        Mosaic.Conditions.Predicate  True if leader key is active.
---@field public leader_inactive      Mosaic.Conditions.Predicate  True if leader key is inactive.
---@field public predicate            Mosaic.Conditions.Evaluator  Evaluate a function condition or return the value directly.

-- luacheck: pop
