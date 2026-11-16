# Tabs

[← mosaic.wz](../.github/readme.md)

## Format tabs

The preset styles the tabs too, and every tab's width goes to the width
budget automatically. Supply only the title text, or replace the whole cell:

```lua
mosaic.setup {
  preset = "powerline",
  tabs = {
    -- Title text only; the preset draws the rest of the cell.
    title = function(tab, max_cells)
      return tab.active_pane.title:sub(1, max_cells)
    end,
    -- Or replace the whole cell: return { bg, fg, text, attributes } segments.
    -- format = function(ctx) ... end,
    -- And the new-tab button: fun({ theme, config, hover }) → segments.
    -- new_tab = function(ctx) ... end,
  },
}
```

`ctx` carries `tab`, `tabs`, `theme`, `config`, `hover`, `max_width`,
`state` (`"active"`, `"hover"` or `"inactive"`), `unseen` (any pane has
unseen output), and `title(max_cells)`, which calls your title hook. Use
`mosaic.width(s)` to measure the decorations, and pass the remaining columns
to `ctx.title`.

To format tabs yourself, set `tabs = false`. Then report the widths, so the
right status still fits:

```lua
wezterm.on("format-tab-title", function(tab, tabs, ...)
  local title = ...
  mosaic.budget.record(tab.tab_index, wezterm.column_width(title))
  mosaic.budget.set_count(#tabs)
  return title
end)
```

Without that, mosaic estimates the tab widths from `tab_max_width`.

## Compose tabs

Build the tab text from components instead of a title hook. The preset still
draws the cell and the index around it:

```lua
tabs = {
  content = {
    active = { "process", "parent", "/", "cwd", "zoomed" },
    inactive = { { "process", icon_only = true }, "title", "output" },
  },
}
```

| Component  | Shows                                                                               | Options                                                             |
| ---------- | ----------------------------------------------------------------------------------- | ------------------------------------------------------------------- |
| `title`    | The tab title, else the pane title, through your `title` hook.                      |                                                                     |
| `process`  | Icon and name of the foreground process.                                            | `icons` (merged over the built-in map), `icon_only`, `icon = false` |
| `cwd`      | The directory's name, or the whole path with `full = true`.                         | `full`, `home`, `aliases`, `max_length`                             |
| `parent`   | Name of the parent directory.                                                       | `max_length`                                                        |
| `zoomed`   | An icon while the pane is zoomed.                                                   | `icon`                                                              |
| `output`   | An icon while a pane has unseen output.                                             | `icon`, `idle` (shown otherwise)                                    |
| `panes`    | The pane count, above one.                                                          | `icon`                                                              |
| `progress` | What the pane's program reports (OSC 9;4): a circle that fills, and the percentage. | `icon = false`, `icon_only`                                         |
| `domain`   | The domain, unless local.                                                           | `icons`, `icon_only`, `show_local`                                  |
| `icon`     | The icon a matching [rule](#tab-rules) sets.                                        | `default`                                                           |

A string is drawn as written and a function `fun(tab, ctx): string` as it
returns. Components get one space between them, strings none, so
`"parent", "/", "cwd"` reads `src/mosaic`. A single list applies to every
tab; hovered tabs use the `inactive` list. When space is short, components
right of the title go first, then the title is cut. Set `tabs.style.index`
to `false` (or `"number0"` to count from zero) to change the preset's index.

## Tab rules

Recolour or re-icon tabs by what runs in them. Rules apply in order; each
match merges its `style` (any `tabs.style` key) over the previous ones:

```lua
tabs = {
  rules = {
    { match = { domain = { pattern = "^SSH" } }, style = { colors = { active = 2, inactive = 2 } }, icon = "" },
    { match = { cwd = { pattern = "^/srv/prod" }, process = "psql" }, style = { colors = { active = "#e46876" } } },
    { match = { user_var = { name = "env", value = "staging" } }, style = { colors = { inactive = 4 } } },
  },
}
```

`match` takes `domain`, `cwd`, `process` (the basename), `title` and
`user_var`. Each value is a string (exact), `{ pattern = "…" }` (Lua
pattern) or `fun(value): boolean`, and every key given must match. A rule
without `match` is rejected, so it can never recolour every tab.

## Tab badges

Make a tab light up while you are elsewhere: on a bell, on unseen output, or
when a script or an agent hook sets a pane user variable:

```lua
tabs = { badges = true } -- bell, plus the working / done / waiting states
```

```sh
# in a hook: mark this pane's tab
printf '\e]1337;SetUserVar=badge=%s\a' "$(printf done | base64)"
```

| Source           | Default badge                 | Cleared                            |
| ---------------- | ----------------------------- | ---------------------------------- |
| `states.working` | robot icon, `6`               | when the variable changes (sticky) |
| `states.waiting` | alert icon, `2`               | when the variable changes (sticky) |
| `states.done`    | check icon, `3`               | when you focus the tab             |
| `bell`           | bell icon, `4`                | when you focus the tab             |
| `output`         | off; `true` for unseen output | when you focus the tab             |

A badge replaces the tab's index with its icon and fills the tab with its
colour. Override any part, for example
`badges = { var = "agent", states = { review = { icon = "", color = 5, sticky = true } }, output = true }`.
A var state wins over a bell, and a bell over output. A non-sticky state
comes back when the variable is set again, even to the same value. Put the
`badges` module in a layout to count the tabs that need you.
