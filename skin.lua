------
-- 皮肤模块，包括基于骨骼的简单的图形绘制
-- 适合绘制简单的类似昆虫、爬行动物的肢体

local skin = {}

local mgl = require "MGL"
local skeleton = require "skeleton"

local SingleJoint = {}
skin.SingleJoint = SingleJoint

function SingleJoint:new(joint)
    local inst = setmetatable({}, {__index = self})
    inst.joint = joint
    return inst
end

local Circle = setmetatable({}, {__index = SingleJoint})
skin.Circle = Circle

function Circle:set(mode, radius)
    self.mode = mode
    self.radius = radius
end

function Circle:draw()
    love.graphics.circle(self.mode,
        self.joint.pos.x, self.joint.pos.y,
        self.radius
    )
end

local Square = setmetatable({}, {__index = SingleJoint})
skin.Square = Square

function Square:set(mode, radius)
    self.mode = mode
    self.radius = radius
end

function Square:draw()
    love.graphics.rectangle(self.mode,
        self.joint.pos.x - self.radius, self.joint.pos.y - self.radius,
        2 * self.radius, 2 * self.radius
    )
end

local DoubleJoint = {}
skin.DoubleJoint = DoubleJoint

function DoubleJoint:new(base_joint, head_joint)
    local inst = setmetatable({}, {__index = self})
    inst.base_joint = base_joint
    inst.head_joint = head_joint
    return inst
end

local Line = setmetatable({}, {__index = DoubleJoint})
skin.Line = Line

function Line:set()
end

function Line:draw()
    love.graphics.line(
        self.base_joint.pos.x, self.base_joint.pos.y,
        self.head_joint.pos.x, self.head_joint.pos.y
    )
end

local CircleSeries = setmetatable({}, {__index = DoubleJoint})
skin.CircleSeries = CircleSeries

function CircleSeries:set(mode, radii)
    self.mode = mode
    self.radii = radii
end

function CircleSeries:set_from_to(mode, n, radius_from, radius_to)
    self.mode = mode
    local radii = {}
    for i = 0, n+1 do
        table.insert(radii, radius_from + (radius_to - radius_from) * i / (n+1))
    end
    self.radii = radii
end

function CircleSeries:draw()
    local from = self.base_joint.pos
    local to = self.head_joint.pos
    local n = #self.radii - 1
    for i, radius in ipairs(self.radii) do
        local pos = from + (to - from) * (i-1) / n
        love.graphics.circle(self.mode,
            pos.x, pos.y,
            radius
        )
    end
end

return skin
