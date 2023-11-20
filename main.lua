
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

local IK = {}

function IK:new(pos)
    local t = setmetatable({}, {__index = IK})
    t.pos = pos
    t.len = 0
    return t
end

function IK:new_child(len, angle_min, angle_max)
    local t = setmetatable({}, {__index = IK})
    t.len = len
    t.parent = self
    t.pos = t.parent.pos + mgl.vec2(len, 0)
    if not angle_min then angle_min = 0 end
    if not angle_max then angle_max = math.pi * 2 end
    t.angle_range = {min = angle_min, max = angle_max}
    return t
end

function IK:show()
    love.graphics.circle('line', self.pos.x, self.pos.y, 5)
    if self.parent then
        love.graphics.line(self.pos.x, self.pos.y, self.parent.pos.x, self.parent.pos.y)
        if self.angle_range then
            local global_angle = math.atan2(self.parent.pos.y - self.pos.y, self.parent.pos.x - self.pos.x)

            local angle_max = self.angle_range.max
            local mx = self.pos.x + math.cos(angle_max + global_angle) * 5
            local my = self.pos.y + math.cos(angle_max + global_angle) * 5
            love.graphics.line(self.pos.x, self.pos.y, mx, my)

            local angle_min = self.angle_range.min
            local mx = self.pos.x + math.cos(angle_min + global_angle) * 5
            local my = self.pos.y + math.cos(angle_min + global_angle) * 5
            love.graphics.line(self.pos.x, self.pos.y, mx, my)
        end
    end
end

-- https://github.com/lincerely/gecko/tree/master
-- https://sean.cm/a/fabrik-algorithm-2d
function reach(tail, target, length)
    if mgl.length(tail - target) < 1e-3 then return tail end
    local streched = tail - target
    local streched_length = mgl.length(streched)
    local scale = length / streched_length;
    return target + streched * scale
end

function lerp(a, b, t)
    return a + (b-a) * t
end

