-- Tests for render/sticks.lua's RX battery icon and text.
--
-- Found via Step 11 simulator testing, in two rounds:
--   1. A discovered sensor reading 0V showed "--.--V" next to a green/
--      "ok" icon -- batteryIconKey() returned "ok" for any cellV <= 0.
--   2. After fixing that to show no icon at all, further testing
--      (a real screenshot, mid-session with capacity already consumed)
--      showed that was still wrong: a discovered sensor genuinely
--      reading 0V is a real "dead battery" reading, the same way Step 4
--      already treats a genuine 0A current reading as valid rather than
--      absent -- it should show "0.00V" and the "dead" icon, not an
--      unknown placeholder. Only a truly undiscovered sensor should
--      show "--.--V" with no icon.
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

  local function drawnTextContains(needle)
    for _, call in ipairs(mock.lcdCalls or {}) do
      if call.name == "drawText" then
        for _, arg in ipairs(call) do
          if type(arg) == "string" and arg:find(needle, 1, true) then
            return true
          end
        end
      end
    end
    return false
  end

  local THEME = { textColor = 0xFFFF, iconFolder = "dark", isLight = false }
  local BOUNDS = { x = 0, y = 0, w = 480, h = 130 }

  t.describe("render/sticks.lua RX battery icon and text", function()
    t.it("shows the placeholder with no icon when the sensor is genuinely undiscovered", function()
      mock.withInstall({
        sensors = { RQly = { value = 95 } }, -- no VFAS/RxBt/etc. at all
      }, function()
        local read = paths.loadWidgetModule("telemetry/read.lua")
        local session = read.init()
        local state = paths.loadWidgetModule("telemetry/state.lua")
        local sticks = paths.loadWidgetModule("render/sticks.lua")

        local snap = read.snapshot(session)
        t.assertFalse(snap.available.battery)
        t.assertNil(snap.batteryCellVoltage)

        local evaluated = state.evaluate(snap)
        sticks.draw(BOUNDS, snap, evaluated, THEME)

        t.assertEqual(#drawBitmapPathsContaining("battery-"), 0)
        t.assertTrue(drawnTextContains("--.--V"))
      end)
    end)

    t.it("shows 0.00V and the dead icon for a fresh connection whose first reading is 0V", function()
      mock.withInstall({
        sensors = {
          RQly = { value = 95 },
          RxBt = { value = 0 }, -- discovered, genuinely reads zero, no prior history
        },
      }, function()
        local read = paths.loadWidgetModule("telemetry/read.lua")
        local session = read.init()
        local state = paths.loadWidgetModule("telemetry/state.lua")
        local sticks = paths.loadWidgetModule("render/sticks.lua")

        local snap = read.snapshot(session)
        t.assertTrue(snap.available.battery)
        t.assertEqual(snap.batteryCellVoltage, 0)
        t.assertNil(snap.batteryCells) -- never established -- no cell count invented

        local evaluated = state.evaluate(snap)
        t.assertEqual(evaluated.battery, state.CRITICAL)

        sticks.draw(BOUNDS, snap, evaluated, THEME)

        t.assertEqual(#drawBitmapPathsContaining("battery-dead.png"), 1)
        t.assertTrue(drawnTextContains("0.00V"))
      end)
    end)

    t.it("shows 0.00V (NS) and the dead icon when a pack drains to 0V after cells were already latched", function()
      local fixture = {
        sensors = {
          RQly = { value = 95 },
          VFAS = { value = 16.8 }, -- 4S, establishes the latch
        },
      }
      mock.withInstall(fixture, function()
        local read = paths.loadWidgetModule("telemetry/read.lua")
        local session = read.init()
        local state = paths.loadWidgetModule("telemetry/state.lua")
        local sticks = paths.loadWidgetModule("render/sticks.lua")

        local first = read.snapshot(session)
        t.assertEqual(first.batteryCells, 4)

        fixture.sensors.VFAS.value = 0
        local snap = read.snapshot(session)
        t.assertEqual(snap.batteryCells, 4) -- latch still holds
        t.assertEqual(snap.batteryCellVoltage, 0)

        local evaluated = state.evaluate(snap)
        sticks.draw(BOUNDS, snap, evaluated, THEME)

        t.assertEqual(#drawBitmapPathsContaining("battery-dead.png"), 1)
        t.assertTrue(drawnTextContains("0.00V (4S)"))
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
        local session = read.init()
        local state = paths.loadWidgetModule("telemetry/state.lua")
        local sticks = paths.loadWidgetModule("render/sticks.lua")

        local snap = read.snapshot(session)
        t.assertNotNil(snap.batteryCellVoltage)

        local evaluated = state.evaluate(snap)
        sticks.draw(BOUNDS, snap, evaluated, THEME)

        t.assertEqual(#drawBitmapPathsContaining("battery-ok.png"), 1)
      end)
    end)
  end)
end
