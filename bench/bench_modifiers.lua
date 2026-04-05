local h = require("bench.helpers")
local z = require("zen")

h.group("Modifiers")

local optional = z.string():optional()
h.measure("optional pass (value)", 2000000, function() optional:safe_parse("hello") end)
h.measure("optional pass (nil)", 2000000, function() optional:safe_parse(nil) end)

local default = z.string():default("fallback")
h.measure("default pass (value)", 2000000, function() default:safe_parse("hello") end)
h.measure("default pass (nil)", 2000000, function() default:safe_parse(nil) end)

local catch = z.string():catch("safe")
h.measure("catch pass (value)", 2000000, function() catch:safe_parse("hello") end)
h.measure("catch pass (error)", 2000000, function() catch:safe_parse(42) end)

h.group("Coercion")

local coerce_num = z.coerce.number()
h.measure("coerce.number() from string", 1000000, function() coerce_num:safe_parse("42") end)
h.measure("coerce.number() from number", 1000000, function() coerce_num:safe_parse(42) end)

local coerce_str = z.coerce.string()
h.measure("coerce.string() from number", 1000000, function() coerce_str:safe_parse(42) end)

local coerce_bool = z.coerce.boolean()
h.measure("coerce.boolean() from string", 1000000, function() coerce_bool:safe_parse("true") end)

h.group("Refine / SuperRefine / Transform")

local refine = z.number():refine(function(val) return val % 2 == 0 end, "must be even")
h.measure("refine() pass", 1000000, function() refine:safe_parse(42) end)
h.measure("refine() fail", 1000000, function() refine:safe_parse(43) end)

local sr = z.object({a = z.number(), b = z.number()}):superRefine(function(val, ctx)
  if val.a > val.b then
    ctx.add_issue({path = {"b"}, message = "b must be >= a"})
  end
end)
h.measure("superRefine() pass", 500000, function() sr:safe_parse({a = 1, b = 2}) end)
h.measure("superRefine() fail", 500000, function() sr:safe_parse({a = 5, b = 1}) end)

local xform = z.string():trim():to_lower()
h.measure("trim + to_lower chain", 1000000, function() xform:safe_parse("  HELLO  ") end)
