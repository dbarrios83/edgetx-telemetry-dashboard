-- Resolves filesystem paths relative to this repo, regardless of the
-- working directory tests were launched from.

local function currentDir()
  local source = debug.getinfo(1, "S").source
  local path = source:match("^@(.*)$") or source
  return path:match("(.*[/\\])") or "./"
end

local TESTS_DIR = currentDir()

local M = {}
M.TESTS_DIR = TESTS_DIR
M.ROOT_DIR = TESTS_DIR .. "../"
M.WIDGET_DIR = M.ROOT_DIR .. "SCRIPTS/WIDGETS/FPVDASH/"
M.FIXTURES_DIR = TESTS_DIR .. "fixtures/"
M.SPEC_DIR = TESTS_DIR .. "spec/"

function M.widget(relativePath)
  return M.WIDGET_DIR .. relativePath
end

function M.fixture(name)
  return M.FIXTURES_DIR .. name .. ".lua"
end

-- Loads a widget module fresh (a new chunk execution), so module-level
-- state such as read.lua's sensor-ID cache never leaks between tests.
function M.loadWidgetModule(relativePath)
  local fullPath = M.widget(relativePath)
  local chunk, err = loadfile(fullPath)
  if not chunk then
    error("failed to load " .. fullPath .. ": " .. tostring(err), 2)
  end
  return chunk()
end

function M.loadFixture(name)
  local fullPath = M.fixture(name)
  local chunk, err = loadfile(fullPath)
  if not chunk then
    error("failed to load fixture " .. fullPath .. ": " .. tostring(err), 2)
  end
  return chunk()
end

local IS_WINDOWS = package.config:sub(1, 1) == "\\"

-- Recursively lists files under `dir` matching Lua pattern `pattern`,
-- using the host shell (dir/s/b on Windows, find on everything else). No
-- third-party Lua modules (e.g. luafilesystem) required. Originally
-- local to tests/run.lua; moved here (Architecture & Packaging
-- Hardening, Task 6) so tests/spec/release_spec.lua can reuse the same
-- directory walk instead of duplicating it.
function M.listFiles(dir, pattern)
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

-- Reads a whole file as a string, or returns nil if it can't be opened.
function M.readFile(path)
  local f = io.open(path, "r")
  if not f then
    return nil
  end
  local content = f:read("*a")
  f:close()
  return content
end

return M
