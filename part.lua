
local part = {}

local mgl = require "MGL"
local skeleton = require "skeleton"
local skin = require "skin"

local Part = {}
part.Part = Part

function Part:new()
    local inst = setmetatable({}, {__index = self})
    return inst
end

return part
