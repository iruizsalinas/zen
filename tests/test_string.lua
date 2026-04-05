local h = require("tests.helpers")
local z = require("zen")
local describe, it = h.describe, h.it
local assert_eq, assert_true, assert_false = h.assert_eq, h.assert_true, h.assert_false
local assert_throws = h.assert_throws

describe("z.string()", function()
  it("accepts strings", function()
    assert_eq(z.string():parse("hello"), "hello")
    assert_eq(z.string():parse(""), "")
  end)

  it("rejects non-strings", function()
    local ok, errs = z.string():safe_parse(123)
    assert_false(ok)
    assert_eq(errs[1].code, "invalid_type")
    assert_true(errs[1].message:find("must be a string"))
    ok = z.string():safe_parse(true)
    assert_false(ok)
    ok = z.string():safe_parse({})
    assert_false(ok)
    ok = z.string():safe_parse(nil)
    assert_false(ok)
  end)

  it(":min() enforces minimum length", function()
    assert_eq(z.string():min(3):parse("abc"), "abc")
    assert_eq(z.string():min(3):parse("abcd"), "abcd")
    local ok, errs = z.string():min(3):safe_parse("ab")
    assert_false(ok)
    assert_eq(errs[1].code, "too_small")
    assert_true(errs[1].message:find("at least 3"))
  end)

  it(":max() enforces maximum length", function()
    assert_eq(z.string():max(5):parse("hello"), "hello")
    local ok, errs = z.string():max(5):safe_parse("toolong")
    assert_false(ok)
    assert_eq(errs[1].code, "too_big")
  end)

  it(":length() enforces exact length", function()
    assert_eq(z.string():length(3):parse("abc"), "abc")
    local ok, errs = z.string():length(3):safe_parse("ab")
    assert_false(ok)
    assert_eq(errs[1].code, "too_small")
    ok, errs = z.string():length(3):safe_parse("abcd")
    assert_false(ok)
    assert_eq(errs[1].code, "too_big")
  end)

  it(":email() validates emails", function()
    assert_eq(z.string():email():parse("user@example.com"), "user@example.com")
    assert_eq(z.string():email():parse("user+tag@example.com"), "user+tag@example.com")
    assert_eq(z.string():email():parse("first.last@sub.example.co"), "first.last@sub.example.co")
    local invalid = {"", "notanemail", "@example.com", "user@", "user@.com",
                     "user@com", "user @example.com", "user@exam ple.com",
                     "user@example..com", ".user@example.com", "user.@example.com",
                     "user@@example.com", "user@-example.com", "user@example-.com"}
    for _, email in ipairs(invalid) do
      local ok, errs = z.string():email():safe_parse(email)
      assert_false(ok, "should reject: " .. email)
      assert_eq(errs[1].code, "invalid_string")
    end
  end)

  it(":url() validates URLs", function()
    local valid_urls = {"http://example.com", "https://example.com", "https://example.com/path",
                        "https://example.com/path?q=1", "https://example.com/path?q=1#frag",
                        "https://sub.example.com", "http://localhost", "http://localhost:8080",
                        "https://192.168.1.1", "https://user:pass@example.com"}
    for _, u in ipairs(valid_urls) do
      assert_eq(z.string():url():parse(u), u, "should accept: " .. u)
    end
    local invalid_urls = {"", "notaurl", "ftp://example.com", "example.com", "http://", "http:// space.com"}
    for _, u in ipairs(invalid_urls) do
      local ok = z.string():url():safe_parse(u)
      assert_false(ok, "should reject: " .. u)
    end
  end)

  it(":uuid() validates UUIDs", function()
    assert_eq(z.string():uuid():parse("550e8400-e29b-41d4-a716-446655440000"),
              "550e8400-e29b-41d4-a716-446655440000")
    assert_eq(z.string():uuid():parse("550E8400-E29B-41D4-A716-446655440000"),
              "550E8400-E29B-41D4-A716-446655440000")
    local invalid = {"", "not-a-uuid", "550e8400e29b41d4a716446655440000",
                     "550e8400-e29b-41d4-a716-44665544000",
                     "550e8400-e29b-41d4-a716-4466554400000",
                     "550e8400-e29b-41d4-a716-44665544000g"}
    for _, u in ipairs(invalid) do
      local ok = z.string():uuid():safe_parse(u)
      assert_false(ok, "should reject: " .. u)
    end
  end)

  it(":ipv4() validates IPv4 addresses", function()
    local valid_ips = {"0.0.0.0", "127.0.0.1", "192.168.1.1", "255.255.255.255", "1.2.3.4"}
    for _, ip in ipairs(valid_ips) do assert_eq(z.string():ipv4():parse(ip), ip) end
    local invalid_ips = {"", "256.0.0.0", "1.2.3.256", "1.2.3", "1.2.3.4.5",
                         "01.0.0.0", "1.02.3.4", "a.b.c.d", "1.2.3.4/24", "1.2.3.04"}
    for _, ip in ipairs(invalid_ips) do
      local ok = z.string():ipv4():safe_parse(ip)
      assert_false(ok, "should reject: " .. ip)
    end
  end)

  it(":ipv6() validates IPv6 addresses", function()
    local valid_addrs = {"2001:0db8:85a3:0000:0000:8a2e:0370:7334", "2001:db8:85a3::8a2e:370:7334",
                         "::1", "::", "fe80::1", "::ffff:192.168.1.1"}
    for _, addr in ipairs(valid_addrs) do
      assert_true((z.string():ipv6():safe_parse(addr)), "should accept: " .. addr)
    end
    local invalid_addrs = {"", "not-ipv6", "12345", ":::", "1:2:3:4:5:6:7:8:9",
                           "gggg::1", "2001:db8::85a3::7334"}
    for _, addr in ipairs(invalid_addrs) do
      assert_false((z.string():ipv6():safe_parse(addr)), "should reject: " .. addr)
    end
  end)

  it(":datetime() validates ISO 8601 datetimes", function()
    local valid_dts = {"2024-01-15T10:30:00", "2024-01-15T10:30:00Z", "2024-01-15T10:30:00z",
                       "2024-01-15T10:30:00+05:30", "2024-01-15T10:30:00-08:00",
                       "2024-01-15T10:30:00.123Z", "2024-01-15T10:30:00.123456+00:00",
                       "2024-12-31T23:59:59Z"}
    for _, dt in ipairs(valid_dts) do assert_eq(z.string():datetime():parse(dt), dt, "should accept: " .. dt) end
    local invalid_dts = {"", "2024-01-15", "2024-13-01T00:00:00", "2024-01-32T00:00:00",
                         "2024-01-15T25:00:00", "2024-01-15T10:60:00", "2024-01-15T10:30:60",
                         "not-a-date", "2024-02-30T00:00:00"}
    for _, dt in ipairs(invalid_dts) do
      assert_false((z.string():datetime():safe_parse(dt)), "should reject: " .. dt)
    end
  end)

  it(":date() validates YYYY-MM-DD", function()
    assert_eq(z.string():date():parse("2024-01-15"), "2024-01-15")
    assert_eq(z.string():date():parse("2024-02-29"), "2024-02-29")
    assert_false((z.string():date():safe_parse("2024-13-01")))
    assert_false((z.string():date():safe_parse("2024-02-30")))
    assert_false((z.string():date():safe_parse("not-a-date")))
  end)

  it(":time() validates HH:MM:SS", function()
    assert_eq(z.string():time():parse("10:30:00"), "10:30:00")
    assert_eq(z.string():time():parse("23:59:59"), "23:59:59")
    assert_eq(z.string():time():parse("10:30:00.123"), "10:30:00.123")
    assert_false((z.string():time():safe_parse("25:00:00")))
    assert_false((z.string():time():safe_parse("10:60:00")))
  end)

  it(":pattern() matches Lua patterns", function()
    assert_eq(z.string():pattern("^%d+$"):parse("12345"), "12345")
    assert_false((z.string():pattern("^%d+$"):safe_parse("abc")))
  end)

  it(":contains() checks substrings", function()
    assert_eq(z.string():contains("world"):parse("hello world"), "hello world")
    assert_false((z.string():contains("xyz"):safe_parse("hello world")))
  end)

  it(":starts_with() checks prefix", function()
    assert_eq(z.string():starts_with("http"):parse("https://x.com"), "https://x.com")
    assert_false((z.string():starts_with("http"):safe_parse("ftp://x.com")))
  end)

  it(":ends_with() checks suffix", function()
    assert_eq(z.string():ends_with(".lua"):parse("test.lua"), "test.lua")
    assert_false((z.string():ends_with(".lua"):safe_parse("test.py")))
  end)

  it(":trim() transforms whitespace", function()
    assert_eq(z.string():trim():parse("  hello  "), "hello")
    assert_eq(z.string():trim():parse("hello"), "hello")
    assert_eq(z.string():trim():parse("  "), "")
    assert_eq(z.string():trim():parse(""), "")
  end)

  it(":trim() before :min() validates trimmed value", function()
    assert_false((z.string():trim():min(1):safe_parse("   ")))
    assert_eq(z.string():trim():min(1):parse("  a  "), "a")
  end)

  it(":nonempty() rejects empty strings", function()
    assert_eq(z.string():nonempty():parse("a"), "a")
    assert_false((z.string():nonempty():safe_parse("")))
  end)

  it(":to_lower() transforms to lowercase", function()
    assert_eq(z.string():to_lower():parse("HELLO"), "hello")
  end)

  it(":to_upper() transforms to uppercase", function()
    assert_eq(z.string():to_upper():parse("hello"), "HELLO")
  end)

  it(":base64() validates base64", function()
    assert_eq(z.string():base64():parse("SGVsbG8="), "SGVsbG8=")
    assert_eq(z.string():base64():parse("dGVzdA=="), "dGVzdA==")
    assert_false((z.string():base64():safe_parse("abc")))
    assert_false((z.string():base64():safe_parse("")))
  end)

  it(":hex() validates hex strings", function()
    assert_eq(z.string():hex():parse("deadbeef"), "deadbeef")
    assert_false((z.string():hex():safe_parse("xyz")))
    assert_false((z.string():hex():safe_parse("")))
  end)

  it("validates API inputs", function()
    assert_throws(function() z.string():min("bad") end, "expects a number")
    assert_throws(function() z.string():max("bad") end, "expects a number")
    assert_throws(function() z.string():length("bad") end, "expects a number")
    assert_throws(function() z.string():pattern(123) end, "expects a string")
    assert_throws(function() z.string():contains(123) end, "expects a string")
    assert_throws(function() z.string():starts_with(123) end, "expects a string")
    assert_throws(function() z.string():ends_with(123) end, "expects a string")
  end)
end)
