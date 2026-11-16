# Usage

[← mosaic.wz](../.github/readme.md)

## Customize without code

Built-in modules and integrations return content only: icon, text,
padding, conditions, and optionally an `accent` colour hint. The preset's
decorator gives each of them its look, so anything you add to a layout
matches the preset. Three tables change everything else, with no module or
decorator to write.

`options` changes any module by name, built-in, integration or your own:

```lua
mosaic.setup {
  preset = "powerline",
  options = {
    clock = { format = "%H:%M", variants = {}, icon = false },
    cwd = { git_root = false, icon = "" },
    battery = { cond = true }, -- stay visible while key hints show
    workspace = { text = { style = { attributes = "" } } }, -- not italic
    zoomed = { text = "Z", accent = 2 },
    cpu = { update = 10 }, -- sample every 10 s
    hostname = { enabled = false },
    process = { fmt = string.upper }, -- format the text
    git = { icon = { color = 3 } }, -- colour just the icon
  },
}
```

`style` sets the colours and glyphs every module is decorated with:

```lua
style = {
  colors = { cwd = 4, clock = "#e46876" }, -- per module
  separators = { left = "", right = "" },
  text = "background", -- text on filled modules
  dim = 9, -- muted text and glyphs (brackets, pure)
  gradient = { base = 5, stops = { -0.15, 0, 0.15, 0.25 } }, -- powerline's right side
  raw = { "battery" }, -- plain text in its colour, no separators
  by_mode = { copy_mode = { gradient = { base = 4 } }, leader = { colors = { workspace = 2 } } },
}
```

`tabs.style` sets the tabs and the new-tab button:

```lua
tabs = {
  style = {
    colors = { active = 5, hover = 7, inactive = 9, text = "background" },
    index = "number", -- "icon", false, or fun(tab, ctx): string
    unseen = "*", -- shown in place of the index on unseen output; false to ignore
    separators = { left = "", right = "" }, -- tab edges
    new_tab = "+", -- new-tab button label
  },
}
```

See [colours](configuration.md#colours) for the values a colour accepts and
[option keys](configuration.md#option-keys) for every key. A module that sets its own `style`
is left exactly as it is: that is the escape hatch for a fully custom look.
Set `decorate` to replace the preset's decorator for every module, or wrap a
module in code with `mosaic.extend`.

## Write a module

A module is a table, or a function `fun(window, pane, theme, config)` that
returns one. Functions run on every repaint, so return `{ enabled = false }`
to skip a frame.

```lua
mosaic.setup {
  preset = "powerline",
  layout = { right = { { "git", "clock" } } },
  modules = {
    git = function(window, pane, theme)
      local branch = pane:get_user_vars().git_branch
      if not branch then
        return { enabled = false }
      end
      return {
        enabled = true,
        can_hide = true,
        update = function() return branch end, -- reuse the spec while unchanged
        accent = 3, -- let the preset style it; or set `style` yourself
        icon = { enabled = true, value = wezterm.nerdfonts.dev_git_branch, padding = { right = 1 } },
        text = { enabled = true, value = branch, variants = { branch:sub(1, 8) } },
      }
    end,
  },
}
```

See [module fields](modules.md#module-fields) for every field. Use `update` for
anything that costs more than a table lookup (sampling, process queries).

## Centre modules

WezTerm's tab bar has a left and a right status but no centre, so mosaic
makes one: `layout.center` modules are drawn where a centred block belongs,
in the space the tabs and the right modules leave.

```lua
mosaic.setup {
  preset = "powerline",
  layout = {
    left = { "workspace" },
    center = { "notice" }, -- messages pop up in the middle
    right = { { "cwd", "clock", "battery" } },
  },
  center = { anchor = "window", overflow = "shift" },
}
```

The right modules keep priority: the centre fits into what they leave, with
the same fitting as any group, and moves out of the way of the tabs and the
right modules (or hides, with `overflow = "hide"`). Decorators see
`ctx.side == "center"`. With the fancy tab bar the position is approximate,
because its proportional font has no column grid.

## Choose the layout per window

`layout` can be a function. It runs on every frame with the window and its
active pane, so the bar can change with the workspace, the domain or the
active key table:

```lua
layout = function(window, pane)
  if pane:get_domain_name():match "^SSH" then
    return { left = { "workspace", "ssh" }, right = { { "hostname", "clock" } } }
  end
  return { left = { "workspace" }, right = { { "cwd", "git", "clock", "battery" } } }
end
```

Sides it leaves out are empty. If it fails, mosaic logs the error once and
draws the preset's layout. Integrations named only by a function layout load
on first use.

## Show a message for a while

`mosaic.notify(window, "session saved", { seconds = 3 })` shows a message in
the `notice` slot, which every preset places on the right. Plugins that do
not depend on mosaic emit the event instead:

```lua
wezterm.emit("mosaic-notify", window, pane, "session saved", { icon = "", accent = 3 })
```

Without a window (`nil`, as in the debug overlay's REPL), the message goes
to every window.

## Editor support

There is no mosaic entry in the
[wezterm-types collection](https://github.com/DrKJeff16/wezterm-types).
Add this checkout's `plugin` and `.meta` directories to your
[LuaLS library settings](https://luals.github.io/wiki/settings/#workspacelibrary)
to use the source annotations:

```lua
---@type Mosaic.Options
local opts = { preset = "powerline" }
```
