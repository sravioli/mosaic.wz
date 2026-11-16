_G.DEMO_READ = _G.DEMO_READ or {}
_G.DEMO_READ["raises"] = true
return { api = 1, new = function() error "nope" end }
