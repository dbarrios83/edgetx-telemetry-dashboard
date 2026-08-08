-- Tests for main.lua's transparency-option resolution (Step 8).
--
-- EdgeTX exposes the "transpLvl" option through one of two widget-option
-- types depending on the firmware build: Choice/Combo (1-based, per
-- EdgeTX's own widget_settings.cpp: getUnsignedValue(optIdx) - 1 feeds a
-- 0-based UI control) or plain VALUE (declared here with min=0, so
-- genuinely 0-based). Both must resolve deterministically to all four
-- TRANSP_VALUES -- the bug this step fixes was guessing the convention
-- from the raw number's range instead of the already-known option type.
return function(t, mock, paths)
  local ZONE = { x = 0, y = 0, w = 480, h = 272 }

  t.describe("main.lua transparency resolution (Choice/Combo option, 1-based)", function()
    -- The mock installs COMBO by default, so main.lua's own
    -- OPTION_COMBO detection takes the Choice/Combo branch.
    t.it("maps all four 1-based levels to their distinct transparency values", function()
      mock.withInstall({ sensors = {} }, function()
        local main = paths.loadWidgetModule("main.lua")
        local seen = {}
        for level = 1, 4 do
          local widget = main.create(ZONE, { darkTheme = 1, transpLvl = level })
          seen[level] = widget.theme.transparency
        end
        t.assertEqual(seen[1], 6)
        t.assertEqual(seen[2], 8)
        t.assertEqual(seen[3], 10)
        t.assertEqual(seen[4], 12)
      end)
    end)

    t.it("falls back to the first level for an out-of-range value", function()
      mock.withInstall({ sensors = {} }, function()
        local main = paths.loadWidgetModule("main.lua")
        local widget = main.create(ZONE, { darkTheme = 1, transpLvl = 0 })
        t.assertEqual(widget.theme.transparency, 6)
      end)
    end)
  end)

  t.describe("main.lua transparency resolution (plain VALUE option, 0-based)", function()
    -- Simulates an EdgeTX build with neither COMBO nor CHOICE defined,
    -- which is exactly the condition main.lua's own OPTION_COMBO check
    -- falls back on -- the widget then declares transpLvl as a plain
    -- VALUE option with min=0, max=3.
    t.it("maps all four 0-based levels to their distinct transparency values", function()
      mock.withInstall({ sensors = {}, disableCombo = true }, function()
        local main = paths.loadWidgetModule("main.lua")
        local seen = {}
        for level = 0, 3 do
          local widget = main.create(ZONE, { darkTheme = 1, transpLvl = level })
          seen[level] = widget.theme.transparency
        end
        t.assertEqual(seen[0], 6)
        t.assertEqual(seen[1], 8)
        t.assertEqual(seen[2], 10)
        t.assertEqual(seen[3], 12)
      end)
    end)
  end)

  t.describe("main.lua transparency resolution defaults", function()
    t.it("resolves the declared default (1) to the first transparency level in both option modes", function()
      mock.withInstall({ sensors = {} }, function()
        local main = paths.loadWidgetModule("main.lua")
        local widget = main.create(ZONE, { darkTheme = 1 }) -- transpLvl omitted
        t.assertEqual(widget.theme.transparency, 6)
      end)

      mock.withInstall({ sensors = {}, disableCombo = true }, function()
        local main = paths.loadWidgetModule("main.lua")
        local widget = main.create(ZONE, { darkTheme = 1 }) -- transpLvl omitted
        t.assertEqual(widget.theme.transparency, 8)
      end)
    end)
  end)

  t.describe("main.lua widget option metadata", function()
    t.it("declares the transpLvl option name at 10 characters or fewer", function()
      mock.withInstall({ sensors = {} }, function()
        local main = paths.loadWidgetModule("main.lua")
        for _, option in ipairs(main.options) do
          t.assertTrue(#option[1] <= 10, "option name too long: " .. option[1])
        end
      end)
    end)
  end)

  -- Architecture & Packaging Hardening, Task 2: EdgeTX loads every
  -- installed widget's top-level chunk whenever a model is selected, even
  -- widgets never placed in a zone. main.lua must not load its nine
  -- submodules until the widget is actually instantiated via create().
  t.describe("main.lua deferred module loading (Task 2)", function()
    local function installWithLoadScriptSpy(fn)
      local loadScriptCalls = {}
      mock.withInstall({
        sensors = {},
        loadScript = function(path)
          loadScriptCalls[#loadScriptCalls + 1] = path
          return loadfile(path)
        end,
      }, function()
        fn(loadScriptCalls)
      end)
    end

    t.it("does not call loadScript for any submodule before create() is invoked", function()
      installWithLoadScriptSpy(function(loadScriptCalls)
        local main = paths.loadWidgetModule("main.lua")
        t.assertEqual(#loadScriptCalls, 0,
          "main.lua's top-level chunk must not load submodules -- EdgeTX runs this chunk for every installed widget when a model is selected, even ones never placed in a zone")

        main.create(ZONE, { darkTheme = 1 })
        t.assertTrue(#loadScriptCalls > 0, "create() must trigger submodule loading")
      end)
    end)

    t.it("loads submodules only once across repeated create()/refresh() calls", function()
      installWithLoadScriptSpy(function(loadScriptCalls)
        local main = paths.loadWidgetModule("main.lua")

        local widget = main.create(ZONE, { darkTheme = 1 })
        local countAfterCreate = #loadScriptCalls
        t.assertTrue(countAfterCreate > 0, "create() must trigger submodule loading")

        main.refresh(widget, nil, nil)
        main.refresh(widget, nil, nil)
        local secondWidget = main.create(ZONE, { darkTheme = 1 })
        main.refresh(secondWidget, nil, nil)

        t.assertEqual(#loadScriptCalls, countAfterCreate,
          "submodules must load exactly once per Lua chunk instance, not once per create()/refresh() call")
      end)
    end)

    t.it("still exposes name/options before create() is ever called", function()
      installWithLoadScriptSpy(function(loadScriptCalls)
        local main = paths.loadWidgetModule("main.lua")
        t.assertEqual(main.name, "Telemetry Dashboard")
        t.assertNotNil(main.options)
        t.assertEqual(#loadScriptCalls, 0,
          "reading name/options must not itself trigger submodule loading")
      end)
    end)
  end)

  -- Architecture & Packaging Hardening, Task 3: this is the actual bug
  -- scenario the read.lua/battery.lua session refactor fixes -- two real
  -- widget instances (two create() calls), not just two lower-level
  -- read.init()/battery.init() sessions in isolation (covered separately
  -- in read_spec.lua and battery_spec.lua).
  t.describe("main.lua per-instance telemetry state isolation (Task 3)", function()
    t.it("does not share a battery latch between two independently-created widget instances", function()
      local fixture = {
        sensors = {
          VFAS = { value = 25.0 }, -- 6S near-full
          RQly = { value = 95 },
        },
      }
      mock.withInstall(fixture, function()
        local main = paths.loadWidgetModule("main.lua")

        -- widgetA sees the pack from near-full charge and correctly
        -- latches 6S, then holds that latch as the pack drains.
        local widgetA = main.create(ZONE, { darkTheme = 1 })
        main.refresh(widgetA, nil, nil)
        t.assertEqual(widgetA.telemetry.batteryCells, 6)

        fixture.sensors.VFAS.value = 21.0
        main.refresh(widgetA, nil, nil)
        t.assertEqual(widgetA.telemetry.batteryCells, 6)

        -- widgetB is created now, mid-flight, and sees this
        -- already-drained 21.0V for the very first time. If the two
        -- widget instances shared a telemetry session (the bug this task
        -- fixes), widgetB would incorrectly inherit widgetA's
        -- already-latched 6. A properly isolated instance has no prior
        -- history, so it infers fresh from the only reading it has ever
        -- seen -- 5, not 6.
        local widgetB = main.create(ZONE, { darkTheme = 1 })
        main.refresh(widgetB, nil, nil)
        t.assertEqual(widgetB.telemetry.batteryCells, 5,
          "a freshly created widget instance must infer its own cell count, not share widgetA's telemetry session")

        -- widgetA's own session must remain completely unaffected by
        -- widgetB's existence.
        fixture.sensors.VFAS.value = 18.0
        main.refresh(widgetA, nil, nil)
        t.assertEqual(widgetA.telemetry.batteryCells, 6)
      end)
    end)
  end)

  -- Stick Modes feature: theme.stickMode feeds render/sticks.lua's
  -- left/right box assignment. "Auto" (the declared default) must prefer
  -- getStickMode() when the firmware provides it -- which it does from
  -- this project's 2.12 floor onward (confirmed against the tagged
  -- v2.12.0/v2.12.1 source; its "Introduced in 3.0" doc comment in
  -- EdgeTX's own source is stale) -- and otherwise fall back to Mode 2,
  -- this widget's original, always-Mode-2 behavior. An explicit override
  -- must always win over getStickMode(), as a manual escape hatch for any
  -- firmware that genuinely doesn't provide it.
  t.describe("main.lua stick mode resolution (Choice/Combo option, 1-based; labels Auto/1/2/3/4)", function()
    t.it("falls back to Mode 2 when Auto and getStickMode() is unavailable", function()
      mock.withInstall({ sensors = {} }, function() -- no fixture.stickMode -> getStickMode undefined
        local main = paths.loadWidgetModule("main.lua")
        local widget = main.create(ZONE, { darkTheme = 1, stickMode = 1 }) -- "Auto"
        t.assertEqual(widget.theme.stickMode, 2)
      end)
    end)

    t.it("prefers getStickMode() when Auto and the firmware provides it", function()
      mock.withInstall({ sensors = {}, stickMode = 3 }, function()
        local main = paths.loadWidgetModule("main.lua")
        local widget = main.create(ZONE, { darkTheme = 1, stickMode = 1 }) -- "Auto"
        t.assertEqual(widget.theme.stickMode, 3)
      end)
    end)

    t.it("an explicit override always wins over getStickMode()", function()
      mock.withInstall({ sensors = {}, stickMode = 2 }, function()
        local main = paths.loadWidgetModule("main.lua")
        local widget = main.create(ZONE, { darkTheme = 1, stickMode = 5 }) -- explicit "4"
        t.assertEqual(widget.theme.stickMode, 4)
      end)
    end)

    t.it("maps all four explicit combo levels to their mode numbers", function()
      mock.withInstall({ sensors = {} }, function()
        local main = paths.loadWidgetModule("main.lua")
        local seen = {}
        for level = 2, 5 do
          local widget = main.create(ZONE, { darkTheme = 1, stickMode = level })
          seen[level] = widget.theme.stickMode
        end
        t.assertEqual(seen[2], 1)
        t.assertEqual(seen[3], 2)
        t.assertEqual(seen[4], 3)
        t.assertEqual(seen[5], 4)
      end)
    end)

    t.it("resolves the declared default (1, Auto) to Mode 2 when stickMode is omitted", function()
      mock.withInstall({ sensors = {} }, function()
        local main = paths.loadWidgetModule("main.lua")
        local widget = main.create(ZONE, { darkTheme = 1 }) -- stickMode omitted
        t.assertEqual(widget.theme.stickMode, 2)
      end)
    end)
  end)

  t.describe("main.lua stick mode resolution (plain VALUE option, 0-based; 0=Auto)", function()
    t.it("falls back to Mode 2 when Auto (0) and getStickMode() is unavailable", function()
      mock.withInstall({ sensors = {}, disableCombo = true }, function()
        local main = paths.loadWidgetModule("main.lua")
        local widget = main.create(ZONE, { darkTheme = 1, stickMode = 0 })
        t.assertEqual(widget.theme.stickMode, 2)
      end)
    end)

    t.it("prefers getStickMode() when Auto (0) and the firmware provides it", function()
      mock.withInstall({ sensors = {}, disableCombo = true, stickMode = 4 }, function()
        local main = paths.loadWidgetModule("main.lua")
        local widget = main.create(ZONE, { darkTheme = 1, stickMode = 0 })
        t.assertEqual(widget.theme.stickMode, 4)
      end)
    end)

    t.it("an explicit override (1-4) always wins over getStickMode()", function()
      mock.withInstall({ sensors = {}, disableCombo = true, stickMode = 1 }, function()
        local main = paths.loadWidgetModule("main.lua")
        local widget = main.create(ZONE, { darkTheme = 1, stickMode = 3 })
        t.assertEqual(widget.theme.stickMode, 3)
      end)
    end)
  end)
end
