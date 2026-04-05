local BaseSchema = require("zen.base")
local util = require("zen.util")
local codes = util.codes

local DAYS_IN_MONTH = {31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31}

local function is_leap_year(y)
  return (y % 4 == 0 and y % 100 ~= 0) or (y % 400 == 0)
end

local function max_day(year, month)
  if month == 2 and is_leap_year(year) then return 29 end
  return DAYS_IN_MONTH[month]
end

local function check_email(s)
  local at = s:find("@", 1, true)
  if not at or at == 1 or at == #s then return false end
  if s:find("@", at + 1, true) then return false end

  local local_part = s:sub(1, at - 1)
  local domain = s:sub(at + 1)

  if #local_part == 0 or #local_part > 64 then return false end
  if local_part:byte(1) == 46 or local_part:byte(-1) == 46 then return false end
  if local_part:find("%.%.") then return false end
  if local_part:find("%s") then return false end
  if local_part:find("[^%w%._%+%-']") then return false end

  if #domain == 0 or #domain > 253 then return false end
  if not domain:find(".", 1, true) then return false end
  if domain:byte(1) == 46 or domain:byte(-1) == 46 then return false end
  if domain:find("%.%.") then return false end

  for label in domain:gmatch("[^%.]+") do
    if #label == 0 or #label > 63 then return false end
    if label:byte(1) == 45 or label:byte(-1) == 45 then return false end
    if label:find("[^%w%-]") then return false end
  end

  local tld = domain:match("[^%.]+$")
  if not tld or #tld < 2 then return false end
  if tld:find("[^%a]") then return false end

  return true
end

local function check_url(s)
  local lower = s:sub(1, 8):lower()
  if lower:sub(1, 7) ~= "http://" and lower:sub(1, 8) ~= "https://" then return false end
  local rest = s:match("^[Hh][Tt][Tt][Pp][Ss]?://(.+)$")
  if not rest or #rest == 0 then return false end

  local host = rest:match("^([^/?#]+)")
  if not host or #host == 0 then return false end

  local hostname = host:match("^(.+):%d+$") or host
  hostname = hostname:match("^.+@(.+)$") or hostname

  if #hostname == 0 then return false end
  if hostname:find("%s") then return false end

  if hostname:lower() == "localhost" then return true end
  if hostname:match("^%d+%.%d+%.%d+%.%d+$") then return true end
  if not hostname:find(".", 1, true) then return false end

  for label in hostname:gmatch("[^%.]+") do
    if #label == 0 or #label > 63 then return false end
  end

  return true
end

local function check_uuid(s)
  if #s ~= 36 then return false end
  for i = 1, 36 do
    local b = s:byte(i)
    if i == 9 or i == 14 or i == 19 or i == 24 then
      if b ~= 45 then return false end
    elseif not ((b >= 48 and b <= 57) or (b >= 65 and b <= 70) or (b >= 97 and b <= 102)) then
      return false
    end
  end
  return true
end

local function check_octet(part)
  if #part > 1 and part:byte(1) == 48 then return false end
  local n = tonumber(part)
  return n and n <= 255
end

local function check_ipv4(s)
  local a, b, c, d = s:match("^(%d+)%.(%d+)%.(%d+)%.(%d+)$")
  if not a then return false end
  return check_octet(a) and check_octet(b) and check_octet(c) and check_octet(d)
end

