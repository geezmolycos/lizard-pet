local lovePhysics = require("love.physics")

-- Variables
local chain = {} -- Array to store chain links
local world -- Physics world
local mouseJoint -- Joint between mouse and chain link
local selectedLink -- Selected chain link

function love.load()
    -- Initialize physics world
    love.physics.setMeter(64)
    world = love.physics.newWorld(0, 9.81 * 64, true)

    -- Create ground body
    local groundBody = love.physics.newBody(world, love.graphics.getWidth() / 2, love.graphics.getHeight() - 50)
    local groundShape = love.physics.newRectangleShape(love.graphics.getWidth(), 100)
    local groundFixture = love.physics.newFixture(groundBody, groundShape)

    -- Create chain links
    local startX = love.graphics.getWidth() / 2 - 100
    local startY = love.graphics.getHeight() / 2

    for i = 1, 100 do
        local linkBody = love.physics.newBody(world, startX + (i - 1) * 30, startY, "dynamic")
        local linkShape = love.physics.newRectangleShape(20, 10)
        local linkFixture = love.physics.newFixture(linkBody, linkShape)

        -- Store link in chain array
        chain[i] = {
            body = linkBody,
            shape = linkShape,
            fixture = linkFixture
        }

        -- Connect links with RevoluteJoint
        if i > 1 then
            local prevLink = chain[i - 1].body
            local joint = love.physics.newRevoluteJoint(prevLink, linkBody, startX + (i - 2) * 30 + 20, startY)
            joint:setLimitsEnabled(true)
            joint:setLimits(-math.pi / 4, math.pi / 4)
        end
    end
end

function love.update(dt)
    -- Update physics simulation
    world:update(dt)

    -- Update mouse joint position
    if mouseJoint and selectedLink then
        local mouseX, mouseY = love.mouse.getPosition()
        mouseJoint:setTarget(mouseX, mouseY)
    end
end

function love.mousepressed(x, y, button)
    -- Check if mouse is clicked on a chain link
    for i, link in ipairs(chain) do
        if link.fixture:testPoint(x, y) then
            selectedLink = link

            -- Create mouse joint
            mouseJoint = love.physics.newMouseJoint(link.body, x, y)
            mouseJoint:setMaxForce(1000000 * link.body:getMass())
            mouseJoint:setTarget(x, y)
            break
        end
    end
end

function love.mousereleased(x, y, button)
    -- Destroy mouse joint
    if mouseJoint and selectedLink then
        mouseJoint:destroy()
        mouseJoint = nil
        selectedLink = nil
    end
end

function love.draw()
    -- Draw ground body
    love.graphics.setColor(0.5, 0.5, 0.5)
    -- love.graphics.polygon("fill", world:getGround():getWorldPoints(groundFixture:getShape():getPoints()))

    -- Draw chain links
    love.graphics.setColor(1, 1, 1)
    for i, link in ipairs(chain) do
        love.graphics.polygon("fill", link.body:getWorldPoints(link.shape:getPoints()))
    end
end