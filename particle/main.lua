-- Initialize the particle system
local particleSystem

function love.load()
    love.graphics.setBackgroundColor(1, 1, 1)
    -- Create a new particle system
    particleSystem = love.graphics.newParticleSystem(love.graphics.newImage("particle.png"), 1000)
    
    -- Set the position of the particle system
    particleSystem:setPosition(400, 300)
    
    -- Set the lifetime of the particles
    particleSystem:setParticleLifetime(1, 5)
    particleSystem:setEmissionRate( 10 )
    
    -- Set the size of the particles
    particleSystem:setSizes(0.5, 1, 0.5)
    
    -- Set the color of the particles
    particleSystem:setColors(255, 255, 255, 255, 255, 255, 255, 0)
    
    -- Set the acceleration of the particles
    particleSystem:setLinearAcceleration(-100, -100, 100, 100)
    
    -- Set the speed of the particles
    particleSystem:setSpeed(100, 200)
    
    -- Set the spread of the particles
    particleSystem:setSpread(2 * math.pi)
    
    -- Start emitting particles
    particleSystem:start()
end

function love.update(dt)
    -- Update the particle system
    particleSystem:update(dt)
end

function love.draw()
    -- Draw the particle system
    love.graphics.draw(particleSystem, 0, 0)
end