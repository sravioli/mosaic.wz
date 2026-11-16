# Modules

[← mosaic.wz](../.github/readme.md)

## Module fields

| Field           | Meaning                                                                                                                                                                                                                                                                                                                            |
| --------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `enabled`       | Must be `true` to render.                                                                                                                                                                                                                                                                                                          |
| `accent`        | Colour hint for the preset: a `theme.ansi` index or a colour. Ignored when the module sets `style`.                                                                                                                                                                                                                                |
| `tint`          | State colour (a low battery, a mode): wins over `style.colors`, `accent` and the preset's position colours, gradients included.                                                                                                                                                                                                    |
| `cond`          | Boolean or `fun(window, pane): boolean`. See `mosaic.cond`.                                                                                                                                                                                                                                                                        |
| `style`         | `{ fg, bg, attributes }`, or `fun(theme, parent_style)`. Setting it opts the module out of preset styling.                                                                                                                                                                                                                         |
| `padding`       | Columns outside the separators: a number or `{ left, right }`.                                                                                                                                                                                                                                                                     |
| `icon`, `text`  | `{ enabled, value, padding, style }`. `value` may be a `fun(window, pane)`. `icon.position = "right"` swaps the order.                                                                                                                                                                                                             |
| `text.variants` | Shorter forms tried before icon-only, longest first.                                                                                                                                                                                                                                                                               |
| `text.trim`     | `false` disables truncation.                                                                                                                                                                                                                                                                                                       |
| `sep`           | `{ enabled, value, style, invert_bg_fg }`. `value` is a string or `{ right, left }`: `right` is drawn before the content and `left` after it (named by glyph direction).                                                                                                                                                           |
| `can_hide`      | Allows a group to hide the module.                                                                                                                                                                                                                                                                                                 |
| `priority`      | Higher values are kept longer by `balanced`.                                                                                                                                                                                                                                                                                       |
| `layout`        | Escape hatch: a string, a FormatItem table, a Ribbon, or `fun(ctx)` returning one. Rendered as-is. `ctx.theme` is the current scheme.                                                                                                                                                                                              |
| `update`        | Function modules only. `seconds` or `{ interval = seconds }` reuses the spec until the interval passes. `fun(window, pane): key` reuses it while the key is unchanged. `{ key = fun, interval = seconds }` while both hold. The cache is per window and is cleared when the colour scheme changes. Fitting still runs every frame. |

## Built-in modules

| Module      | Shows                                                                                                    |
| ----------- | -------------------------------------------------------------------------------------------------------- |
| `hints`     | Empty slot for key hints from another plugin. Every preset places it. Define `modules.hints` to fill it. |
| `leader`    | Leader indicator while the leader is active.                                                             |
| `mode`      | Active key table (`copy_mode` → `COPY`).                                                                 |
| `workspace` | Workspace name, hidden in modes.                                                                         |
| `zoomed`    | `ZOOM` while the active pane is zoomed.                                                                  |
| `cwd`       | Current directory (git root inside a repository).                                                        |
| `parent`    | Name of the parent directory.                                                                            |
| `hostname`  | Short host name of the pane.                                                                             |
| `username`  | `WEZTERM_USER` user var, else `$USER`.                                                                   |
| `ssh`       | Remote host for SSH domains or a foreground `ssh`.                                                       |
| `domain`    | Mux domain, hidden when local.                                                                           |
| `process`   | Foreground process name.                                                                                 |
| `title`     | Active pane title.                                                                                       |
| `tabs`      | Active tab and count, e.g. `2/5`.                                                                        |
| `clock`     | Date and time, with shorter variants.                                                                    |
| `battery`   | Charge and state. Hidden without a battery.                                                              |
| `cpu`       | CPU utilisation, every 3 s.                                                                              |
| `ram`       | Memory in use, every 3 s.                                                                                |
| `network`   | Download/upload rate, every 2 s.                                                                         |
| `disk`      | Used space on the root volume, every 30 s.                                                               |
| `git`       | Branch of the repository (short commit when detached), read from `.git/HEAD`.                            |
| `kube`      | Kubernetes context and namespace, read from the kubeconfig.                                              |
| `media`     | Now playing (playerctl on Linux, Music or Spotify on macOS).                                             |
| `panes`     | Pane count of the active tab, above one.                                                                 |
| `progress`  | Progress the active pane's program reports (`OSC 9;4`), e.g. a build. WezTerm nightly.                   |
| `window`    | Window title.                                                                                            |
| `notice`    | Messages from `mosaic.notify`, while they last.                                                          |
| `badges`    | How many other tabs have a [badge](tabs.md#tab-badges).                                                  |

`update-status` runs on the GUI thread, so no module blocks it. `git` and
`kube` read a file. `media` asks the player from a timer and only reads the
answer while drawing.
On Linux they read `/proc` directly (disk runs `df` every 30 s). On macOS they
run only fast commands (`ps`, `vm_stat`, `sysctl`, `netstat -ibn`, `df`).
On Windows they hide themselves for now, because the CIM queries are too slow
to run from a repaint.
