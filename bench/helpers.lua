local helpers = {}

local results = {}
local current_group = ""

function helpers.group(name)
  current_group = name
  print()
  print(name)
  print(string.rep("-", 78))
end

function helpers.measure(name, iterations, fn)
  collectgarbage("collect")
  collectgarbage("collect")
  local mem_before = collectgarbage("count")

  local start = os.clock()
  for i = 1, iterations do fn() end
  local elapsed = os.clock() - start

  collectgarbage("collect")
  local mem_after = collectgarbage("count")

  local ops = math.floor(iterations / elapsed)
  local alloc = mem_after - mem_before

  results[#results + 1] = {
    group = current_group,
    name = name,
    ops = ops,
    elapsed = elapsed,
    alloc = alloc,
    iterations = iterations,
  }

  io.write(string.format("  %-50s %9d ops/s  %.3fs\n", name, ops, elapsed))
  io.flush()
end

function helpers.report()
  print()
  print(string.rep("=", 78))
  print(string.format("  %-50s %9s", "SUMMARY", "ops/s"))
  print(string.rep("=", 78))
  for _, r in ipairs(results) do
    io.write(string.format("  %-50s %9d\n", r.name, r.ops))
  end
end

return helpers
