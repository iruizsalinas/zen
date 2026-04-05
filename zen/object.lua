local BaseSchema = require("zen.base")
local util = require("zen.util")
local copy_list = util.copy_list
local deep_copy = util.deep_copy
local codes = util.codes

local ObjectSchema = setmetatable({}, {__index = BaseSchema})
ObjectSchema.__index = ObjectSchema

function ObjectSchema._new(shape)
  local self = BaseSchema._new("object", ObjectSchema)
  self._shape = shape
  self._unknown_keys = "strip"
  self._catchall_schema = nil
  return self
end

function ObjectSchema:_check_type(value) return type(value) == "table" end
function ObjectSchema:_type_error() return "must be a table" end

function ObjectSchema:_validate_type(value, path)
  local result = {}
  local errors

  local field_path = copy_list(path)
  local depth = #field_path + 1
  for field, schema in pairs(self._shape) do
    field_path[depth] = field

    local field_result, field_errors = schema:_validate(value[field], field_path)
    if field_errors then
      if not errors then errors = {} end
      for i = 1, #field_errors do errors[#errors + 1] = field_errors[i] end
    elseif field_result ~= nil then
      result[field] = field_result
    end
  end

  if self._catchall_schema or self._unknown_keys ~= "strip" then
    for key in pairs(value) do
      if self._shape[key] == nil then
        if self._catchall_schema then
          local key_path = copy_list(path)
          key_path[#key_path + 1] = key
          local val_result, val_errors = self._catchall_schema:_validate(value[key], key_path)
          if val_errors then
            if not errors then errors = {} end
            for i = 1, #val_errors do errors[#errors + 1] = val_errors[i] end
          elseif val_result ~= nil then
            result[key] = val_result
          end
        elseif self._unknown_keys == "strict" then
          local key_path = copy_list(path)
          key_path[#key_path + 1] = key
          if not errors then errors = {} end
          errors[#errors + 1] = {path = key_path, message = "unrecognized key", code = codes.unrecognized_keys}
        elseif self._unknown_keys == "passthrough" then
          result[key] = deep_copy(value[key])
        end
      end
    end
  end

  return result, errors
end

function ObjectSchema:strict()
  local new = self:_clone()
  new._unknown_keys = "strict"
  return new
end

function ObjectSchema:passthrough()
  local new = self:_clone()
  new._unknown_keys = "passthrough"
  return new
end

function ObjectSchema:strip()
  local new = self:_clone()
  new._unknown_keys = "strip"
  return new
end

function ObjectSchema:catchall(schema)
  if not require("zen.util").is_schema(schema) then
    error("catchall() expects a schema", 2)
  end
  local new = self:_clone()
  new._catchall_schema = schema
  return new
end

function ObjectSchema:partial(keys)
  local new = self:_clone()
  local new_shape = {}
  if keys then
    local key_set = {}
    for i = 1, #keys do key_set[keys[i]] = true end
    for k, s in pairs(self._shape) do
      new_shape[k] = key_set[k] and s:optional() or s
    end
  else
    for k, s in pairs(self._shape) do new_shape[k] = s:optional() end
  end
  new._shape = new_shape
  return new
end

function ObjectSchema:required(keys)
  local new = self:_clone()
  local new_shape = {}
  if keys then
    local key_set = {}
    for i = 1, #keys do key_set[keys[i]] = true end
    for k, s in pairs(self._shape) do
      if key_set[k] then
        local field = s:_clone()
        field._is_optional = false
        field._has_default = false
        new_shape[k] = field
      else
        new_shape[k] = s
      end
    end
  else
    for k, s in pairs(self._shape) do
      local field = s:_clone()
      field._is_optional = false
      field._has_default = false
      new_shape[k] = field
    end
  end
  new._shape = new_shape
  return new
end

function ObjectSchema:pick(keys)
  if type(keys) ~= "table" then error("pick() expects a table of keys", 2) end
  local new = self:_clone()
  local key_set = {}
  for i = 1, #keys do key_set[keys[i]] = true end
  local new_shape = {}
  for k, s in pairs(self._shape) do
    if key_set[k] then new_shape[k] = s end
  end
  new._shape = new_shape
  return new
end

function ObjectSchema:omit(keys)
  if type(keys) ~= "table" then error("omit() expects a table of keys", 2) end
  local new = self:_clone()
  local key_set = {}
  for i = 1, #keys do key_set[keys[i]] = true end
  local new_shape = {}
  for k, s in pairs(self._shape) do
    if not key_set[k] then new_shape[k] = s end
  end
  new._shape = new_shape
  return new
end

function ObjectSchema:extend(extra_shape)
  if type(extra_shape) ~= "table" then error("extend() expects a table", 2) end
  local new = self:_clone()
  local merged = {}
  for k, s in pairs(self._shape) do merged[k] = s end
  for k, s in pairs(extra_shape) do merged[k] = s end
  new._shape = merged
  return new
end

function ObjectSchema:get_shape()
  local copy = {}
  for k, s in pairs(self._shape) do copy[k] = s end
  return copy
end

return ObjectSchema
