# Configuration

[← mosaic.wz](../.github/readme.md)

## Example

Call setup before `apply_to_config`. Every option is optional:

```lua
mosaic.setup {
  preset = "bubbles",
  position = "top",
  fit = "exhaustive",
  layout = {
    left = { "leader", "workspace", "mode" },
    right = { "hints", { "cwd", "hostname", "clock", "battery" } },
  },
}
```

## Options

| Option                     | Type                                                | Default                                          | Description                                                                                                                                                                  |
| -------------------------- | --------------------------------------------------- | ------------------------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `enabled`                  | `boolean`                                           | `true`                                           | `false` clears the bar.                                                                                                                                                      |
| `position`                 | `"top"\|"bottom"`                                   | `"bottom"`                                       | Sets `tab_bar_at_bottom`.                                                                                                                                                    |
| `preset`                   | `string?`                                           | `nil`                                            | One of the [presets](../.github/readme.md#pick-a-preset). Supplies the layout, modules, decorator and tabs.                                                                  |
| `flexible`                 | `boolean`                                           | `true`                                           | Fit modules to the free width.                                                                                                                                               |
| `fit`                      | `"greedy"\|"balanced"\|"exhaustive"`                | `"balanced"`                                     | Fitting strategy for groups; see [fitting](#fitting).                                                                                                                        |
| `layout`                   | `{ left?, center?, right? }\|fun(window, pane)`     | preset's                                         | Module names per side; a nested table is a fitted group. Replaces the preset layout entirely. A function returns the layout for each window on every frame.                  |
| `layout.center`            | `item[]`                                            | `{}`                                             | Modules drawn in the [centre](usage.md#centre-modules) of the bar.                                                                                                           |
| `center.anchor`            | `"window"\|"free"`                                  | `"window"`                                       | Centre on the whole bar, or in the space between the tabs and the right modules.                                                                                             |
| `center.overflow`          | `"shift"\|"hide"`                                   | `"shift"`                                        | When the centred spot would touch the tabs or the right modules: slide into the free space, or hide.                                                                         |
| `center.margin`            | `integer`                                           | `1`                                              | Columns kept clear on both sides of the centre.                                                                                                                              |
| `modules`                  | `table<string, module\|string>`                     | `{}`                                             | Replaces modules by name. A string aliases another name, e.g. `hints = "chord.hints"`.                                                                                       |
| `options`                  | `table<string, table>`                              | `{}`                                             | Changes a module by name; see [option keys](#option-keys). Integrations receive theirs too.                                                                                  |
| `style.colors`             | `table<string, colour>`                             | `{}`                                             | A module's colour.                                                                                                                                                           |
| `style.separators`         | `{ left?, right? }`                                 | preset's                                         | Glyphs drawn before (`left`) and after (`right`) every module.                                                                                                               |
| `style.text`               | `colour`                                            | `"background"`                                   | Text on filled modules (powerline, bubbles, slanted, blocks).                                                                                                                |
| `style.dim`                | `colour`                                            | `9`                                              | Muted text and glyphs (brackets' brackets, pure's text).                                                                                                                     |
| `style.gradient`           | `{ base?, stops? }`                                 | `{ base = 5, stops = { -0.15, 0, 0.15, 0.25 } }` | Powerline's right-side gradient: the base colour and the darken (-) / lighten (+) offset of each stop. Longer groups stretch over the range.                                 |
| `style.raw`                | `string[]`                                          | `{}`                                             | Modules drawn plain: their colour as text on the bar background, one column of padding each side, no separators.                                                             |
| `style.by_mode`            | `table<string, style>`                              | `{}`                                             | Style merged over the rest while a key table (by name) or the leader (`leader`) is active.                                                                                   |
| `style.separators.between` | `string`                                            | `nil`                                            | Glyph between the modules of a group, in `style.dim`.                                                                                                                        |
| `scheme`                   | `string\|table`                                     | `nil`                                            | Take the palette from another colour scheme (a name or a scheme table). The bar keeps the active scheme's background.                                                        |
| `decorate`                 | `fun(spec, ctx): spec`                              | preset's                                         | Replaces the preset's decorator.                                                                                                                                             |
| `tabs`                     | `false\|{ title?, format?, new_tab?, style? }`      | preset's                                         | Tab hooks and look; `false` leaves `format-tab-title` to you.                                                                                                                |
| `tabs.style.colors`        | `table<string, colour>`                             | preset's                                         | `active`, `hover` and `inactive` fill the tab for its state, `text` is the text on filled tabs. brackets and pure also read `dim`, and pure reads `head` (the active index). |
| `tabs.style.index`         | `"number"\|"number0"\|"icon"\|false\|fun(tab, ctx)` | preset's                                         | The tab's index: from one, from zero, a Nerd Font digit, none, or your text.                                                                                                 |
| `tabs.style.unseen`        | `string\|false`                                     | preset's                                         | Replaces the index while a pane has unseen output.                                                                                                                           |
| `tabs.style.separators`    | `{ left?, right? }`                                 | preset's                                         | Tab and new-tab button edges.                                                                                                                                                |
| `tabs.style.new_tab`       | `string`                                            | `"+"`                                            | New-tab button label.                                                                                                                                                        |
| `tabs.style.padding`       | `integer\|{ left?, right? }`                        | `0`                                              | Columns around the tab text.                                                                                                                                                 |
| `tabs.content`             | `item[]\|{ active?, inactive? }`                    | `nil`                                            | Tab text from [components](tabs.md#compose-tabs).                                                                                                                            |
| `tabs.rules`               | `rule[]`                                            | `{}`                                             | Per-tab [rules](tabs.md#tab-rules).                                                                                                                                          |
| `tabs.badges`              | `true\|table`                                       | `nil`                                            | [Tab badges](tabs.md#tab-badges).                                                                                                                                            |

### Colours

Every colour option takes `1`-`8` for `theme.ansi`, `9`-`16` for
`theme.brights`, `"foreground"` or `"background"` for the scheme's own, a
colour string such as `"#e46876"`, or `fun(theme): colour`. Values follow
the active colour scheme, so they stay right when you switch scheme.

### Option keys

Every module accepts these keys in `options[name]`. They are merged into the
module's spec each frame, over what the module returns:

| Key                                           | Type                         | Effect                                                                                                               |
| --------------------------------------------- | ---------------------------- | -------------------------------------------------------------------------------------------------------------------- |
| `enabled`                                     | `boolean`                    | `false` hides the module.                                                                                            |
| `cond`                                        | `boolean\|fun(window, pane)` | When it shows; `true` keeps it visible during key hints and modes.                                                   |
| `icon`                                        | `false\|string\|table`       | Hide the icon, replace the glyph, or merge into it (`position`, `padding`, `style`, and `color` for the icon alone). |
| `text`                                        | `false\|string\|table`       | Hide the text, replace it, or merge into it (`value`, `variants`, `trim`, `padding`, `style`).                       |
| `accent`                                      | `colour`                     | The module's colour hint; `style.colors` still wins.                                                                 |
| `padding`, `can_hide`, `priority`, `min_text` |                              | As in [module fields](modules.md#module-fields).                                                                     |
| `sep`                                         | `false\|table`               | `false` drops the separators; a table is merged over the preset's (`value`, `style`).                                |
| `style`                                       |                              | Style the module yourself; the preset then leaves it alone.                                                          |
| `update`                                      | `number\|table\|fun\|false`  | Replaces the module's refresh interval or key; `false` re-runs it every frame.                                       |
| `fmt`                                         | `fun(text, window, pane)`    | Formats the text and every variant.                                                                                  |

Some built-ins read keys of their own:

| Module     | Key                                                     | Default                                   | Effect                                                                   |
| ---------- | ------------------------------------------------------- | ----------------------------------------- | ------------------------------------------------------------------------ |
| `clock`    | `format`                                                | `"%a %b %-d %H:%M"`                       | strftime format.                                                         |
| `clock`    | `variants`                                              | `{ "%b %-d %H:%M", "%a %H:%M", "%H:%M" }` | Shorter formats tried when space is tight, longest first.                |
| `cwd`      | `git_root`                                              | `true`                                    | `false` shows the directory itself inside a repository.                  |
| `cwd`      | `home`                                                  | `nil`                                     | Replace the home directory, e.g. `"~"`.                                  |
| `cwd`      | `aliases`                                               | `nil`                                     | `{ { pattern = "^/srv/www", replacement = "www" } }`, applied first.     |
| `cwd`      | `max_length`                                            | `nil`                                     | Cut from the left past this width.                                       |
| `parent`   | `full`, `home`, `aliases`, `max_length`                 |                                           | `full = true` shows the whole parent path.                               |
| `clock`    | `icons`                                                 | hour faces                                | `false`, or `{ ["00"] = glyph, ... }` by 24-hour hour.                   |
| `battery`  | `all`                                                   | `false`                                   | Every battery's charge.                                                  |
| `battery`  | `time`                                                  | `false`                                   | Time to empty or full after the charge.                                  |
| `battery`  | `levels`                                                | `nil`                                     | `{ [15] = 2, [40] = 4 }`: a state colour at or below a charge.           |
| `battery`  | `charging`                                              | `nil`                                     | State colour while charging or full, over `levels`.                      |
| `mode`     | `modes`                                                 | `{}`                                      | `{ copy_mode = { text = "YANK", icon = "", color = 4 } }` per key table. |
| `mode`     | `format`                                                | upper-case name                           | `fun(name): string` for the default text.                                |
| `process`  | `icons`, `icon_only`                                    | built-in map                              | Glyph per process basename (`false` drops one).                          |
| `domain`   | `icons`, `show_local`                                   | built-in map                              | Glyph per domain name or prefix.                                         |
| `git`      | `interval`, `detached`                                  | `5`, `true`                               | Seconds between reads; `false` hides a detached HEAD.                    |
| `kube`     | `path`, `namespace`, `interval`                         | kubeconfig, `true`, `10`                  |                                                                          |
| `media`    | `interval`, `players`, `format`, `paused`, `max_length` | `5`, all, `"{artist} - {title}"`, `false` |                                                                          |
| `progress` | `error_color`, `icon`                                   | `2`, `true`                               | Colour of an error state; `false` hides the glyph.                       |

### Option validation

Options are checked against a schema when you call setup. An invalid
top-level option is logged and falls back to its default; unknown keys log a
warning. Invalid options never break the config.

## Behavior and precedence

A name in `layout` resolves to your `modules[name]`, then to the preset's
module of that name, then to an integration (dotted names) or a built-in.
User `style` fields are merged over the preset's; `tabs` fields override the
preset's one by one. `setup` is safe to call on every config reload.

The preset's decorator styles every module that does not set its own `style`:

- `powerline`: rounded pills on the left; on the right, a gradient from
  `ansi[5]` across each group by position, each segment opening with an arrow
  in the previous segment's colour. Groups longer than four stretch the
  gradient.
- `minimal`: the module's colour as text on the bar's background.
- `bubbles`: a rounded pill in the module's colour.

A module's colour is `style.colors[name]`, else its `accent`, else the
built-in default for its name. Each preset uses `style.separators` in place
of its own glyphs (minimal draws none unless you set them). Disabled modules
don't take a position, so gradients and arrows stay continuous. Keep `raw`
modules outside groups so they don't sit inside a gradient.

A custom `decorate` receives the spec and `ctx` (`name`, `side`, `group`,
`index` and `count` among the group's enabled modules, `names`, `first`,
`last`, `theme`, `config`, `style`) and returns a styled copy; don't modify
the spec.

### Fitting

Entries in a layout side render left to right. A nested table is a group:
its modules share the remaining width under the `fit` strategy.

| `fit`        | Behaviour                                                                                                                       |
| ------------ | ------------------------------------------------------------------------------------------------------------------------------- |
| `greedy`     | Left to right, each module takes the widest form that fits.                                                                     |
| `balanced`   | Shrink every module to its minimum before hiding any; `can_hide` modules go first, then lowest `priority`, then the rightmost.  |
| `exhaustive` | Search every combination and keep the one that shows the most. Groups with more than 4096 combinations fall back to `balanced`. |

The forms tried for each module are: full, each of `text.variants`, text only,
icon only, a truncated text (unless `text.trim = false`), and hidden (only
with `can_hide`).

### Fancy tab bar

With `use_fancy_tab_bar`, WezTerm draws the tabs itself and colours each one
from its first cell, so presets cannot shape them. mosaic then returns the
title alone (your `title` hook applies), in the colours of the preset's title
segment, so the active tab keeps the preset's colour. The status bar works as
usual, on the titlebar colour (`window_frame.active_titlebar_bg`, or
`inactive_titlebar_bg` when unfocused). Fancy text is proportional, so mosaic
estimates the free columns from the `window_frame.font_size` to `font_size`
ratio.
