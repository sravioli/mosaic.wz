---Tab scenarios for the tab specs: title kinds x states x index x width.
local function pane(title, process, cwd)
  local cwd_url = cwd and { file_path = cwd } or nil
  return {
    title = title,
    foreground_process_name = process or "",
    current_working_dir = cwd_url,
    get_current_working_dir = function()
      return cwd_url
    end,
    get_foreground_process_name = function()
      return process
    end,
  }
end
local titles = {
  { "shell", pane("~/source/project - zsh", "/usr/bin/zsh", "/home/mock/source/project") },
  { "editor", pane("nvim", "/usr/bin/nvim", "/home/mock/source/mosaic") },
  { "app", pane("Build output", "/usr/bin/node", "/home/mock/work") },
  { "emoji", pane("🤖 Fix the flaky test", "/usr/bin/node", "/home/mock") },
  { "short", pane("htop", "/usr/bin/htop", "/home/mock") },
  { "long", pane("a very long window title that will certainly need truncation", nil, nil) },
}
local list = {}
for _, t in ipairs(titles) do
  for _, st in ipairs { "active", "hover", "inactive", "unseen", "custom" } do
    for _, idx in ipairs { 0, 3 } do
      for _, w in ipairs { 34, 18, 9 } do
        local tab = {
          tab_index = idx,
          is_active = st == "active",
          tab_title = st == "custom" and "renamed" or "",
          active_pane = t[2],
          panes = { { has_unseen_output = st == "unseen" } },
        }
        list[#list + 1] = {
          name = ("%s/%s/%d@%d"):format(t[1], st, idx, w),
          tab = tab,
          hover = st == "hover",
          width = w,
        }
      end
    end
  end
end
local theme = dofile("spec/support/scenarios.lua").theme
theme.tab_bar.inactive_tab_hover = { bg_color = "#2a2a37" }

return {
  list = list,
  config = {
    use_fancy_tab_bar = false,
    enable_tab_bar = true,
    color_scheme = "test",
    color_schemes = { test = theme },
  },
}
