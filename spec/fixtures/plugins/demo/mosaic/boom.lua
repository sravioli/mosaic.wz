_G.DEMO_READ = _G.DEMO_READ or {}
_G.DEMO_READ["boom"] = true
-- Must never be read: requiring it fails the laziness spec.
error "demo.mosaic.boom was required"
