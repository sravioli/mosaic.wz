---@module "mosaic.engine.icons"
---@author sravioli
---@license GNU-GPLv2

---Glyph maps shared by the `process` / `domain` modules and the tab
---components. Users merge their own over these with an `icons` option.

local wezterm = require "wezterm"

local nf = wezterm.nerdfonts

local M = {}

---Foreground process basename -> glyph.
M.PROCESS = {
  bash = nf.cod_terminal_bash,
  btm = nf.md_chart_donut_variant,
  btop = nf.md_chart_areaspline,
  bun = nf.md_hamburger,
  cargo = nf.dev_rust,
  curl = nf.md_flattr,
  docker = nf.md_docker,
  ["docker-compose"] = nf.md_docker,
  fish = nf.md_fish,
  gh = nf.dev_github_badge,
  git = nf.dev_git,
  go = nf.md_language_go,
  htop = nf.md_chart_areaspline,
  kubectl = nf.md_kubernetes,
  lazygit = nf.dev_git,
  lua = nf.seti_lua,
  make = nf.seti_makefile,
  node = nf.md_nodejs,
  npm = nf.md_npm,
  nu = nf.md_console,
  nvim = nf.custom_neovim,
  pnpm = nf.md_npm,
  psql = nf.dev_postgresql,
  pwsh = nf.md_powershell,
  python = nf.dev_python,
  python3 = nf.dev_python,
  ruby = nf.dev_ruby,
  rustc = nf.dev_rust,
  ssh = nf.md_lan_connect,
  sudo = nf.fa_hashtag,
  tmux = nf.cod_terminal_tmux,
  top = nf.md_chart_areaspline,
  vim = nf.dev_vim,
  wget = nf.md_arrow_down_box,
  yazi = nf.md_folder,
  zsh = nf.dev_terminal,
}

---Glyph for anything not in `PROCESS`.
M.PROCESS_DEFAULT = nf.md_console

---Domain name prefix -> glyph, tried longest first.
M.DOMAIN = {
  local_ = nf.md_monitor,
  SSH = nf.md_ssh,
  SSHMUX = nf.md_ssh,
  WSL = nf.md_microsoft_windows,
  docker = nf.md_docker,
  unix = nf.cod_terminal_linux,
}

---Glyph for `name` from `defaults` overlaid by `user`; `fallback` otherwise.
---@param  defaults table
---@param  user     table|nil
---@param  name     string
---@param  fallback string|nil
---@return string|nil
function M.lookup(defaults, user, name, fallback)
  local glyph = user and user[name]
  if glyph == nil then
    glyph = defaults[name]
  end
  if glyph == nil then
    return fallback
  end
  return glyph or nil -- false: no glyph
end

---Glyph for a domain name: an exact name, else the longest matching prefix.
---@param  name string
---@param  user table|nil
---@return string|nil
function M.domain(name, user)
  local exact = M.lookup(M.DOMAIN, user, name == "local" and "local_" or name)
  if exact or (user and user[name] == false) then
    return exact
  end
  local best, len = nil, 0
  for i, map in ipairs { M.DOMAIN, user or {} } do
    for prefix, glyph in pairs(map) do
      -- The user's map wins ties.
      local longer = #prefix > len or (i == 2 and #prefix == len)
      if longer and name:sub(1, #prefix) == prefix then
        best, len = glyph, #prefix
      end
    end
  end
  return best or nf.md_server_network
end

---Glyph for a process basename.
---@param  name string
---@param  user table|nil
---@return string|nil
function M.process(name, user)
  return M.lookup(M.PROCESS, user, name, M.PROCESS_DEFAULT)
end

return M
