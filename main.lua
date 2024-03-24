
if os.getenv("LOCAL_LUA_DEBUGGER_VSCODE") == "1" then
    require("lldebugger").start()
end

love.filesystem.setRequirePath(love.filesystem.getRequirePath() .. ';lua/?.lua;lua/?/init.lua')

local log = require "log"
log.remove_file()

log.warn("Lizard pet: Hello from main.lua")

local user_config = require "user_config"

local mgl = require "MGL"
local Slab = require "Slab"
local skeleton = require "skeleton"
local draw_modifier = require "draw_modifier"
local perlin = require "perlin"

local dragon = require "dragon"

local dragon_obj = dragon.Dragon:new()

local port = require "port"

love.load = function(args)
    log.info("Begin loading")
    user_config.load_from_file()
    user_config.set_default("log_level", "info")
    
    log.info("initialize port")
    port.init(user_config.get("port") or {})
    Slab.Initialize(args)
    dragon_obj:build()
end
local debug_window_show = false
local shadow_height = 0
local show_target = false

local clock = 0
local target
function love.draw()
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
        love.graphics.circle("line", target.x, target.y, 10)
    end

    Slab.Draw()

    love.timer.sleep(1/100)
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
    dragon_obj:update({
        target = target,
        dt = dt,
        clock = clock
    })
end

love.mousemoved = function(x, y, ...)
end

love.mousepressed = function(x, y, button, ...)
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
end

love.mousereleased = function(x, y, button, ...)
end

love.quit = function()
    log.info("Begin quiting")
    log.info("saving config")
    user_config.set("port", port.user_config)
    user_config.save_to_file()
    log.warn("Quiting...")
end
