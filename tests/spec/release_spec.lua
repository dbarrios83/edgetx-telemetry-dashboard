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
          -- Each openBitmapFromCandidates(roots, { "a.png", "b.png", ... })
          -- call is a fallback list -- only one candidate needs to exist,
          -- not all of them (e.g. context.lua's { "sat.png", "sats.png" }
          -- deliberately keeps a name that has never shipped as a
          -- forward-compatible fallback). So candidates are grouped per
          -- call, not flattened across the whole file.
          for namesBlock in content:gmatch("openBitmapFromCandidates%s*%([%w_]+%s*,%s*%{(.-)%}%s*%)") do
            local candidates = {}
            for name in namesBlock:gmatch('"([%w%-_%.]+%.png)"') do
              candidates[#candidates + 1] = name
            end

            if #candidates > 0 then
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
      end

      t.assertEqual(#problems, 0, "dangling icon reference(s):\n  " .. table.concat(problems, "\n  "))
    end)
  end)

  t.describe("release packaging: module-load references resolve to a real file", function()
    t.it("every loadModule()/loadSiblingModule() literal path resolves under SCRIPTS/WIDGETS/FPVDASH", function()
      local problems = {}

      -- Lua patterns have no alternation, so loadModule() and
      -- loadSiblingModule() are matched in two separate passes rather
      -- than one combined pattern.
      local CALL_PATTERNS = { "loadModule", "loadSiblingModule" }

      for _, file in ipairs(widgetLuaFiles()) do
        local content = paths.readFile(file)
        if content then
          for _, callName in ipairs(CALL_PATTERNS) do
            for relativePath in content:gmatch(callName .. '%("([^"]+)"%)') do
              if not paths.readFile(paths.widget(relativePath)) then
                problems[#problems + 1] = file .. ": " .. callName .. '("' .. relativePath .. '") does not resolve to a real file'
              end
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
