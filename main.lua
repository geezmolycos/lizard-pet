
if os.getenv("LOCAL_LUA_DEBUGGER_VSCODE") == "1" then
    require("lldebugger").start()
end

love.filesystem.setRequirePath(love.filesystem.getRequirePath() .. ';lua/?.lua;lua/?/init.lua')

local log, user_config, mgl, Slab, perlin, dragon, port

local ok, res = xpcall(function ()
    log = require "log"
    log.remove_file()

    log.warn("Lizard pet: Hello from main.lua")

    user_config = require "user_config"

    mgl = require "MGL"
    Slab = require "Slab"
    perlin = require "perlin"

    dragon = require "dragon"

    port = require "port"
end, debug.traceback)
if not ok then
    love.window.showMessageBox("Error", "Error when requiring library: " .. tostring(res), "error")
    love.event.quit()
end

local dragon_obj

local is_picking_color = false
local picking_color_for = 'body'
local color_picker_color = {0, 0, 0, 0}

local color_all_parts = {
    'body',
    'front_leg',
    'hind_leg',
    'front_paw',
    'hind_paw',
    'left_wing_base',
    'left_wing_membrane',
    'right_wing_base',
    'right_wing_membrane',
}

local function color_gsetter(part, set)
    if part == 'body' then
        if set then dragon_obj.body_color = set else return dragon_obj.body_color end
    elseif part == 'front_leg' then
        if set then
            dragon_obj.legs[1].limb_color = set
            dragon_obj.legs[2].limb_color = set
        else
            return dragon_obj.legs[1].limb_color
        end
    elseif part == 'hind_leg' then
        if set then
            dragon_obj.legs[3].limb_color = set
            dragon_obj.legs[4].limb_color = set
        else
            return dragon_obj.legs[3].limb_color
        end
    elseif part == 'front_paw' then
        if set then
            dragon_obj.legs[1].paw_color = set
            dragon_obj.legs[2].paw_color = set
        else
            return dragon_obj.legs[1].paw_color
        end
    elseif part == 'hind_paw' then
        if set then
            dragon_obj.legs[3].paw_color = set
            dragon_obj.legs[4].paw_color = set
        else
            return dragon_obj.legs[3].paw_color
        end
    elseif part == 'left_wing_base' then
        if set then
            dragon_obj.left_wing.limb_color = set
        else
            return dragon_obj.left_wing.limb_color
        end
    elseif part == 'right_wing_base' then
        if set then
            dragon_obj.right_wing.limb_color = set
        else
            return dragon_obj.right_wing.limb_color
        end
    elseif part == 'left_wing_membrane' then
        if set then
            dragon_obj.left_wing.membrane_color = set
        else
            return dragon_obj.left_wing.membrane_color
        end
    elseif part == 'right_wing_membrane' then
        if set then
            dragon_obj.right_wing.membrane_color = set
        else
            return dragon_obj.right_wing.membrane_color
        end
    end
end

love.load = function(args)
    local ok, res = xpcall(function ()
        log.info("Begin loading")
        user_config.load_from_file()
        user_config.set_default("log_level", "info")
        user_config.set_default("colors", {
            -- defaults will be saved on first run
        })

        log.info("initialize port")
        port.init(user_config.get("port") or {})
        Slab.Initialize(args)
        dragon_obj = dragon.Dragon:new()
        dragon_obj:build()
        for i, part in ipairs(color_all_parts) do
            color_gsetter(part, user_config.get('colors')[part])
        end
    end, debug.traceback)
    if not ok then
        log.fatal("Error when loading: ", res)
        love.window.showMessageBox("Error", "Error when loading: " .. tostring(res), "error")
        love.event.quit()
    end
end
local debug_window_show = false
local shadow_height = 0
local show_target = false
local show_skeleton = false

