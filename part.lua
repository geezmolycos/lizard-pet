
local part = {}

local mgl = require "MGL"
local skeleton = require "skeleton"
local skin = require "skin"

local path_sentinel = {_path_sentinel = true}

local IDTable = {}
part.IDTable = IDTable

function IDTable:new()
    local inst = setmetatable({}, {__index = self})
    inst.t = {}
    inst.id = 0
end

function IDTable:add(thing)
    local id = self.id
    self.t[id] = thing
    self.id = id + 1
    return id
end

local Part = {}
part.Part = Part

function Part:new()
    local inst = setmetatable({}, {__index = self})
    inst.children = IDTable:new()
    inst.joints = IDTable:new()
    inst.callables = IDTable:new()
    inst.patches = IDTable:new()
    inst.update_list = {}
    inst.draw_list = {}
    return inst
end

function Part:call_at_path(path, args)
    if #path >= 1 then
        -- recursive
        local current_level = path[1]
        local rest = {table.unpack(path, 1)}
        if self.children.t[current_level] == nil then
            error(current_level .. ' does not exist')
        end
        self.children.t[current_level]:call_at_path(rest, args)
    end
    local patch_name = path[1]
    if patch_name == path_sentinel then
        self:update(args)
    else
        self.callables[patch_name](args)
    end
end

function Part:update(args)
    for thing in self.update_list do
        if type(thing) == 'function' then
            thing(args)
        else
            self:call_at_path(thing, args)
        end
    end
end

function Part:quick_add_update(callable)
    local id = self.callables:add(callable)
    table.insert(self.update_list, {id})
end

function Part:draw_at_path(path, args)
    if #path >= 1 then
        -- recursive
        local current_level = path[1]
        local rest = {table.unpack(path, 1)}
        if self.children.t[current_level] == nil then
            error(current_level .. ' does not exist')
        end
        self.children.t[current_level]:draw_at_path(rest, args)
    end
    local patch_name = path[1]
    if patch_name == path_sentinel then
        self:draw(args)
    else
        self.patches[patch_name].draw(args)
    end
end

function Part:draw(args)
    for thing in self.draw_list do
        if type(thing) == 'function' then
            thing(args)
        else
            self:draw_at_path(thing, args)
        end
    end
end

function Part:quick_add_draw(patch)
    local id = self.patches:add(patch)
    table.insert(self.draw_list, {id})
end

