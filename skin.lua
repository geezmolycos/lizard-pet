
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

function Line:set()
end

function Line:draw()
    love.graphics.line(
        self.base_joint.pos.x, self.base_joint.pos.y,
        self.head_joint.pos.x, self.head_joint.pos.y
    )
end

return skin
