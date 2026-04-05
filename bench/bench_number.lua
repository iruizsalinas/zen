local h = require("bench.helpers")
local z = require("zen")

h.group("Number validators")

local constrained = z.number():min(0):max(1000):integer()
h.measure("min+max+integer pass", 2000000, function() constrained:safe_parse(42) end)
h.measure("min+max+integer fail (float)", 2000000, function() constrained:safe_parse(3.14) end)
h.measure("min+max+integer fail (range)", 2000000, function() constrained:safe_parse(9999) end)

local between = z.number():between(1, 100)
h.measure("between() pass", 2000000, function() between:safe_parse(50) end)
h.measure("between() fail", 2000000, function() between:safe_parse(200) end)

local mul = z.number():multiple_of(5)
h.measure("multiple_of() pass", 2000000, function() mul:safe_parse(15) end)
h.measure("multiple_of() fail", 2000000, function() mul:safe_parse(13) end)

local bare = z.number()
h.measure("bare number() pass", 2000000, function() bare:safe_parse(42) end)
