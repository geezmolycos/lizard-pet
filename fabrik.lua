
local fabrik = {}

local inspect = require "inspect"
local mgl = require "MGL"

-- https://github.com/lincerely/gecko/tree/master
-- https://sean.cm/a/fabrik-algorithm-2d

function fabrik.link(length)
    return {
        length = length
    }
end

function fabrik.constraint(fixed, moving, angle_min, angle_max)
    return {
        fixed = fixed,
        moving = moving,
        angle_min = angle_min,
        angle_max = angle_max
    }
end

local Joint = {}
Joint.__index = Joint
fabrik.Joint = Joint

function Joint.new(pos)
    local self = setmetatable({}, Joint)
    self.neighbors = {}
    self.neighbor_count = 0
    self.influences = {}
    self.influence_count = 0
    self.constraints = {}
    self.pos = pos or mgl.vec2(0, 0)
    return self
end

function Joint:add_neighbor(joint, link)
    if self.neighbors[joint] == nil then
        -- update count
        self.neighbor_count = self.neighbor_count + 1
        joint.neighbor_count = joint.neighbor_count + 1
    end
    self.neighbors[joint] = link
    joint.neighbors[self] = link
end

function Joint:add_influence(joint, pos)
    if self.influences[joint] == nil then
        -- update count
        self.influence_count = self.influence_count + 1
    end
    self.influences[joint] = pos
end

function Joint:clear_influence()
    self.influences = {}
    self.influence_count = 0
end

function Joint:get_influence(joint)
    if self.influences[joint] ~= nil then
        return self.influences[joint]
    else
        return self.pos
    end
end

function Joint:add_constraint(constraint)
    table.insert(self.constraints, constraint)
end

function Joint:update_pos()
    if self.influence_count == 0 then return end
    local centroid = mgl.vec2(0, 0)
    local i = 0
    for joint, pos in pairs(self.influences) do
        centroid = centroid + pos
        i = i + 1
    end
    centroid = centroid / i
    self.pos = centroid
    self:clear_influence()
end

function Joint:influence_lengths(without)
    for joint, link in pairs(self.neighbors) do
        if joint ~= without then
            local new_joint_pos = self.pos + mgl.normalize(joint.pos - self.pos) * link.length
            joint:add_influence(self, new_joint_pos)
        end
    end
end

function Joint:influence_constraints(without)
    for i, constraint in ipairs(self.constraints) do
        if constraint.moving ~= without then
            local to_fixed = constraint.fixed:get_influence(self) - self.pos
            local to_moving = constraint.moving:get_influence(self) - self.pos
            local angle_to_fixed = math.atan2(to_fixed.y, to_fixed.x)
            local angle_to_moving = math.atan2(to_moving.y, to_moving.x)
            local angle_to_moving_min = (angle_to_fixed + constraint.angle_min) % (2*math.pi)
            local angle_to_moving_max = (angle_to_fixed + constraint.angle_max) % (2*math.pi)
            local angle_half = (angle_to_moving_max - angle_to_moving_min) % (2*math.pi) / 2
            local angle_mid = (angle_to_moving_max - angle_half) % (2*math.pi)
            local shifted_angle = (angle_to_moving - angle_mid) % (2*math.pi)
            -- choose the nearest valid angle
            if angle_half < shifted_angle and shifted_angle < math.pi then
                shifted_angle = angle_half
            elseif math.pi <= shifted_angle and shifted_angle < 2*math.pi - angle_half then
                shifted_angle = 2*math.pi - angle_half
            end
            -- shift back
            angle_to_moving = (shifted_angle + angle_mid) % (2*math.pi)
            to_moving = mgl.length(to_moving) * mgl.vec2(math.cos(angle_to_moving), math.sin(angle_to_moving))
            constraint.moving:add_influence(self, self.pos + to_moving)
        end
    end
end

function Joint:influence_all(without)
    self:influence_lengths(without)
    self:influence_constraints(without)
end

function Joint:influence_recursive(without)
    self:influence_all(without)
    for joint, link in pairs(self.neighbors) do
        if joint ~= without then
            if joint.influence_count >= joint.neighbor_count - 1 then
                joint:update_pos()
                joint:influence_recursive(self)
            end
        end
    end
end

function Joint:finish_recursive()
    self:update_pos()
    for joint, link in pairs(self.neighbors) do
        joint:finish_recursive()
    end
end

return fabrik
