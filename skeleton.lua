------
-- 骨骼模块，包含结点、长度约束和角度约束
-- 运作物理特性

local skeleton = {}

local mgl = require "MGL"

--- 线性插值
-- @param a 起始值
-- @param b 终止值
-- @param t 时间/位置，取0时返回a，取1时返回b
function skeleton.lerp(a, b, t)
    return a + t * (b-a)
end

--- 生成一个长度约束的表，可以用来把两个结点连接到一起.
-- 使用 fabrik 算法，详见参考：
-- <https://github.com/lincerely/gecko/tree/master>
-- <https://sean.cm/a/fabrik-algorithm-2d>
-- @param length_min
-- @param length_max
-- @param speed 一端结点移动时，另一端结点最大的移动速度。非 `exponential` 的情况下，为像素/秒，而 `exponential` 的情况下，为相对值
-- @param exponential 是否让移动速度随距离指数型衰减，效果更有弹力
-- @param drag 0~1 值，一端移动会带动另一端以相同方式移动
-- @return table, 可以用来给 @{Joint:add_neighbor} 使用
function skeleton.link(length_min, length_max, speed, exponential, drag)
    return {
        length_min = length_min,
        length_max = length_max or length_min,
        length_absolute_min = length_min / 2,
        length_absolute_max = length_max * 2,
        speed = speed or 1.0,
        exponential = exponential or false,
        drag = drag or 0.0
    }
end

--- 生成一个角度约束的表，用来限制和某个结点相连的两个其他结点的角度.
-- 使用 fabrik 算法，详见参考：
-- <https://github.com/lincerely/gecko/tree/master>
-- <https://sean.cm/a/fabrik-algorithm-2d>
-- @param fixed 作为参考的结点，这个约束只会控制以下的 moving 结点
-- @param moving 受控制的结点
-- @param angle_min 角度下限（弧度）
-- @param angle_max 角度上限（弧度）
-- @param speed 速度（类似 @{link}）
-- @param exponential 指数衰减（类似 @{link}）
-- @param drag 拖拽（类似 @{link}）
-- @return table, 可以用来给 @{Joint:add_constraint} 使用
function skeleton.constraint(fixed, moving, angle_min, angle_max, speed, exponential, drag)
    return {
        fixed = fixed,
        moving = moving,
        angle_min = angle_min,
        angle_max = angle_max,
        speed = speed or 1.0,
        exponential = exponential or false,
        drag = drag or 0.0
    }
end

local Joint = {}
skeleton.Joint = Joint

--- 创建一个结点
-- @param pos 初始位置，默认为 (0, 0)
function Joint:new(pos)
    local inst = setmetatable({}, {__index = self})
    inst.neighbors = {}
    inst.neighbor_count = 0
    inst.influences = {}
    inst.influence_count = 0
    inst.constraints = {}
    inst.pos = pos or mgl.vec2(0, 0)
    inst.drag_translate = mgl.vec2(0, 0)
    inst.drag_rotate = 0
    return inst
end

--- 添加邻居结点.
-- 这个只是单向的，一般肯定要添加双向的，请用@{Joint:add_mutual_neighbor}
-- @param joint 邻居结点
-- @param link 长度约束
-- @see link
function Joint:add_neighbor(joint, link)
    if self.neighbors[joint] == nil then
        -- update count
        self.neighbor_count = self.neighbor_count + 1
    end
    self.neighbors[joint] = link
end

--- 移除邻居结点
-- @param joint 邻居结点
function Joint:remove_neighbor(joint)
    if self.neighbors[joint] ~= nil then
        self.neighbor_count = self.neighbor_count - 1
    end
    self.neighbors[joint] = nil
end

--- 添加相互的邻居结点
-- @param joint 邻居结点
-- @param link 长度约束
-- @see Joint:add_neighbor
function Joint:add_mutual_neighbor(joint, link)
    self:add_neighbor(joint, link)
    joint:add_neighbor(self, link)
end

--- 移除相互的邻居结点
-- @param joint 邻居结点
function Joint:remove_mutual_neighbor(joint)
    self:remove_neighbor(joint)
    joint:remove_neighbor(self)
end

--- 添加角度约束
-- @param constraint
-- @see constraint
function Joint:add_constraint(constraint)
    self.constraints[constraint] = true
end

--- 移除角度约束
-- @param constraint 需要和添加的时候是同一个表
function Joint:remove_constraint(constraint)
    self.constraints[constraint] = nil