local clock = 0
local target, near_target
function love.draw()
    local ok, res = xpcall(function ()
        -- draw dragon
        love.graphics.push('all')
        -- draw shadow
        local body_center = dragon_obj.body.joints[9].pos
        local max_radius = 80
        local current_radius = max_radius * (1.2 - shadow_height)
        love.graphics.setColor(0, 0, 0, 0.1)
        love.graphics.circle('fill', body_center.x, body_center.y, current_radius * 0.6)
        love.graphics.circle('fill', body_center.x, body_center.y, current_radius * 0.8)
        love.graphics.circle('fill', body_center.x, body_center.y, current_radius)
        
        dragon_obj:draw()
        love.graphics.pop('all')
        if show_target then
            love.graphics.setColor(1, 1, 1)
            love.graphics.circle("line", target.x, target.y, 10)
            love.graphics.setColor(1, 1, 0)
            love.graphics.circle("line", near_target.x, near_target.y, 10)
        end

        if show_skeleton then
            love.graphics.setColor(1, 1, 1, 1)
            for i, j in ipairs(dragon_obj.body.joints) do
                love.graphics.circle('line', j.pos.x, j.pos.y, 3)
            end
            for i = 1, #dragon_obj.body.joints-1 do
                love.graphics.line(
                    dragon_obj.body.joints[i].pos.x, dragon_obj.body.joints[i].pos.y,
                    dragon_obj.body.joints[i+1].pos.x, dragon_obj.body.joints[i+1].pos.y
                )
            end
            for _, wing_name in ipairs({'left_wing', 'right_wing'}) do
                for i, name in ipairs({'main_root', 'elbow', 'paw', 'finger1', 'finger2', 'finger3', 'finger4', 'hind_root', 'hind'}) do
                    love.graphics.circle('line', dragon_obj[wing_name].joints[name].pos.x, dragon_obj[wing_name].joints[name].pos.y, 3)
                end
            end
            love.graphics.setColor(0, 0, 0)
            for _, leg in ipairs(dragon_obj.legs) do
                for i, name in ipairs({'fixation', 'elbow', 'paw'}) do
                    love.graphics.circle('line', leg[name].pos.x, leg[name].pos.y, 3)
                end
                love.graphics.line(
                    leg.fixation.pos.x, leg.fixation.pos.y,
                    leg.elbow.pos.x, leg.elbow.pos.y
                )
                love.graphics.line(
                    leg.elbow.pos.x, leg.elbow.pos.y,
                    leg.paw.pos.x, leg.paw.pos.y
                )
            end
        end

        Slab.Draw()


        love.timer.sleep(1/100)
    end, debug.traceback)
    if not ok then
        log.fatal("Error when drawing: ", res)
        love.window.showMessageBox("Error", "Error when drawing: " .. tostring(res), "error")
        love.event.quit()
    end
end

local menu_visible = false
local menu_open = false
local menu_grace = false -- make the first click not close the menu
local menu_x = 0
local menu_y = 0
local menu_is_hovered = false

local log_window_visible = false

local function colorHex(rgba)
--	colorHex(rgba)
--	where rgba is string as "#336699cc"
    local rb = tonumber(string.sub(rgba, 2, 3), 16) 
    local gb = tonumber(string.sub(rgba, 4, 5), 16) 
    local bb = tonumber(string.sub(rgba, 6, 7), 16)
    local ab = tonumber(string.sub(rgba, 8, 9), 16) or nil
--	print (rb, gb, bb, ab) -- prints 	51	102	153	204
--	print (love.math.colorFromBytes( rb, gb, bb, ab )) -- prints	0.2	0.4	0.6	0.8
    return {love.math.colorFromBytes( rb, gb, bb, ab )}
end

local log_colors = {
    colorHex("#ad7fa8"),
    colorHex("#ef2929"),
    colorHex("#fce94f"),
    colorHex("#8ae234"),
    colorHex("#34e2e2"),
    colorHex("#729fcf"),
}

