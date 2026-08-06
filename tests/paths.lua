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

return M
