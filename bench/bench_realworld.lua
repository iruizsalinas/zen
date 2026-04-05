local h = require("bench.helpers")
local z = require("zen")

h.group("Real-world schemas")

local user_registration = z.object({
  username = z.string():min(3):max(20):pattern("^%w+$"),
  email    = z.string():email(),
  password = z.string():min(8):max(128),
  age      = z.number():integer():min(13):max(120),
  role     = z.enum({"user", "admin"}),
  bio      = z.string():max(500):optional(),
  tags     = z.array(z.string():min(1)):max(10):optional(),
  address  = z.object({
    street = z.string():min(1),
    city   = z.string():min(1),
    zip    = z.string():pattern("^%d%d%d%d%d$"),
  }):optional(),
})

local registration_data = {
  username = "alice123", email = "alice@example.com", password = "securepass123",
  age = 28, role = "user", bio = "Hello there",
  tags = {"lua", "dev"},
  address = {street = "123 Main St", city = "NYC", zip = "10001"},
}

h.measure("user registration (full)", 100000, function()
  user_registration:safe_parse(registration_data)
end)

h.measure("user registration (minimal)", 200000, function()
  user_registration:safe_parse({
    username = "bob", email = "bob@test.org", password = "mypassword",
    age = 25, role = "user",
  })
end)

local api_response = z.discriminated_union("status", {
  z.object({
    status = z.literal("ok"),
    data = z.object({
      items = z.array(z.object({
        id   = z.integer():min(1),
        name = z.string():min(1),
        price = z.number():min(0),
      })),
      total = z.integer():min(0),
    }),
  }),
  z.object({
    status = z.literal("error"),
    message = z.string():min(1),
    code = z.integer(),
  }),
})

h.measure("API response (success, 3 items)", 100000, function()
  api_response:safe_parse({
    status = "ok",
    data = {
      items = {
        {id = 1, name = "Widget", price = 9.99},
        {id = 2, name = "Gadget", price = 19.99},
        {id = 3, name = "Thing", price = 4.99},
      },
      total = 3,
    },
  })
end)

h.measure("API response (error)", 200000, function()
  api_response:safe_parse({status = "error", message = "Not found", code = 404})
end)

local config = z.object({
  host     = z.string():min(1),
  port     = z.coerce.number():integer():between(1, 65535),
  debug    = z.coerce.boolean():default(false),
  workers  = z.coerce.integer():default(4),
  log      = z.enum({"debug", "info", "warn", "error"}):default("info"),
  origins  = z.array(z.string():url()):optional(),
})

h.measure("config with coercion + defaults", 200000, function()
  config:safe_parse({host = "localhost", port = "8080", debug = "true", workers = "2", log = "debug"})
end)
