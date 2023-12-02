
local draw_modifier = {}

local mgl = require "MGL"

function draw_modifier.color(f, color)
    return function (args)
        local old_color = {love.graphics.getColor()}
        love.graphics.setColor(unpack(color))
        local ret = f(args)
        love.graphics.setColor(unpack(old_color))
        return ret
    end
end

function draw_modifier.transform(f, transform)
    return function (args)
        love.graphics.push()
        love.graphics.applyTransform(transform)
        local ret = f(args)
        love.graphics.pop()
        return ret
    end
end

function draw_modifier.combine(...)
    local ff = {...}
    return function (args)
        local rets = {}
        for i, f in ipairs(ff) do
            rets[i] = f(args)
        end
        return rets
    end
end

return draw_modifier
