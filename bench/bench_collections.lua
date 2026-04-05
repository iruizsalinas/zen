local h = require("bench.helpers")
local z = require("zen")

h.group("Array validation")

local arr_10 = {}
for i = 1, 10 do arr_10[i] = "item" end
local arr_100 = {}
for i = 1, 100 do arr_100[i] = "item" end
local arr_1000 = {}
for i = 1, 1000 do arr_1000[i] = "item" end

local str_arr = z.array(z.string())
h.measure("array of 10 strings", 200000, function() str_arr:safe_parse(arr_10) end)
h.measure("array of 100 strings", 20000, function() str_arr:safe_parse(arr_100) end)
h.measure("array of 1000 strings", 2000, function() str_arr:safe_parse(arr_1000) end)

local constrained_arr = z.array(z.string():min(1)):min(1):max(50)
h.measure("array with constraints pass", 200000, function() constrained_arr:safe_parse(arr_10) end)

local empty_arr = z.array(z.number())
h.measure("empty array pass", 500000, function() empty_arr:safe_parse({}) end)

h.group("Tuple validation")

local tup = z.tuple(z.string(), z.number(), z.boolean())
h.measure("tuple 3 elements pass", 500000, function() tup:safe_parse({"hello", 42, true}) end)
h.measure("tuple 3 elements fail", 500000, function() tup:safe_parse({"hello", "bad", true}) end)

h.group("Record validation")

local rec = z.record(z.number())
local rec_data = {x = 1, y = 2, z = 3, w = 4, h = 5}
h.measure("record 5 entries pass", 200000, function() rec:safe_parse(rec_data) end)

local rec_with_keys = z.record(z.string():min(1), z.number())
h.measure("record with key validation pass", 200000, function() rec_with_keys:safe_parse(rec_data) end)
