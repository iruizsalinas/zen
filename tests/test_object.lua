local h = require("tests.helpers")
local z = require("zen")
local describe, it = h.describe, h.it
local assert_eq, assert_true, assert_false = h.assert_eq, h.assert_true, h.assert_false
local assert_error_has = h.assert_error_has

describe("z.object()", function()
  it("validates simple objects", function()
    local schema = z.object({name = z.string(), age = z.number()})
    local result = schema:parse({name = "Alice", age = 30})
    assert_eq(result.name, "Alice")
    assert_eq(result.age, 30)
  end)

  it("returns a clean copy", function()
    local schema = z.object({name = z.string()})
    local input = {name = "Alice", extra = "data"}
    local result = schema:parse(input)
    assert_eq(result.name, "Alice")
    assert_eq(result.extra, nil)
    assert_true(result ~= input)
  end)

  it("reports errors for missing required keys", function()
    local ok, errs = z.object({name = z.string(), email = z.string()}):safe_parse({name = "Alice"})
    assert_false(ok)
    assert_error_has(errs, {"email"}, "required")
  end)

  it("reports multiple errors", function()
    local schema = z.object({name = z.string():min(1), email = z.string():email(), role = z.enum({"admin", "user"})})
    local ok, errs = schema:safe_parse({name = "", email = "bad", role = "root"})
    assert_false(ok)
    assert_error_has(errs, {"name"}, "at least 1")
    assert_error_has(errs, {"email"}, "email")
    assert_error_has(errs, {"role"}, "one of")
  end)

  it("strips unknown keys by default", function()
    local result = z.object({name = z.string()}):parse({name = "Alice", age = 30, extra = true})
    assert_eq(result.name, "Alice")
    assert_eq(result.age, nil)
  end)

  it(":strict() rejects unknown keys", function()
    local ok, errs = z.object({name = z.string()}):strict():safe_parse({name = "Alice", age = 30})
    assert_false(ok)
    assert_error_has(errs, {"age"}, "unrecognized")
  end)

  it(":passthrough() preserves unknown keys", function()
    local result = z.object({name = z.string()}):passthrough():parse({name = "Alice", age = 30, nested = {x = 1}})
    assert_eq(result.name, "Alice")
    assert_eq(result.age, 30)
    assert_eq(result.nested.x, 1)
  end)

  it("validates nested objects recursively", function()
    local schema = z.object({address = z.object({street = z.string(), city = z.string()})})
    local result = schema:parse({address = {street = "123 Main", city = "NYC"}})
    assert_eq(result.address.street, "123 Main")
  end)

  it("reports correct paths for nested errors", function()
    local schema = z.object({address = z.object({street = z.string(), city = z.string()})})
    local ok, errs = schema:safe_parse({address = {street = "123 Main"}})
    assert_false(ok)
    assert_error_has(errs, {"address", "city"}, "required")
  end)

  it("handles optional fields", function()
    local result = z.object({name = z.string(), bio = z.string():optional()}):parse({name = "Alice"})
    assert_eq(result.name, "Alice")
    assert_eq(result.bio, nil)
  end)

  it("handles fields with defaults", function()
    local result = z.object({name = z.string(), role = z.string():default("user")}):parse({name = "Alice"})
    assert_eq(result.role, "user")
  end)

  it("rejects non-table input", function()
    local ok, errs = z.object({name = z.string()}):safe_parse("not a table")
    assert_false(ok)
    assert_true(errs[1].message:find("table"))
  end)

  it("accepts empty object with no required fields", function()
    assert_true((z.object({a = z.string():optional()}):safe_parse({})))
  end)
end)

describe("object :partial() / :required() / :pick() / :omit() / :extend()", function()
  it(":partial() makes all fields optional", function()
    assert_true((z.object({name = z.string(), age = z.number()}):partial():safe_parse({})))
  end)

  it(":partial() still validates types", function()
    assert_false((z.object({name = z.string()}):partial():safe_parse({name = 42})))
  end)

  it("selective :partial(keys)", function()
    local schema = z.object({a = z.string(), b = z.number(), c = z.boolean()}):partial({"a", "c"})
    assert_true((schema:safe_parse({b = 42})))
    assert_false((schema:safe_parse({a = "hi", c = true}))) -- b still required
  end)

  it(":required() makes all fields required", function()
    local schema = z.object({a = z.string():optional(), b = z.number():optional()}):required()
    assert_false((schema:safe_parse({})))
    assert_true((schema:safe_parse({a = "hi", b = 1})))
  end)

  it(":required(keys) makes specific fields required", function()
    local schema = z.object({
      a = z.string():optional(), b = z.number():optional(), c = z.boolean():optional(),
    }):required({"a"})
    assert_false((schema:safe_parse({b = 1, c = true})))
    assert_true((schema:safe_parse({a = "hi"})))
  end)

  it(":pick() selects fields", function()
    local base = z.object({name = z.string(), age = z.number(), email = z.string()})
    assert_true((base:pick({"name", "email"}):safe_parse({name = "Alice", email = "a@b.com"})))
  end)

  it(":pick() doesn't require omitted fields", function()
    assert_true((z.object({name = z.string(), age = z.number()}):pick({"name"}):safe_parse({name = "Alice"})))
  end)

  it(":omit() excludes fields", function()
    assert_true((z.object({name = z.string(), age = z.number(), email = z.string()}):omit({"email"}):safe_parse({name = "Alice", age = 30})))
  end)

  it(":extend() adds fields", function()
    local result = z.object({name = z.string()}):extend({age = z.number()}):parse({name = "Alice", age = 30})
    assert_eq(result.name, "Alice")
    assert_eq(result.age, 30)
  end)

  it(":extend() can overwrite fields", function()
    assert_false((z.object({name = z.string()}):extend({name = z.string():min(5)}):safe_parse({name = "Al"})))
  end)

  it("manipulation doesn't mutate original", function()
    local base = z.object({name = z.string(), age = z.number()})
    base:partial()
    base:pick({"name"})
    assert_false((base:safe_parse({name = "Alice"}))) -- age still required
  end)
end)

describe("object :get_shape() / :catchall()", function()
  it(":get_shape() returns the shape table", function()
    local shape = z.object({name = z.string(), age = z.number()}):get_shape()
    assert_true(shape.name ~= nil)
    assert_true(shape.age ~= nil)
  end)

  it(":catchall(schema) validates unknown keys", function()
    local ok, result = z.object({name = z.string()}):catchall(z.number()):safe_parse({name = "Alice", score = 42, level = 5})
    assert_true(ok)
    assert_eq(result.score, 42)
  end)

  it(":catchall(schema) rejects invalid unknown keys", function()
    assert_false((z.object({name = z.string()}):catchall(z.number()):safe_parse({name = "Alice", bad = "string"})))
  end)
end)
