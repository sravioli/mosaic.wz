_G.DEMO_READ = _G.DEMO_READ or {}
_G.DEMO_READ["badevents"] = true
return { api = 1, events = "demo-changed", new = function() return {} end }
