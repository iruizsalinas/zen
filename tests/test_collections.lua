local h = require("tests.helpers")
local z = require("zen")
local describe, it = h.describe, h.it
local assert_eq, assert_true, assert_false = h.assert_eq, h.assert_true, h.assert_false
local assert_error_has = h.assert_error_has

describe("z.array()", function()
  it("validates arrays of strings", function()
    local result = z.array(z.string()):parse({"a", "b", "c"})
    assert_eq(result[1], "a")
    assert_eq(result[2], "b")
    assert_eq(result[3], "c")
  end)

  it("validates arrays of numbers", function()
    local result = z.array(z.number()):parse({1, 2, 3})
    assert_eq(result[1], 1)
    assert_eq(result[3], 3)
  end)

  it("reports item errors with correct path", function()
    local ok, errs = z.array(z.number()):safe_parse({1, "two", 3})
    assert_false(ok)
    assert_error_has(errs, {2}, "must be a number")
  end)

  it("reports multiple item errors", function()
    local ok, errs = z.array(z.number()):safe_parse({"a", "b", "c"})
    assert_false(ok)
    assert_error_has(errs, {1}, "must be a number")
    assert_error_has(errs, {2}, "must be a number")
    assert_error_has(errs, {3}, "must be a number")
  end)

  it(":min() enforces minimum length", function()
    assert_eq(#z.array(z.number()):min(2):parse({1, 2}), 2)
    local ok, errs = z.array(z.number()):min(2):safe_parse({1})
    assert_false(ok)
    assert_eq(errs[1].code, "too_small")
  end)

  it(":max() enforces maximum length", function()
    local ok, errs = z.array(z.number()):max(2):safe_parse({1, 2, 3})
    assert_false(ok)
    assert_eq(errs[1].code, "too_big")
  end)

  it(":nonempty() requires at least one element", function()
    assert_false((z.array(z.number()):nonempty():safe_parse({})))
    assert_eq(#z.array(z.number()):nonempty():parse({1}), 1)
  end)

  it(":length() enforces exact length", function()
    assert_false((z.array(z.number()):length(3):safe_parse({1, 2})))
    assert_false((z.array(z.number()):length(3):safe_parse({1, 2, 3, 4})))
    assert_eq(#z.array(z.number()):length(3):parse({1, 2, 3}), 3)
  end)

  it("validates empty arrays", function()
    local result = z.array(z.string()):parse({})
    local count = 0
    for _ in pairs(result) do count = count + 1 end
    assert_eq(count, 0)
  end)

  it("rejects non-sequential tables", function()
    assert_false((z.array(z.number()):safe_parse({a = 1, b = 2})))
  end)

  it("rejects non-table input", function()
    assert_false((z.array(z.string()):safe_parse("not an array")))
    assert_false((z.array(z.string()):safe_parse(42)))
  end)

  it("validates nested arrays", function()
    local result = z.array(z.array(z.number())):parse({{1, 2}, {3, 4}})
    assert_eq(result[1][1], 1)
    assert_eq(result[2][2], 4)
  end)

  it("validates arrays of objects", function()
    local ok, errs = z.array(z.object({name = z.string()})):safe_parse({{name = "Alice"}, {age = 30}})
    assert_false(ok)
    assert_error_has(errs, {2, "name"}, "required")
  end)
end)

describe("z.tuple()", function()
  it("validates per-position schemas", function()
    local ok, result = z.tuple(z.string(), z.number(), z.boolean()):safe_parse({"hello", 42, true})
    assert_true(ok)
    assert_eq(result[1], "hello")
    assert_eq(result[2], 42)
    assert_eq(result[3], true)
  end)

  it("rejects wrong length", function()
    assert_false((z.tuple(z.string(), z.number()):safe_parse({"hello"})))
    assert_false((z.tuple(z.string(), z.number()):safe_parse({"hello", 42, true})))
  end)

  it("reports per-position type errors", function()
    local ok, errs = z.tuple(z.string(), z.number()):safe_parse({"hello", "world"})
    assert_false(ok)
    assert_error_has(errs, {2}, "must be a number")
  end)
end)

describe("z.record()", function()
  it("validates values against schema", function()
    local ok, result = z.record(z.number()):safe_parse({x = 1, y = 2, z = 3})
    assert_true(ok)
    assert_eq(result.x, 1)
  end)

  it("rejects invalid values", function()
    local ok, errs = z.record(z.number()):safe_parse({x = 1, y = "bad"})
    assert_false(ok)
    assert_error_has(errs, {"y"}, "must be a number")
  end)

  it("validates keys when key schema provided", function()
    local ok, errs = z.record(z.string():min(2), z.number()):safe_parse({x = 1, ab = 2})
    assert_false(ok)
    assert_error_has(errs, {"x"}, "at least 2")
  end)

  it("returns clean copy", function()
    local input = {a = 1, b = 2}
    local result = z.record(z.number()):parse(input)
    assert_true(result ~= input)
    assert_eq(result.a, 1)
  end)
end)
