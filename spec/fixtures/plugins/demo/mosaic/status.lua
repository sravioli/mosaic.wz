_G.DEMO_READ = _G.DEMO_READ or {}
_G.DEMO_READ["status"] = true
-- Valid integration: records what mosaic passes to new().
_G.DEMO_CALLS = _G.DEMO_CALLS or {}
return {
  api = 1,
  events = { "demo-changed" },
  new = function(opts, mosaic)
    table.insert(_G.DEMO_CALLS, { opts = opts, mosaic = mosaic })
    return function()
      return { enabled = true, cond = true, text = { enabled = true, value = opts.label or "DEMO" } }
    end
  end,
}
