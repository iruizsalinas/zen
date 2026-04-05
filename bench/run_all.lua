print("zen benchmark suite")
print(string.rep("=", 78))

require("bench.bench_primitives")
require("bench.bench_string")
require("bench.bench_number")
require("bench.bench_object")
require("bench.bench_collections")
require("bench.bench_combinators")
require("bench.bench_modifiers")
require("bench.bench_realworld")

local h = require("bench.helpers")
h.report()
