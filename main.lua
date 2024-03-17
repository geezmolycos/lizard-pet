
if os.getenv("LOCAL_LUA_DEBUGGER_VSCODE") == "1" then
    require("lldebugger").start()
end
-- Make sure the shared library can be found through package.cpath before loading the module.
-- For example, if you put it in the LÖVE save directory, you could do something like this:
local lua_path = love.filesystem.getSource() .. "/lua"
local lib_path = love.filesystem.getSource() .. "/lib"
local extension = jit.os == "Windows" and "dll" or jit.os == "Linux" and "so" or jit.os == "OSX" and "dylib"

package.path = string.format("%s;%s/?/init.lua", package.path, lua_path)
package.path = string.format("%s;%s/?.%s", package.path, lua_path, "lua")
package.cpath = string.format("%s;%s/?.%s", package.cpath, lib_path, extension)

local ffi = require "ffi"
local inspect = require "inspect"
local imgui = require "cimgui"
local mgl = require "MGL"
local skeleton = require "skeleton"
local draw_modifier = require "draw_modifier"
local perlin = require "perlin"

local mouse_joint = skeleton.Joint:new(mgl.vec2(50, 200))

local dragon = require "dragon"

local body = dragon.Body:new()
body:build(mouse_joint, 22, mgl.vec2(60, 200), mgl.vec2(10, 0))
body.draw = draw_modifier.color({.7, .7, .7}, body.draw)

local left_wing = dragon.Wing:new()
left_wing:build(body.joints[6], body.joints[5], body.joints[10], body.joints[5], body.joints[13], mgl.rotate(math.pi/2))

local right_wing = dragon.Wing:new()
right_wing:build(body.joints[6], body.joints[5], body.joints[10], body.joints[5], body.joints[13], mgl.rotate(-math.pi/2) * mgl.scale(mgl.vec2(1, -1)))

local legs = {dragon.Leg:new(), dragon.Leg:new(), dragon.Leg:new(), dragon.Leg:new()}

legs[1]:build(body.joints[6], body.joints[5], mgl.vec2(20, 20), mgl.vec2(8, 16), mgl.vec2(8, 16), -70, 1)
legs[2]:build(body.joints[6], body.joints[5], mgl.vec2(20, -20), mgl.vec2(8, -16), mgl.vec2(8, -16), 70, 1)
legs[3]:build(body.joints[11], body.joints[10], mgl.vec2(30, -30), mgl.vec2(12, -17), mgl.vec2(12, -17), 70, 1.5)
legs[4]:build(body.joints[11], body.joints[10], mgl.vec2(30, 30), mgl.vec2(12, 17), mgl.vec2(12, 17), -70, 1.5)

love.load = function()
    imgui.love.Init() -- or imgui.love.Init("RGBA32") or imgui.love.Init("Alpha8")
end
local wing = ffi.new("float[1]")
local air = ffi.new("int[1]")
local show_target = ffi.new("bool[1]", {false})
local state = 'landed'
local speed = 1
local fly_freq = 1.8
-- landed, takeoff, flying, landing

wing[0] = 0.2
left_wing:spread(wing[0])
right_wing:spread(wing[0])
air[0] = 0
local leg_step = 0
local leg_step_count = 0
local clock = 0
local target
love.draw = function()
    -- example window
    local status
    status = imgui.SliderFloat("wing", wing, 0.0, 1.0)
    if status then
        left_wing:spread(wing[0])
        right_wing:spread(wing[0])
    end
    status = imgui.SliderInt("air", air, 0, 2)
    if status then
        for _, leg in ipairs(legs) do
            leg:air(air[0])
        end
    end
    imgui.Text("leg: %d", ffi.cast('int', leg_step))
    imgui.Text("state: " .. state)
    imgui.Text("speed: " .. speed)
    imgui.Checkbox("Show target", show_target);
    
    -- code to render imgui
    imgui.Render()
    imgui.love.RenderDrawLists()
    love.graphics.push('all')
    for _, leg in ipairs(legs) do
        leg:draw()
    end
    left_wing:draw()
    right_wing:draw()
    body:draw()
    love.graphics.pop('all')
    if show_target[0] then
        love.graphics.circle("line", target.x, target.y, 10)
    end
