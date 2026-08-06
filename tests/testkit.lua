-- Minimal dependency-free test framework for the FPVDASH Lua widget.
-- No external Lua rocks/modules required, so it runs on any stock
-- Lua 5.1-5.4 interpreter locally and in CI.

local M = {}

local stats = { total = 0, passed = 0, failed = 0 }
local failures = {}
local suiteStack = {}

local function currentLabel(name)
  if #suiteStack == 0 then
    return name
  end
  return table.concat(suiteStack, " > ") .. " > " .. name
end

function M.describe(name, fn)
  suiteStack[#suiteStack + 1] = name
  local ok, err = pcall(fn)
  suiteStack[#suiteStack] = nil
  if not ok then
    error(err, 0)
  end
end

function M.it(name, fn)
  stats.total = stats.total + 1
  local label = currentLabel(name)
  local ok, err = pcall(fn)
  if ok then
    stats.passed = stats.passed + 1
  else
    stats.failed = stats.failed + 1
    failures[#failures + 1] = { label = label, err = err }
  end
end

local function fail(message, level)
  error(message, (level or 1) + 1)
end

function M.assertEqual(actual, expected, message)
  if actual ~= expected then
    fail(string.format(
      "%s\n    expected: %s\n    actual:   %s",
      message or "assertEqual failed",
      tostring(expected),
      tostring(actual)
    ), 2)
  end
end

function M.assertNotEqual(actual, expected, message)
  if actual == expected then
    fail(string.format(
      "%s\n    did not expect: %s",
      message or "assertNotEqual failed",
      tostring(expected)
    ), 2)
  end
end

function M.assertTrue(value, message)
  if not value then
    fail(message or "assertTrue failed: value is falsy", 2)
  end
end

function M.assertFalse(value, message)
  if value then
    fail(message or "assertFalse failed: value is truthy", 2)
  end
end

function M.assertNil(value, message)
  if value ~= nil then
    fail(string.format(
      "%s\n    expected nil, got: %s",
      message or "assertNil failed",
      tostring(value)
    ), 2)
  end
end

function M.assertNotNil(value, message)
  if value == nil then
    fail(message or "assertNotNil failed: value is nil", 2)
  end
end

-- Compares two numbers within an epsilon, useful for voltage/ratio math.
function M.assertNear(actual, expected, epsilon, message)
  epsilon = epsilon or 0.001
  if type(actual) ~= "number" or type(expected) ~= "number" or math.abs(actual - expected) > epsilon then
    fail(string.format(
      "%s\n    expected: %s (+/- %s)\n    actual:   %s",
      message or "assertNear failed",
      tostring(expected), tostring(epsilon), tostring(actual)
    ), 2)
  end
end

function M.reset()
  stats = { total = 0, passed = 0, failed = 0 }
  failures = {}
  suiteStack = {}
end

function M.summary()
  return stats, failures
end

-- Prints a summary and returns true when everything passed.
function M.report()
  if #failures > 0 then
    print("")
    print("Failures:")
    for i = 1, #failures do
      print(string.format("  %d) %s", i, failures[i].label))
      print("     " .. tostring(failures[i].err):gsub("\n", "\n     "))
    end
  end

  print("")
  print(string.format(
    "%d tests, %d passed, %d failed",
    stats.total, stats.passed, stats.failed
  ))

  return stats.failed == 0
end

return M
