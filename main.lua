
-- Make sure the shared library can be found through package.cpath before loading the module.
-- For example, if you put it in the LÖVE save directory, you could do something like this:
local lua_path = love.filesystem.getSource() .. "/lua"
local lib_path = love.filesystem.getSource() .. "/lib"
local extension = jit.os == "Windows" and "dll" or jit.os == "Linux" and "so" or jit.os == "OSX" and "dylib"

package.path = string.format("%s;%s/?/init.lua", package.path, lua_path)
package.path = string.format("%s;%s/?.%s", package.path, lua_path, "lua")
package.cpath = string.format("%s;%s/?.%s", package.cpath, lib_path, extension)

local inspect = require "inspect"
local imgui = require "cimgui"
local mgl = require "MGL"
local skeleton = require "skeleton"

local mouse_joint = skeleton.Joint:new(mgl.vec2(10, 100))
local k = mouse_joint
local body_joints = {mouse_joint}
-- body
for i = 1, 10 do
    local j = skeleton.Joint:new(mgl.vec2(i*10+30, 100))
    table.insert(body_joints, j)
    if i == 1 then
        k:add_mutual_neighbor(j, {
            length_min = 30,
            length_max = 60,
            length_absolute_min = 1,
            length_absolute_max = 1e5,
            speed = 200,
            exponential = false,
            drag = 0
        })
    else
        k:add_mutual_neighbor(j, skeleton.link(15, 15, 500, false, 0))
    end
    k = j
end

for i = 3, 10 do
    local c = skeleton.constraint(
        body_joints[i-1],
        body_joints[i+1],
        math.pi*7/8,
        math.pi*9/8,
        math.pi/2,
        false,
        1.0
    )
    body_joints[i]:add_constraint(c)
end

local demo_lizard = require "demo_lizard"

local legs = {}

for _, is_back in ipairs({false, true}) do
    for _, is_right in ipairs({false, true}) do
        local leg = demo_lizard.LizardLeg:new()
        local t
        if is_right then t = -1 else t = 1 end
        if is_back then
            leg:build(body_joints[4], body_joints[2], mgl.vec2(35, -20 * t), mgl.vec2(10, -15 * t))
        else
            leg:build(body_joints[8], body_joints[6], mgl.vec2(35, -20 * t), mgl.vec2(10, -15 * t))
        end
        table.insert(legs, leg)
    end
end


love.load = function()
    imgui.love.Init() -- or imgui.love.Init("RGBA32") or imgui.love.Init("Alpha8")
end

love.draw = function()
    -- example window
    imgui.ShowDemoWindow()
    
    -- code to render imgui
    imgui.Render()
    imgui.love.RenderDrawLists()

    for i, ik in ipairs(body_joints) do
        love.graphics.circle('line', ik.pos.x, ik.pos.y, 5)
        -- love.graphics.print(ik.drag_rotate, ik.pos.x, ik.pos.y)
    end
    for _, l in ipairs(legs) do
        l:draw()
    end
end

love.update = function(dt)
    imgui.love.Update(dt)
    imgui.NewFrame()

    local target = mgl.vec2(love.mouse.getPosition())
    mouse_joint.pos = target
    mouse_joint:influence_recursive(nil, dt)
    
    for _, l in ipairs(legs) do
        l:update({time = dt})
    end
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