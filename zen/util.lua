local util = {}

util.EMPTY_PATH = {}

function util.is_schema(v)
  return type(v) == "table" and type(v._validate) == "function"
end

util.codes = {
  invalid_type      = "invalid_type",
  too_small         = "too_small",
  too_big           = "too_big",
  invalid_string    = "invalid_string",
  invalid_enum      = "invalid_enum",
  invalid_literal   = "invalid_literal",
  invalid_union     = "invalid_union",
  unrecognized_keys = "unrecognized_keys",
  custom            = "custom",
}

function util.deep_copy(t, depth)
  if type(t) ~= "table" then return t end
  depth = (depth or 0) + 1
  if depth > 64 then return t end
  local copy = {}
  for k, v in pairs(t) do
    copy[util.deep_copy(k, depth)] = util.deep_copy(v, depth)
  end
  return copy
end

function util.copy_list(t)
  local new = {}
  for i = 1, #t do new[i] = t[i] end
  return new
end

function util.is_sequential(t)
  if type(t) ~= "table" then return false end
  local max_key = 0
  local count = 0
  for k in pairs(t) do
    if type(k) ~= "number" or k < 1 or k ~= math.floor(k) then
      return false
    end
    count = count + 1
    if k > max_key then max_key = k end
  end
  return max_key == count
end

function util.format_path(path)
  if #path == 0 then return "" end
  local parts = {}
  for i = 1, #path do
    parts[i] = tostring(path[i])
  end
  return table.concat(parts, ".")
end

function util.coerce_string(val)
  if type(val) == "string" then return val end
  if val == nil then return val end
  return tostring(val)
end

function util.coerce_number(val)
  if type(val) == "number" then return val end
  if type(val) == "string" then return tonumber(val) or val end
  if type(val) == "boolean" then return val and 1 or 0 end
  return val
end

function util.coerce_boolean(val)
  if type(val) == "boolean" then return val end
  if type(val) == "string" then
    local lower = val:lower()
    if lower == "true" or lower == "1" or lower == "yes" then return true end
    if lower == "false" or lower == "0" or lower == "no" or lower == "" then return false end
  end
  if type(val) == "number" then
    if val == 1 then return true end
    if val == 0 then return false end
  end
  return val
end

return util