end

local takeoff_delay = 1
local takeoff_distance = 500
local landing_distance = 200

love.update = function(dt)
    clock = clock + dt
    imgui.love.Update(dt)
    imgui.NewFrame()

    if target == nil then
        target = body.target_joint.pos
    end

    local mouse_pos = mgl.vec2(love.mouse.getPosition())

    target = body.head.pos
    -- random offset mouse_pos
    mouse_pos.x = mouse_pos.x + 100 * perlin:noise(clock, 123.8975, 456.0231)
    mouse_pos.y = mouse_pos.y + 100 * perlin:noise(clock, 986.423, 461.511)
    -- move target to mouse
    local target_move_vec = mouse_pos - target
    -- if mgl.length(target_move_vec) > dt * 200 then
    --     target_move_vec = mgl.normalize(target_move_vec) * dt * 200
    -- end
    target_move_vec.x = target_move_vec.x + mgl.length(target_move_vec) * 0.7 * perlin:noise(clock, 64.56, 379.615)
    target_move_vec.y = target_move_vec.y + mgl.length(target_move_vec) * 0.7 * perlin:noise(clock, 65.64, 311.156)
    target = target + target_move_vec


    if state == 'landed' then
        local target_wing_spread = perlin:noise(clock, 4564.453, 4635.312) / 2 + 0.5
        target_wing_spread = target_wing_spread * 0.2 + 0.1
        local diff = target_wing_spread - wing[0]
        if math.abs(diff) > dt / 1 then
            diff = diff / math.abs(diff) * dt/1
        end
        wing[0] = wing[0] + diff
        left_wing:spread(wing[0])
        right_wing:spread(wing[0])
        left_wing:flap(0.5)
        right_wing:flap(0.5)
        speed = 0.1 + (perlin:noise(clock, 5610.153, 2455.987) / 2 + 0.5) * 0.2
    end
    if state == 'landed' and mgl.length(mouse_pos - body.joints[1].pos) > takeoff_distance then
        state = 'takeoff'
        takeoff_delay = 1
        air[0] = 1
        for i, leg in ipairs(legs) do
            leg:air(1)
        end
    end
    if state == 'takeoff' then
        local target = math.sin(clock * fly_freq * math.pi) / 2 + 0.5
        target = target * 0.3 + 0.4
        local diff = target - wing[0]
        if math.abs(diff) > dt / 0.5 then
            diff = diff / math.abs(diff) * dt/0.5
        end
        wing[0] = wing[0] + diff
        if math.abs(target - wing[0]) < 0.02 then
            takeoff_delay = takeoff_delay - dt
            if takeoff_delay <= 0 then
                state = 'flying'
                air[0] = 2
                for i, leg in ipairs(legs) do
                    leg:air(2)
                end
            end
        end
        left_wing:spread(wing[0])
        right_wing:spread(wing[0])
        left_wing:flap(wing[0])
        right_wing:flap(wing[0])
    end
    if state == 'flying' then
        local wing_speed_target = math.sin(clock * fly_freq * math.pi) / 2 + 0.5
        wing_speed_target = wing_speed_target * 0.3 + 0.4
        local diff = wing_speed_target - wing[0]
        if math.abs(diff) > dt / 0.5 then
            diff = diff / math.abs(diff) * dt/0.5
        end
        wing[0] = wing[0] + diff
        left_wing:spread(wing[0])
        right_wing:spread(wing[0])
        left_wing:flap(wing[0])
        right_wing:flap(wing[0])
        local target_speed = -math.sin(clock * fly_freq * math.pi) / 2 + 0.5
        target_speed = target_speed * 0.3 + 0.4
        local speed_diff = target_speed - speed
        if math.abs(speed_diff) > dt / 0.5 then
            speed_diff = speed_diff / math.abs(speed_diff) * dt/0.5
        end
        speed = speed + speed_diff
    end
    if state == 'flying' and mgl.length(target - body.joints[1].pos) < landing_distance then
        state = 'landing'
        air[0] = 0
        for i, leg in ipairs(legs) do
            leg:air(0)
        end
    end
    if state == 'landing' then
        local target_speed = 0.1 + (perlin:noise(clock, 5610.153, 2455.987) / 2 + 0.5) * 0.2
        local speed_diff = target_speed - speed
        if math.abs(speed_diff) > dt / 2 then
            speed_diff = speed_diff / math.abs(speed_diff) * dt/2
        end
        speed = speed + speed_diff
        if math.abs(target_speed - speed) < 0.02 then
            state = 'landed'
        end
    end
    local next_leg_step = leg_step
    for i, leg in ipairs(legs) do
        local args = {
            time = dt,
            mouse_pos = target,
        }
        if leg_step == i % 2 then
            args.stay = true
        end
        leg:update(args)
        if args.half_step then
            next_leg_step = 1 - (i % 2)
            leg_step_count = leg_step_count + 1
        end
    end
    if leg_step_count > 0 then
        leg_step = next_leg_step
        leg_step_count = 0
    end
    body:update({
        time = dt,
        mouse_pos = target,
        speed = speed
    })
    left_wing:update({
        time = dt,
        mouse_pos = target,
        speed = (state == 'flying' or state == 'takeoff') and 10 or 1
    })
    right_wing:update({
        time = dt,
        mouse_pos = target,
        speed = (state == 'flying' or state == 'takeoff') and 10 or 1
    })
