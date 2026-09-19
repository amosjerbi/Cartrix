function love.conf(t)
    t.identity = "rocknix-3d-carousel"
    t.version = "11.4"
    t.window.title = "ROCKNIX 3D Carousel"
    -- RG DS presents two 640x480 panels as one 1280x480 logical surface.
    -- The launcher maps the left half to the upper panel and the right half
    -- to the lower panel.  The draw code still supports ordinary displays.
    t.window.width = 1280
    t.window.height = 480
    t.window.vsync = 1
    t.window.resizable = true
    t.window.highdpi = false
    t.window.stencil = true
    t.window.depth = 24
end
