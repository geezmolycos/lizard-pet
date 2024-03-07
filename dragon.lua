
local dragon = {}

local mgl = require "MGL"
local skeleton = require "skeleton"
local skin = require "skin"
local part = require "part"
local draw_modifier = require "draw_modifier"
local perlin = require "perlin"

local Body = setmetatable({}, {__index = part.Part})
dragon.Body = Body

function Body:build(target_joint, length, head_pos, delta_pos)
    self.target_joint = target_joint
    self.head = skeleton.Joint:new(head_pos)
    self.target_joint:add_neighbor(self.head, {
        length_min = 30,
        length_max = 60,
        length_absolute_min = 1,
        length_absolute_max = 1e5,
        speed = 500,
        exponential = false,
        drag = 0
    })
    self.joints = {self.head}
    local joint_pos = head_pos
    local delta_length = mgl.length(delta_pos)
    for i = 2, length do
        joint_pos = joint_pos + delta_pos
        local joint = skeleton.Joint:new(joint_pos)
        self.joints[#self.joints]:add_mutual_neighbor(joint, skeleton.link(delta_length, delta_length, 1e5))
        table.insert(self.joints, joint)
    end
    for i = 3, length-1 do
        local c
        if i > 5 and i < 14 then
            c = skeleton.constraint(
                self.joints[i-1],
                self.joints[i+1],
                math.pi*63/64,
                math.pi*65/64,
                math.pi
            )
        else
            c = skeleton.constraint(
                self.joints[i-1],
                self.joints[i+1],
                math.pi*14/16,
                math.pi*18/16,
                math.pi
            )
        end
        self.joints[i]:add_constraint(c)
    end
    self.patches = {}
    local size = {4,9,6,7, 7,7,7,7, 9,7,6,4, 3,2,2,2, 2,2,1,1, 1,0}
    for i = 1, #self.joints-1 do
        local patch = skin.CircleSeries:new(self.joints[i], self.joints[i+1])
        patch:set_from_to('fill', 4, size[i], size[i+1])
        table.insert(self.patches, patch)
    end
end

function Body:destroy()
    if self.joints and #self.joints > 0 then
        self.target_joint:remove_neighbor(self.joints[1])
    end
end

function Body:update(args)
    self.target_joint.pos = args.mouse_pos
    if not args.speed then args.speed = 1 end
    self.target_joint:influence_recursive(nil, args.time * args.speed)
end

function Body:draw(args)
    for _, patch in ipairs(self.patches) do
        patch:draw(args)
    end
end


local Wing = setmetatable({}, {__index = part.Part})
dragon.Wing = Wing

Wing.spread_pos = {
    main_front = {0, -10},
    main_root = {0, 0},
    elbow = {40, 10},
    paw = {80, -20},
    finger1 = {120, -40},
    finger2 = {190, 0},
    finger3 = {160, 20},
    finger4 = {100, 40},
    hind_front = {0, -10},
    hind_root = {0, 0},
    hind = {30, 40}
}

local bounce_speed = 10000
local fast_speed = 100
local fast_angular_speed_exp = 3
local walk_speed = 50

function Wing:main_rel_to_global()
    local attach_to_front = self.main_front.pos - self.main_attach.pos
    local attach_to_front_dir = mgl.normalize(attach_to_front)
    local attach_to_front_angle = math.atan2(attach_to_front_dir.y, attach_to_front_dir.x)
    local rel_to_global = mgl.translate(self.main_attach.pos) * mgl.rotate(attach_to_front_angle)
    return rel_to_global * self.transform
end

function Wing:hind_rel_to_global()
    local attach_to_front = self.hind_front.pos - self.hind_attach.pos
    local attach_to_front_dir = mgl.normalize(attach_to_front)
    local attach_to_front_angle = math.atan2(attach_to_front_dir.y, attach_to_front_dir.x)
    local rel_to_global = mgl.translate(self.hind_attach.pos) * mgl.rotate(attach_to_front_angle)
    return rel_to_global * self.transform
end

function add_constraint(first, second, third, first_pos, second_pos, third_pos, alt_angle, strength, hardness)
    if not hardness then hardness = 1 end
    local to_first = (first_pos or first.pos) - (second_pos or second.pos)
    local to_third = (third_pos or third.pos) - (second_pos or second.pos)
    local to_first_angle = math.atan2(to_first.y, to_first.x)
    local to_third_angle = math.atan2(to_third.y, to_third.x)
    local angle = to_first_angle - to_third_angle
    if alt_angle then
        -- local angle_diff = (math.rad(alt_angle) - angle) % (2*math.pi)
        local angle_diff = math.rad(alt_angle)
        angle = angle + angle_diff * strength
    end
    second:add_constraint(skeleton.constraint(
        third, first, angle, angle, fast_angular_speed_exp * hardness, true
    ))
    return angle
end

function curve(p1, p2, base, strength)
    local mid = (p1 + p2) / 2
    local mid_to_base = base - mid
    mid_to_base = mid_to_base * strength
    local new_base = mid + mid_to_base
    local c = love.math.newBezierCurve({p1.x, p1.y, new_base.x, new_base.y, p2.x, p2.y})
    return c
end

function Wing:build(main_attach, main_front, hind_attach, hind_front, hind_back, transform)
    self.main_attach = main_attach
    self.main_front = main_front
    self.hind_attach = hind_attach
    self.hind_front = hind_front
    self.hind_back = hind_back
    self.transform = transform
    local main_rel_to_global = self:main_rel_to_global()
    local hind_rel_to_global = self:hind_rel_to_global()
    self.joints = {}
    local names = {'main_root', 'elbow', 'paw', 'finger1', 'finger2', 'finger3', 'finger4', 'hind_root', 'hind'}
    local pos = Wing.spread_pos
    for k, v in pairs(pos) do
        pos[k] = mgl.vec2(v)
    end
    for _, name in ipairs(names) do
        local this_pos
        if string.sub(name, 1, 4) == 'hind' then
            this_pos = mgl.vec2(hind_rel_to_global * mgl.vec3(pos[name], 1))
        else
            this_pos = mgl.vec2(main_rel_to_global * mgl.vec3(pos[name], 1))
        end
        self.joints[name] = skeleton.Joint:new(this_pos)
    end
    -- neighbors
    local links = {
        main_root = {'elbow'},
        elbow = {'paw'},
        paw = {'finger1', 'finger2', 'finger3', 'finger4'},
        hind_root = {'hind'}
    }
    local width = {
        main_root = 4,
        elbow = 3,
        paw = 2,
        hind_root = 2
    }
    self.patches = {}
    for parent, children in pairs(links) do
        for _, child in pairs(children) do
            local length = mgl.length(self.joints[parent].pos - self.joints[child].pos)
            self.joints[parent]:add_mutual_neighbor(self.joints[child], skeleton.link(length, length, bounce_speed, false))
            local patch = skin.Line:new(self.joints[parent], self.joints[child])
            patch.draw = draw_modifier.line_width(width[parent], patch.draw)
            table.insert(self.patches, patch)
        end
    end
    self:spread(1)
end

function Wing:spread(strength)
    local main_rel_to_global = self:main_rel_to_global()
    local hind_rel_to_global = self:hind_rel_to_global()
    local pos = Wing.spread_pos
    local main_sign = mgl.determinant(main_rel_to_global)
    local hind_sign = mgl.determinant(hind_rel_to_global)
    function M(pos)
        return mgl.vec2(main_rel_to_global * mgl.vec3(pos, 1))
    end
    function H(pos)
        return mgl.vec2(hind_rel_to_global * mgl.vec3(pos, 1))
    end
    self.joints.main_root.constraints = {}
    self.joints.elbow.constraints = {}
    self.joints.paw.constraints = {}
    self.joints.hind_root.constraints = {}
    add_constraint(self.joints.elbow, self.joints.main_root, self.main_front,
        M(Wing.spread_pos.elbow), M(Wing.spread_pos.main_root), M(Wing.spread_pos.main_front), 70 * main_sign, 1-strength)
    add_constraint(self.joints.paw, self.joints.elbow, self.joints.main_root,
        M(Wing.spread_pos.paw), M(Wing.spread_pos.elbow), M(Wing.spread_pos.main_root), -120 * main_sign, 1-strength)
    for _, name in ipairs({'finger1', 'finger2', 'finger3', 'finger4'}) do
        add_constraint(self.joints[name], self.joints.paw, self.joints.elbow,
            M(Wing.spread_pos[name]), M(Wing.spread_pos.paw), M(Wing.spread_pos.elbow), ({150, 120, 110, 80})[_] * main_sign, 1-strength, 3)
    end
    add_constraint(self.joints.hind, self.joints.hind_root, self.hind_front,
        H(Wing.spread_pos.hind), H(Wing.spread_pos.hind_root), H(Wing.spread_pos.hind_front), 10 * hind_sign, 1-strength)
end

function Wing:flap(strength)
    local main_rel_to_global = self:main_rel_to_global()
    local hind_rel_to_global = self:hind_rel_to_global()
    local pos = Wing.spread_pos
    local main_sign = mgl.determinant(main_rel_to_global)
    local hind_sign = mgl.determinant(hind_rel_to_global)
    function M(pos)
        return mgl.vec2(main_rel_to_global * mgl.vec3(pos, 1))
    end
    function H(pos)
        return mgl.vec2(hind_rel_to_global * mgl.vec3(pos, 1))
    end
    self.joints.main_root.constraints = {}
    add_constraint(self.joints.elbow, self.joints.main_root, self.main_front,
        M(Wing.spread_pos.elbow), M(Wing.spread_pos.main_root), M(Wing.spread_pos.main_front), (140 - strength *140) * main_sign, 1-strength)
end

function Wing:update(args)
    self.joints.main_root.pos = self.main_attach.pos
    self.joints.main_root:influence_recursive(nil, args.time * args.speed)
    self.joints.hind_root.pos = self.hind_attach.pos
    self.joints.hind_root:influence_recursive(nil, args.time * args.speed)
end

function Wing:draw_membrane_triangle(p1, p2, base)
    love.graphics.polygon("fill", {base.x, base.y, p1.x, p1.y, p2.x, p2.y})
end

function Wing:draw_membrane(p1, p2, base, strength)
    local c = curve(p1, p2, base, strength)
    local vertices  = {base.x, base.y, unpack(c:render(3))}
    
    for i = 1, #vertices - 2, 2 do
        love.graphics.polygon("fill", {base.x, base.y, unpack(vertices, i, i+3)})
    end
end

function Wing:draw(args)
    -- draw wing membranes
    draw_modifier.color({.3, .3, .3}, function ()
        -- main membrane
        self:draw_membrane_triangle(self.joints.finger4.pos, self.joints.elbow.pos, self.joints.paw.pos)
        self:draw_membrane_triangle(self.joints.elbow.pos, self.joints.hind_root.pos, self.joints.main_root.pos)
        self:draw_membrane_triangle(self.joints.hind_root.pos, self.joints.hind.pos, self.joints.elbow.pos)
        self:draw_membrane(self.joints.finger4.pos, self.joints.hind.pos, self.joints.elbow.pos, 0.7)
        -- tail
        self:draw_membrane(self.joints.hind.pos, self.hind_back.pos, self.joints.hind_root.pos, 0.5)
        -- shoulder
        self:draw_membrane(self.joints.main_root.pos, self.joints.paw.pos, self.joints.elbow.pos, 0.5)
        -- webbing
        self:draw_membrane(self.joints.finger1.pos, self.joints.finger2.pos * 0.3 + self.joints.paw.pos * 0.7, self.joints.paw.pos, 0.3)
        self:draw_membrane(self.joints.finger2.pos, self.joints.finger3.pos, self.joints.paw.pos, 0.3)
        self:draw_membrane(self.joints.finger3.pos, self.joints.finger4.pos, self.joints.paw.pos, 0.3)
    end)()
    draw_modifier.color({.7, .7, .7}, function ()
        love.graphics.circle('fill', self.joints.main_root.pos.x * 0.8 + self.joints.elbow.pos.x * 0.2, self.joints.main_root.pos.y * 0.8 + self.joints.elbow.pos.y * 0.2, 5)
        love.graphics.circle('fill', self.joints.main_root.pos.x * 0.7 + self.joints.elbow.pos.x * 0.3, self.joints.main_root.pos.y * 0.7 + self.joints.elbow.pos.y * 0.3, 4)
        love.graphics.circle('fill', self.joints.paw.pos.x * 0.9 + self.joints.elbow.pos.x * 0.1, self.joints.paw.pos.y * 0.9 + self.joints.elbow.pos.y * 0.1, 3)
        love.graphics.circle('fill', self.joints.paw.pos.x, self.joints.paw.pos.y, 4)
        for _, patch in ipairs(self.patches) do
            patch:draw(args)
        end
    end)()
end

local Leg = setmetatable({}, {__index = part.Part})
dragon.Leg = Leg

function Leg:build(root_joint, front_joint, target, elbow_pos, air_pos, paw_angle, thickness)
    self.root_joint = root_joint
    self.front_joint = front_joint
    self.target = target
    self.elbow_pos = elbow_pos
    self.air_pos = air_pos
    self.paw_angle = paw_angle
    self.paw_length = 10
    self.air_stage = 0
    self.speed = 600
    self.air_speed_multiplier = 10
    self.step = 40
    self.fixation = skeleton.Joint:new()
    self.elbow = skeleton.Joint:new()
    self.paw = skeleton.Joint:new()
    self.current_target = skeleton.Joint:new()
    self:init_skeleton()
    self.patches = {}
    local names = {'fixation', 'elbow', 'paw'}
    local size = {7*thickness,4*thickness,4*thickness,5*thickness}
    for i = 1, #names-1 do
        local patch = skin.CircleSeries:new(self[names[i]], self[names[i+1]])
        patch:set_from_to('fill', 8, size[i], size[i+1])
        table.insert(self.patches, patch)
    end
end

function Leg:destroy()
end

function Leg:get_rel_to_global()
    local root_to_front = self.front_joint.pos - self.root_joint.pos
    local root_to_front_dir = mgl.normalize(root_to_front)
    local root_to_front_angle = math.atan2(root_to_front_dir.y, root_to_front_dir.x)
    local rel_to_global = mgl.translate(self.root_joint.pos) * mgl.rotate(root_to_front_angle)
    return rel_to_global
end

function Leg:init_skeleton()
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

    local elbow_to_fixation_angle = math.atan2(self.elbow_pos.y, self.elbow_pos.x)
    if elbow_to_fixation_angle < 0 then
        self.fixation:add_constraint(skeleton.constraint(
            self.front_joint,
            self.elbow,
            elbow_to_fixation_angle-math.pi,
            elbow_to_fixation_angle,
            12*math.pi
        ))
    else
        self.fixation:add_constraint(skeleton.constraint(
            self.front_joint,
            self.elbow,
            elbow_to_fixation_angle,
            elbow_to_fixation_angle+math.pi,
            12*math.pi
        ))
    end
    self.fixation.pos = self.root_joint.pos
    self.elbow.pos = elbow_pos
    self.paw.pos = paw_pos
    self.current_target.pos = paw_pos
end

function Leg:update(args)
    local rel_to_global = self:get_rel_to_global()
    local new_target = mgl.vec2(rel_to_global * mgl.vec3(self.target, 1))
    local current_target = self.current_target.pos
    if mgl.length(new_target - self.paw.pos) > self.step * 3 / 4 then
        args.half_step = true
    end
    if not args.stay and mgl.length(new_target - self.paw.pos) > self.step then
        current_target = new_target
        args.moved = true
    end
    if mgl.length(new_target - self.paw.pos) > 2 * self.step then
        current_target = new_target
        args.moved = true
    end
    if self.air_stage == 1 then
        local diff = mgl.vec2(rel_to_global * mgl.vec3(self.air_pos, 1)) - self.current_target.pos
        diff = diff / mgl.length(diff)
        current_target = self.current_target.pos + diff * args.time * 400
    end
    if self.air_stage == 2 then
        current_target = mgl.vec2(rel_to_global * mgl.vec3(self.air_pos, 1))
    end

    local multiplier = 1
    if self.air_stage == 1 then multiplier = 0.5 end
    if self.air_stage == 2 then multiplier = 5 end

    self.fixation.pos = self.root_joint.pos
    self.fixation:influence_recursive(nil, args.time/2 * multiplier)
    self.current_target.pos = current_target
    self.current_target:influence_recursive(nil, args.time/2 * multiplier)
end

function Leg:draw(args)
    local elbow_to_front = self.paw.pos - self.elbow.pos
    local front_angle = math.atan2(elbow_to_front.y, elbow_to_front.x)
    local paw_abs_angle = front_angle + self.paw_angle
    local paw_abs_direction = mgl.vec2(math.cos(paw_abs_angle), math.sin(paw_abs_angle))
    local paw_vector = paw_abs_direction * self.paw_length
    local paw_normal = mgl.vec2(mgl.rotate(90) * mgl.vec3(paw_vector, 1))
    local paw_pos = self.paw.pos + paw_vector
    love.graphics.setColor(.2, .2, .2)
    love.graphics.setLineWidth(14)
    love.graphics.line(self.paw.pos.x, self.paw.pos.y, paw_pos.x, paw_pos.y)
    love.graphics.circle('fill', paw_pos.x, paw_pos.y, 7)
    love.graphics.circle('fill', self.paw.pos.x, self.paw.pos.y, 7)
    draw_modifier.color({.5, .5, .5}, function ()
        for _, patch in ipairs(self.patches) do
            patch:draw()
        end
    end)()

    -- local rel_to_global = self:get_rel_to_global()
    -- local new_target = mgl.vec2(rel_to_global * mgl.vec3(self.target, 1))
    -- love.graphics.circle('line', new_target.x, new_target.y, 10)
    -- local current_target = mgl.vec2(mgl.vec3(self.current_target.pos, 1))
    -- love.graphics.circle('line', current_target.x, current_target.y, 10)
end

function Leg:air(air_stage)
    self.air_stage = air_stage
end

return dragon