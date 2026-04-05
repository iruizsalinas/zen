local h = require("tests.helpers")
local z = require("zen")
local describe, it = h.describe, h.it
local assert_eq, assert_true, assert_false = h.assert_eq, h.assert_true, h.assert_false
local assert_throws, assert_error_has = h.assert_throws, h.assert_error_has

describe("parse modes", function()
  it(":parse() returns clean data on success", function()
    assert_eq(z.string():parse("hello"), "hello")
  end)

  it(":parse() throws on failure", function()
    assert_throws(function() z.string():parse(42) end, "Validation failed")
  end)

  it(":safe_parse() returns true, data on success", function()
    local ok, result = z.string():safe_parse("hello")
    assert_true(ok)
    assert_eq(result, "hello")
  end)

  it(":safe_parse() returns false, errors on failure", function()
    local ok, errs = z.string():safe_parse(42)
    assert_false(ok)
    assert_eq(type(errs), "table")
    assert_true(#errs > 0)
  end)
end)

describe("error format", function()
  it("errors have path, message, and code", function()
    local ok, errs = z.string():safe_parse(42)
    assert_false(ok)
    assert_eq(type(errs[1].path), "table")
    assert_eq(type(errs[1].message), "string")
    assert_eq(type(errs[1].code), "string")
  end)

  it("top-level errors have empty path", function()
    local ok, errs = z.string():safe_parse(42)
    assert_eq(#errs[1].path, 0)
  end)

  it("object errors have field in path", function()
    local ok, errs = z.object({name = z.string()}):safe_parse({})
    assert_eq(errs[1].path[1], "name")
  end)

  it("nested object errors have full path", function()
    local ok, errs = z.object({user = z.object({profile = z.object({name = z.string()})})}):safe_parse({user = {profile = {}}})
    assert_false(ok)
    assert_eq(errs[1].path[1], "user")
    assert_eq(errs[1].path[2], "profile")
    assert_eq(errs[1].path[3], "name")
  end)

  it("array errors have numeric index in path", function()
    local ok, errs = z.array(z.string()):safe_parse({1, 2, 3})
    assert_false(ok)
    assert_eq(type(errs[1].path[1]), "number")
  end)

  it("parse() error includes path", function()
    assert_throws(function() z.object({name = z.string()}):parse({}) end, "name: required")
  end)
end)

describe("optional / default", function()
  it(":optional() lets nil pass for any type", function()
    assert_eq(z.string():optional():parse(nil), nil)
    assert_eq(z.number():optional():parse(nil), nil)
    assert_eq(z.boolean():optional():parse(nil), nil)
  end)

  it(":default() provides value when nil", function()
    assert_eq(z.string():default("fallback"):parse(nil), "fallback")
    assert_eq(z.number():default(0):parse(nil), 0)
  end)

  it(":default() with function", function()
    local schema = z.number():default(function() return 42 end)
    assert_eq(schema:parse(nil), 42)
    local calls = 0
    local s2 = z.number():default(function() calls = calls + 1; return calls end)
    assert_eq(s2:parse(nil), 1)
    assert_eq(s2:parse(nil), 2)
  end)

  it(":default() uses provided value over default", function()
    assert_eq(z.string():default("fallback"):parse("custom"), "custom")
  end)

  it(":optional() still validates non-nil types", function()
    assert_false((z.string():optional():safe_parse(123)))
  end)
end)

describe(".catch()", function()
  it("returns fallback on type error", function()
    assert_eq(z.string():catch("default"):parse(42), "default")
  end)

  it("returns fallback on validation error", function()
    assert_eq(z.string():min(5):catch("short"):parse("hi"), "short")
  end)

  it("returns normal value on success", function()
    assert_eq(z.string():catch("default"):parse("hello"), "hello")
  end)

  it("returns fallback on nil when not optional", function()
    assert_eq(z.string():catch("none"):parse(nil), "none")
  end)

  it("supports function fallback", function()
    local calls = 0
    local schema = z.string():catch(function() calls = calls + 1; return "fb" .. calls end)
    assert_eq(schema:parse(42), "fb1")
    assert_eq(schema:parse(42), "fb2")
  end)
end)

describe(".describe()", function()
  it("attaches description metadata", function()
    assert_eq(z.string():describe("User's name")._description, "User's name")
  end)

  it("does not affect validation", function()
    local schema = z.string():min(1):describe("Name")
    assert_eq(schema:parse("Alice"), "Alice")
    assert_false((schema:safe_parse("")))
  end)

  it("is preserved through chaining", function()
    assert_eq(z.string():describe("Name"):min(1)._description, "Name")
  end)
end)

describe("custom error messages", function()
  it("string :min() with custom message", function()
    local ok, errs = z.string():min(3, "Name too short"):safe_parse("ab")
    assert_false(ok)
    assert_eq(errs[1].message, "Name too short")
  end)

  it("string :email() with custom message", function()
    local ok, errs = z.string():email("Invalid email"):safe_parse("bad")
    assert_false(ok)
    assert_eq(errs[1].message, "Invalid email")
  end)

  it("number :min() with custom message", function()
    local ok, errs = z.number():min(18, "Must be an adult"):safe_parse(12)
    assert_false(ok)
    assert_eq(errs[1].message, "Must be an adult")
  end)

  it("number :positive() with custom message", function()
    local ok, errs = z.number():positive("Must be positive"):safe_parse(-1)
    assert_false(ok)
    assert_eq(errs[1].message, "Must be positive")
  end)

  it("number :integer() with custom message", function()
    local ok, errs = z.number():integer("Whole numbers only"):safe_parse(3.5)
    assert_false(ok)
    assert_eq(errs[1].message, "Whole numbers only")
  end)

  it("array :nonempty() with custom message", function()
    local ok, errs = z.array(z.string()):nonempty("Need at least one tag"):safe_parse({})
    assert_false(ok)
    assert_eq(errs[1].message, "Need at least one tag")
  end)

  it("uses default message when none provided", function()
    local ok, errs = z.string():min(3):safe_parse("ab")
    assert_false(ok)
    assert_true(errs[1].message:find("at least 3"))
  end)

  it("works in object fields", function()
    local schema = z.object({
      name = z.string():min(1, "Name is required"),
      age = z.number():min(0, "Age cannot be negative"),
    })
    local ok, errs = schema:safe_parse({name = "", age = -1})
    assert_false(ok)
    assert_error_has(errs, {"name"}, "Name is required")
    assert_error_has(errs, {"age"}, "Age cannot be negative")
  end)
end)

describe(":refine()", function()
  it("custom validator passes", function()
    assert_eq(z.string():refine(function(val) return val ~= "admin" end, "cannot be admin"):parse("user"), "user")
  end)

  it("custom validator fails", function()
    local ok, errs = z.string():refine(function(val) return val ~= "admin" end, "cannot be admin"):safe_parse("admin")
    assert_false(ok)
    assert_eq(errs[1].code, "custom")
    assert_true(errs[1].message:find("cannot be admin"))
  end)

  it("default error message", function()
    local ok, errs = z.number():refine(function(val) return val % 2 == 0 end):safe_parse(3)
    assert_false(ok)
    assert_true(errs[1].message:find("custom validation failed"))
  end)

  it("validates API input", function()
    assert_throws(function() z.string():refine("not a function") end, "expects a function")
  end)
end)

describe(":superRefine()", function()
  it("adds multiple issues", function()
    local schema = z.object({password = z.string(), confirm = z.string()})
      :superRefine(function(val, ctx)
        if val.password ~= val.confirm then
          ctx.add_issue({path = {"confirm"}, message = "passwords do not match"})
        end
      end)
    local ok, errs = schema:safe_parse({password = "abc", confirm = "xyz"})
    assert_false(ok)
    local found = false
    for _, e in ipairs(errs) do
      if e.message == "passwords do not match" then found = true end
    end
    assert_true(found)
  end)

  it("passes when no issues added", function()
    assert_eq(z.string():superRefine(function(val, ctx) end):parse("hello"), "hello")
  end)
end)

describe(":transform()", function()
  it("transforms the value", function()
    assert_eq(z.string():transform(string.upper):parse("hello"), "HELLO")
  end)

  it("chains with validation", function()
    assert_eq(z.string():trim():transform(string.lower):parse("  HELLO  "), "hello")
  end)

  it("transforms numbers", function()
    assert_eq(z.number():transform(function(val) return val * 2 end):parse(5), 10)
  end)

  it("does not run on validation failure", function()
    local transformed = false
    local schema = z.string():min(5):transform(function(val) transformed = true; return val:upper() end)
    z.string():min(5):safe_parse("hi")
    assert_false(transformed)
  end)

  it("validates API input", function()
    assert_throws(function() z.string():transform("not a function") end, "expects a function")
  end)
end)

describe("schema immutability", function()
  it("chaining creates new schemas, not mutations", function()
    local base = z.string()
    local with_min = base:min(3)
    local with_max = base:max(10)
    assert_true((base:safe_parse("")))
    assert_false((with_min:safe_parse("ab")))
    assert_true((with_max:safe_parse("ab")))
    assert_false((with_max:safe_parse("this is way too long")))
  end)

  it("optional doesn't mutate original", function()
    local req = z.string()
    local opt = req:optional()
    assert_false((req:safe_parse(nil)))
    assert_true((opt:safe_parse(nil)))
  end)

  it("object strict doesn't mutate original", function()
    local base = z.object({name = z.string()})
    local strict = base:strict()
    local result = base:parse({name = "Alice", age = 30})
    assert_eq(result.age, nil)
    assert_false((strict:safe_parse({name = "Alice", age = 30})))
  end)
end)

describe("z.coerce", function()
  it("coerce.number() converts strings", function()
    assert_eq(z.coerce.number():parse("42"), 42)
    assert_eq(z.coerce.number():parse("3.14"), 3.14)
    assert_eq(z.coerce.number():parse(42), 42)
  end)

  it("coerce.number() fails on non-numeric strings", function()
    assert_false((z.coerce.number():safe_parse("abc")))
  end)

  it("coerce.string() converts numbers", function()
    assert_eq(z.coerce.string():parse(42), "42")
    assert_eq(z.coerce.string():parse(true), "true")
  end)

  it("coerce.boolean() converts strings", function()
    assert_eq(z.coerce.boolean():parse("true"), true)
    assert_eq(z.coerce.boolean():parse("false"), false)
    assert_eq(z.coerce.boolean():parse("1"), true)
    assert_eq(z.coerce.boolean():parse("0"), false)
    assert_eq(z.coerce.boolean():parse("yes"), true)
    assert_eq(z.coerce.boolean():parse("no"), false)
  end)

  it("coerce.boolean() fails on unrecognized strings", function()
    assert_false((z.coerce.boolean():safe_parse("maybe")))
  end)

  it("coerce.integer() converts and validates", function()
    assert_eq(z.coerce.integer():parse("42"), 42)
    assert_false((z.coerce.integer():safe_parse("3.14")))
  end)

  it("coercion chains with validators", function()
    assert_eq(z.coerce.number():min(10):parse("42"), 42)
    assert_false((z.coerce.number():min(10):safe_parse("5")))
  end)
end)

describe("z.custom()", function()
  it("validates with custom function", function()
    local schema = z.custom(function(val) return type(val) == "string" end, "must be string")
    assert_eq(schema:parse("hi"), "hi")
    assert_false((schema:safe_parse(42)))
  end)
end)

describe("zen.flatten_errors()", function()
  it("flattens errors by path", function()
    local ok, errs = z.object({name = z.string():min(1), age = z.number()}):safe_parse({name = "", age = "bad"})
    assert_false(ok)
    local flat = z.flatten_errors(errs)
    assert_true(flat.name ~= nil)
    assert_true(flat.age ~= nil)
    assert_true(#flat.name > 0)
  end)

  it("puts root errors under _root", function()
    local ok, errs = z.string():safe_parse(42)
    local flat = z.flatten_errors(errs)
    assert_true(flat._root ~= nil)
  end)
end)