local function check_ipv6(s)
  if s:find("[^%x:%.]+") then return false end
  local dc = s:find("::", 1, true)
  if dc and s:find("::", dc + 1, true) then return false end

  local groups = {}
  local pos = 1
  while pos <= #s do
    local sep = s:find(":", pos, true)
    if sep == pos then
      groups[#groups + 1] = ""
      pos = sep + 1
      if pos <= #s and s:byte(pos) == 58 then pos = pos + 1 end
    elseif sep then
      groups[#groups + 1] = s:sub(pos, sep - 1)
      pos = sep + 1
    else
      groups[#groups + 1] = s:sub(pos)
      break
    end
  end

  local last = groups[#groups]
  if last and last:find(".", 1, true) then
    if not check_ipv4(last) then return false end
    groups[#groups] = nil
    local ipv4_groups = 2
    if dc then
      if #groups + ipv4_groups > 6 then return false end
    else
      if #groups + ipv4_groups ~= 8 then return false end
    end
    for i = 1, #groups do
      local g = groups[i]
      if g ~= "" then
        if #g > 4 or #g == 0 then return false end
      end
    end
    return true
  end

  if dc then
    if #groups > 8 then return false end
    for i = 1, #groups do
      local g = groups[i]
      if g ~= "" then
        if #g > 4 or #g == 0 then return false end
      end
    end
  else
    if #groups ~= 8 then return false end
    for i = 1, 8 do
      local g = groups[i]
      if not g or #g == 0 or #g > 4 then return false end
    end
  end

  return true
end

local function check_datetime(s)
  local year, month, day, hour, min, sec, rest = s:match(
    "^(%d%d%d%d)%-(%d%d)%-(%d%d)[T ](%d%d):(%d%d):(%d%d)(.*)$"
  )
  if not year then return false end
  year = tonumber(year)
  month, day = tonumber(month), tonumber(day)
  hour, min, sec = tonumber(hour), tonumber(min), tonumber(sec)
  if month < 1 or month > 12 then return false end
  if day < 1 or day > max_day(year, month) then return false end
  if hour > 23 or min > 59 or sec > 59 then return false end
  if rest == "" or rest == "Z" or rest == "z" then return true end
  if rest:byte(1) == 46 then
    rest = rest:match("^%.%d+(.*)$")
    if not rest then return false end
  end
  if rest == "" or rest == "Z" or rest == "z" then return true end
  local tz_h, tz_m = rest:match("^[%+%-](%d%d):(%d%d)$")
  if not tz_h then return false end
  if tonumber(tz_h) > 23 or tonumber(tz_m) > 59 then return false end
  return true
end

local function check_date(s)
  local year, month, day = s:match("^(%d%d%d%d)%-(%d%d)%-(%d%d)$")
  if not year then return false end
  year = tonumber(year)
  month, day = tonumber(month), tonumber(day)
  if month < 1 or month > 12 then return false end
  if day < 1 or day > max_day(year, month) then return false end
  return true
end

local function check_time(s)
  local hour, min, sec, rest = s:match("^(%d%d):(%d%d):(%d%d)(.*)$")
  if not hour then return false end
  if tonumber(hour) > 23 or tonumber(min) > 59 or tonumber(sec) > 59 then return false end
  if rest == "" then return true end
  if rest:match("^%.%d+$") then return true end
  return false
end

local StringSchema = setmetatable({}, {__index = BaseSchema})
StringSchema.__index = StringSchema

function StringSchema._new()
  return BaseSchema._new("string", StringSchema)
end

function StringSchema:_check_type(value) return type(value) == "string" end
function StringSchema:_type_error() return "must be a string" end

function StringSchema:min(n, msg)
  if type(n) ~= "number" then error("min() expects a number, got " .. type(n), 2) end
  return self:_add_check(function(val)
    if #val < n then
      return false, msg or ("must be at least " .. n .. (n == 1 and " character" or " characters")), codes.too_small
    end
    return true
  end)
end

function StringSchema:max(n, msg)
  if type(n) ~= "number" then error("max() expects a number, got " .. type(n), 2) end
  return self:_add_check(function(val)
    if #val > n then
      return false, msg or ("must be at most " .. n .. (n == 1 and " character" or " characters")), codes.too_big
    end
    return true
  end)
end

function StringSchema:length(n, msg)
  if type(n) ~= "number" then error("length() expects a number, got " .. type(n), 2) end
  return self:_add_check(function(val)
    if #val ~= n then
      local code = #val < n and codes.too_small or codes.too_big
      return false, msg or ("must be exactly " .. n .. (n == 1 and " character" or " characters")), code
    end
    return true
  end)
end

function StringSchema:email(msg)
  return self:_add_check(function(val)
    if not check_email(val) then return false, msg or "must be a valid email address", codes.invalid_string end
    return true
  end)
end

function StringSchema:url(msg)
  return self:_add_check(function(val)
    if not check_url(val) then return false, msg or "must be a valid URL", codes.invalid_string end
    return true
  end)
end

function StringSchema:uuid(msg)
  return self:_add_check(function(val)
    if not check_uuid(val) then return false, msg or "must be a valid UUID", codes.invalid_string end
    return true
  end)
end

function StringSchema:pattern(pat, msg)
  if type(pat) ~= "string" then error("pattern() expects a string, got " .. type(pat), 2) end
  return self:_add_check(function(val)
    if not val:find(pat) then return false, msg or ("must match pattern: " .. pat), codes.invalid_string end
    return true
  end)
end

function StringSchema:contains(substr, msg)
  if type(substr) ~= "string" then error("contains() expects a string, got " .. type(substr), 2) end
  return self:_add_check(function(val)
    if not val:find(substr, 1, true) then return false, msg or ("must contain \"" .. substr .. "\""), codes.invalid_string end
    return true
  end)
end

function StringSchema:starts_with(prefix, msg)
  if type(prefix) ~= "string" then error("starts_with() expects a string, got " .. type(prefix), 2) end
  return self:_add_check(function(val)
    if val:sub(1, #prefix) ~= prefix then return false, msg or ("must start with \"" .. prefix .. "\""), codes.invalid_string end
    return true
  end)
end

function StringSchema:ends_with(suffix, msg)
  if type(suffix) ~= "string" then error("ends_with() expects a string, got " .. type(suffix), 2) end
  return self:_add_check(function(val)
    if #suffix == 0 then return true end
    if val:sub(-#suffix) ~= suffix then return false, msg or ("must end with \"" .. suffix .. "\""), codes.invalid_string end
    return true
  end)
end

function StringSchema:trim()
  return self:_add_transform(function(val) return (val:gsub("^%s+", "")):gsub("%s+$", "") end)
end

function StringSchema:to_lower()  return self:_add_transform(string.lower) end
function StringSchema:to_upper()  return self:_add_transform(string.upper) end
function StringSchema:nonempty(msg) return self:min(1, msg) end

function StringSchema:ipv4(msg)
  return self:_add_check(function(val)
    if not check_ipv4(val) then return false, msg or "must be a valid IPv4 address", codes.invalid_string end
    return true
  end)
end

function StringSchema:ipv6(msg)
  return self:_add_check(function(val)
    if not check_ipv6(val) then return false, msg or "must be a valid IPv6 address", codes.invalid_string end
    return true
  end)
end

function StringSchema:datetime(msg)
  return self:_add_check(function(val)
    if not check_datetime(val) then return false, msg or "must be a valid ISO 8601 datetime string", codes.invalid_string end
    return true
  end)
end

function StringSchema:date(msg)
  return self:_add_check(function(val)
    if not check_date(val) then return false, msg or "must be a valid date (YYYY-MM-DD)", codes.invalid_string end
    return true
  end)
end

function StringSchema:time(msg)
  return self:_add_check(function(val)
    if not check_time(val) then return false, msg or "must be a valid time (HH:MM:SS)", codes.invalid_string end
    return true
  end)
end

function StringSchema:base64(msg)
  return self:_add_check(function(val)
    if #val == 0 or #val % 4 ~= 0 or not val:find("^[A-Za-z0-9+/]*=?=?$") then
      return false, msg or "must be valid base64", codes.invalid_string
    end
    return true
  end)
end

function StringSchema:hex(msg)
  return self:_add_check(function(val)
    if #val == 0 or val:find("[^%x]") then return false, msg or "must be a valid hex string", codes.invalid_string end
    return true
  end)
end

return StringSchema
