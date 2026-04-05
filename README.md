# zen

Lightweight schema validation for Lua.

## Install

```
luarocks install zen
```

## Quick start

```lua
local z = require("zen")

local schema = z.object({
  name  = z.string():min(1):max(100),
  email = z.string():email(),
  age   = z.number():integer():min(0):optional(),
  role  = z.enum({"admin", "user", "guest"}),
})

local user = schema:parse({name = "Alice", email = "alice@example.com", role = "admin"})
```

## API Reference

### Primitives

| Constructor | Description |
|---|---|
| `z.string()` | Validates strings |
| `z.number()` | Validates numbers (rejects NaN and Infinity) |
| `z.boolean()` | Validates booleans |
| `z.integer()` | Shorthand for `z.number():integer()` |
| `z.any()` | Accepts any non-nil value |
| `z.nil_()` | Accepts only nil |
| `z.literal(value)` | Exact value match |
| `z.enum(values)` | One of a set of values |
| `z.custom(fn, msg)` | Schema from a validator function |

### String validators

All chainable. Each returns a new schema.

```lua
z.string()
  :min(n)             -- minimum length
  :max(n)             -- maximum length
  :length(n)          -- exact length
  :nonempty()         -- alias for :min(1)
  :email()            -- valid email address
  :url()              -- valid URL (http/https)
  :uuid()             -- valid UUID
  :ipv4()             -- valid IPv4 address
  :ipv6()             -- valid IPv6 address
  :datetime()         -- valid ISO 8601 datetime
  :date()             -- valid date (YYYY-MM-DD)
  :time()             -- valid time (HH:MM:SS)
  :pattern(lua_pat)   -- matches a Lua pattern
  :contains(str)      -- contains substring
  :starts_with(str)   -- starts with prefix
  :ends_with(str)     -- ends with suffix
  :base64()           -- valid base64 encoding
  :hex()              -- valid hex string
  :trim()             -- trim whitespace (transform)
  :to_lower()         -- convert to lowercase (transform)
  :to_upper()         -- convert to uppercase (transform)
```

### Number validators

```lua
z.number()
  :min(n)             -- >= n  (alias: :gte(n))
  :max(n)             -- <= n  (alias: :lte(n))
  :gt(n)              -- > n
  :lt(n)              -- < n
  :integer()          -- must be integer
  :multiple_of(n)     -- must be divisible by n (alias: :step(n))
  :positive()         -- > 0
  :negative()         -- < 0
  :nonnegative()      -- >= 0
  :nonpositive()      -- <= 0
  :between(lo, hi)    -- inclusive range
  :allow_infinity()   -- opt in to accepting math.huge
```

`z.number()` rejects NaN and Infinity by default. Use `:allow_infinity()` if you need to accept `math.huge`.

### Objects

```lua
local schema = z.object({
  name = z.string(),
  age  = z.number():optional(),
})

schema:strict()          -- reject unknown keys
schema:passthrough()     -- allow and keep unknown keys
schema:strip()           -- silently remove unknown keys (default)
schema:catchall(schema)  -- validate unknown keys against a schema
schema:partial()         -- make all fields optional
schema:partial({"name"}) -- make specific fields optional
schema:required()        -- make all fields required
schema:required({"age"}) -- make specific fields required
schema:pick({"name"})    -- select subset of fields
schema:omit({"age"})     -- exclude fields
schema:extend({          -- add/overwrite fields
  email = z.string():email(),
})
schema:get_shape()       -- access the shape table
```

Objects strip unknown keys by default and return a clean copy of the data.

### Arrays

```lua
z.array(z.string())
  :min(n)             -- minimum length
  :max(n)             -- maximum length
  :length(n)          -- exact length
  :nonempty()         -- alias for :min(1)
```

### Records

Validate tables where all values (and optionally keys) match a schema:

```lua
z.record(z.number())                      -- {[string]: number}
z.record(z.string():min(1), z.number())   -- validate keys too
```

### Tuples

Fixed-length arrays with per-position schemas:

```lua
z.tuple(z.string(), z.number(), z.boolean())
```

### Composition

```lua
z.union(z.string(), z.number())
z.intersection(
  z.object({name = z.string()}),
  z.object({age = z.number()})
)

-- shorthand
z.string():or_(z.number())       -- union
z.object({a = z.string()}):and_( -- intersection
  z.object({b = z.number()})
)

z.string():optional()
z.string():default("fallback")
z.string():catch("safe value")  -- return fallback on any error
z.string():describe("User name")
```

### Discriminated unions

Efficient dispatch on a tag field with clear error messages:

```lua
local event = z.discriminated_union("type", {
  z.object({type = z.literal("click"), x = z.number(), y = z.number()}),
  z.object({type = z.literal("keypress"), key = z.string()}),
  z.object({type = z.literal("scroll"), delta = z.number()}),
})
```

### Lazy schemas (recursive types)

```lua
local node = z.object({
  value = z.number(),
  children = z.array(z.lazy(function() return node end)):optional(),
})
```

### Pipes

Chain one schema's output into another:

```lua
local str_to_num = z.string()
  :transform(tonumber)
  :pipe(z.number():min(0))

str_to_num:parse("42")  -- 42
```

### Coercion

Convert input before validating:

```lua
z.coerce.number():parse("42")       -- 42
z.coerce.string():parse(42)         -- "42"
z.coerce.boolean():parse("true")    -- true
z.coerce.integer():parse("42")      -- 42
```

### Custom validation

```lua
z.string():refine(function(val)
  return val ~= "admin"
end, "cannot be admin")

z.string():trim():transform(string.lower)

-- superRefine for multiple issues
z.object({password = z.string(), confirm = z.string()})
  :superRefine(function(val, ctx)
    if val.password ~= val.confirm then
      ctx.add_issue({path = {"confirm"}, message = "passwords do not match"})
    end
  end)
```

### Custom error messages

Every validator accepts an optional message as the last argument:

```lua
z.string():min(3, "Name too short")
z.string():email("Please enter a valid email")
z.number():min(18, "Must be an adult")
z.array(z.string()):nonempty("Add at least one tag")
```

### Parse modes

```lua
local data = schema:parse(input)

local ok, result = schema:safe_parse(input)
if not ok then
  for _, err in ipairs(result) do
    print(table.concat(err.path, ".") .. ": " .. err.message)
  end
end
```

### Error format

Each error is a table with:

| Field | Type | Description |
|---|---|---|
| `path` | `table` | Array of keys to the error location, e.g. `{"address", "zip"}` |
| `message` | `string` | Human-readable message, e.g. `"must be at least 3 characters"` |
| `code` | `string` | One of: `invalid_type`, `too_small`, `too_big`, `invalid_string`, `invalid_enum`, `invalid_literal`, `invalid_union`, `unrecognized_keys`, `custom` |

### Error utilities

```lua
local ok, errs = schema:safe_parse(bad_data)
local flat = z.flatten_errors(errs)
-- {name = {"too short", "invalid"}, age = {"required"}}
```

### Immutability

Every method returns a new schema. The original is never mutated:

```lua
local base = z.string():min(1)
local name  = base:max(100)  -- base unchanged
local title = base:max(200)  -- base unchanged
```

## Compatibility

Lua 5.1, 5.2, 5.3, 5.4, 5.5, and LuaJIT.
