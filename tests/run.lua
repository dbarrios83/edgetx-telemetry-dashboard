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

local IS_WINDOWS = package.config:sub(1, 1) == "\\"

-- Recursively lists files under `dir` matching `pattern`, using the host
-- shell (dir/s/b on Windows, find on everything else). No third-party Lua
-- modules (e.g. luafilesystem) required.
local function listFiles(dir, pattern)
  local files = {}
  local handle
  if IS_WINDOWS then
    handle = io.popen(string.format('dir "%s" /s /b /a:-d 2>NUL', dir))
  else
    handle = io.popen(string.format("find '%s' -type f 2>/dev/null", dir))
  end

  if not handle then
    return files
  end

  for line in handle:lines() do
    local clean = line:gsub("[\r\n]+$", "")
    if clean ~= "" and clean:match(pattern) then
      files[#files + 1] = clean
    end
  end
  handle:close()

  table.sort(files)
  return files
end

local function syntaxCheckWidgetFiles()
  local files = listFiles(paths.WIDGET_DIR, "%.lua$")

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
  local specFiles = listFiles(paths.SPEC_DIR, "%.lua$")

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
