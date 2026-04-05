local h = require("bench.helpers")
local z = require("zen")

h.group("String validators")

local min_max = z.string():min(1):max(100)
h.measure("min+max pass", 2000000, function() min_max:safe_parse("hello world") end)
h.measure("min+max fail (empty)", 2000000, function() min_max:safe_parse("") end)

local email = z.string():email()
h.measure("email() pass", 1000000, function() email:safe_parse("user@example.com") end)
h.measure("email() fail", 1000000, function() email:safe_parse("not-an-email") end)

local url = z.string():url()
h.measure("url() pass", 1000000, function() url:safe_parse("https://example.com/path?q=1") end)
h.measure("url() fail", 1000000, function() url:safe_parse("not-a-url") end)

local uuid = z.string():uuid()
h.measure("uuid() pass", 1000000, function() uuid:safe_parse("550e8400-e29b-41d4-a716-446655440000") end)
h.measure("uuid() fail", 1000000, function() uuid:safe_parse("not-a-uuid") end)

local ip = z.string():ipv4()
h.measure("ip() pass", 1000000, function() ip:safe_parse("192.168.1.1") end)
h.measure("ip() fail", 1000000, function() ip:safe_parse("999.999.999.999") end)

local ipv6 = z.string():ipv6()
h.measure("ipv6() pass", 500000, function() ipv6:safe_parse("2001:db8:85a3::8a2e:370:7334") end)
h.measure("ipv6() fail", 500000, function() ipv6:safe_parse("not-ipv6") end)

local dt = z.string():datetime()
h.measure("datetime() pass", 1000000, function() dt:safe_parse("2024-01-15T10:30:00Z") end)

local date = z.string():date()
h.measure("date() pass", 1000000, function() date:safe_parse("2024-01-15") end)

local time = z.string():time()
h.measure("time() pass", 1000000, function() time:safe_parse("10:30:00") end)

local pat = z.string():pattern("^%d%d%d%d%d$")
h.measure("pattern() pass", 2000000, function() pat:safe_parse("10001") end)
h.measure("pattern() fail", 2000000, function() pat:safe_parse("abc") end)

local hex = z.string():hex()
h.measure("hex() pass", 2000000, function() hex:safe_parse("deadbeef") end)

local b64 = z.string():base64()
h.measure("base64() pass", 2000000, function() b64:safe_parse("SGVsbG8=") end)

h.group("String transforms")

local trim = z.string():trim()
h.measure("trim() short string", 2000000, function() trim:safe_parse("  hello  ") end)

local trim_large = z.string():trim()
local big_str = string.rep("x", 10000)
h.measure("trim() 10KB string", 100000, function() trim_large:safe_parse(big_str) end)

local lower = z.string():to_lower()
h.measure("to_lower()", 2000000, function() lower:safe_parse("HELLO WORLD") end)
