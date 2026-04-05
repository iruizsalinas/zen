local BaseSchema = require("zen.base")
local util = require("zen.util")
local copy_list = util.copy_list
local is_sequential = util.is_sequential
local codes = util.codes

local collections = {}

local ArraySchema = setmetatable({}, {__index = BaseSchema})
ArraySchema.__index = ArraySchema

function ArraySchema._new(item_schema)
  local self = BaseSchema._new("array", ArraySchema)
  self._item_schema = item_schema
  return self
end

function ArraySchema:_check_type(value) return is_sequential(value) end
function ArraySchema:_type_error() return "must be an array" end

function ArraySchema:_validate_type(value, path)
  local result = {}
  local errors
  local len = #value

  local item_path = copy_list(path)
  local depth = #item_path + 1
  for i = 1, len do
    item_path[depth] = i

    local item_result, item_errors = self._item_schema:_validate(value[i], item_path)
    if item_errors then
      if not errors then errors = {} end
      for j = 1, #item_errors do errors[#errors + 1] = item_errors[j] end
    end
    result[i] = item_result
  end

  return result, errors
end

function ArraySchema:min(n, msg)
  if type(n) ~= "number" then error("min() expects a number, got " .. type(n), 2) end
  return self:_add_check(function(val)
    if #val < n then
      return false, msg or ("must have at least " .. n .. (n == 1 and " element" or " elements")), codes.too_small
    end
    return true
  end)
end

function ArraySchema:max(n, msg)
  if type(n) ~= "number" then error("max() expects a number, got " .. type(n), 2) end
  return self:_add_check(function(val)
    if #val > n then
      return false, msg or ("must have at most " .. n .. (n == 1 and " element" or " elements")), codes.too_big
    end
    return true
  end)
end

function ArraySchema:nonempty(msg) return self:min(1, msg) end

function ArraySchema:length(n, msg)
  if type(n) ~= "number" then error("length() expects a number, got " .. type(n), 2) end
  return self:_add_check(function(val)
    local len = #val
    if len ~= n then
      local code = len < n and codes.too_small or codes.too_big
      return false, msg or ("must have exactly " .. n .. (n == 1 and " element" or " elements")), code
    end
    return true
  end)
end

collections.ArraySchema = ArraySchema

local TupleSchema = setmetatable({}, {__index = BaseSchema})
TupleSchema.__index = TupleSchema

function TupleSchema._new(schemas)
  local self = BaseSchema._new("tuple", TupleSchema)
  self._schemas = schemas
  return self
end

function TupleSchema:_check_type(value) return is_sequential(value) end
function TupleSchema:_type_error() return "must be an array" end

function TupleSchema:_validate_type(value, path)
  local expected = #self._schemas
  local actual = #value

  if actual ~= expected then
    return nil, {{
      path    = copy_list(path),
      message = "must have exactly " .. expected .. (expected == 1 and " element" or " elements"),
      code    = actual < expected and codes.too_small or codes.too_big,
    }}
  end

  local result = {}
  local errors

  local item_path = copy_list(path)
  local tdepth = #item_path + 1
  for i = 1, expected do
    item_path[tdepth] = i

    local item_result, item_errors = self._schemas[i]:_validate(value[i], item_path)
    if item_errors then
      if not errors then errors = {} end
      for j = 1, #item_errors do errors[#errors + 1] = item_errors[j] end
    end
    result[i] = item_result
  end

  return result, errors
end

collections.TupleSchema = TupleSchema

local RecordSchema = setmetatable({}, {__index = BaseSchema})
RecordSchema.__index = RecordSchema

function RecordSchema._new(key_schema, value_schema)
  local self = BaseSchema._new("record", RecordSchema)
  self._key_schema = key_schema
  self._value_schema = value_schema
  return self
end

function RecordSchema:_check_type(value) return type(value) == "table" end
function RecordSchema:_type_error() return "must be a table" end

function RecordSchema:_validate_type(value, path)
  local result = {}
  local errors

  for k, val in pairs(value) do
    local entry_path = copy_list(path)
    entry_path[#entry_path + 1] = k

    if self._key_schema then
      local _, key_errors = self._key_schema:_validate(k, entry_path)
      if key_errors then
        if not errors then errors = {} end
        for i = 1, #key_errors do errors[#errors + 1] = key_errors[i] end
      end
    end

    local val_result, val_errors = self._value_schema:_validate(val, entry_path)
    if val_errors then
      if not errors then errors = {} end
      for i = 1, #val_errors do errors[#errors + 1] = val_errors[i] end
    elseif val_result ~= nil then
      result[k] = val_result
    end
  end

  return result, errors
end

collections.RecordSchema = RecordSchema

return collections
