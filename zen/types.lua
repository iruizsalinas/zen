local BaseSchema = require("zen.base")
local util = require("zen.util")
local copy_list = util.copy_list
local deep_copy = util.deep_copy
local codes = util.codes
local EMPTY_PATH = util.EMPTY_PATH

local types = {}

local BooleanSchema = setmetatable({}, {__index = BaseSchema})
BooleanSchema.__index = BooleanSchema

function BooleanSchema._new()
  return BaseSchema._new("boolean", BooleanSchema)
end

function BooleanSchema:_check_type(value) return type(value) == "boolean" end
function BooleanSchema:_type_error() return "must be a boolean" end

types.BooleanSchema = BooleanSchema

local AnySchema = setmetatable({}, {__index = BaseSchema})
AnySchema.__index = AnySchema

function AnySchema._new()
  return BaseSchema._new("any", AnySchema)
end

function AnySchema:_check_type(value) return true end

function AnySchema:_validate_type(value, path)
  if type(value) == "table" then return deep_copy(value), nil end
  return value, nil
end

types.AnySchema = AnySchema

local NilSchema = setmetatable({}, {__index = BaseSchema})
NilSchema.__index = NilSchema

function NilSchema._new()
  return BaseSchema._new("nil", NilSchema)
end

function NilSchema:_validate(value, path)
  path = path or EMPTY_PATH
  if value ~= nil then
    if self._has_catch then return self:_do_catch(), nil end
    return nil, {{path = copy_list(path), message = "must be nil", code = codes.invalid_type}}
  end
  return nil, nil
end

types.NilSchema = NilSchema

local LiteralSchema = setmetatable({}, {__index = BaseSchema})
LiteralSchema.__index = LiteralSchema

function LiteralSchema._new(expected)
  local self = BaseSchema._new("literal", LiteralSchema)
  self._expected = expected
  return self
end

function LiteralSchema:_check_type(value) return true end

function LiteralSchema:_validate_type(value, path)
  if value ~= self._expected then
    local display = tostring(self._expected)
    if type(self._expected) == "string" then display = "\"" .. self._expected .. "\"" end
    return nil, {{
      path    = copy_list(path),
      message = "must be exactly " .. display,
      code    = codes.invalid_literal,
    }}
  end
  return value, nil
end

types.LiteralSchema = LiteralSchema

local EnumSchema = setmetatable({}, {__index = BaseSchema})
EnumSchema.__index = EnumSchema

function EnumSchema._new(values)
  local self = BaseSchema._new("enum", EnumSchema)
  self._values = values
  self._value_set = {}
  for i = 1, #values do self._value_set[values[i]] = true end
  return self
end

function EnumSchema:_check_type(value) return true end

function EnumSchema:_validate_type(value, path)
  if not self._value_set[value] then
    local parts = {}
    for i = 1, #self._values do parts[i] = tostring(self._values[i]) end
    return nil, {{
      path    = copy_list(path),
      message = "must be one of: " .. table.concat(parts, ", "),
      code    = codes.invalid_enum,
    }}
  end
  return value, nil
end

types.EnumSchema = EnumSchema

return types
