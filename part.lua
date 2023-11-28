
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
    return inst
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
    return inst
end

function Part:on_message(args)
end

function Part:message(path, args)
    if #path >= 0 then
        -- recursive
        local current_level = path[1]
        local rest = {table.unpack(path, 1)}
        if self.children.t[current_level] == nil then
            error(current_level .. ' does not exist')
        end
        self.children.t[current_level]:message(rest, args)
    end
    self:on_message(args)
end

function Part:update_children(args)
    for id, child in pairs(self.children.t) do
        child.update(args)
    end
end

return part