love.update = function(dt)
    local ok, res = xpcall(function ()
        if port.mouse_overrided then
            port.try_mouse_event(love.handlers['mousepressed'], love.handlers['mousereleased'], love.handlers['mousemoved'])
        end
        clock = clock + dt
        Slab.Update(dt)

        if Slab.BeginWindow('Menu', {Title = "Menu", X = menu_x, Y = menu_y, ResetPosition = menu_open, IsOpen = menu_visible}) then
            if Slab.Button("Show Logs") then
                log_window_visible = true
            end
            Slab.Separator()
            Slab.Text("OS config:")
            port.user_config_gui(Slab)
            Slab.Separator()
            Slab.Text('Colors:')
            local function color_button(part)
                Slab.Rectangle({ W = 18, H = 18, Color = color_gsetter(part) })
                Slab.SameLine()
                if Slab.Button(part) then
                    is_picking_color = true
                    picking_color_for = part
                    color_picker_color = color_gsetter(part)
                end
            end
            for _, part in ipairs({
                'body', '',
                'front_leg', 'front_paw', '',
                'hind_leg', 'hind_paw', '',
                'left_wing_base', 'left_wing_membrane', '',
                'right_wing_base', 'right_wing_membrane', '',
            }) do
                if part == '' then
                    Slab.NewLine()
                else
                    color_button(part)
                    Slab.SameLine()
                end
            end
            Slab.NewLine()
            if Slab.CheckBox(show_skeleton, "Show skeleton") then
                show_skeleton = not show_skeleton
            end
            if Slab.CheckBox(show_target, "Show target") then
                show_target = not show_target
            end
            Slab.Separator()
            if is_picking_color then
                local result = Slab.ColorPicker({ Color = color_picker_color })
                local should_apply = result.Color
                if result.Button == 1 then
                    is_picking_color = false
                end
                if result.Button == -1 then
                    is_picking_color = false
                    should_apply = color_picker_color
                end
                color_gsetter(picking_color_for, should_apply)
            end
            if Slab.Button("Quit") then
                love.event.quit()
            end
        else
            menu_visible = false
        end
        Slab.EndWindow()
        menu_is_hovered = not Slab.IsVoidHovered()
        menu_open = false

        if Slab.BeginWindow('Logs', {Title = "Logs", W = 600, H = 300, AutoSizeWindow = false, IsOpen = log_window_visible}) then
            for i, v in ipairs(log.history) do
                local level, prelude, lineinfo, text = unpack(v)
                local color = log_colors[level]
                Slab.Textf(string.format("[%s] ", prelude), { Color = color })
                Slab.SameLine()
                Slab.Textf(string.format("%s: %s", lineinfo, text))
            end
        else
            log_window_visible = false
        end
        Slab.EndWindow()

        if target == nil then
            target = dragon_obj.body.target_joint.pos
        end

        local x, y = love.mouse.getPosition()
        local mouse_pos = mgl.vec2(x, y)

        target = dragon_obj.body.head.pos
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
        if is_picking_color then
            target = target + mgl.vec2(-400, 0) -- offset dragon for easier seeing color
        end
        local arg = {
            target = target,
            dt = dt,
            clock = clock
        }
        dragon_obj:update(arg)
        near_target = arg.near_target
    end, debug.traceback)
    if not ok then
        log.fatal("Error when updating: ", res)
        love.window.showMessageBox("Error", "Error when updating: " .. tostring(res), "error")
        love.event.quit()
    end
end

love.mousemoved = function(x, y, ...)
end

love.mousepressed = function(x, y, button, ...)
    local ok, res = xpcall(function ()
        -- menu show and hide
        if button == 1 and not menu_is_hovered then
            if menu_grace then menu_grace = false
            elseif menu_visible then menu_visible = false end
        end
        if button == 2 and port.should_open_config_gui() then
            menu_visible = true
            menu_open = true
            menu_grace = true
            menu_x = x
            menu_y = y
            port.init_user_config_gui(Slab)
        end
    end, debug.traceback)
    if not ok then
        log.fatal("Error in mousepressed: ", res)
        love.window.showMessageBox("Error", "Error in mousepressed: " .. tostring(res), "error")
        love.event.quit()
    end
end

love.mousereleased = function(x, y, button, ...)
end

love.quit = function()
    log.info("Begin quiting")
    log.info("saving config")
    user_config.set("port", port.user_config)
    local colors = {}
    for i, part in ipairs(color_all_parts) do
        colors[part] = color_gsetter(part)
    end
    user_config.set("colors", colors)
    user_config.save_to_file()
    log.warn("Quiting...")
end
