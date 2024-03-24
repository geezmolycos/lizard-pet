local dummy = {}

dummy.mouse_overrided = false

function dummy.try_mouse_event(pressed, released, moved)
    -- do nothing
end

function dummy.init_user_config_gui(Slab)
    -- do nothing
end

function dummy.should_open_config_gui()
    return true
end

function dummy.user_config_gui(Slab)
    Slab.Text("Dummy OS Port is used, no config available")
    Slab.Text("This Slider is just for fun")
    Slab.InputNumberSlider("fun", 87, 0, 100, { Precision = 0, UserSlider = true })
end

function dummy.init(user_config)
    love.window.setMode(
        1280, 720,
        { borderless = false, resizable = false, vsync = 0, msaa = 4,
          highdpi = true, usedpiscale = false }
    )
end

return dummy
