local BaseSchema = require("zen.base")
local codes = require("zen.util").codes

local NumberSchema = setmetatable({}, {__index = BaseSchema})
NumberSchema.__index = NumberSchema

function NumberSchema._new()
  local self = BaseSchema._new("number", NumberSchema)
  self._allow_infinity = false
  return self
end

function NumberSchema:_check_type(value)
  if type(value) ~= "number" or value ~= value then return false end
  if not self._allow_infinity and (value == math.huge or value == -math.huge) then return false end
  return true
end

function NumberSchema:_type_error() return "must be a number" end

function NumberSchema:allow_infinity()
  local new = self:_clone()
  new._allow_infinity = true
  return new
end

function NumberSchema:min(n, msg)
  if type(n) ~= "number" then error("min() expects a number, got " .. type(n), 2) end
  return self:_add_check(function(val)
    if val < n then return false, msg or ("must be at least " .. n), codes.too_small end
    return true
  end)
end

NumberSchema.gte = NumberSchema.min

function NumberSchema:max(n, msg)
  if type(n) ~= "number" then error("max() expects a number, got " .. type(n), 2) end
  return self:_add_check(function(val)
    if val > n then return false, msg or ("must be at most " .. n), codes.too_big end
    return true
  end)
end

NumberSchema.lte = NumberSchema.max

function NumberSchema:gt(n, msg)
  if type(n) ~= "number" then error("gt() expects a number, got " .. type(n), 2) end
  return self:_add_check(function(val)
    if val <= n then return false, msg or ("must be greater than " .. n), codes.too_small end
    return true
  end)
end

function NumberSchema:lt(n, msg)
  if type(n) ~= "number" then error("lt() expects a number, got " .. type(n), 2) end
  return self:_add_check(function(val)
    if val >= n then return false, msg or ("must be less than " .. n), codes.too_big end
    return true
  end)
end

function NumberSchema:integer(msg)
  return self:_add_check(function(val)
    if val == math.huge or val == -math.huge or val ~= math.floor(val) then
      return false, msg or "must be an integer", codes.invalid_type
    end
    return true
  end)
end

function NumberSchema:multiple_of(n, msg)
  if type(n) ~= "number" then error("multiple_of() expects a number, got " .. type(n), 2) end
  if n == 0 then error("multiple_of() expects a non-zero number", 2) end
  return self:_add_check(function(val)
    local remainder = val % n
    if remainder ~= 0 and math.abs(remainder - n) > 1e-10 then
      return false, msg or ("must be a multiple of " .. n), codes.custom
    end
    return true
  end)
end

NumberSchema.step = NumberSchema.multiple_of

function NumberSchema:positive(msg)    return self:gt(0, msg) end
function NumberSchema:negative(msg)    return self:lt(0, msg) end
function NumberSchema:nonnegative(msg) return self:min(0, msg) end
function NumberSchema:nonpositive(msg) return self:max(0, msg) end

function NumberSchema:between(lo, hi, msg)
  if type(lo) ~= "number" then error("between() expects numbers, got " .. type(lo), 2) end
  if type(hi) ~= "number" then error("between() expects numbers, got " .. type(hi), 2) end
  return self:_add_check(function(val)
    if val < lo or val > hi then
      local code = val < lo and codes.too_small or codes.too_big
      return false, msg or ("must be between " .. lo .. " and " .. hi), code
    end
    return true
  end)
end

return NumberSchema