function update_IKs(IKs, st, et)
    if st then
        local t = st
        for k, j in pairs(IKs) do
            j.pos = reach(j.pos, t, j.len)
            t = j.pos
        end
    end
    if et then
        IKs[#IKs].pos = et
        local t = et
        for i = #IKs - 1, 1, -1 do
            local j = IKs[i]
            local prev_len = IKs[i+1].len
            j.pos = reach(j.pos, t, prev_len)
            t = j.pos
        end
    end
end

function local_position(p0, p_forward, len, angle)
    local d = p_forward - p0
    d = mgl.normalize(d) * len
    local cos_a = math.cos(angle)
    local sin_a = math.sin(angle)
    return mgl.vec2(cos_a * d.x - sin_a * d.y, sin_a * d.x + cos_a * d.y)
end

function draw_gecko_leg(leg_IK)
    local gecko_leg = {4, 2, 2, 3}
    local fill_n = 4

    for k, v in pairs(leg_IK) do
        if k == 1 then
            love.graphics.circle('line', v.pos.x, v.pos.y, gecko_leg[1])
        else
            for i = 0, fill_n do
                local p = lerp(leg_IK[k-1].pos, v.pos, i/fill_n)
                local r = lerp(gecko_leg[k], gecko_leg[k+1], i/fill_n)
                love.graphics.circle('line', p.x, p.y, r)
            end
        end
    end
end

function draw_gecko_body(body_IK)
    local gecko_body = {4,9,6,7, 7,5,5,4, 3,2,2,2, 1,1,0}
    local fill_n = 10

    for k, v in pairs(body_IK) do
        if k == 1 then
            love.graphics.circle('line', v.pos.x, v.pos.y, gecko_body[k])
        else
            for i = 0, fill_n do
                local p = lerp(body_IK[k-1].pos, v.pos, i/fill_n)
                local r = lerp(gecko_body[k], gecko_body[k+1], i/fill_n)
                love.graphics.circle('line', p.x, p.y, r)
            end
        end
    end
end

function draw_gecko_IKs(body_IK, legs)
    for _, l in pairs(legs) do
        if l.left_up then love.graphics.circle('line', l.left_target.x, l.left_target.y, 3) end
        if l.right_up then love.graphics.circle('line', l.right_target.x, l.right_target.y, 3) end

        for k, v in pairs(l.left_IK) do
            --print(tostring(k), v.x-8, v.y-8, 5)
            v:show()
        end
        for k, v in pairs(l.right_IK) do
            --print(tostring(k), v.x-8, v.y-8, 6)
            v:show()
        end
    end

    for k, v in pairs(body_IK) do 
        --print(tostring(k), v.x-8, v.y-8, 15)
        v:show()
    end
end

function update_legs(legs)
    
    local prev_left, prev_right = false, false

    for k, l in pairs(legs) do
        if #legs > 1 then
            if k == 1 then 
                prev_left, prev_right = legs[#legs].left_up, legs[#legs].right_up
            else
                prev_left, prev_right = legs[k-1].left_up, legs[k-1].right_up
            end
        end

        if prev_right or l.left_up then
            local d = local_position(l.base_joint.pos, l.forward_joint.pos, l.step_length, l.leg_angle)
            l.left_target = l.base_joint.pos + d
            local t = lerp(l.left_IK[1].pos, l.left_target, l.leg_speed)
            update_IKs(l.left_IK, t, l.base_joint.pos)
            if mgl.length(l.left_target - l.left_IK[1].pos) <= 2 then
                l.left_up = false
            end
        else 
            update_IKs(l.left_IK, l.left_target, l.base_joint.pos)
            if not l.right_up and mgl.length(l.left_target - l.base_joint.pos) > l.step_length then 
                l.left_up = true
            end
        end

        local force = .5

        if l.left_up then
            local d = local_position(l.base_joint.pos, l.left_IK[1].pos, force, math.pi/2)
            l.base_joint.pos = l.base_joint.pos + d
        end

        if prev_left or l.right_up then
            local d = local_position(l.base_joint.pos, l.forward_joint.pos, l.step_length, -l.leg_angle)
            l.right_target = l.base_joint.pos + d
            local t = lerp(l.right_IK[1].pos, l.right_target, l.leg_speed)
            update_IKs(l.right_IK, t, l.base_joint.pos)
            if mgl.length(l.right_target - l.right_IK[1].pos) <= 2 then 
                l.right_up = false
            end
        else
            update_IKs(l.right_IK, l.right_target, l.base_joint.pos)
            if not l.left_up and mgl.length(l.right_target - l.base_joint.pos) > l.step_length then 
                l.right_up = true
            end
        end


        if l.right_up then 
            local d = local_position(l.base_joint.pos, l.right_IK[1].pos, force, -math.pi/2)
            l.base_joint.pos = l.base_joint.pos + d
        end

    end
end

local body_IK={}
local legs={}
local target={}
local right_target={}
local mov_speed = 0.1
local target_speed = .01
local is_debug=false
local hide_graphic=false

function gecko_init()
	body_IK[1] = IK:new(mgl.vec2(20, 136/2))
	for i = 1, 10 do
		body_IK[i+1] = body_IK[i]:new_child(15)
	end

	legs = {}
	legs[1]= {
		step_length=20,
		leg_length=10,
		leg_speed=.3,
		leg_angle=40*math.pi/180,
		joint_cnt=2,
		base_joint=body_IK[3],
		forward_joint=body_IK[2],
	}
	legs[2]= {
		step_length=20,
		leg_length=10,
		leg_speed=.3,
		leg_angle=40*math.pi/180,
		joint_cnt=2,
		base_joint=body_IK[5],
		forward_joint=body_IK[4],
	}

	for k,l in pairs(legs) do 
		l.left_IK={}
		l.left_IK[1] = IK:new(l.base_joint.pos)
		l.right_IK={}
		l.right_IK[1] = IK:new(l.base_joint.pos)
		l.left_IK[2] = l.left_IK[1]:new_child(l.leg_length, math.rad(-30), math.rad(0))
		l.right_IK[2] = l.right_IK[1]:new_child(l.leg_length, math.rad(-30), math.rad(0))
		l.left_IK[3] = l.left_IK[2]:new_child(l.leg_length, math.rad(-30), math.rad(30))
		l.right_IK[3] = l.right_IK[2]:new_child(l.leg_length, math.rad(-30), math.rad(30))

		local d = local_position(l.base_joint.pos, l.forward_joint.pos, l.step_length, -l.leg_angle)
		l.right_target = l.base_joint.pos + d
		d = local_position(l.base_joint.pos, l.forward_joint.pos, l.step_length, l.leg_angle)
		l.left_target = l.base_joint.pos + d
	end
end

love.load = function()
    imgui.love.Init() -- or imgui.love.Init("RGBA32") or imgui.love.Init("Alpha8")
    gecko_init()
end

love.draw = function()
    -- example window
    imgui.ShowDemoWindow()
    
    -- code to render imgui
    imgui.Render()
    imgui.love.RenderDrawLists()

    draw_gecko_body(body_IK)
    for _, l in pairs(legs) do
        draw_gecko_leg(l.left_IK)
        draw_gecko_leg(l.right_IK)
    end
end

love.update = function(dt)
    imgui.love.Update(dt)
    imgui.NewFrame()

    local floored_legs = 0
	local total_legs = #legs * 2
	for _, l in pairs(legs) do
		if not l.left_up then floored_legs = floored_legs + 1 end
		if not l.right_up then floored_legs = floored_legs + 1 end
	end

    local target = mgl.vec2(love.mouse.getPosition())
    target = body_IK[1].pos + mgl.normalize(target - body_IK[1].pos) * mov_speed
    update_IKs(body_IK, target)
	update_legs(legs)
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