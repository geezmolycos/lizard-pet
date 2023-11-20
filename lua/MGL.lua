-- https://github.com/ImagicTheCat/MGL
-- MIT license (see LICENSE or MGL.lua)
--[[
MIT License

Copyright (c) 2020 ImagicTheCat

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
]]

local xtype = require("xtype")
local table_unpack = table.unpack or unpack
local loadstring = loadstring or load

-- MGL interface/data.

local mgl_mt = {}
local mgl = setmetatable({}, mgl_mt)

-- Handle MGL loaders.
local loaders = {} -- map of pattern => loader
function mgl_mt.__index(t, k)
  if type(k) ~= "string" then return end
  for pattern, loader in pairs(loaders) do
    local pr = {string.match(k, pattern)}
    if #pr > 0 then
      local v = loader(table_unpack(pr))
      t[k] = v
      return v
    end
  end
end

-- Add MGL loader.
-- pattern: Lua pattern
-- callback(...): called when an undefined field is accessed with the specified pattern
--- ...: pattern captures (returned by string.match)
--- should return the field value
function mgl.addLoader(pattern, callback)
  loaders[pattern] = callback
end

-- Generate function.
-- name: identify the generated function for debug
function mgl.genfunc(code, name)
  local f, err = loadstring(code, "MGL generated "..name)
  if not f then error(err) end
  return f
end

-- Initialize operation multifunctions.
-- ...: list of identifiers
function mgl.initmfs(...)
  for _, id in ipairs({...}) do
    if not rawget(mgl, id) then mgl[id] = xtype.multifunction() end
  end
end

-- Load modules.
require("MGL.scalar")(mgl)
require("MGL.vector")(mgl)
require("MGL.matrix")(mgl)
require("MGL.transform")(mgl)

return mgl
