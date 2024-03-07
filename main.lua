
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

legs[1]:build(body.joints[6], body.joints[5], mgl.vec2(30, 30), mgl.vec2(10, 20), mgl.vec2(10, 20))
legs[2]:build(body.joints[6], body.joints[5], mgl.vec2(30, -30), mgl.vec2(10, -20), mgl.vec2(10, -20))
legs[3]:build(body.joints[11], body.joints[10], mgl.vec2(40, -40), mgl.vec2(12, -17), mgl.vec2(12, -17))
legs[4]:build(body.joints[11], body.joints[10], mgl.vec2(40, 40), mgl.vec2(12, 17), mgl.vec2(12, 17))

love.load = function()
    imgui.love.Init() -- or imgui.love.Init("RGBA32") or imgui.love.Init("Alpha8")
end
local x = ffi.new("float[1]")
local air = ffi.new("int[1]")
x[0] = 1
air[0] = 0
local leg_step = 0
local leg_step_count = 0
local time = 0
local target
love.draw = function()
    -- example window
    local status
    status = imgui.SliderFloat("wing", x, 0.0, 1.0)
    if status then
        left_wing:spread(x[0])
        right_wing:spread(x[0])
    end
    status = imgui.SliderInt("air", air, 0, 2)
    if status then
        for _, leg in ipairs(legs) do
            leg:air(air[0])
        end
    end
    imgui.Text("leg: %d", ffi.cast('int', leg_step))
    
    -- code to render imgui
    imgui.Render()
    imgui.love.RenderDrawLists()
    left_wing:draw()
    right_wing:draw()
    body:draw()
    for _, leg in ipairs(legs) do
        leg:draw()
    end
    love.graphics.circle("line", target.x, target.y, 10)
end

love.update = function(dt)
    time = time + dt
    imgui.love.Update(dt)
    imgui.NewFrame()

    target = mgl.vec2(love.mouse.getPosition())
    target.x = target.x + 100 * perlin:noise(time, 123, 456)
    target.y = target.y + 100 * perlin:noise(time, 986, 461)
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
        mouse_pos = target
    })
    left_wing:update({
        time = dt,
        mouse_pos = target
    })
    right_wing:update({
        time = dt,
        mouse_pos = target
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