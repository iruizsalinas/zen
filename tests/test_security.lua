local h = require("tests.helpers")
local z = require("zen")
local describe, it = h.describe, h.it
local assert_eq, assert_true, assert_false = h.assert_eq, h.assert_true, h.assert_false

describe("safe_parse never throws", function()
  it("catches transform errors", function()
    local ok, errs = z.string():transform(function() error("boom") end):safe_parse("hi")
    assert_false(ok)
    assert_true(errs[1].message:find("boom") ~= nil)
  end)

  it("catches refine errors", function()
    local ok, errs = z.string():refine(function() error("crash") end):safe_parse("hi")
    assert_false(ok)
  end)

  it("catches superRefine errors", function()
    local ok, errs = z.string():superRefine(function() error("explode") end):safe_parse("hi")
    assert_false(ok)
  end)

  it("catches lazy schema errors", function()
    local ok, errs = z.lazy(function() error("bad schema") end):safe_parse("hi")
    assert_false(ok)
  end)

  it("catches catch function errors", function()
    local ok, errs = z.string():catch(function() error("catch broke") end):safe_parse(42)
    assert_false(ok)
  end)

  it("catches stack overflow on deep recursion", function()
    local node
    node = z.object({
      val = z.number(),
      child = z.lazy(function() return node end):optional(),
    })
    local data = {val = 1}
    local cur = data
    for i = 2, 50000 do
      cur.child = {val = i}
      cur = cur.child
    end
    local ok, errs = node:safe_parse(data)
    assert_false(ok)
    assert_true(errs[1].message:find("stack overflow") ~= nil)
  end)
end)

