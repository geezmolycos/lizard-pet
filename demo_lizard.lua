
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
    for _, name in ipairs({'fixation', 'elbow', 'paw', 'current_target'}) do
        local patch = skin.Circle:new(self[name])
        patch:set('line', 3)
        table.insert(self.patches, patch)
    end
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
    self.fixation.pos = self.root_joint.pos
    self.elbow.pos = elbow_pos
    self.paw.pos = paw_pos
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
    self:update_children(args)
end

function LizardLeg:draw(args)
    for _, patch in ipairs(self.patches) do
        patch:draw()
    end
end

return demo_lizard
