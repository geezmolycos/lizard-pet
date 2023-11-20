-- https://github.com/ImagicTheCat/MGL
-- MIT license (see LICENSE or MGL.lua)

local xtype = require("xtype")

-- Optimization tip:
-- It seems that the JIT compiler (LuaJIT) can't perform some optimizations in
-- this context when the type metatable is passed as an upvalue to functions
-- taking parameters based on the same metatable.
-- Best to get the metatable directly from the parameters.

-- load
return function(mgl)
  local generated = {}
  local accessors = { -- vector accessors for each component
    {"x", "r"},
    {"y", "g"},
    {"z", "b"},
    {"w", "a"}
  }
  local vec = xtype.create("vec")
  -- loader
  mgl.addLoader("^vec(%d+)$", function(D)
    mgl.require_vec(tonumber(D))
    return mgl["vec"..D]
  end)

  -- Require vec(D) vector type.
  -- D: (optional) dimension
  -- return vec(D) or vec xtype
  function mgl.require_vec(D)
    if not D then return vec end
    if D <= 1 then error("invalid vector dimension") end
    if generated[D] then return generated[D] end -- prevent regeneration
    -- create type
    local Tname = "vec"..D
    local T = xtype.create(Tname, vec)
    generated[D] = T
    T.D = D
    T.mt = {
      xtype = T,
      __add = xtype.op.add,
      __sub = xtype.op.sub,
      __mul = xtype.op.mul,
      __div = xtype.op.div,
      __mod = xtype.op.mod,
      __pow = xtype.op.pow,
      __concat = xtype.op.concat,
      __eq = xtype.op.eq,
      __lt = xtype.op.lt,
      __le = xtype.op.le
    }
    -- init multifunctions
    mgl.initmfs(Tname, "copy", "length", "normalize", "dot", "cross")

    -- DATA
    -- gen: getters
    do
      local codes = {}
      for i=1, math.min(D, 4) do
        table.insert(codes, i == 1 and "if " or "elseif ")
        local tests = {}
        for n=1,#accessors[i] do table.insert(tests, "k == \""..accessors[i][n].."\"") end
        table.insert(codes, table.concat(tests, " or "))
        table.insert(codes, " then return t["..i.."]\n")
      end
      table.insert(codes, "end")
      local code = xtype.tplsub([[
return function(t, k)
  $dispatch
end
      ]], {dispatch = table.concat(codes)})
      local f = mgl.genfunc(code, Tname..":get")()
      T.mt.__index = f
    end
    -- gen: setters
    do
      local codes = {}
      for i=1, math.min(D, 4) do
        table.insert(codes, i == 1 and "if " or "elseif ")
        local tests = {}
        for n=1,#accessors[i] do table.insert(tests, "k == \""..accessors[i][n].."\"") end
        table.insert(codes, table.concat(tests, " or "))
        table.insert(codes, " then t["..i.."] = v\n")
      end
      table.insert(codes, "else rawset(t,k,v) end")
      local code = xtype.tplsub([[
local rawset = rawset
return function(t, k, v)
  $dispatch
end
      ]], {dispatch = table.concat(codes)})
      local f = mgl.genfunc(code, Tname..":set")()
      T.mt.__newindex = f
    end
    -- gen: copy
    do
      local code = xtype.tplsub([[
return function(a,b)
  $ops
end
      ]], {ops = xtype.tpllist("a[$] = b[$]", 1, D, "\n")})
      local f = mgl.genfunc(code, Tname..":copy")()
      mgl.copy:define(f, T, T)
    end

    -- MISC
    -- gen: tostring
    do
      local code = xtype.tplsub([[return function(a) return "("..$cs..")" end]], --
        {cs = xtype.tpllist("a[$]", 1, D, [[..","..]])})
      local f = mgl.genfunc(code, Tname..":tostring")()
      T.mt.__tostring = f
    end

    -- CONSTRUCTORS
    -- gen: generic constructor
    mgl[Tname]:addGenerator(function(mf, ...)
      local sign = {...}
      -- build init list code
      local initl = {}
      for i, t in ipairs(sign) do
        if t == "number" then -- scalar
          table.insert(initl, "a"..i)
        elseif xtype.of(t, vec) then -- vec
          for j=1, t.D do table.insert(initl, "a"..i.."["..j.."]") end
        else return end -- invalid type
      end
      if #initl < D then return end -- check complete
      if #sign ~= 1 and #initl > D then return end -- check valid truncation
      -- main code
      local code = xtype.tplsub([[
local mt = ...
local smt = setmetatable
return function($as) return smt({$init}, mt) end
      ]], {
        as = xtype.tpllist("a$", 1, #sign),
        init = table.concat(initl, ", ", 1, D)
      })
      -- compile
      local f = mgl.genfunc(code, Tname..":generic_constructor")(T.mt)
      mgl[Tname]:define(f, ...)
    end)

    -- gen: scalar constructor
    do
      local code = xtype.tplsub([[
local mt = ...
local smt = setmetatable
return function(x) return smt({$xs}, mt) end
      ]], {xs = xtype.tpllist("x", 1, D)})
      local f = mgl.genfunc(code, Tname..":scalar_constructor")(T.mt)
      mgl[Tname]:define(f, "number")
    end

    -- gen: table list constructor
    do
      local code = xtype.tplsub([[
local mt = ...
local smt = setmetatable
return function(t) return smt({$ts}, mt) end
      ]], {ts = xtype.tpllist("t[$]", 1, D)})
      local f = mgl.genfunc(code, Tname..":table_list_constructor")(T.mt)
      mgl[Tname]:define(f, "table")
    end

    -- COMPARISON
    -- gen: equal
    do
      local code = xtype.tplsub([[return function(a, b) return $expr end]], --
        {expr = xtype.tpllist("a[$] == b[$]", 1, D, " and ")})
      local f = mgl.genfunc(code, Tname..":equal")()
      xtype.op.eq:define(f, T, T)
    end

    -- BASIC ARITHMETIC
    -- gen: unm
    do
      local code = xtype.tplsub([[
local gmt, smt = getmetatable, setmetatable
return function(a) return smt({$opl}, gmt(a)) end
      ]], {opl = xtype.tpllist("-a[$]", 1, D)})
      local f = mgl.genfunc(code, Tname..":unm")()
      T.mt.__unm = f
    end

    -- gen: add
    do
      local code = xtype.tplsub([[
local gmt, smt = getmetatable, setmetatable
return function(a, b) return smt({$opl}, gmt(a)) end
      ]], {opl = xtype.tpllist("a[$]+b[$]", 1, D)})
      local f = mgl.genfunc(code, Tname..":add")()
      xtype.op.add:define(f, T, T)
    end

    -- gen: sub
    do
      local code = xtype.tplsub([[
local gmt, smt = getmetatable, setmetatable
return function(a, b) return smt({$opl}, gmt(a)) end
      ]], {opl = xtype.tpllist("a[$]-b[$]", 1, D)})
      local f = mgl.genfunc(code, Tname..":sub")()
      xtype.op.sub:define(f, T, T)
    end

    -- gen: mul
    do
      local code = xtype.tplsub([[
local gmt, smt = getmetatable, setmetatable
return function(a, b) return smt({$opl}, gmt(a)) end
      ]], {opl = xtype.tpllist("a[$]*b[$]", 1, D)})
      local f = mgl.genfunc(code, Tname..":mul")()
      xtype.op.mul:define(f, T, T)
    end

    -- gen: mul number
    do
      local code = xtype.tplsub([[
local gmt, smt = getmetatable, setmetatable
return function(a, n) return smt({$opl}, gmt(a)) end
      ]], {opl = xtype.tpllist("a[$]*n", 1, D)})
      local f = mgl.genfunc(code, Tname..":mul_number")()
      xtype.op.mul:define(f, T, "number")
    end

    -- gen: mul number alt
    do
      local code = xtype.tplsub([[
local gmt, smt = getmetatable, setmetatable
return function(n, a) return smt({$opl}, gmt(a)) end
      ]], {opl = xtype.tpllist("n*a[$]", 1, D)})
      local f = mgl.genfunc(code, Tname..":mul_number_alt")()
      xtype.op.mul:define(f, "number", T)
    end

    -- gen: div
    do
      local code = xtype.tplsub([[
local gmt, smt = getmetatable, setmetatable
return function(a, b) return smt({$opl}, gmt(a)) end
      ]], {opl = xtype.tpllist("a[$]/b[$]", 1, D)})
      local f = mgl.genfunc(code, Tname..":div")()
      xtype.op.div:define(f, T, T)
    end

    -- gen: div number
    do
      local code = xtype.tplsub([[
local gmt, smt = getmetatable, setmetatable
return function(a, n) return smt({$opl}, gmt(a)) end
      ]], {opl = xtype.tpllist("a[$]/n", 1, D)})
      local f = mgl.genfunc(code, Tname..":div_number")()
      xtype.op.div:define(f, T, "number")
    end

    -- OPERATIONS
    -- gen: length
    do
      local code = xtype.tplsub([[
local sqrt = math.sqrt
return function(a) return sqrt($expr) end
      ]], {expr = xtype.tpllist("a[$]*a[$]", 1, D, "+")})
      local f = mgl.genfunc(code, Tname..":length")()
      mgl.length:define(f, T)
    end

    -- gen: normalize
    do
      local code = xtype.tplsub([[
local sqrt = math.sqrt
local gmt, smt = getmetatable, setmetatable
return function(a)
  local length = sqrt($length_expr)
  return smt({$opl}, gmt(a))
end
      ]], {
        length_expr = xtype.tpllist("a[$]*a[$]", 1, D, "+"),
        opl = xtype.tpllist("a[$]/length", 1, D)
      })
      local f = mgl.genfunc(code, Tname..":normalize")()
      mgl.normalize:define(f, T)
    end

    -- gen: dot
    do
      local code = xtype.tplsub([[
return function(a, b) return $expr end
      ]], {expr = xtype.tpllist("a[$]*b[$]", 1, D, "+")})
      local f = mgl.genfunc(code, Tname..":dot")()
      mgl.dot:define(f, T, T)
    end

    -- gen: cross
    if D == 3 then
      local gmt, smt = getmetatable, setmetatable
      local function f(a, b)
        return smt({
          a[2]*b[3]-a[3]*b[2],
          a[3]*b[1]-a[1]*b[3],
          a[1]*b[2]-a[2]*b[1]
        }, gmt(a))
      end
      mgl.cross:define(f, T, T)
    end

    return T
  end
end
