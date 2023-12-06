
local draw_modifier = {}

local mgl = require "MGL"

function draw_modifier.color(color, f)
    return function (...)
        local old_color = {love.graphics.getColor()}
        love.graphics.setColor(unpack(color))
        local ret = f(...)
        love.graphics.setColor(unpack(old_color))
        return ret
    end
end

function draw_modifier.line_width(width, f)
    return function (...)
        local old_width = love.graphics.getLineWidth()
        love.graphics.setLineWidth(width)
        local ret = f(...)
        love.graphics.setLineWidth(old_width)
        return ret
    end
end

function draw_modifier.transform(transform, f)
    return function (...)
        love.graphics.push()
        love.graphics.applyTransform(transform)
        local ret = f(...)
        love.graphics.pop()
        return ret
    end
end

function draw_modifier.combine(...)
    local ff = {...}
    return function (...)
        local rets = {}
        for i, f in ipairs(ff) do
            rets[i] = f(...)
        end
        return rets
    end
end

return draw_modifier
