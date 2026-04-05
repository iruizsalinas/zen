local helpers = {}

local total, passed, failed = 0, 0, 0
local current_section = ""
local failures = {}

function helpers.describe(name, fn)
  current_section = name
  fn()
end

function helpers.it(name, fn)
  total = total + 1
  local ok, err = pcall(fn)
  if ok then
    passed = passed + 1
  else
    failed = failed + 1
    failures[#failures + 1] = current_section .. " > " .. name .. "\n    " .. tostring(err)
    io.write("F")
    io.flush()
    return
  end
  io.write(".")
  io.flush()
end

function helpers.assert_eq(actual, expected, msg)
  if actual ~= expected then
    error((msg or "") .. " expected: " .. tostring(expected) .. ", got: " .. tostring(actual), 2)
  end
end

function helpers.assert_true(val, msg)
  if not val then error(msg or "expected true, got " .. tostring(val), 2) end
end

function helpers.assert_false(val, msg)
  if val then error(msg or "expected false, got " .. tostring(val), 2) end
end

function helpers.assert_throws(fn, substr)
  local ok, err = pcall(fn)
  if ok then error("expected error to be thrown", 2) end
  if substr and not tostring(err):find(substr, 1, true) then
    error("expected error containing '" .. substr .. "', got: " .. tostring(err), 2)
  end
end

function helpers.assert_error_has(errors, field_path, msg_substr)
  if type(field_path) == "string" then field_path = {field_path} end
  for i = 1, #errors do
    local e = errors[i]
    local path_match = true
    if #e.path == #field_path then
      for j = 1, #field_path do
        if e.path[j] ~= field_path[j] then path_match = false; break end
      end
    else
      path_match = false
    end
    if path_match then
      if not msg_substr or e.message:find(msg_substr, 1, true) then
        return true
      end
    end
  end
  local paths = {}
  for i = 1, #errors do
    local p = {}
    for j = 1, #errors[i].path do p[j] = tostring(errors[i].path[j]) end
    paths[i] = "[" .. table.concat(p, ".") .. "] " .. errors[i].message
  end
  error("no error with path {" .. table.concat(field_path, ".") ..
    "} and message '" .. (msg_substr or "*") .. "'\n    errors: " ..
    table.concat(paths, "; "), 2)
end

function helpers.report()
  print()
  print()
  if failed == 0 then
    print(string.format("All %d tests passed.", total))
  else
    print(string.format("%d passed, %d failed out of %d tests.", passed, failed, total))
    print()
    for i = 1, #failures do
      print("FAIL: " .. failures[i])
    end
  end
  return failed == 0
end

return helpers
