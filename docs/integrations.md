# Integrations

[← mosaic.wz](../.github/readme.md)

Other plugins can ship mosaic modules. Name one in a layout as
`<plugin>.<module>` to use it:

```lua
mosaic.setup {
  preset = "powerline",
  layout = {
    left = { "leader", "workspace", "chord.mode" },
    right = { "chord.hints", { "beacon.update", "cwd", "clock" } },
  },
  options = { ["beacon.update"] = { icon = false } }, -- options for that module
  modules = { hints = "chord.hints" }, -- or fill a preset's slot by alias
}
```

- The plugin must be loaded (`wezterm.plugin.require`) before mosaic renders.
- An integration's code is read only when a layout names it. Unused
  integrations cost nothing.
- `mosaic.discover()` lists the integrations your loaded plugins ship. It
  only lists file names and runs nothing.
- A broken integration logs one error, and only its slot stays empty.

## Writing an integration

Ship `plugin/<plugin>/mosaic/<module>.lua` in your plugin. It must return:

```lua
return {
  api = 1, -- mosaic.INTEGRATION_API; other values are rejected
  events = { "my-plugin-changed" }, -- optional: mosaic refreshes the bar on these
  notices = { ["my-plugin-saved"] = "saved" }, -- optional: show a message on an event (or fun(window, ...): text)
  new = function(opts, mosaic)
    -- opts: the user's `options["<plugin>.<module>"]` table (or {})
    -- mosaic: the public API (cond, palette, extend, remaining_width, width, icons, ...)
    return function(window, pane, theme, config)
      -- Content only: the user's preset styles it. `accent` hints a colour.
      return { enabled = true, accent = 4, text = { enabled = true, value = "..." } }
    end
  end,
}
```

Rules:

1. Never `require` mosaic. Use only the `mosaic` table passed to `new`. Your
   plugin then has no dependency on mosaic, and `api` guards compatibility.
2. Nothing may have side effects when the file is required or `new` runs:
   no `wezterm.on`, processes, disk access or timers. Declare `events`
   instead, and mosaic wires them.
3. `new` runs once per config evaluation. Per-frame work goes in the
   returned module. Throttle anything costly with `update`.
4. Read your plugin's state cheaply (in memory or `wezterm.GLOBAL`). Never
   block `update-status`.
5. Return content only, never `style` or `sep`, so the module follows the
   user's preset, colours and separators. Use `accent` (a `theme.ansi` index
   or a colour) to hint a colour.
6. Module names match `^[%w_]+$`.
7. Don't give your own options the names of the [option keys](configuration.md#option-keys)
   (`icon`, `text`, `cond`, ...) unless they mean the same thing: mosaic also
   merges those into your module's spec.
