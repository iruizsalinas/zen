local h = require("tests.helpers")
local z = require("zen")
local describe, it = h.describe, h.it
local assert_eq, assert_true, assert_false = h.assert_eq, h.assert_true, h.assert_false
local assert_throws, assert_error_has = h.assert_throws, h.assert_error_has

describe("z.union()", function()
  it("matches first schema", function()
    assert_eq(z.union(z.string(), z.number()):parse("hello"), "hello")
  end)

  it("matches second schema", function()
    assert_eq(z.union(z.string(), z.number()):parse(42), 42)
  end)

  it("rejects when no schema matches", function()
    local ok, errs = z.union(z.string(), z.number()):safe_parse(true)
    assert_false(ok)
    assert_eq(errs[1].code, "invalid_union")
  end)

  it(":optional() works on unions", function()
    local schema = z.union(z.string(), z.number()):optional()
    local ok, result = schema:safe_parse(nil)
    assert_true(ok)
    assert_eq(result, nil)
    assert_eq(schema:parse("hi"), "hi")
    assert_eq(schema:parse(42), 42)
  end)

  it("includes variant_errors on failure", function()
    local ok, errs = z.union(z.string(), z.number()):safe_parse(true)
    assert_false(ok)
    assert_true(errs[1].variant_errors ~= nil)
    assert_eq(#errs[1].variant_errors, 2)
  end)

  it("requires at least 2 schemas", function()
    assert_throws(function() z.union(z.string()) end, "at least 2")
  end)
end)

describe("z.intersection()", function()
  it("passes when both schemas match", function()
    local schema = z.intersection(z.object({name = z.string()}), z.object({age = z.number()}))
    local ok, result = schema:safe_parse({name = "Alice", age = 30})
    assert_true(ok)
    assert_eq(result.name, "Alice")
    assert_eq(result.age, 30)
  end)

  it("fails when either schema fails", function()
    local ok, errs = z.intersection(z.object({name = z.string()}), z.object({age = z.number()})):safe_parse({name = "Alice"})
    assert_false(ok)
    assert_error_has(errs, {"age"}, "required")
  end)

  it("collects errors from both schemas", function()
    local ok, errs = z.intersection(z.object({name = z.string()}), z.object({age = z.number()})):safe_parse({})
    assert_false(ok)
    assert_error_has(errs, {"name"}, "required")
    assert_error_has(errs, {"age"}, "required")
  end)
end)

describe("z.discriminated_union()", function()
  it("dispatches on discriminant field", function()
    local schema = z.discriminated_union("type", {
      z.object({type = z.literal("admin"), level = z.number()}),
      z.object({type = z.literal("user"), name = z.string()}),
      z.object({type = z.literal("guest")}),
    })
    local ok1, r1 = schema:safe_parse({type = "admin", level = 5})
    assert_true(ok1)
    assert_eq(r1.level, 5)
    local ok2, r2 = schema:safe_parse({type = "user", name = "Alice"})
    assert_true(ok2)
    assert_eq(r2.name, "Alice")
    assert_true((schema:safe_parse({type = "guest"})))
  end)

  it("reports error on unknown discriminant", function()
    local schema = z.discriminated_union("type", {z.object({type = z.literal("a")}), z.object({type = z.literal("b")})})
    local ok, errs = schema:safe_parse({type = "c"})
    assert_false(ok)
    assert_true(errs[1].message:find("expected one of"))
  end)

  it("reports error on missing discriminant", function()
    local schema = z.discriminated_union("type", {z.object({type = z.literal("a")}), z.object({type = z.literal("b")})})
    local ok, errs = schema:safe_parse({name = "Alice"})
    assert_false(ok)
    assert_true(errs[1].message:find("missing discriminant"))
  end)

  it("validates variant fields", function()
    local schema = z.discriminated_union("kind", {
      z.object({kind = z.literal("num"), value = z.number()}),
      z.object({kind = z.literal("str"), value = z.string()}),
    })
    assert_false((schema:safe_parse({kind = "num", value = "not a number"})))
  end)
end)

describe("z.lazy()", function()
  it("resolves schema on first use", function()
    local schema = z.lazy(function() return z.string():min(1) end)
    assert_eq(schema:parse("hello"), "hello")
    assert_false((schema:safe_parse("")))
  end)

  it("supports recursive schemas", function()
    local node
    node = z.object({
      value = z.number(),
      children = z.array(z.lazy(function() return node end)):optional(),
    })
    local tree = {
      value = 1,
      children = {
        {value = 2, children = {}},
        {value = 3, children = {{value = 4}}},
      },
    }
    local ok, result = node:safe_parse(tree)
    assert_true(ok)
    assert_eq(result.value, 1)
    assert_eq(result.children[2].children[1].value, 4)
  end)

  it("caches the resolved schema", function()
    local calls = 0
    local schema = z.lazy(function() calls = calls + 1; return z.string() end)
    schema:parse("a")
    schema:parse("b")
    assert_eq(calls, 1)
  end)
end)

describe(":and_() / :or_()", function()
  it(":and_() creates intersection", function()
    local ok, result = z.object({name = z.string()}):and_(z.object({age = z.number()})):safe_parse({name = "Alice", age = 30})
    assert_true(ok)
    assert_eq(result.name, "Alice")
    assert_eq(result.age, 30)
  end)

  it(":or_() creates union", function()
    local schema = z.string():or_(z.number())
    assert_eq(schema:parse("hi"), "hi")
    assert_eq(schema:parse(42), 42)
    assert_false((schema:safe_parse(true)))
  end)
end)

describe(":pipe()", function()
  it("chains validation through another schema", function()
    assert_eq(z.string():transform(tonumber):pipe(z.number():min(0)):parse("42"), 42)
  end)

  it("reports errors from piped schema", function()
    local ok, errs = z.string():transform(tonumber):pipe(z.number():min(10)):safe_parse("5")
    assert_false(ok)
    assert_true(errs[1].message:find("at least 10"))
  end)

  it("doesn't run pipe on earlier errors", function()
    assert_false((z.string():min(5):pipe(z.string():max(3)):safe_parse("hi")))
  end)
end)
