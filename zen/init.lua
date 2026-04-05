local util         = require("zen.util")
local BaseSchema   = require("zen.base")
local StringSchema = require("zen.string")
local NumberSchema = require("zen.number")
local types        = require("zen.types")
local ObjectSchema = require("zen.object")
local collections  = require("zen.collections")
local combinators  = require("zen.combinators")

local BooleanSchema         = types.BooleanSchema
local AnySchema             = types.AnySchema
local NilSchema             = types.NilSchema
local LiteralSchema         = types.LiteralSchema
local EnumSchema            = types.EnumSchema
local ArraySchema           = collections.ArraySchema
local TupleSchema           = collections.TupleSchema
local RecordSchema          = collections.RecordSchema
local UnionSchema           = combinators.UnionSchema
local IntersectionSchema    = combinators.IntersectionSchema
local LazySchema            = combinators.LazySchema
local DiscriminatedUnionSchema = combinators.DiscriminatedUnionSchema

local zen = {}

zen.codes = util.codes

-- resolve forward references for BaseSchema:and_() and :or_()
BaseSchema._union_ctor = function(schemas) return UnionSchema._new(schemas) end
BaseSchema._intersection_ctor = function(l, r) return IntersectionSchema._new(l, r) end

function zen.string()
  return StringSchema._new()
end

function zen.number()
  return NumberSchema._new()
end

function zen.boolean()
  return BooleanSchema._new()
end

function zen.integer()
  return NumberSchema._new():integer()
end

function zen.any()
  return AnySchema._new()
end

function zen.nil_()
  return NilSchema._new()
end

function zen.literal(value)
  if value == nil then error("literal() expects a non-nil value", 2) end
  return LiteralSchema._new(value)
end

function zen.enum(values)
  if type(values) ~= "table" then error("enum() expects a table of values", 2) end
  if #values == 0 then error("enum() requires at least one value", 2) end
  return EnumSchema._new(values)
end

function zen.object(shape)
  if type(shape) ~= "table" then error("object() expects a table", 2) end
  return ObjectSchema._new(shape)
end

function zen.array(item_schema)
  if item_schema == nil then error("array() expects a schema", 2) end
  return ArraySchema._new(item_schema)
end

function zen.record(key_or_value, value_schema)
  if value_schema then
    return RecordSchema._new(key_or_value, value_schema)
  else
    if key_or_value == nil then error("record() expects a schema", 2) end
    return RecordSchema._new(nil, key_or_value)
  end
end

function zen.tuple(...)
  local schemas = {...}
  if #schemas == 0 then error("tuple() requires at least one schema", 2) end
  return TupleSchema._new(schemas)
end

function zen.union(...)
  local schemas = {...}
  if #schemas < 2 then error("union() requires at least 2 schemas", 2) end
  return UnionSchema._new(schemas)
end

function zen.intersection(left, right)
  if left == nil or right == nil then error("intersection() requires 2 schemas", 2) end
  return IntersectionSchema._new(left, right)
end

function zen.lazy(fn)
  if type(fn) ~= "function" then error("lazy() expects a function", 2) end
  return LazySchema._new(fn)
end

function zen.discriminated_union(discriminant, schemas)
  if type(discriminant) ~= "string" then
    error("discriminated_union() expects a string discriminant key", 2)
  end
  if type(schemas) ~= "table" or #schemas < 2 then
    error("discriminated_union() requires at least 2 variant schemas", 2)
  end
  return DiscriminatedUnionSchema._new(discriminant, schemas)
end

function zen.custom(fn, message)
  if type(fn) ~= "function" then
    error("custom() expects a function as first argument", 2)
  end
  return AnySchema._new():refine(fn, message)
end

function zen.flatten_errors(errors)
  local flat = {}
  for i = 1, #errors do
    local e = errors[i]
    local key = util.format_path(e.path)
    if key == "" then key = "_root" end
    if not flat[key] then flat[key] = {} end
    local msgs = flat[key]
    msgs[#msgs + 1] = e.message
  end
  return flat
end

zen.coerce = {}

function zen.coerce.string()
  local s = StringSchema._new()
  s._coerce = util.coerce_string
  return s
end

function zen.coerce.number()
  local s = NumberSchema._new()
  s._coerce = util.coerce_number
  return s
end

function zen.coerce.boolean()
  local s = BooleanSchema._new()
  s._coerce = util.coerce_boolean
  return s
end

function zen.coerce.integer()
  local s = NumberSchema._new()
  s._coerce = util.coerce_number
  return s:integer()
end

return zen
