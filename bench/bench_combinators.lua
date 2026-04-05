local h = require("bench.helpers")
local z = require("zen")

h.group("Union")

local union2 = z.union(z.string(), z.number())
h.measure("union(2) match first", 1000000, function() union2:safe_parse("hello") end)
h.measure("union(2) match second", 1000000, function() union2:safe_parse(42) end)
h.measure("union(2) no match", 1000000, function() union2:safe_parse(true) end)

local union5 = z.union(
  z.literal("a"), z.literal("b"), z.literal("c"), z.literal("d"), z.literal("e")
)
h.measure("union(5 literals) match last", 1000000, function() union5:safe_parse("e") end)
h.measure("union(5 literals) no match", 1000000, function() union5:safe_parse("z") end)

h.group("Discriminated union")

local du = z.discriminated_union("type", {
  z.object({type = z.literal("admin"), level = z.number()}),
  z.object({type = z.literal("user"), name = z.string()}),
  z.object({type = z.literal("guest")}),
})
h.measure("discriminated(3) pass", 500000, function() du:safe_parse({type = "user", name = "Alice"}) end)
h.measure("discriminated(3) bad discriminant", 500000, function() du:safe_parse({type = "unknown"}) end)
h.measure("discriminated(3) field error", 500000, function() du:safe_parse({type = "admin", level = "bad"}) end)

h.group("Intersection")

local inter = z.intersection(
  z.object({name = z.string()}),
  z.object({age = z.number()})
)
h.measure("intersection pass", 500000, function() inter:safe_parse({name = "Alice", age = 30}) end)
h.measure("intersection fail", 500000, function() inter:safe_parse({name = "Alice"}) end)

h.group("Lazy")

local lazy = z.lazy(function() return z.string():min(1) end)
lazy:safe_parse("warmup")

h.measure("lazy (cached) pass", 1000000, function() lazy:safe_parse("hello") end)

h.group("Pipe")

local pipe = z.string():transform(tonumber):pipe(z.number():min(0))
h.measure("string->number pipe pass", 500000, function() pipe:safe_parse("42") end)
h.measure("string->number pipe fail", 500000, function() pipe:safe_parse("-5") end)
