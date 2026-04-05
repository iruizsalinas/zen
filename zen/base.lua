local util = require("zen.util")
local copy_list = util.copy_list
local format_path = util.format_path
local EMPTY_PATH = util.EMPTY_PATH
local codes = util.codes

local BaseSchema = {}
BaseSchema.__index = BaseSchema

function BaseSchema._new(schema_type, mt)
  return setmetatable({
    _schema_type = schema_type,
    _pipeline    = {},
    _is_optional = false,
    _has_default = false,
    _default_val = nil,
    _has_catch   = false,
    _catch_val   = nil,
    _coerce      = nil,
    _description = nil,
  }, mt or BaseSchema)
end

function BaseSchema:_clone()
  local new = {}
  for k, v in pairs(self) do
    if k == "_pipeline" then
      new[k] = copy_list(v)
    else
      new[k] = v
    end
  end
  return setmetatable(new, getmetatable(self))
end

function BaseSchema:_add_check(fn)
  local new = self:_clone()
  new._pipeline[#new._pipeline + 1] = {kind = "check", fn = fn}
  return new
end

function BaseSchema:_add_transform(fn)
  local new = self:_clone()
  new._pipeline[#new._pipeline + 1] = {kind = "transform", fn = fn}
  return new
end

function BaseSchema:_check_type(value) return true end
function BaseSchema:_type_error() return "invalid value" end
function BaseSchema:_validate_type(value, path) return value, nil end

function BaseSchema:_do_catch()
  local c = self._catch_val
  if type(c) == "function" then c = c() end
  return c
end

function BaseSchema:_run_pipeline(result, path)
  local errors
  local current = result
  for i = 1, #self._pipeline do
    local step = self._pipeline[i]
    if step.kind == "check" then
      local ok, msg, code = step.fn(current)
      if not ok then
        if not errors then errors = {} end
        errors[#errors + 1] = {
          path    = copy_list(path),
          message = msg or "validation failed",
          code    = code or codes.custom,
        }
      end
    elseif step.kind == "transform" then
      if not errors then
        current = step.fn(current)
      end
    elseif step.kind == "super_check" then
      local issues = step.fn(current)
      if issues and #issues > 0 then
        if not errors then errors = {} end
        for j = 1, #issues do
          local issue = issues[j]
          local issue_path = copy_list(path)
          if issue.path then
            for k = 1, #issue.path do
              issue_path[#issue_path + 1] = issue.path[k]
            end
          end
          errors[#errors + 1] = {
            path    = issue_path,
            message = issue.message or "validation failed",
            code    = issue.code or codes.custom,
          }
        end
      end
    elseif step.kind == "pipe" then
      if not errors then
        local pipe_result, pipe_errors = step.schema:_validate(current, path)
        if pipe_errors then
          errors = pipe_errors
        else
          current = pipe_result
        end
      end
    end
  end
  return current, errors
end

function BaseSchema:_validate(value, path)
  path = path or EMPTY_PATH

  if self._coerce and value ~= nil then
    value = self._coerce(value)
  end

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

  if not self:_check_type(value) then
    if self._has_catch then return self:_do_catch(), nil end
    return nil, {{path = copy_list(path), message = self:_type_error(), code = codes.invalid_type}}
  end

  local result, errors = self:_validate_type(value, path)
  if errors then
    if self._has_catch then return self:_do_catch(), nil end
    return result, errors
  end

  if #self._pipeline == 0 then return result, nil end

  local final, pipe_errors = self:_run_pipeline(result, path)
  if pipe_errors then
    if self._has_catch then return self:_do_catch(), nil end
    return final, pipe_errors
  end

  return final, nil
end

function BaseSchema:parse(data)
  local result, errors = self:_validate(data)
  if errors then
    local parts = {}
    for i = 1, #errors do
      local e = errors[i]
      local prefix = #e.path > 0 and (format_path(e.path) .. ": ") or ""
      parts[#parts + 1] = prefix .. e.message
    end
    error("Validation failed:\n  " .. table.concat(parts, "\n  "), 2)
  end
  return result
end

function BaseSchema:safe_parse(data)
  local ok, result, errors = pcall(self._validate, self, data)
  if not ok then
    return false, {{path = {}, message = tostring(result), code = codes.custom}}
  end
  if errors then return false, errors end
  return true, result
end

function BaseSchema:optional()
  local new = self:_clone()
  new._is_optional = true
  return new
end

function BaseSchema:default(value)
  local new = self:_clone()
  new._has_default = true
  new._default_val = value
  new._is_optional = true
  return new
end

function BaseSchema:catch(value)
  local new = self:_clone()
  new._has_catch = true
  new._catch_val = value
  return new
end

function BaseSchema:describe(text)
  local new = self:_clone()
  new._description = text
  return new
end

function BaseSchema:refine(fn, message)
  if type(fn) ~= "function" then
    error("refine() expects a function as first argument", 2)
  end
  return self:_add_check(function(val)
    if fn(val) then return true end
    return false, message or "custom validation failed", codes.custom
  end)
end

function BaseSchema:superRefine(fn)
  if type(fn) ~= "function" then
    error("superRefine() expects a function as first argument", 2)
  end
  local new = self:_clone()
  new._pipeline[#new._pipeline + 1] = {kind = "super_check", fn = function(val)
    local issues = {}
    local ctx = {
      add_issue = function(opts)
        issues[#issues + 1] = {
          path    = opts.path,
          message = opts.message or "validation failed",
          code    = opts.code or codes.custom,
        }
      end
    }
    fn(val, ctx)
    return issues
  end}
  return new
end

function BaseSchema:transform(fn)
  if type(fn) ~= "function" then
    error("transform() expects a function as first argument", 2)
  end
  return self:_add_transform(fn)
end

function BaseSchema:pipe(schema)
  local new = self:_clone()
  new._pipeline[#new._pipeline + 1] = {kind = "pipe", schema = schema}
  return new
end

-- and_/or_ use constructors injected by init.lua to avoid circular requires
function BaseSchema:and_(schema)
  return BaseSchema._intersection_ctor(self, schema)
end

function BaseSchema:or_(schema)
  return BaseSchema._union_ctor({self, schema})
end

return BaseSchema
