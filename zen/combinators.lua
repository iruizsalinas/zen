local BaseSchema = require("zen.base")
local util = require("zen.util")
local ObjectSchema = require("zen.object")
local types = require("zen.types")
local copy_list = util.copy_list
local codes = util.codes
local EMPTY_PATH = util.EMPTY_PATH
local LiteralSchema = types.LiteralSchema

local combinators = {}

local UnionSchema = setmetatable({}, {__index = BaseSchema})
UnionSchema.__index = UnionSchema

function UnionSchema._new(schemas)
  local self = BaseSchema._new("union", UnionSchema)
  self._schemas = schemas
  return self
end

function UnionSchema:_validate(value, path)
  path = path or EMPTY_PATH

  if value == nil then
    if self._has_default then
      local d = self._default_val
      if type(d) == "function" then d = d() end
      return d, nil
    end
    if self._is_optional then return nil, nil end
  end

  local all_variant_errors = {}
  for i = 1, #self._schemas do
    local r, e = self._schemas[i]:_validate(value, path)
    if not e then
      if #self._pipeline == 0 then return r, nil end
      return self:_run_pipeline(r, path)
    end
    all_variant_errors[i] = e
  end

  if self._has_catch then return self:_do_catch(), nil end
  if value == nil then
    return nil, {{path = copy_list(path), message = "required", code = codes.invalid_type}}
  end
  return nil, {{
    path           = copy_list(path),
    message        = "must match at least one of the given schemas",
    code           = codes.invalid_union,
    variant_errors = all_variant_errors,
  }}
end

combinators.UnionSchema = UnionSchema

local IntersectionSchema = setmetatable({}, {__index = BaseSchema})
IntersectionSchema.__index = IntersectionSchema

function IntersectionSchema._new(left, right)
  local self = BaseSchema._new("intersection", IntersectionSchema)
  self._left = left
  self._right = right
  return self
end

function IntersectionSchema:_validate(value, path)
  path = path or EMPTY_PATH

  if value == nil then
    if self._has_default then
      local d = self._default_val
      if type(d) == "function" then d = d() end
      return d, nil
    end
    if self._is_optional then return nil, nil end
  end

  local left_result, left_errors = self._left:_validate(value, path)
  local right_result, right_errors = self._right:_validate(value, path)

  if left_errors or right_errors then
    local errors = {}
    if left_errors then
      for i = 1, #left_errors do errors[#errors + 1] = left_errors[i] end
    end
    if right_errors then
      for i = 1, #right_errors do errors[#errors + 1] = right_errors[i] end
    end
    if self._has_catch then return self:_do_catch(), nil end
    return nil, errors
  end

  if type(left_result) == "table" and type(right_result) == "table" then
    for k, v in pairs(right_result) do left_result[k] = v end
  end

  if #self._pipeline == 0 then return left_result, nil end
  return self:_run_pipeline(left_result, path)
end

combinators.IntersectionSchema = IntersectionSchema

local LazySchema = setmetatable({}, {__index = BaseSchema})
LazySchema.__index = LazySchema

function LazySchema._new(fn)
  local self = BaseSchema._new("lazy", LazySchema)
  self._lazy_fn = fn
  self._lazy_schema = nil
  return self
end

function LazySchema:_resolve()
  if not self._lazy_schema then
    self._lazy_schema = self._lazy_fn()
  end
  return self._lazy_schema
end

function LazySchema:_validate(value, path)
  path = path or EMPTY_PATH

  if value == nil then
    if self._has_default then
      local d = self._default_val
      if type(d) == "function" then d = d() end
      return d, nil
    end
    if self._is_optional then return nil, nil end
  end

  local resolved = self:_resolve()
  local result, errors = resolved:_validate(value, path)

  if errors then
    if self._has_catch then return self:_do_catch(), nil end
    return result, errors
  end

  if #self._pipeline == 0 then return result, nil end
  return self:_run_pipeline(result, path)
end

combinators.LazySchema = LazySchema

local DiscriminatedUnionSchema = setmetatable({}, {__index = BaseSchema})
DiscriminatedUnionSchema.__index = DiscriminatedUnionSchema

function DiscriminatedUnionSchema._new(discriminant, schemas)
  local self = BaseSchema._new("discriminated_union", DiscriminatedUnionSchema)
  self._discriminant = discriminant
  self._schemas = schemas
  self._lookup = {}

  for i = 1, #schemas do
    local variant = schemas[i]
    if getmetatable(variant) ~= ObjectSchema then
      error("discriminated_union variants must be object schemas", 3)
    end
    local field_schema = variant._shape[discriminant]
    if not field_schema or getmetatable(field_schema) ~= LiteralSchema then
      error("discriminated_union variant " .. i ..
        " must have a literal() schema for key '" .. discriminant .. "'", 3)
    end
    local disc_value = field_schema._expected
    if self._lookup[disc_value] then
      error("discriminated_union has duplicate discriminant value: " .. tostring(disc_value), 3)
    end
    self._lookup[disc_value] = variant
  end

  return self
end

function DiscriminatedUnionSchema:_validate(value, path)
  path = path or EMPTY_PATH

  if value == nil then
    if self._has_default then
      local d = self._default_val
      if type(d) == "function" then d = d() end
      return d, nil
    end
    if self._is_optional then return nil, nil end
    if self._has_catch then return self:_do_catch(), nil end
    return nil, {{path = copy_list(path), message = "required", code = codes.invalid_type}}
  end

  if type(value) ~= "table" then
    if self._has_catch then return self:_do_catch(), nil end
    return nil, {{path = copy_list(path), message = "must be a table", code = codes.invalid_type}}
  end

  local disc_value = value[self._discriminant]
  if disc_value == nil then
    if self._has_catch then return self:_do_catch(), nil end
    local disc_path = copy_list(path)
    disc_path[#disc_path + 1] = self._discriminant
    return nil, {{
      path    = disc_path,
      message = "missing discriminant key '" .. self._discriminant .. "'",
      code    = codes.invalid_union,
    }}
  end

  local variant = self._lookup[disc_value]
  if not variant then
    if self._has_catch then return self:_do_catch(), nil end
    local disc_path = copy_list(path)
    disc_path[#disc_path + 1] = self._discriminant
    local expected = {}
    for k in pairs(self._lookup) do expected[#expected + 1] = tostring(k) end
    local got = tostring(disc_value)
    if #got > 50 then got = got:sub(1, 50) .. "..." end
    return nil, {{
      path    = disc_path,
      message = "expected one of: " .. table.concat(expected, ", ") .. "; got " .. got,
      code    = codes.invalid_union,
    }}
  end

  local result, errors = variant:_validate(value, path)
  if errors then
    if self._has_catch then return self:_do_catch(), nil end
    return result, errors
  end

  if #self._pipeline == 0 then return result, nil end
  return self:_run_pipeline(result, path)
end

combinators.DiscriminatedUnionSchema = DiscriminatedUnionSchema

return combinators
