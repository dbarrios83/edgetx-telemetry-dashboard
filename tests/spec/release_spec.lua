-- Release/packaging structural checks (Architecture & Packaging
-- Hardening, Task 6).
--
-- These catch packaging mistakes statically -- a typo'd or deleted icon
-- filename, a dangling loadModule()/loadSiblingModule() path, folder-name
-- drift -- instead of relying on a manual SD-card copy and simulator
-- session to notice. All three checks work by reading the real source
-- and the real icons/ directory tree from disk (via paths.readFile /
-- paths.listFiles), not by exercising the mocked EdgeTX API -- the mock's
-- Bitmap.open() always succeeds regardless of whether a file actually
-- exists, so it can't catch this class of mistake; only a real
-- filesystem check can.
return function(t, mock, paths)
  local function widgetLuaFiles()
    return paths.listFiles(paths.WIDGET_DIR, "%.lua$")
  end

  -- Extracts every openBitmapFromCandidates(roots, {...}) call's
  -- candidate filename list from `content`, as an array of arrays (one
  -- inner array per call site, since it's a fallback list -- only one
  -- candidate needs to exist, not all of them; see the icon-check
  -- describe block below). Tolerates whitespace between the function
  -- name and "(", and either quote style for the string literals --
  -- found missing in external review (2026-08-07): the original pattern
  -- only matched a directly-adjacent "(" and double-quoted strings, so a
  -- call written in valid-but-different Lua style could silently bypass
  -- the check entirely rather than being flagged.
  local function extractIconCalls(content)
    local calls = {}
    for namesBlock in content:gmatch("openBitmapFromCandidates%s*%(%s*[%w_]+%s*,%s*%{(.-)%}%s*%)") do
      local candidates = {}
      for name in namesBlock:gmatch('"([%w%-_%.]+%.png)"') do
        candidates[#candidates + 1] = name
      end
      for name in namesBlock:gmatch("'([%w%-_%.]+%.png)'") do
        candidates[#candidates + 1] = name
      end
      if #candidates > 0 then
        calls[#calls + 1] = candidates
      end
    end
    return calls
  end

  -- Extracts every loadModule()/loadSiblingModule() literal path
  -- argument from `content`, as { callName, path } entries. Same
  -- whitespace/quote tolerance as extractIconCalls, and for the same
  -- reason.
  local function extractModuleLoadRefs(content)
    local refs = {}
    -- Lua patterns have no alternation, so loadModule() and
    -- loadSiblingModule() are matched in separate passes rather than one
    -- combined pattern.
    local CALL_NAMES = { "loadModule", "loadSiblingModule" }
    for _, callName in ipairs(CALL_NAMES) do
      for relativePath in content:gmatch(callName .. '%s*%(%s*"([^"]+)"%s*%)') do
        refs[#refs + 1] = { callName = callName, path = relativePath }
      end
      for relativePath in content:gmatch(callName .. "%s*%(%s*'([^']+)'%s*%)") do
        refs[#refs + 1] = { callName = callName, path = relativePath }
      end
    end
    return refs
  end

  t.describe("release packaging: extraction pattern robustness", function()
    t.it("finds openBitmapFromCandidates() candidates regardless of quote style or whitespace before '('", function()
      local calls = extractIconCalls([[
        local a = openBitmapFromCandidates(roots, { "double.png" })
        local b = openBitmapFromCandidates (roots, { 'single.png' })
        local c = openBitmapFromCandidates  (  roots , { "spaced.png" } )
      ]])
      t.assertEqual(#calls, 3)
      t.assertEqual(calls[1][1], "double.png")
      t.assertEqual(calls[2][1], "single.png")
      t.assertEqual(calls[3][1], "spaced.png")
    end)

    t.it("finds loadModule()/loadSiblingModule() paths regardless of quote style or whitespace before '('", function()
      local refs = extractModuleLoadRefs([[
        local a = loadModule("double/quoted.lua")
        local b = loadModule ('single/quoted.lua')
        local c = loadSiblingModule  (  "spaced.lua"  )
      ]])
      t.assertEqual(#refs, 3)
      t.assertEqual(refs[1].path, "double/quoted.lua")
      t.assertEqual(refs[2].path, "single/quoted.lua")
      t.assertEqual(refs[3].path, "spaced.lua")
    end)
  end)

  t.describe("release packaging: icon references resolve to a real file", function()
    t.it("every openBitmapFromCandidates() call has at least one candidate that exists under icons/", function()
      -- Build the set of real icon basenames present anywhere under
      -- icons/ (any subfolder -- dark/light/battery/link/flat all share
      -- one flat namespace of filenames in this codebase).
      local iconFiles = paths.listFiles(paths.WIDGET_DIR .. "icons", "%.png$")
      local exists = {}
      for _, path in ipairs(iconFiles) do
        local basename = path:match("([^/\\]+)$")
        if basename then
          exists[basename] = true
        end
      end
      t.assertTrue(#iconFiles > 0, "expected to find at least one .png under " .. paths.WIDGET_DIR .. "icons")

      local problems = {}
      for _, file in ipairs(widgetLuaFiles()) do
        local content = paths.readFile(file)
        if content then
          for _, candidates in ipairs(extractIconCalls(content)) do
            local found = false
            for _, name in ipairs(candidates) do
              if exists[name] then
                found = true
                break
              end
            end
            if not found then
              problems[#problems + 1] = file .. ": none of [" .. table.concat(candidates, ", ") .. "] exist under icons/"
            end
          end
        end
      end

      t.assertEqual(#problems, 0, "dangling icon reference(s):\n  " .. table.concat(problems, "\n  "))
    end)
  end)

  t.describe("release packaging: module-load references resolve to a real file", function()
    t.it("every loadModule()/loadSiblingModule() literal path resolves under SCRIPTS/WIDGETS/FPVDASH", function()
      local problems = {}

      for _, file in ipairs(widgetLuaFiles()) do
        local content = paths.readFile(file)
        if content then
          for _, ref in ipairs(extractModuleLoadRefs(content)) do
            if not paths.readFile(paths.widget(ref.path)) then
              problems[#problems + 1] = file .. ": " .. ref.callName .. '("' .. ref.path .. '") does not resolve to a real file'
            end
          end
        end
      end

      t.assertEqual(#problems, 0, "dangling module-load reference(s):\n  " .. table.concat(problems, "\n  "))
    end)
  end)

  t.describe("release packaging: folder-name consistency", function()
    -- Deliberately does NOT assert a length limit on "FPVDASH" or on the
    -- widget's registered name -- Task 1 found no confirmed hard limit
    -- for either in current EdgeTX 2.12+ firmware source (see
    -- docs/platform/compatibility-matrix.md Section 8). Asserting one
    -- here would repeat exactly the mistake Task 1 corrected: guessing at
    -- a limit that was never confirmed to exist. What this guards
    -- against instead is the actual realistic risk -- the folder name
    -- string drifting out of sync across the files that reference it.
    t.it("SCRIPTS/WIDGETS/FPVDASH exists and every WIDGET_ROOTS table names it consistently", function()
      t.assertNotNil(paths.readFile(paths.widget("main.lua")),
        "SCRIPTS/WIDGETS/FPVDASH/main.lua must exist -- this is the widget's real install path")

      local checked = 0
      for _, file in ipairs(widgetLuaFiles()) do
        local content = paths.readFile(file)
        if content and content:find("WIDGET_ROOTS", 1, true) then
          checked = checked + 1
          t.assertTrue(content:find('"/WIDGETS/FPVDASH/"', 1, true) ~= nil,
            file .. "'s WIDGET_ROOTS must include the real install path /WIDGETS/FPVDASH/")
          t.assertTrue(content:find('"/SCRIPTS/WIDGETS/FPVDASH/"', 1, true) ~= nil,
            file .. "'s WIDGET_ROOTS must include the SD-card dev path /SCRIPTS/WIDGETS/FPVDASH/")
        end
      end

      -- main.lua + telemetry/read.lua + all 5 sibling-loading render
      -- files = 7 files with their own WIDGET_ROOTS table.
      t.assertEqual(checked, 7, "expected 7 files with their own WIDGET_ROOTS table (main.lua, telemetry/read.lua, and the 5 render/*.lua files that load render/primitives.lua) -- got a different count, which means a file was added/removed without this check being updated")
    end)
  end)
end
