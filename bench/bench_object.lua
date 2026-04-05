local h = require("bench.helpers")
local z = require("zen")

h.group("Object validation")

local small = z.object({name = z.string(), age = z.number()})
h.measure("2 fields pass", 500000, function()
  small:safe_parse({name = "Alice", age = 30})
end)

local medium = z.object({
  name   = z.string():min(1):max(100),
  email  = z.string():email(),
  age    = z.number():integer():min(0),
  role   = z.enum({"admin", "user", "guest"}),
  active = z.boolean(),
  score  = z.number():min(0):max(100),
  city   = z.string():max(50),
  zip    = z.string():pattern("^%d%d%d%d%d$"),
  plan   = z.enum({"free", "pro", "enterprise"}),
  level  = z.integer():between(1, 100),
})

local medium_valid = {
  name = "Alice", email = "alice@example.com", age = 30,
  role = "admin", active = true, score = 95.5, city = "NYC",
  zip = "10001", plan = "pro", level = 42,
}

local medium_invalid = {
  name = "", email = "bad", age = -1,
  role = "root", active = "yes", score = 200, city = "NYC",
  zip = "abc", plan = "ultra", level = 3.5,
}

h.measure("10 fields pass", 200000, function() medium:safe_parse(medium_valid) end)
h.measure("10 fields fail (all errors)", 200000, function() medium:safe_parse(medium_invalid) end)

local nested = z.object({
  user = z.object({
    profile = z.object({
      name = z.string():min(1),
      bio  = z.string():max(500):optional(),
    }),
    settings = z.object({
      theme  = z.enum({"light", "dark"}),
      notify = z.boolean(),
    }),
  }),
})

h.measure("nested 3 levels pass", 200000, function()
  nested:safe_parse({
    user = {
      profile = {name = "Alice", bio = "Hello"},
      settings = {theme = "dark", notify = true},
    },
  })
end)

local strict = z.object({name = z.string()}):strict()
h.measure("strict mode pass", 500000, function() strict:safe_parse({name = "Alice"}) end)
h.measure("strict mode fail (extra key)", 500000, function() strict:safe_parse({name = "Alice", age = 30}) end)

local with_catchall = z.object({name = z.string()}):catchall(z.number())
h.measure("catchall pass", 500000, function()
  with_catchall:safe_parse({name = "Alice", score = 42, level = 5})
end)

local with_optional = z.object({
  name = z.string(),
  bio  = z.string():optional(),
  age  = z.number():default(0),
})
h.measure("optional + default pass", 500000, function()
  with_optional:safe_parse({name = "Alice"})
end)
