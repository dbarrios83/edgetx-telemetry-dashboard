-- FPVDASH Lua test harness entrypoint.
--
-- Usage (from the repo root, any stock Lua 5.1-5.4 interpreter):
--   lua tests/run.lua
--
-- Runs two things:
--   1. A syntax/load check (loadfile, no execution) on every .lua file
--      under SCRIPTS/WIDGETS/FPVDASH.
--   2. Every tests/spec/*.lua unit test file.
-- Exits 0 when everything passes, 1 otherwise (for CI).

local function scriptDir()
  local source = debug.getinfo(1, "S").source
  local path = source:match("^@(.*)$") or source
  return path:match("(.*[/\\])") or "./"
end

local HERE = scriptDir()
local paths = dofile(HERE .. "paths.lua")
local t = dofile(HERE .. "testkit.lua")
local mock = dofile(HERE .. "mock_edgetx.lua")

local function syntaxCheckWidgetFiles()
  local files = paths.listFiles(paths.WIDGET_DIR, "%.lua$")

  t.describe("syntax check: every widget .lua file loads without a syntax error", function()
    for _, file in ipairs(files) do
      t.it(file, function()
        local chunk, err = loadfile(file)
        if not chunk then
          error("syntax error: " .. tostring(err), 0)
        end
      end)
    end
  end)

  return #files
end

local function runSpecs()
  local specFiles = paths.listFiles(paths.SPEC_DIR, "%.lua$")

  for _, file in ipairs(specFiles) do
    local specFn, loadErr = loadfile(file)
    if not specFn then
      error("failed to load spec file " .. file .. ": " .. tostring(loadErr))
    end

    local ok, specOrErr = pcall(specFn)
    if not ok then
      error("failed to execute spec file " .. file .. ": " .. tostring(specOrErr))
    end

    if type(specOrErr) ~= "function" then
      error("spec file must return a function(t, mock, paths): " .. file)
    end

    specOrErr(t, mock, paths)
  end

  return #specFiles
end

print("FPVDASH Lua test harness")
print(("=" ):rep(40))

local widgetFileCount = syntaxCheckWidgetFiles()
print(string.format("Syntax-checked %d widget file(s) under %s", widgetFileCount, paths.WIDGET_DIR))

if widgetFileCount == 0 then
  print("WARNING: no widget .lua files were found -- check paths.lua / WIDGET_DIR.")
end

local specFileCount = runSpecs()
print(string.format("Executed %d spec file(s) under %s", specFileCount, paths.SPEC_DIR))

if specFileCount == 0 then
  print("WARNING: no spec files were found -- check paths.lua / SPEC_DIR.")
end

local ok = t.report()
os.exit(ok and 0 or 1)
