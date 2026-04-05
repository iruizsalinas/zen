local h = require("tests.helpers")
local z = require("zen")
local describe, it = h.describe, h.it
local assert_eq, assert_true, assert_false = h.assert_eq, h.assert_true, h.assert_false
local assert_error_has = h.assert_error_has

describe("edge cases", function()
  it("nil input to every type", function()
    local schemas = {z.string(), z.number(), z.boolean(), z.any()}
    for _, schema in ipairs(schemas) do
      assert_false((schema:safe_parse(nil)))
    end
    assert_true((z.nil_():safe_parse(nil)))
  end)

  it("empty string vs nil", function()
    assert_true((z.string():safe_parse("")))
    assert_false((z.string():safe_parse(nil)))
  end)

  it("empty table as object vs array", function()
    assert_true((z.object({}):safe_parse({})))
    assert_true((z.array(z.string()):safe_parse({})))
  end)

  it("very large strings", function()
    local big = string.rep("a", 100000)
    assert_eq(#z.string():parse(big), 100000)
  end)

  it("very large numbers", function()
    assert_eq(z.number():parse(1e308), 1e308)
    assert_eq(z.number():parse(-1e308), -1e308)
  end)

  it("unicode strings in validators", function()
    assert_true((z.string():min(1):safe_parse("\195\169")))
  end)

  it("complex nested schema", function()
    local user_schema = z.object({
      name = z.string():min(1):max(100),
      email = z.string():email(),
      age = z.number():integer():min(0):optional(),
      role = z.enum({"admin", "user", "guest"}),
      website = z.string():url():optional(),
      tags = z.array(z.string()):optional(),
      address = z.object({
        street = z.string(),
        city = z.string(),
        zip = z.string():pattern("^%d%d%d%d%d$"),
      }):optional(),
    })

    local result = user_schema:parse({
      name = "John", email = "john@example.com", role = "admin", age = 30,
      tags = {"lua", "dev"},
      address = {street = "123 Main St", city = "NYC", zip = "10001"},
    })
    assert_eq(result.name, "John")
    assert_eq(result.tags[1], "lua")
    assert_eq(result.address.zip, "10001")

    local minimal = user_schema:parse({name = "Jane", email = "jane@test.org", role = "user"})
    assert_eq(minimal.name, "Jane")
    assert_eq(minimal.age, nil)

    local ok, errs = user_schema:safe_parse({name = "", email = "not-an-email", role = "superadmin"})
    assert_false(ok)
    assert_error_has(errs, {"name"}, "at least 1")
    assert_error_has(errs, {"email"}, "email")
    assert_error_has(errs, {"role"}, "one of")
  end)
end)
