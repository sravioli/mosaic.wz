_G.DEMO_READ = _G.DEMO_READ or {}
_G.DEMO_READ["badreturn"] = true
return { api = 1, new = function() return 42 end }
