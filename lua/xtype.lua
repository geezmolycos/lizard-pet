-- https://github.com/ImagicTheCat/lua-xtype
-- MIT license (see LICENSE or src/xtype.lua)
--[[
MIT License

Copyright (c) 2021 ImagicTheCat

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

local ffi
do
  local ok; ok, ffi = pcall(require, "ffi")
  ffi = ok and ffi or nil
end
local loadstring = loadstring or load
local table_unpack = table.unpack or unpack
local type, select, getmetatable, pcall = type, select, getmetatable, pcall
local table_pack = table.pack or function(...)
  local t = {...}
  t.n = select("#", ...)
  return t
end

local function error_arg(index, expected)
  error("bad argument #"..index.." ("..expected.." expected)")
end

-- xtype

local xtype = {}

local function xtype_tostring(t)
  local mt = getmetatable(t)
  mt.__tostring = nil
  local str = string.gsub(tostring(t), "table:", "xtype<"..t.xtype_name..">:", 1)
  mt.__tostring = xtype_tostring
  return str
end

local type_mt = {
  xtype = "xtype",
  __tostring = xtype_tostring
}

local xtype_is
-- Check if a value is a valid type.
local function xtype_check(t) return type(t) == "string" or xtype_is(t, "xtype") end
xtype.check = xtype_check
-- Check if an argument is a type.
local function check_type(v, index)
  if not xtype_check(v) then error_arg(index, "type") end
end

local ctype_types = {} -- map of ctype id => type

-- Get/bind a type to a ctype (LuaJIT FFI).
--
-- This can't be changed afterwards.
-- The same type can be bound to different ctypes; it can be useful when
-- different ctype qualifiers should match the same type.
--
-- ctype: cdata ctype object
-- t: (optional) type
-- return bound type
function xtype.ctype(ctype, t)
  local id = tonumber(ctype)
  if t and not ctype_types[id] then
    check_type(t, 2)
    ctype_types[id] = t
  end
  return ctype_types[id]
end

local function cdata_get(v) return v.__xtype end

-- Get terminal type of a value.
local function xtype_get(v)
  local v_type = type(v)
  if v_type == "table" or v_type == "userdata" then
    local mt = getmetatable(v)
    return mt and mt.xtype or v_type
  elseif v_type == "cdata" then
    local xt = ctype_types[tonumber(ffi.typeof(v))]
    if not xt then -- try to acquire type from field
      local ok; ok, xt = pcall(cdata_get, v)
      if ok then xtype.ctype(ffi.typeof(v), xt) end
    end
    return xt or v_type
  else return v_type end
end
xtype.get = xtype_get

-- Check if a value is of type t.
xtype_is = function(v, t)
  check_type(t, 2)
  local vt = xtype_get(v)
  if type(vt) == "table" then return vt.xtype_set[t] ~= nil
  else return vt == t end
end
xtype.is = xtype_is

-- Create a type.
--
-- The created type is a table with 3 fields: xtype_name, xtype_stack and xtype_set.
-- The table can be modified as long as the xtype fields are left untouched.
-- A default metatable is set; it can be replaced at the condition that the
-- type would still be recognized as a "xtype".
--
-- name: human-readable string (doesn't have to be unique)
-- ...: base types, ordered by descending proximity, to the least specific type
-- return created type
function xtype.create(name, ...)
  if type(name) ~= "string" then error_arg(1, "string") end
  -- check base types
  local bases = table_pack(...)
  for i=1, bases.n do check_type(bases[i], i+1) end
  -- create
  local t = setmetatable({
    xtype_name = name,
    xtype_stack = {},
    xtype_set = {}
  }, type_mt)
  -- append self
  table.insert(t.xtype_stack, t)
  t.xtype_set[t] = true
  -- Inherits from base types (some kind of cascade breadth first search).
  -- Each base type is evaluated left to right, with one type inheritance per step.
  local step = 1
  local browsing = true
  while browsing do
    browsing = false
    for _, base in ipairs(bases) do
      if type(base) == "string" then -- primitive type
        if step == 1 then
          browsing = true
          if not t.xtype_set[base] then
            t.xtype_set[base] = true
            table.insert(t.xtype_stack, base)
          end
        end
      else -- non-primitive type
        local st = base.xtype_stack[step]
        if st then
          browsing = true
          if not t.xtype_set[st] then
            t.xtype_set[st] = true
            table.insert(t.xtype_stack, st)
          end
        end
      end
    end
    step = step+1
  end
  return t
end

-- Check if a type is of type ot.
function xtype.of(t, ot)
  check_type(t, 1); check_type(ot, 2)
  if type(t) == "table" then return t.xtype_set[ot] ~= nil
  else return t == ot end
end

-- Get the name of a type.
-- return string or nothing if not a type
function xtype.name(t)
  if xtype_check(t) then return type(t) == "string" and t or t.xtype_name end
end

-- Multifunction.

local function multifunction_tostring(t)
  local mt = getmetatable(t)
  mt.__tostring = nil
  local str = string.gsub(tostring(t), "table:", "multifunction:", 1)
  mt.__tostring = multifunction_tostring
  return str
end

local multifunction = {}

-- Check and return signature (list of types).
-- ...: types
local function check_sign(...)
  local sign = table_pack(...)
  for i=1, sign.n do check_type(sign[i], i) end
  return sign
end
xtype.checkSign = check_sign

-- Return formatted signature string.
local function format_sign(sign)
  local names = {}
  for _, t in ipairs(sign) do
    table.insert(names, type(t) == "string" and t or t.xtype_name)
  end
  return "("..table.concat(names, ", ")..")"
end
xtype.formatSign = format_sign

-- Stack distance to another type from a terminal type.
-- ot: support "any" keyword
-- return distance or nil/nothing if not of type ot
local function type_dist(t, ot)
  if ot == "any" then -- special keyword
    return type(t) == "string" and 1 or #t.xtype_stack
  else
    if type(t) == "string" then return t == ot and 0 or nil end
    for i, st in ipairs(t.xtype_stack) do
      if st == ot then return i-1 end
    end
  end
end
xtype.typeDist = type_dist

-- Distance to another signature from a call signature.
-- osign: support "any" keyword
-- return distance or nothing if not generalizable to osign
local function sign_dist(sign, osign)
  local dist = 0
  for i=1, #sign do
    local tdist = type_dist(sign[i], osign[i])
    if not tdist then return end
    dist = dist+tdist
  end
  return dist
end
xtype.signDist = sign_dist

-- Create hash sign tree.
local function new_hsign()
  local count = 0
  local hasher_mt
  hasher_mt = {
    __index = function(t, k)
      count = count+1
      local st = setmetatable({count}, hasher_mt)
      t[k] = st
      return st
    end
  }
  local root = setmetatable({count}, hasher_mt)
  return root
end

-- Hash function signature.
-- sign: signature, list of types
-- return number
local function mf_hash_sign(self, sign)
  local node = self.hsign
  for _, t in ipairs(sign) do node = node[t] end
  return node[1]
end
multifunction.hashSign = mf_hash_sign

-- Find candidate.
-- return candidate or nothing if none found
--- candidate: {.sign, .dist, .def}
---- sign: call signature
---- dist: distance from call signature
---- def: candidate definition
local function mf_find_candidate(self, sign)
  -- find candidates
  local candidates = {}
  for hash, def in pairs(self.definitions) do
    if #sign == #def.sign then -- same number of parameters
      local dist = sign_dist(sign, def.sign)
      if dist then table.insert(candidates, {sign = sign, def = def, dist = dist}) end
    end
  end
  -- sort candidates
  table.sort(candidates, function(a, b) return a.dist < b.dist end)
  -- check for ambiguity
  if candidates[1] and candidates[2] and candidates[1].dist == candidates[2].dist then
    -- generate ambiguity error
    local candidate_signs = {}
    for _, candidate in ipairs(candidates) do
      if candidate.dist ~= candidates[1].dist then break end
      table.insert(candidate_signs, "\t"..format_sign(candidate.def.sign))
    end
    error("ambiguous call signature "..format_sign(sign).."\ncandidates:\n"..table.concat(candidate_signs, "\n"))
  end
  return candidates[1]
end

local function mf_resolve_sign(self, sign)
  local hash = mf_hash_sign(self, sign)
  local candidate = self.candidates[hash]
  if not candidate then
    candidate = mf_find_candidate(self, sign)
    if not candidate then -- re-try
      -- call generators
      for generator in pairs(self.generators) do generator(self, table_unpack(sign)) end
      candidate = mf_find_candidate(self, sign)
    end
    self.candidates[hash] = candidate
  end
  return candidate and candidate.def.f
end

-- Unoptimized multifunction call.
local function mf_call(self, ...)
  local sign = table_pack(...)
  for i=1, sign.n do sign[i] = xtype_get(sign[i]) end
  local f = mf_resolve_sign(self, sign)
  if not f then error("unresolved call signature "..format_sign(sign)) end
  return f(...)
end

local mfcalls = {}
-- Generate optimized multifunction call.
-- n: maximum number of parameters
local function gen_opt_mfcall(n)
  -- cache check
  local mfcall = mfcalls[n]
  if mfcall then return mfcall end
  -- generate code
  local main = [=[
local select = select
local xtype_get, mf_call = ...
return function(self, ...)
  -- optimized path
  local n = select("#", ...)
  local hash
  --
  $hash_code
  --
  local candidate = self.candidates[hash]
  if candidate then return candidate.def.f(...) end

  -- fallback to unoptimized path
  return mf_call(self, ...)
end
  ]=]
  -- generate table/vararg-less hashing for each arguments count
  local hcode = "if n == 0 then hash = self.hsign[1]\n"
  for i=1,n do
    hcode = hcode.."elseif n == "..i.." then\n"
    hcode = hcode.."local "..xtype.tpllist("a$", 1, i, ", ").." = ...\n"
    hcode = hcode.."hash = self.hsign"..xtype.tpllist("[xtype_get(a$)]", 1, i, "").."[1]\n"
  end
  hcode = hcode.."end\n"
  local code = xtype.tplsub(main, {hash_code = hcode})
  -- compile
  mfcall = loadstring(code, "=[xtype-opt-mfcall #"..n.."]")(xtype_get, mf_call)
  -- cache
  mfcalls[n] = mfcall
  return mfcall
end

-- Define a multifunction signature.
-- The keyword "any" matches any type. It is the least specific match for a
-- given terminal type.
--
-- f: definition function; nil to undefine
-- ...: signature, list of types
function multifunction:define(f, ...)
  local sign = check_sign(...)
  local hash = mf_hash_sign(self, sign)
  if f then -- define
    -- increase call parameters, re-compile call function
    if sign.n > self.max_calln then
      self.max_calln = sign.n
      local fcall = gen_opt_mfcall(self.max_calln)
      local mt = getmetatable(self)
      self.call = fcall
      mt.__call = fcall
    end
    -- definition
    local def = self.definitions[hash]
    if def then def.f = f -- update definition
    else -- new definition
      def = {f = f, sign = sign}
      self.definitions[hash] = def
      -- update candidates (better or equivalent match)
      for chash, candidate in pairs(self.candidates) do
        local dist = sign_dist(candidate.sign, sign)
        if dist then
          if dist < candidate.dist then -- update if better candidate
            candidate.def, candidate.dist = def, dist
          elseif dist == candidate.dist then -- remove candidate on ambiguity
            self.candidates[chash] = nil
          end
        end
      end
    end
  else -- undefine
    local def = self.definitions[hash]
    if def then
      self.definitions[hash] = nil
      -- remove candidates (removed definition)
      for chash, candidate in pairs(self.candidates) do
        if candidate.def == def then self.candidates[chash] = nil end
      end
    end
  end
end

-- Get the resolved function for a specific signature.
-- ...: call signature, list of (terminal) types
-- return function or nil without a matching definition
function multifunction:resolve(...)
  local sign = check_sign(...)
  return mf_resolve_sign(self, sign)
end

-- Add a generator function.
--
-- All generators are called when no matching definition has been found to
-- eventually define new signatures.
--
-- f(multifunction, ...): called to generate new definitions
--- ...: call signature, list of (terminal) types
function multifunction:addGenerator(f)
  self.generators[f] = true
end

-- Create a multifunction.
function xtype.multifunction()
  -- The metatable is per multifunction to independently update the call
  -- function.
  local default_call = gen_opt_mfcall(0)
  local multifunction_mt = {
    xtype = "multifunction",
    __tostring = multifunction_tostring,
    __index = multifunction,
    __call = default_call
  }
  return setmetatable({
    hsign = new_hsign(),
    definitions = {}, -- map of sign hash => {.f, .sign}
    generators = {}, -- set of generator functions
    candidates = {}, -- cached candidates, map of call sign hash => {.sign, .dist, .def}
    max_calln = 0, -- maximum call parameters
    call = default_call
  }, multifunction_mt)
end

-- Code generation tools.

-- Generate "a1, a2, a3, a4..." list string.
-- tpl: string where "$" will be replaced by the index
-- i: start index
-- j: end index
-- separator: (optional) default: ", "
function xtype.tpllist(tpl, i, j, separator)
  local list = {}
  for k=i,j do table.insert(list, (string.gsub(tpl, "%$", k))) end
  return table.concat(list, separator or ", ")
end

-- Template substitution.
-- tpl: string with $... parameters
-- args: map of param => value
-- return processed template
function xtype.tplsub(tpl, args)
  return string.gsub(tpl, "%$([%w_]+)", args)
end

-- Global multifunctions namespace for binary operators.
-- For interoperability between third-party types.
-- Equality (eq) has a default behavior defined as: eq(any, any) -> false
--
-- map of Lua binary op name => multifunction
-- (add, sub, mul, div, mod, pow, concat, eq, lt, le, idiv, band, bor, bxor, shl, shr)
xtype.op = {
  add = xtype.multifunction(),
  sub = xtype.multifunction(),
  mul = xtype.multifunction(),
  div = xtype.multifunction(),
  mod = xtype.multifunction(),
  pow = xtype.multifunction(),
  concat = xtype.multifunction(),
  eq = xtype.multifunction(),
  lt = xtype.multifunction(),
  le = xtype.multifunction(),
  idiv = xtype.multifunction(),
  band = xtype.multifunction(),
  bor = xtype.multifunction(),
  bxor = xtype.multifunction(),
  shl = xtype.multifunction(),
  shr = xtype.multifunction()
}

-- Default eq behavior.
xtype.op.eq:define(function() return false end, "any", "any")

return xtype
