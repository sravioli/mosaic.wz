---@module "mosaic.modules.kube"
---@author sravioli
---@license GNU-GPLv2

---Current Kubernetes context (and its namespace), read from the kubeconfig
---file: `path`, else the first `$KUBECONFIG` entry, else `~/.kube/config`.
---No kubectl process; re-read every `interval` seconds (default 10).
---Options: `path`, `namespace = false`, `interval`.
---
---shortcut: a line-based reader for the usual kubeconfig layout, not a YAML
---parser; inline flow maps (`{...}`) are not understood.

local icons = require "mosaic.engine.icons"
local wezterm = require "wezterm"

local config = require "mosaic.engine.config"

local M = {}

---@param  s string
---@return string
local function unquote(s)
  return (s:gsub("^%s+", ""):gsub("%s+$", ""):gsub('^"(.*)"$', "%1"):gsub("^'(.*)'$", "%1"))
end

---@return string|nil
function M.path(opts)
  if opts.path then
    return opts.path
  end
  local env = os.getenv "KUBECONFIG"
  if env and env ~= "" then
    local sep = require("mosaic.engine.system").os == "windows" and ";" or ":"
    return env:match("^([^" .. sep .. "]+)")
  end
  return wezterm.home_dir .. "/.kube/config"
end

---Current context and its namespace from kubeconfig text.
---@param  text string
---@return string|nil context, string|nil namespace
function M.parse(text)
  local current = text:match "\ncurrent%-context:%s*([^\r\n]+)"
    or text:match "^current%-context:%s*([^\r\n]+)"
  if not current then
    return nil
  end
  current = unquote(current)
  if current == "" then
    return nil
  end
  local namespace
  local block = nil
  local function close()
    if block and block.name == current then
      namespace = block.namespace
    end
  end
  local in_contexts = false
  for line in (text .. "\n"):gmatch "([^\r\n]*)\r?\n" do
    -- `- context:` items of a top-level `contexts:` list may sit at column 0.
    local item = in_contexts and line:match "^%s*%-%s"
    if line:match "^%S" and not item then
      close()
      block = nil
      in_contexts = line:match "^contexts:" ~= nil
    elseif in_contexts then
      if item then
        close()
        block = {}
        line = line:gsub("^(%s*)%-", "%1 ")
      end
      if block then
        local ns = line:match "^%s+namespace:%s*(.-)%s*$"
        local name = line:match "^%s+name:%s*(.-)%s*$"
        if ns then
          block.namespace = unquote(ns)
        elseif name then
          block.name = unquote(name)
        end
      end
    end
  end
  close()
  return current, namespace
end

return function()
  local opts = config.option "kube"
  local file = M.path(opts)
  local f = file and io.open(file, "r")
  if not f then
    return { enabled = false, update = opts.interval or 10 }
  end
  local text = f:read "*a" or ""
  f:close()
  local context, namespace = M.parse(text)
  if not context then
    return { enabled = false, update = opts.interval or 10 }
  end
  local value = context
  if namespace and namespace ~= "" and opts.namespace ~= false then
    value = context .. ":" .. namespace
  end
  return {
    enabled = true,
    cond = true,
    can_hide = true,
    update = opts.interval or 10,
    padding = { left = 1 },
    icon = {
      enabled = true,
      value = icons.symbol "Status.kube",
      padding = { right = 1 },
    },
    text = { enabled = true, value = value, variants = namespace and { context } or nil },
  }
end
