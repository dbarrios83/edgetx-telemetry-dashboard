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
    -- Which root(s) a given openBitmapFromCandidates() call actually
    -- searches (icons/<theme>/, icons/battery/, icons/link/, flat
    -- icons/, or some combination as a fallback chain) is decided by
    -- each render/*.lua file's own root-building logic, which differs
    -- per renderer and even per call site within one renderer (compare
    -- render/context.lua's loadIconSet(), which has no flat fallback, to
    -- render/topbar.lua's buildThemedRoots(), which does; or
    -- render/sticks.lua's battery/link icons, which aren't theme-scoped
    -- at all). Reconstructing that scoping from source text requires
    -- either parsing every root-list definition or hard-coding each call
    -- site's folder by hand -- both drift-prone. So instead of guessing,
    -- this drives each renderer's real draw() against a Bitmap.open that
    -- checks the actual icons/ tree on disk, for both themes, and
    -- records which candidate basenames it actually resolved -- exactly
    -- the codepath and roots EdgeTX itself would use. Found incomplete
    -- via external review (2026-08-07): an earlier version of this test
    -- matched candidate basenames anywhere under icons/, which also
    -- can't tell "resolves via *this* call's actual roots" from "a
    -- same-named file happens to sit in an unrelated specialized
    -- subfolder" apart.
    local RENDERER_DRAWS = {
      { path = "render/context.lua", bounds = { x = 0, y = 0, w = 320, h = 80 } },
      { path = "render/sticks.lua", bounds = { x = 0, y = 0, w = 480, h = 130 } },
      { path = "render/topbar.lua", bounds = { x = 0, y = 0, w = 480, h = 40 } },
      { path = "render/timers.lua", bounds = { x = 0, y = 0, w = 320, h = 40 } },
    }

    -- Strips a candidate's full simulated EdgeTX path (e.g.
    -- "/SCRIPTS/WIDGETS/FPVDASH/icons/dark/current.png") down to the
    -- "icons/..." suffix shared by all 4 install-path root variants, so
    -- it can be checked against this repo's real on-disk layout.
    local function realIconFileExists(path)
      local suffix = path:match("FPVDASH/(icons/.+)$")
      return suffix ~= nil and paths.readFile(paths.WIDGET_DIR .. suffix) ~= nil
    end

    t.it("every openBitmapFromCandidates() call resolves for both the dark and the light theme", function()
      local problems = {}

      for _, renderer in ipairs(RENDERER_DRAWS) do
        local content = paths.readFile(paths.widget(renderer.path))
        local calls = content and extractIconCalls(content) or {}

        if #calls > 0 then
          for _, themeName in ipairs({ "dark", "light" }) do
            -- A single draw() only ever takes each call's *primary*
            -- candidate path -- render/sticks.lua's connection icons
            -- fall back to openBitmapFromCandidates(roots, {"link.png",
            -- ...}) only "if not CONNECTION_ICONS.ok" (i.e. only if the
            -- primary "connection-ok.png" lookup already failed), so one
            -- draw() against the repo's current, complete icon set can
            -- never reach that fallback call at all. Re-drawing with
            -- every previously-resolved file hidden forces the next
            -- fallback layer to actually run, so repeating until a draw
            -- opens nothing new discovers every reachable candidate, not
            -- just the first one taken today.
            local opened = {}
            local hidden = {}
            local sawNewOpen = true
            while sawNewOpen do
              sawNewOpen = false

              mock.withInstall({ sensors = {} }, function()
                Bitmap.open = function(path)
                  local basename = path:match("([^/\\]+)$")
                  if not hidden[basename] and realIconFileExists(path) then
                    if not opened[basename] then
                      opened[basename] = true
                      sawNewOpen = true
                    end
                    return { __mockBitmap = path }
                  end
                  return nil
                end

                local read = paths.loadWidgetModule("telemetry/read.lua")
                local session = read.init()
                local snap = read.snapshot(session)
                local evaluated = paths.loadWidgetModule("telemetry/state.lua").evaluate(snap)
                local theme = { textColor = 0xFFFF, iconFolder = themeName, isLight = (themeName == "light") }

                paths.loadWidgetModule(renderer.path).draw(renderer.bounds, snap, evaluated, theme)
              end)

              for basename in pairs(opened) do
                hidden[basename] = true
              end
            end

            for _, candidates in ipairs(calls) do
              local found = false
              for _, name in ipairs(candidates) do
                if opened[name] then
                  found = true
                  break
                end
              end
              if not found then
                problems[#problems + 1] = renderer.path .. " (" .. themeName .. " theme): none of [" ..
                  table.concat(candidates, ", ") .. "] were opened from disk during draw()"
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
