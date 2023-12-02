
local demo_lizard = {}

local mgl = require "MGL"
local skeleton = require "skeleton"
local skin = require "skin"
local part = require "part"

local LizardLeg = setmetatable({}, {__index = part.Part})
demo_lizard.LizardLeg = LizardLeg

function LizardLeg:build(root_joint, front_joint, target, elbow_pos)
    self.root_joint = root_joint
    self.front_joint = front_joint
    self.target = target
    self.elbow_pos = elbow_pos
    self.speed = 800
    self.step = 40
    self.fixation = skeleton.Joint:new()
    self.elbow = skeleton.Joint:new()
    self.paw = skeleton.Joint:new()
    self.current_target = skeleton.Joint:new()
    self:init_skeleton()
    self.patches = {}
    local names = {'fixation', 'elbow', 'paw', 'current_target'}
    local size = {5,2,2,3}
    for i = 1, #names-1 do
        local patch = skin.CircleSeries:new(self[names[i]], self[names[i+1]])
        patch:set_from_to('fill', 4, size[i], size[i+1])
        table.insert(self.patches, patch)
    end
end

function LizardLeg:destroy()
end

function LizardLeg:get_rel_to_global()
    local root_to_front = self.front_joint.pos - self.root_joint.pos
    local root_to_front_dir = mgl.normalize(root_to_front)
    local root_to_front_angle = math.atan2(root_to_front_dir.y, root_to_front_dir.x)
    local rel_to_global = mgl.translate(self.root_joint.pos) * mgl.rotate(root_to_front_angle)
    return rel_to_global
end

function LizardLeg:init_skeleton()
    local rel_to_global = self:get_rel_to_global()
    local paw_pos_rel = self.target
    local elbow_len = mgl.length(self.elbow_pos)
    local paw_len = mgl.length(paw_pos_rel - self.elbow_pos)
    local paw_pos = mgl.vec2(rel_to_global * mgl.vec3(paw_pos_rel, 1))
    local elbow_pos = mgl.vec2(rel_to_global * mgl.vec3(self.elbow_pos, 1))
    self.fixation:add_mutual_neighbor(self.elbow, skeleton.link(elbow_len, elbow_len, 500))
    self.elbow:add_mutual_neighbor(self.paw, skeleton.link(paw_len, paw_len, 500))
    self.paw:add_mutual_neighbor(self.current_target, {
        length_min = 0.1,
        length_max = 1,
        length_absolute_min = 0.1,
        length_absolute_max = 1e5,
        speed = self.speed,
        exponential = false,
        drag = 0
    })

    local elbow_to_fixation_angle = math.atan2(-self.elbow_pos.y, -self.elbow_pos.x)
    local elbow_to_paw_angle = math.atan2((self.target - self.elbow_pos).y, (self.target - self.elbow_pos).x)
    local fixation_to_paw_angle = elbow_to_paw_angle - elbow_to_fixation_angle
    self.elbow:add_constraint(skeleton.constraint(
        self.fixation,
        self.paw,
        fixation_to_paw_angle - math.pi/2,
        fixation_to_paw_angle + math.pi/2,
        12*math.pi
    ))
    self.fixation.pos = self.root_joint.pos
    self.elbow.pos = elbow_pos
    self.paw.pos = paw_pos
    self.current_target.pos = paw_pos
end

function LizardLeg:update(args)
    local rel_to_global = self:get_rel_to_global()
    local new_target = mgl.vec2(rel_to_global * mgl.vec3(self.target, 1))
    local current_target = self.current_target.pos
    if mgl.length(new_target - self.paw.pos) > self.step then
        current_target = new_target
    end
    self.current_target.pos = current_target
    self.current_target:influence_recursive(nil, args.time/2)
    self.fixation.pos = self.root_joint.pos
    self.fixation:influence_recursive(nil, args.time/2)
    self.current_target.pos = current_target
end

function LizardLeg:draw(args)
    for _, patch in ipairs(self.patches) do
        patch:draw()
    end
end

local LizardBody = setmetatable({}, {__index = part.Part})
demo_lizard.LizardBody = LizardBody

function LizardBody:build(target_joint, length, head_pos, delta_pos)
    self.target_joint = target_joint
    self.head = skeleton.Joint:new(head_pos)
    self.target_joint:add_neighbor(self.head, {
        length_min = 30,
        length_max = 60,
        length_absolute_min = 1,
        length_absolute_max = 1e5,
        speed = 50,
        exponential = false,
        drag = 0
    })
    self.joints = {self.head}
    local joint_pos = head_pos
    local delta_length = mgl.length(delta_pos)
    for i = 2, length do
        joint_pos = joint_pos + delta_pos
        local joint = skeleton.Joint:new(joint_pos)
        self.joints[#self.joints]:add_mutual_neighbor(joint, skeleton.link(delta_length, delta_length, 500))
        table.insert(self.joints, joint)
    end
    for i = 3, length-1 do
        local c = skeleton.constraint(
            self.joints[i-1],
            self.joints[i+1],
            math.pi*7/8,
            math.pi*9/8,
            math.pi/2
        )
        self.joints[i]:add_constraint(c)
    end
    self.patches = {}
    local size = {4,9,6,7, 7,5,5,4, 3,2,2,2, 1,1,0}
    for i = 1, #self.joints-1 do
        local patch = skin.CircleSeries:new(self.joints[i], self.joints[i+1])
        patch:set_from_to('fill', 4, size[i], size[i+1])
        table.insert(self.patches, patch)
    end
end

function LizardBody:destroy()
    if self.joints and #self.joints > 0 then
        self.target_joint:remove_neighbor(self.joints[1])
    end
end

function LizardBody:update(args)
    self.target_joint.pos = args.mouse_pos
    self.target_joint:influence_recursive(nil, args.time)
end

function LizardBody:draw(args)
    for _, patch in ipairs(self.patches) do
        patch:draw()
    end
end

return demo_lizard
