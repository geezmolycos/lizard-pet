-- https://github.com/ImagicTheCat/MGL
-- MIT license (see LICENSE or MGL.lua)

local xtype = require("xtype")

-- load
return function(mgl)
  mgl.initmfs("translate", "rotate", "scale", "orthographic", "perspective")
  local vec2 = mgl.require_vec(2)
  local vec3 = mgl.require_vec(3)
  local mat3 = mgl.require_mat(3)
  local mat4 = mgl.require_mat(4)

  -- TRANSFORM
  -- translate identity (homogeneous)
  --- 2D
  do
    local smt, mt = setmetatable, mat3.mt
    local function f(a)
      return smt({
        1,0,a[1],
        0,1,a[2],
        0,0,1
      }, mt)
    end
    mgl.translate:define(f, vec2)
  end
  --- 3D
  do
    local smt, mt = setmetatable, mat4.mt
    local function f(a)
      return smt({
        1,0,0,a[1],
        0,1,0,a[2],
        0,0,1,a[3],
        0,0,0,1
      }, mt)
    end
    mgl.translate:define(f, vec3)
  end

  -- rotate identity (homogeneous)
  --- 2D (theta)
  do
    local smt, mt = setmetatable, mat3.mt
    local cos, sin = math.cos, math.sin
    local function f(theta)
      return smt({
        cos(theta), -sin(theta), 0,
        sin(theta), cos(theta), 0,
        0,0,1
      }, mt)
    end
    mgl.rotate:define(f, "number")
  end
  --- 3D (axis, theta)
  do
    local smt, mt = setmetatable, mat4.mt
    local cos, sin = math.cos, math.sin
    local function f(a, theta)
      local c, s = cos(theta), sin(theta)
      local C = 1-c
      return smt({
        a[1]*a[1]*C+c, a[1]*a[2]*C-a[3]*s, a[1]*a[3]*C+a[2]*s, 0,
        a[1]*a[2]*C+a[3]*s, a[2]*a[2]*C+c, a[2]*a[3]*C-a[1]*s, 0,
        a[1]*a[3]*C-a[2]*s, a[2]*a[3]*C+a[1]*s, a[3]*a[3]*C+c, 0,
        0,0,0,1
      }, mt)
    end
    mgl.rotate:define(f, vec3, "number")
  end

  -- scale identity (homogeneous)
  --- 2D
  do
    local smt, mt = setmetatable, mat3.mt
    local function f(a)
      return smt({
        a[1],0,0,
        0,a[2],0,
        0,0,1
      }, mt)
    end
    mgl.scale:define(f, vec2)
  end
  --- 3D
  do
    local smt, mt = setmetatable, mat4.mt
    local function f(a)
      return smt({
        a[1],0,0,0,
        0,a[2],0,0,
        0,0,a[3],0,
        0,0,0,1
      }, mt)
    end
    mgl.scale:define(f, vec3)
  end

  -- PROJECTION
  -- orthographic (GL compatible)
  do
    local smt, mt = setmetatable, mat4.mt
    local function f(left, right, bottom, top, near, far)
      return smt({
        2/(right-left), 0, 0, -(right+left)/(right-left),
        0, 2/(top-bottom), 0, -(top+bottom)/(top-bottom),
        0, 0, -2/(far-near), -(far+near)/(far-near),
        0, 0, 0, 1
      }, mt)
    end
    mgl.orthographic:define(f, "number", "number", "number", "number", "number", "number")
  end

  -- perspective (GL compatible)
  do
    local smt, mt = setmetatable, mat4.mt
    local tan = math.tan
    local function f(hfov, aspect, near, far)
      local F = tan(hfov/2)/aspect
      return smt({
        1/(aspect*F), 0, 0, 0,
        0, 1/F, 0, 0,
        0, 0, -(far+near)/(far-near), -(2*far*near)/(far-near),
        0, 0, -1, 0
      }, mt)
    end
    mgl.perspective:define(f, "number", "number", "number", "number")
  end
end