end

love.mousemoved = function(x, y, ...)
    imgui.love.MouseMoved(x, y)
    if not imgui.love.GetWantCaptureMouse() then
        -- your code here
    end
end

love.mousepressed = function(x, y, button, ...)
    imgui.love.MousePressed(button)
    if not imgui.love.GetWantCaptureMouse() then
        -- your code here 
        left_wing.joints.paw.pos = mgl.vec2(x, y)
        for name, joint in pairs(left_wing.joints) do
            print(name, inspect(joint, {depth = 2}))
        end
    end
end

love.mousereleased = function(x, y, button, ...)
    imgui.love.MouseReleased(button)
    if not imgui.love.GetWantCaptureMouse() then
        -- your code here 
    end
end

love.wheelmoved = function(x, y)
    imgui.love.WheelMoved(x, y)
    if not imgui.love.GetWantCaptureMouse() then
        -- your code here 
    end
end

love.keypressed = function(key, ...)
    imgui.love.KeyPressed(key)
    if not imgui.love.GetWantCaptureKeyboard() then
        -- your code here 
    end
end

love.keyreleased = function(key, ...)
    imgui.love.KeyReleased(key)
    if not imgui.love.GetWantCaptureKeyboard() then
        -- your code here 
    end
end

love.textinput = function(t)
    imgui.love.TextInput(t)
    if imgui.love.GetWantCaptureKeyboard() then
        -- your code here 
    end
end

love.quit = function()
    return imgui.love.Shutdown()
end

-- for gamepad support also add the following:

love.joystickadded = function(joystick)
    imgui.love.JoystickAdded(joystick)
    -- your code here 
end

love.joystickremoved = function(joystick)
    imgui.love.JoystickRemoved()
    -- your code here 
end

love.gamepadpressed = function(joystick, button)
    imgui.love.GamepadPressed(button)
    -- your code here 
end

love.gamepadreleased = function(joystick, button)
    imgui.love.GamepadReleased(button)
    -- your code here 
end

-- choose threshold for considering analog controllers active, defaults to 0 if unspecified
local threshold = 0.2 

love.gamepadaxis = function(joystick, axis, value)
    imgui.love.GamepadAxis(axis, value, threshold)
    -- your code here 
end