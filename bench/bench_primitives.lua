local h = require("bench.helpers")
local z = require("zen")

h.group("Primitives")

local str = z.string()
h.measure("string() pass", 2000000, function() str:safe_parse("hello") end)
h.measure("string() fail (number)", 2000000, function() str:safe_parse(42) end)
h.measure("string() fail (nil)", 2000000, function() str:safe_parse(nil) end)

local num = z.number()
h.measure("number() pass", 2000000, function() num:safe_parse(42) end)
h.measure("number() fail (string)", 2000000, function() num:safe_parse("42") end)
h.measure("number() fail (infinity)", 2000000, function() num:safe_parse(math.huge) end)

local bool = z.boolean()
h.measure("boolean() pass", 2000000, function() bool:safe_parse(true) end)
h.measure("boolean() fail", 2000000, function() bool:safe_parse(1) end)

local int = z.integer()
h.measure("integer() pass", 2000000, function() int:safe_parse(42) end)
h.measure("integer() fail (float)", 2000000, function() int:safe_parse(3.14) end)

local lit = z.literal("admin")
h.measure("literal() pass", 2000000, function() lit:safe_parse("admin") end)
h.measure("literal() fail", 2000000, function() lit:safe_parse("user") end)

local enum = z.enum({"admin", "user", "guest"})
h.measure("enum() pass", 2000000, function() enum:safe_parse("user") end)
h.measure("enum() fail", 2000000, function() enum:safe_parse("root") end)

local any = z.any()
h.measure("any() pass (string)", 2000000, function() any:safe_parse("hi") end)
h.measure("any() pass (table)", 500000, function() any:safe_parse({a = 1}) end)