end

--- 添加对其他结点的影响.
-- 影响可以包含 `pos`, `drag_translate`, `drag_rotate` 属性。
-- 每次更新时，首先会计算邻居的影响，再将各影响平均，最后得到最终位置
--
-- 该系列函数较底层，一般不会用到
-- @param joint 需要和添加的时候是同一个表
-- @param t 需要和添加的时候是同一个表
function Joint:add_influence(joint, t)
    if self.influences[joint] == nil then
        -- update count
        self.influence_count = self.influence_count + 1
    end
    self.influences[joint] = t
end

--- 清除影响
function Joint:clear_influence()
    self.influences = {}
    self.influence_count = 0
end

--- 获取某邻居对自身的影响
-- @param joint 邻居
function Joint:get_influence(joint)
    if self.influences[joint] ~= nil then
        return self.influences[joint]
    else
        return {
            pos = self.pos,
            drag_translate = mgl.vec2(0, 0),
            drag_rotate = 0
        }
    end
end

--- 根据影响更新自己的位置.
-- 较底层，一般不会用到
function Joint:update_pos()
    if self.influence_count == 0 then return end
    local centroid = mgl.vec2(0, 0)
    local i = 0
    for joint, t in pairs(self.influences) do
        centroid = centroid + t.pos
        i = i + 1
    end
    centroid = centroid / i
    self.pos = centroid
end

--- 根据影响中的拖拽因素更新自己的位置.
-- 较底层，一般不会用到
function Joint:update_drag()
    local translate = mgl.vec2(0, 0)
    local translate_count = 0
    local rotate = 0
    local rotate_count = 0
    for joint, t in pairs(self.influences) do
        if t.drag_translate then
            translate = translate + t.drag_translate
            translate_count = translate_count + 1
        end
        if t.drag_rotate then
            rotate = rotate + t.drag_rotate
            rotate_count = rotate_count + 1
        end
    end
    if translate_count ~= 0 then
        translate = translate / translate_count
    end
    self.drag_translate = translate
    if rotate_count ~= 0 then
        rotate = rotate / rotate_count
    end
    self.drag_rotate = rotate
end

--- 根据影响更新位置，考虑拖拽，并清除影响
function Joint:update_self()
    self:update_pos()
    self:update_drag()
    self:clear_influence()
end

--- 考虑长度约束条件，对邻居结点施加影响
-- @param without 要忽略的邻居结点
-- @param time 经过的时间长度
function Joint:influence_lengths(without, time)                                                                                                                            
    for joint, link in pairs(self.neighbors) do
        -- can use single joint or multiple joints
        if without == nil or joint ~= without and without[joint] == nil then
            local self_influence = joint:get_influence(self)
            local joint_pos = self_influence.pos
            local drag_translation = self.drag_translate * link.drag
            local drag_rotation = self.drag_rotate
            joint_pos = mgl.vec2(mgl.rotate(drag_rotation) * mgl.vec3(joint_pos + drag_translation - self.pos, 1)) + self.pos

            local to_joint = joint_pos - self.pos
            local dir_to_joint = mgl.normalize(to_joint)
            if dir_to_joint.x ~= dir_to_joint.x or dir_to_joint.y ~= dir_to_joint.y then
                dir_to_joint = mgl.vec2(1, 0) -- prevent singularity point
            end
            local length_to_joint = mgl.length(to_joint)
            local target_length = math.min(math.max(link.length_min, length_to_joint), link.length_max)
            local length_difference = target_length - length_to_joint
            local can_move_length = link.speed * time
            if link.exponential then
                can_move_length = can_move_length * math.abs(length_difference)
            end
            local moved_length
            if length_difference >= 0 then
                moved_length = math.min(can_move_length, length_difference)
            else
                moved_length = math.max(-can_move_length, length_difference)
            end
            local new_length = length_to_joint + moved_length
            new_length = math.min(math.max(link.length_absolute_min, new_length), link.length_absolute_max)
            local translate = moved_length * dir_to_joint
            local new_joint_pos = self.pos + new_length * dir_to_joint
            joint:add_influence(self, {
                pos = new_joint_pos,
                drag_translate = self_influence.drag_translate + translate + drag_translation,
                drag_rotate = self_influence.drag_rotate
            })
        end
    end
end

