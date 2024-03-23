
if os.getenv("LOCAL_LUA_DEBUGGER_VSCODE") == "1" then
    require("lldebugger").start()
end

love.filesystem.setRequirePath(love.filesystem.getRequirePath() .. ';lua/?.lua;lua/?/init.lua')

local log = require "log"
log.remove_file()

log.warn("Lizard pet: Hello from main.lua")

local user_config = require "user_config"
user_config.load_from_file()
user_config.set_default("test", 1)

local mgl = require "MGL"
local Slab = require "Slab"
local skeleton = require "skeleton"
local draw_modifier = require "draw_modifier"
local perlin = require "perlin"

local dragon = require "dragon"

local dragon_obj = dragon.Dragon:new()

local port = require "port"

love.load = function(args)
    port.init(2)
    port.set_top(port.hwnd)
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
local menu_grace = false -- make the first click not close the menu
local menu_x = 0
local menu_y = 0
local menu_is_hovered = false

love.update = function(dt)
    if port.should_try_mouse_event then
        port.try_mouse_event(love.handlers['mousepressed'], love.handlers['mousereleased'], love.handlers['mousemoved'])
    end
    clock = clock + dt
    Slab.Update(dt)

    if menu_visible then
        Slab.BeginWindow('Menu', {Title = "Menu", X = menu_x, Y = menu_y})
        Slab.Text("Hello World")
        port.user_config_gui(Slab)
        if Slab.Button("Quit") then
            love.event.quit()
        end
        Slab.EndWindow()
        menu_is_hovered = not Slab.IsVoidHovered()
    end

    if target == nil then
        target = dragon_obj.body.target_joint.pos
    end

    local mouse_pos = mgl.vec2(port.get_mouse_pos())

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
    if button == 2 then
        menu_visible = true
        menu_grace = true
        menu_x = x
        menu_y = y
    end
end

love.mousereleased = function(x, y, button, ...)
end

love.quit = function()
    log.info("Begin quiting")
    log.info("saving config")
    user_config.save_to_file()
    log.warn("Quiting...")
end
