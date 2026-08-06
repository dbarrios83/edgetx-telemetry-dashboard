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
end