--- 考虑角度约束条件，对邻居结点施加影响
-- @param without 要忽略的邻居结点
-- @param time 经过的时间长度
function Joint:influence_constraints(without, time)
    local i = 0
    for constraint, _ in pairs(self.constraints) do
        i = i + 1
        if without == nil or constraint.moving ~= without and without[constraint.moving] == nil then
            local fixed_influence = constraint.fixed:get_influence(self)
            local moving_influence = constraint.moving:get_influence(self)
            local to_fixed = fixed_influence.pos - self.pos
            local to_moving = moving_influence.pos - self.pos
            local angle_to_fixed = math.atan2(to_fixed.y, to_fixed.x)
            local angle_to_moving = math.atan2(to_moving.y, to_moving.x)
            local angle_to_moving_min = (angle_to_fixed + constraint.angle_min) % (2*math.pi)
            local angle_to_moving_max = (angle_to_fixed + constraint.angle_max) % (2*math.pi)
            local angle_half = (angle_to_moving_max - angle_to_moving_min) % (2*math.pi) / 2
            local angle_mid = (angle_to_moving_max - angle_half) % (2*math.pi)
            local shifted_angle = (angle_to_moving - angle_mid) % (2*math.pi)
            local angle_difference = 0
            -- choose the nearest valid angle
            if angle_half < shifted_angle and shifted_angle < math.pi then
                angle_difference = angle_half - shifted_angle
            elseif math.pi <= shifted_angle and shifted_angle < 2*math.pi - angle_half then
                angle_difference = 2*math.pi - angle_half - shifted_angle
            end
            local can_move_angle = constraint.speed * time
            if constraint.exponential then
                can_move_angle = can_move_angle * math.abs(angle_difference)
            end
            local moved_angle
            if angle_difference >= 0 then
                moved_angle = math.min(can_move_angle, angle_difference)
            else
                moved_angle = math.max(-can_move_angle, angle_difference)
            end
            angle_to_moving = (angle_to_moving + moved_angle) % (2*math.pi)
            local to_target = mgl.length(to_moving) * mgl.vec2(math.cos(angle_to_moving), math.sin(angle_to_moving))
            constraint.moving:add_influence(self, {
                pos = self.pos + to_target,
                drag_translate = moving_influence.drag_translate + to_target - to_moving, -- small arc is like line
                drag_rotate = moving_influence.drag_rotate + moved_angle * constraint.drag
            })
        end
    end
end

--- 考虑长度和角度约束条件，对邻居结点施加影响
-- @param without 要忽略的邻居结点
-- @param time 经过的时间长度
function Joint:influence_all(without, time)
    self:influence_lengths(without, time)
    self:influence_constraints(without, time)
end

--- 递归对邻居节点施加影响.
-- 该函数是主要使用的函数。
-- 例如让头运动带动身体，可以先改变头结点的坐标，然后让头结点递归施加影响，就带动了连接的身体结点。
-- @param without 要忽略的邻居结点
-- @param time 经过的时间长度
function Joint:influence_recursive(without, time)
    self:influence_all(without, time)
    for joint, link in pairs(self.neighbors) do
        if without == nil or joint ~= without and without[joint] == nil then
            joint:update_self()
            joint:influence_recursive(self, time)
        end
    end
end

function Joint:foreach(fn, without)
    fn(self)
    for joint, link in pairs(self.neighbors) do
        if joint ~= without then
            joint:foreach(fn, self)
        end
    end
end

local function shallow_copy(t)
    local t_new = {}
    for i, v in pairs(t) do
        t_new[i] = v
    end
    return t_new
end

function Joint:copy(without, without_new)
    local self_new = getmetatable(self).__index:new()
    -- copy neighbors and influences
    local copied = {[without] = without_new}
    for _, name in ipairs({'neighbors', 'influences'}) do
        for joint, link in pairs(self[name]) do
            if joint == without then
                self_new[name][without_new] = shallow_copy(link)
            else
                local joint_new = joint:copy(self, self_new)
                copied[joint] = joint_new
                self_new[name][joint_new] = shallow_copy(link)
            end
        end
    end
    self_new.neighbor_count = self.neighbor_count
    self_new.influence_count = self.influence_count
    -- copy constraints
    for constraint, _ in pairs(self.constraints) do
        local constraint_new = shallow_copy(constraint)
        constraint_new.fixed = copied[constraint.fixed]
        constraint_new.moving = copied[constraint.moving]
        self_new.constraints[constraint_new] = true
    end
    self_new.pos = self.pos
    self_new.drag_translate = self.drag_translate
    self_new.drag_rotate = self.drag_rotate
end

return skeleton