describe("error message safety", function()
  it("discriminated union truncates huge discriminant values", function()
    local du = z.discriminated_union("type", {
      z.object({type = z.literal("a")}),
      z.object({type = z.literal("b")}),
    })
    local ok, errs = du:safe_parse({type = string.rep("x", 100000)})
    assert_false(ok)
    assert_true(#errs[1].message < 200)
  end)

  it("error messages never contain the raw input value", function()
    local secret = "super_secret_token_12345"
    local ok, errs = z.number():safe_parse(secret)
    assert_false(ok)
    assert_eq(errs[1].message, "must be a number")
    assert_true(errs[1].message:find(secret) == nil)
  end)
end)

describe("error path integrity", function()
  it("object errors have independent paths", function()
    local ok, errs = z.object({a = z.number(), b = z.number(), c = z.number()})
      :safe_parse({a = "x", b = "y", c = "z"})
    assert_false(ok)
    local paths = {}
    for _, e in ipairs(errs) do paths[e.path[1]] = true end
    assert_true(paths["a"] and paths["b"] and paths["c"])
  end)

  it("nested errors have correct compound paths", function()
    local ok, errs = z.object({user = z.object({name = z.number(), age = z.number()})})
      :safe_parse({user = {name = "x", age = "y"}})
    assert_false(ok)
    for _, e in ipairs(errs) do
      assert_eq(e.path[1], "user")
      assert_true(e.path[2] == "name" or e.path[2] == "age")
    end
  end)

  it("array of objects paths are all unique", function()
    local schema = z.array(z.object({x = z.number(), y = z.number()}))
    local data = {}
    for i = 1, 100 do data[i] = {x = "bad", y = "bad"} end
    local ok, errs = schema:safe_parse(data)
    assert_false(ok)
    local unique = {}
    for _, e in ipairs(errs) do unique[table.concat(e.path, ".")] = true end
    local count = 0
    for _ in pairs(unique) do count = count + 1 end
    assert_eq(count, 200)
  end)

  it("deep nesting paths are correct", function()
    local ok, errs = z.object({
      users = z.array(z.object({tags = z.array(z.number())}))
    }):safe_parse({users = {{tags = {"a", "b"}}, {tags = {"c"}}}})
    assert_false(ok)
    for _, e in ipairs(errs) do
      assert_eq(e.path[1], "users")
      assert_eq(type(e.path[2]), "number")
      assert_eq(e.path[3], "tags")
      assert_eq(type(e.path[4]), "number")
    end
  end)

  it("mutating an error does not affect subsequent parses", function()
    local schema = z.object({a = z.string()})
    local ok1, errs1 = schema:safe_parse({})
    errs1[1].path[1] = "MUTATED"
    errs1[1].message = "MUTATED"
    local ok2, errs2 = schema:safe_parse({})
    assert_eq(errs2[1].path[1], "a")
    assert_eq(errs2[1].message, "required")
  end)
end)

describe("clean copy guarantee", function()
  it("object result is independent of input", function()
    local input = {name = "Alice", nested = {val = 1}}
    local schema = z.object({name = z.string(), nested = z.object({val = z.number()})})
    local result = schema:parse(input)
    result.name = "CHANGED"
    result.nested.val = 999
    assert_eq(input.name, "Alice")
    assert_eq(input.nested.val, 1)
  end)

  it("array result is independent of input", function()
    local input = {1, 2, 3}
    local result = z.array(z.number()):parse(input)
    result[1] = 999
    assert_eq(input[1], 1)
  end)

  it("transform receives copy not original", function()
    local input = {items = {1, 2, 3}}
    local schema = z.object({
      items = z.array(z.number()):transform(function(arr)
        arr[4] = 999
        return arr
      end)
    })
    schema:safe_parse(input)
    assert_eq(input.items[4], nil)
  end)
end)

describe("resource exhaustion", function()
  it("trim is linear on large strings", function()
    local s = string.rep("x", 1000000)
    local start = os.clock()
    z.string():trim():parse(s)
    assert_true(os.clock() - start < 1.0)
  end)

  it("email rejects oversized input instantly", function()
    local start = os.clock()
    z.string():email():safe_parse(string.rep("a", 100000) .. "@example.com")
    assert_true(os.clock() - start < 0.01)
  end)

  it("uuid rejects wrong length instantly", function()
    local start = os.clock()
    z.string():uuid():safe_parse(string.rep("a", 1000000))
    assert_true(os.clock() - start < 0.01)
  end)

  it("1000 field errors collected without crash", function()
    local shape, data = {}, {}
    for i = 1, 1000 do
      shape["f" .. i] = z.string()
      data["f" .. i] = 42
    end
    local ok, errs = z.object(shape):safe_parse(data)
    assert_false(ok)
    assert_eq(#errs, 1000)
  end)
end)

describe("type confusion", function()
  it("every schema rejects nil cleanly", function()
    local schemas = {
      z.string(), z.number(), z.boolean(), z.any(),
      z.literal("x"), z.enum({"a"}),
      z.object({a = z.string()}), z.array(z.string()),
      z.record(z.number()), z.tuple(z.string()),
    }
    for _, schema in ipairs(schemas) do
      local ok, errs = schema:safe_parse(nil)
      assert_false(ok)
      assert_eq(type(errs), "table")
    end
  end)

  it("exotic types never crash", function()
    local exotic = {print, coroutine.create(function() end), io.stdout}
    local schemas = {z.string(), z.number(), z.boolean(), z.object({}), z.array(z.any())}
    for _, val in ipairs(exotic) do
      for _, schema in ipairs(schemas) do
        local ok, errs = schema:safe_parse(val)
        assert_false(ok)
        assert_eq(errs[1].code, "invalid_type")
      end
    end
  end)
end)

describe("schema immutability under stress", function()
  it("schema works identically after failed parse", function()
    local schema = z.object({name = z.string():min(3)})
    schema:safe_parse({name = 42})
    schema:safe_parse({})
    schema:safe_parse({name = ""})
    local ok, result = schema:safe_parse({name = "Alice"})
    assert_true(ok)
    assert_eq(result.name, "Alice")
  end)

  it("GC during validation does not corrupt state", function()
    local schema = z.object({
      a = z.string():transform(function(val)
        collectgarbage("collect")
        return val
      end),
      b = z.number(),
    })
    local ok, result = schema:safe_parse({a = "hello", b = 42})
    assert_true(ok)
    assert_eq(result.a, "hello")
    assert_eq(result.b, 42)
  end)
end)

describe("edge case values", function()
  it("enum with falsy values", function()
    local schema = z.enum({false, 0, ""})
    assert_true((schema:safe_parse(false)))
    assert_true((schema:safe_parse(0)))
    assert_true((schema:safe_parse("")))
    assert_false((schema:safe_parse(nil)))
    assert_false((schema:safe_parse(true)))
  end)

  it("literal false", function()
    assert_true((z.literal(false):safe_parse(false)))
    assert_false((z.literal(false):safe_parse(true)))
    assert_false((z.literal(false):safe_parse(nil)))
  end)

  it("coerce rejects infinity strings", function()
    assert_false((z.coerce.number():safe_parse("inf")))
    assert_false((z.coerce.number():safe_parse("nan")))
  end)

  it("coerce handles hex and scientific notation", function()
    local ok1, r1 = z.coerce.number():safe_parse("0xff")
    assert_true(ok1)
    assert_eq(r1, 255)
    local ok2, r2 = z.coerce.number():safe_parse("1e10")
    assert_true(ok2)
  end)

  it("sparse arrays rejected", function()
    assert_false((z.array(z.number()):safe_parse({[1] = 1, [3] = 3})))
  end)

  it("mixed key tables rejected as arrays", function()
    assert_false((z.array(z.number()):safe_parse({[1] = 1, x = 2})))
  end)

  it("empty string is a valid string", function()
    assert_true((z.string():safe_parse("")))
  end)

  it("false is a valid boolean", function()
    assert_true((z.boolean():safe_parse(false)))
  end)
end)
