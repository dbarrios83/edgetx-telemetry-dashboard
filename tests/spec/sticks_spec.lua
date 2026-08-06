-- Tests for render/sticks.lua's RX battery icon selection.
--
-- Found via Step 11 simulator testing: when battery voltage is unknown
-- (e.g. a discovered sensor genuinely reporting 0V), the widget showed
-- the "--.--V" placeholder text next to a green/full battery icon --
-- batteryIconKey() returned "ok" for the unknown case. A misleading
-- combination for a safety-relevant indicator, not caught by earlier
-- tests because none of them inspected icon selection, only text.
return function(t, mock, paths)
  local function drawBitmapPathsContaining(needle)
    local matches = {}
    for _, call in ipairs(mock.lcdCalls or {}) do
      if call.name == "drawBitmap" and type(call[1]) == "table" and type(call[1].__mockBitmap) == "string" then
        if call[1].__mockBitmap:find(needle, 1, true) then
          matches[#matches + 1] = call[1].__mockBitmap
        end
      end
    end
    return matches
  end

  local THEME = { textColor = 0xFFFF, iconFolder = "dark", isLight = false }
  local BOUNDS = { x = 0, y = 0, w = 480, h = 130 }

  t.describe("render/sticks.lua RX battery icon", function()
    t.it("draws no battery icon when voltage is unknown (RxBt discovered but reads 0)", function()
      mock.withInstall({
        sensors = {
          RQly = { value = 95 },
          RxBt = { value = 0 },
        },
      }, function()
        local read = paths.loadWidgetModule("telemetry/read.lua")
        local state = paths.loadWidgetModule("telemetry/state.lua")
        local sticks = paths.loadWidgetModule("render/sticks.lua")

        local snap = read.snapshot()
        t.assertTrue(snap.available.battery)
        t.assertNil(snap.batteryCellVoltage)

        local evaluated = state.evaluate(snap)
        sticks.draw(BOUNDS, snap, evaluated, THEME)

        t.assertEqual(#drawBitmapPathsContaining("battery-"), 0)
      end)
    end)

    t.it("draws the ok icon for a healthy known voltage", function()
      mock.withInstall({
        sensors = {
          RQly = { value = 95 },
          VFAS = { value = 15.2 }, -- 4S @ 3.80V/cell -> "ok" tier (3.70-4.00)
        },
      }, function()
        local read = paths.loadWidgetModule("telemetry/read.lua")
        local state = paths.loadWidgetModule("telemetry/state.lua")
        local sticks = paths.loadWidgetModule("render/sticks.lua")

        local snap = read.snapshot()
        t.assertNotNil(snap.batteryCellVoltage)

        local evaluated = state.evaluate(snap)
        sticks.draw(BOUNDS, snap, evaluated, THEME)

        t.assertEqual(#drawBitmapPathsContaining("battery-ok.png"), 1)
      end)
    end)
  end)
end
