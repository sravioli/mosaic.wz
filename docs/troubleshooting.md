# Troubleshooting

[← mosaic.wz](../.github/readme.md)

## The bar is empty or a module never shows

Start with the doctor. In the debug overlay (**Ctrl+Shift+L**) run
`require("mosaic.api").doctor()`. It logs, line by line, missing programs, rejected
options, layout names that resolve nowhere, options for names that are not
in the layout, and what each module costs per frame.

The overlay also shows `unknown module` and validation messages. A module whose `cond` fails, or that returns `enabled = false`,
renders nothing; `cwd`, `clock` and `battery` also hide while key hints are
shown. In a narrow window, `can_hide` modules are the first to go.

## An integration's slot stays empty

The plugin that ships it must be loaded with `wezterm.plugin.require` before
mosaic renders. `mosaic.discover()` lists the names mosaic can find; a
rejected integration logs one error naming it.

## The new-tab button keeps an old look

A colour scheme switcher that copies `tab_bar_style` into window overrides
pins the old button. mosaic redraws it on `window-config-reloaded`; after a
runtime scheme switch, call `mosaic.set_new_tab_button(config, theme)`.

Report problems in [issues](https://github.com/sravioli/mosaic.wz/issues)
with WezTerm/plugin versions, the preset, and your `setup` options.
