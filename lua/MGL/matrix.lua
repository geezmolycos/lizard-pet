-- https://github.com/ImagicTheCat/MGL
-- MIT license (see LICENSE or MGL.lua)

local xtype = require("xtype")
local unpack = table.unpack or unpack

-- load
return function(mgl)
  local generated = {}
  local mat = xtype.create("mat")
  local vec = mgl.require_vec()
  -- loaders
  mgl.addLoader("^mat(%d+)$", function(N)
    mgl.require_mat(tonumber(N))
    return mgl["mat"..N]
  end)
  mgl.addLoader("^mat(%d+)x(%d+)$", function(N, M)
    if N == M then return end
    mgl.require_mat(tonumber(N), tonumber(M))
    return mgl["mat"..N.."x"..M]
  end)

  -- Require mat(N)(M)/mat(N) vector type.
  -- Matrix values are stored as a row-major ordered list; columns are vectors.
  -- N: (optional) columns
  -- M: (optional) rows (default: N)
  -- return mat(N)(M)/mat(N) or mat xtype
  function mgl.require_mat(N, M)
    if not N then return mat end
    M = M or N
    if M <= 1 or N <= 1 then error("invalid matrix dimensions") end
    local Tname = "mat"..N..(M ~= N and "x"..M or "")
    if generated[Tname] then return generated[Tname] end -- prevent regeneration
    -- create type
    local T = xtype.create(Tname, mat)
    generated[Tname] = T
    T.N, T.M = N, M
    T.mt = {
      xtype = T,
      __index = {},
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
    mgl.initmfs(Tname, "copy", "transpose", "determinant", "inverse")

    -- DATA
    -- gen: vector accessor
    do
      local g_as, s_as = {}, {}
      for i=1,M do -- retrieve column by index
        local a = "a["..((i-1)*N).."+idx]"
        table.insert(g_as, a)
        table.insert(s_as, a.." = b["..i.."]")
      end
      local code = xtype.tplsub([[
local mt = ...
local smt = setmetatable
return function(a, idx, b)
  if b then -- set vector
    $s_as
  else -- get vector
    return smt({$g_as}, mt)
  end
end
      ]], {
        g_as = table.concat(g_as, ", "),
        s_as = table.concat(s_as, "\n")
      })
      local f = mgl.genfunc(code, Tname..":vector_accessor")(mgl.require_vec(M).mt)
      T.mt.__index.v = f
    end
    -- gen: copy
    do
      local code = xtype.tplsub([[
return function(a,b)
  $ops
end
      ]], {ops = xtype.tpllist("a[$] = b[$]", 1, M*N, "\n")})
      local f = mgl.genfunc(code, Tname..":copy")()
      mgl.copy:define(f, T, T)
    end

    -- MISC
    -- gen: tostring
    do
      local lines = {}
      for i=1,M do
        local line = xtype.tplsub([[tins(t, "|"..$cs.."|")]], --
          {cs = xtype.tpllist("a[$]", (i-1)*N+1, i*N, [[..","..]])})
        table.insert(lines, line)
      end
      local code = xtype.tplsub([[
local tins, tcc = table.insert, table.concat
return function(a)
  local t = {}
  $inserts
  return tcc(t, "\n")
end
      ]], {inserts = table.concat(lines, "\n")})
      local f = mgl.genfunc(code, Tname..":tostring")()
      T.mt.__tostring = f
    end

    -- CONSTRUCTORS
    -- gen: scalar constructor
    do
      -- generate identity
      local vs = {}; for i=1,N*M do table.insert(vs, (i-1)%N == math.floor((i-1)/N) and "x" or "0") end
      local code = xtype.tplsub([[
local mt = ...
local smt = setmetatable
return function(x) return smt({$vs}, mt) end
      ]], {vs = table.concat(vs, ",")})
      local f = mgl.genfunc(code, Tname..":scalar_constructor")(T.mt)
      mgl[Tname]:define(f, "number")
    end

    -- gen: table list constructor
    do
      local code = xtype.tplsub([[
local mt = ...
local smt = setmetatable
return function(t) return smt({$ts}, mt) end
      ]], {ts = xtype.tpllist("t[$]", 1, M*N)})
      local f = mgl.genfunc(code, Tname..":table_list_constructor")(T.mt)
      mgl[Tname]:define(f, "table")
    end

    -- gen: generic mat constructor
    mgl[Tname]:addGenerator(function(mf, ...)
      if select("#", ...) ~= 1 then return end
      local a = ...; if not xtype.of(a, mat) then return end
      -- generate mat values
      local vs = {}
      for i=1,N do
        for j=1,M do
          if i <= a.N and j <= a.M then -- valid value from input
            local ai = i+(j-1)*a.N
            table.insert(vs, "a["..ai.."]")
          else -- identity fill
            table.insert(vs, i == j and "1" or "0")
          end
        end
      end
      local code = xtype.tplsub([[
local mt = ...
local smt = setmetatable
return function(a) return smt({$vs}, mt) end
      ]], {vs = table.concat(vs, ", ")})
      local f = mgl.genfunc(code, Tname..":generic_mat_constructor")(T.mt)
      mgl[Tname]:define(f, a)
    end)

    -- gen: vectors constructor (columns)
    do
      local ptypes = {}
      local vcs = {}
      local mvec = mgl.require_vec(M)
      for i=1,N do
        table.insert(ptypes, mvec)
        -- write vector components to row-major order
        for j=1,M do table.insert(vcs, "v"..j.."["..i.."]") end
      end
      local code = xtype.tplsub([[
local mt = ...
local smt = setmetatable
return function($vs) return smt({$vcs}, mt) end
      ]], {
        vs = xtype.tpllist("v$", 1, N),
        vcs = table.concat(vcs, ", ")
      })
      local f = mgl.genfunc(code, Tname..":vectors_constructor")(T.mt)
      mgl[Tname]:define(f, unpack(ptypes))
    end

    -- COMPARISON
    -- gen: equal
    do
      local code = xtype.tplsub([[return function(a, b) return $expr end]], --
        {expr = xtype.tpllist("a[$] == b[$]", 1, M*N, " and ")})
      local f = mgl.genfunc(code, Tname..":equal")()
      xtype.op.eq:define(f, T, T)
    end

    -- BASIC ARITHMETIC
    -- gen: unm
    do
      local code = xtype.tplsub([[
local gmt, smt = getmetatable, setmetatable
return function(a) return smt({$opl}, gmt(a)) end
      ]], {opl = xtype.tpllist("-a[$]", 1, M*N)})
      local f = mgl.genfunc(code, Tname..":unm")()
      T.mt.__unm = f
    end

    -- gen: add
    do
      local code = xtype.tplsub([[
local gmt, smt = getmetatable, setmetatable
return function(a, b) return smt({$opl}, gmt(a)) end
      ]], {opl = xtype.tpllist("a[$]+b[$]", 1, M*N)})
      local f = mgl.genfunc(code, Tname..":add")()
      xtype.op.add:define(f, T, T)
    end

    -- gen: sub
    do
      local code = xtype.tplsub([[
local gmt, smt = getmetatable, setmetatable
return function(a, b) return smt({$opl}, gmt(a)) end
      ]], {opl = xtype.tpllist("a[$]-b[$]", 1, M*N)})
      local f = mgl.genfunc(code, Tname..":sub")()
      xtype.op.sub:define(f, T, T)
    end

    -- gen: mul number
    do
      local code = xtype.tplsub([[
local gmt, smt = getmetatable, setmetatable
return function(a, n) return smt({$opl}, gmt(a)) end
      ]], {opl = xtype.tpllist("a[$]*n", 1, M*N)})
      local f = mgl.genfunc(code, Tname..":mul_number")()
      xtype.op.mul:define(f, T, "number")
    end

    -- gen: mul number alt
    do
      local code = xtype.tplsub([[
local gmt, smt = getmetatable, setmetatable
return function(n, a) return smt({$opl}, gmt(a)) end
      ]], {opl = xtype.tpllist("a[$]*n", 1, M*N)})
      local f = mgl.genfunc(code, Tname..":mul_number_alt")()
      xtype.op.mul:define(f, "number", T)
    end

    -- gen: div number
    do
      local code = xtype.tplsub([[
local gmt, smt = getmetatable, setmetatable
return function(a, n) return smt({$opl}, gmt(a)) end
      ]], {opl = xtype.tpllist("a[$]/n", 1, M*N)})
      local f = mgl.genfunc(code, Tname..":div_number")()
      xtype.op.div:define(f, T, "number")
    end

    -- OPERATIONS
    -- gen: transpose
    do
      local as = {}
      for i=1,N do for j=1,M do table.insert(as, "a["..((j-1)*N+i).."]") end end

      if M == N then -- square
        local code = xtype.tplsub([[
local gmt, smt = getmetatable, setmetatable
return function(a) return smt({$as}, gmt(a)) end
        ]], {as = table.concat(as, ", ")})
        local f = mgl.genfunc(code, Tname..":transpose")()
        mgl.transpose:define(f, T)
      else -- general case
        local code = xtype.tplsub([[
local mt = ...
local smt = setmetatable
return function(a) return smt({$as}, mt) end
        ]], {as = table.concat(as, ", ")})
        local f = mgl.genfunc(code, Tname..":transpose")(mgl.require_mat(M, N).mt)
        mgl.transpose:define(f, T)
      end
    end

    -- Determinant and inverse based on:
    --- https://en.wikipedia.org/wiki/Invertible_matrix
    --- https://github.com/willnode/N-Matrix-Programmer

    -- gen: determinant / inverse
    if M == N and M == 2 then -- mat2
      -- determinant
      local function f(a)
        return a[1]*a[4]-a[2]*a[3]
      end
      mgl.determinant:define(f, T)

      -- inverse
      local gmt, smt = getmetatable, setmetatable
      local function f(a)
        local d = a[1]*a[4]-a[2]*a[3]
        local invd = 1/d
        if d ~= 0 then
          return smt({a[4]*invd, -a[2]*invd, -a[3]*invd, a[1]*invd}, gmt(a)), d
        else
          local nan = 0/0
          return smt({nan,nan,nan,nan}, gmt(a)), d
        end
      end
      mgl.inverse:define(f, T)
    elseif M == N and M == 3 then -- mat3
      -- determinant
      local function f(a)
        return a[1]*(a[5]*a[9]-a[6]*a[8]) --
          -a[2]*(a[4]*a[9]-a[6]*a[7]) --
          +a[3]*(a[4]*a[8]-a[5]*a[7])
      end
      mgl.determinant:define(f, T)

      -- inverse
      local gmt, smt = getmetatable, setmetatable
      local function f(a)
        local d = a[1]*(a[5]*a[9]-a[6]*a[8]) --
          -a[2]*(a[4]*a[9]-a[6]*a[7]) --
          +a[3]*(a[4]*a[8]-a[5]*a[7])
        local invd = 1/d
        if d ~= 0 then
          return smt({
            invd*(a[5]*a[9] - a[6]*a[8]),
            invd*-(a[2]*a[9] - a[3]*a[8]),
            invd*(a[2]*a[6] - a[3]*a[5]),
            invd*-(a[4]*a[9] - a[6]*a[7]),
            invd*(a[1]*a[9] - a[3]*a[7]),
            invd*-(a[1]*a[6] - a[3]*a[4]),
            invd*(a[4]*a[8] - a[5]*a[7]),
            invd*-(a[1]*a[8] - a[2]*a[7]),
            invd*(a[1]*a[5] - a[2]*a[4])
          }, gmt(a)), d
        else
          local nan = 0/0
          return smt({nan,nan,nan,nan,nan,nan,nan,nan,nan}, gmt(a)), d
        end
      end
      mgl.inverse:define(f, T)
    elseif M == N and M == 4 then -- mat4
      -- determinant
      local function f(a)
        local A2323 = a[11]*a[16] - a[12]*a[15]
        local A1323 = a[10]*a[16] - a[12]*a[14]
        local A1223 = a[10]*a[15] - a[11]*a[14]
        local A0323 = a[9]*a[16] - a[12]*a[13]
        local A0223 = a[9]*a[15] - a[11]*a[13]
        local A0123 = a[9]*a[14] - a[10]*a[13]
        local A2313 = a[7]*a[16] - a[8]*a[15]
        local A1313 = a[6]*a[16] - a[8]*a[14]
        local A1213 = a[6]*a[15] - a[7]*a[14]
        local A2312 = a[7]*a[12] - a[8]*a[11]
        local A1312 = a[6]*a[12] - a[8]*a[10]
        local A1212 = a[6]*a[11] - a[7]*a[10]
        local A0313 = a[5]*a[16] - a[8]*a[13]
        local A0213 = a[5]*a[15] - a[7]*a[13]
        local A0312 = a[5]*a[12] - a[8]*a[9]
        local A0212 = a[5]*a[11] - a[7]*a[9]
        local A0113 = a[5]*a[14] - a[6]*a[13]
        local A0112 = a[5]*a[10] - a[6]*a[9]

        return a[1]*(a[6]*A2323 - a[7]*A1323 + a[8]*A1223)
          - a[2]*(a[5]*A2323 - a[7]*A0323 + a[8]*A0223)
          + a[3]*(a[5]*A1323 - a[6]*A0323 + a[8]*A0123)
          - a[4]*(a[5]*A1223 - a[6]*A0223 + a[7]*A0123)
      end
      mgl.determinant:define(f, T)

      -- inverse
      local gmt, smt = getmetatable, setmetatable
      local function f(a)
        local A2323 = a[11]*a[16] - a[12]*a[15]
        local A1323 = a[10]*a[16] - a[12]*a[14]
        local A1223 = a[10]*a[15] - a[11]*a[14]
        local A0323 = a[9]*a[16] - a[12]*a[13]
        local A0223 = a[9]*a[15] - a[11]*a[13]
        local A0123 = a[9]*a[14] - a[10]*a[13]
        local A2313 = a[7]*a[16] - a[8]*a[15]
        local A1313 = a[6]*a[16] - a[8]*a[14]
        local A1213 = a[6]*a[15] - a[7]*a[14]
        local A2312 = a[7]*a[12] - a[8]*a[11]
        local A1312 = a[6]*a[12] - a[8]*a[10]
        local A1212 = a[6]*a[11] - a[7]*a[10]
        local A0313 = a[5]*a[16] - a[8]*a[13]
        local A0213 = a[5]*a[15] - a[7]*a[13]
        local A0312 = a[5]*a[12] - a[8]*a[9]
        local A0212 = a[5]*a[11] - a[7]*a[9]
        local A0113 = a[5]*a[14] - a[6]*a[13]
        local A0112 = a[5]*a[10] - a[6]*a[9]

        local d = a[1]*(a[6]*A2323 - a[7]*A1323 + a[8]*A1223)
          - a[2]*(a[5]*A2323 - a[7]*A0323 + a[8]*A0223)
          + a[3]*(a[5]*A1323 - a[6]*A0323 + a[8]*A0123)
          - a[4]*(a[5]*A1223 - a[6]*A0223 + a[7]*A0123)
        local invd = 1/d
        if d ~= 0 then
          return smt({
            invd*(a[6]*A2323 - a[7]*A1323 + a[8]*A1223),
            invd* -(a[2]*A2323 - a[3]*A1323 + a[4]*A1223),
            invd*(a[2]*A2313 - a[3]*A1313 + a[4]*A1213),
            invd* -(a[2]*A2312 - a[3]*A1312 + a[4]*A1212),
            invd* -(a[5]*A2323 - a[7]*A0323 + a[8]*A0223),
            invd*(a[1]*A2323 - a[3]*A0323 + a[4]*A0223),
            invd* -(a[1]*A2313 - a[3]*A0313 + a[4]*A0213),
            invd*(a[1]*A2312 - a[3]*A0312 + a[4]*A0212),
            invd*(a[5]*A1323 - a[6]*A0323 + a[8]*A0123),
            invd* -(a[1]*A1323 - a[2]*A0323 + a[4]*A0123),
            invd*(a[1]*A1313 - a[2]*A0313 + a[4]*A0113),
            invd* -(a[1]*A1312 - a[2]*A0312 + a[4]*A0112),
            invd* -(a[5]*A1223 - a[6]*A0223 + a[7]*A0123),
            invd*(a[1]*A1223 - a[2]*A0223 + a[3]*A0123),
            invd* -(a[1]*A1213 - a[2]*A0213 + a[3]*A0113),
            invd*(a[1]*A1212 - a[2]*A0212 + a[3]*A0112)
          }, gmt(a)), d
        else
          local nan = 0/0
          return smt({nan,nan,nan,nan,nan,nan,nan,nan,nan,nan,nan,nan,nan,nan,nan,nan}, gmt(a)), d
        end
      end
      mgl.inverse:define(f, T)
    end

    return T
  end

  -- gen: generic mul (mat/vec)
  xtype.op.mul:addGenerator(function(mf, ...)
    if select("#", ...) ~= 2 then return end
    local a, b = ...
    -- check a
    if not xtype.of(a, mat) then return end
    local Na, Ma = a.N, a.M
    -- check b
    local Nb, Mb
    if xtype.of(b, mat) then Nb, Mb = b.N, b.M
    elseif xtype.of(b, vec) then Nb, Mb = 1, b.D
    else return end -- invalid b type
    if Na ~= Mb then return end -- invalid operation
    -- generate
    --- result type
    local Nr, Mr = Nb, Ma
    local r = (Nr == 1 and mgl.require_vec(Mr) or mgl.require_mat(Nr, Mr))
    --- code
    local opl = {}
    for j=1,Mr do -- each result row
      for i=1,Nr do -- each result column
        local adds = {}
        for n=1,Na do -- each mul operation
          table.insert(adds, "a["..((j-1)*Na+n).."]*b["..((n-1)*Nb+i).."]")
        end
        table.insert(opl, table.concat(adds, "+"))
      end
    end
    local code = xtype.tplsub([[
local smt = setmetatable
local mt = ...
return function(a, b) return smt({$opl}, mt) end
    ]], {opl = table.concat(opl, ", ")})
    local f = mgl.genfunc(code, a.xtype_name..":"..b.xtype_name..":generic_mul")(r.mt)
    mf:define(f, a, b)
  end)
end
