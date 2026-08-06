-- Unit tests for telemetry/state.lua. This module is pure logic (no
-- EdgeTX API calls), so no mock installation is required.
return function(t, mock, paths)
  local state = paths.loadWidgetModule("telemetry/state.lua")

  t.describe("telemetry/state.lua battery", function()
    -- evaluateBattery() takes a resolved PER-CELL voltage, not total pack
    -- voltage. Cell-count resolution (explicit "Cels" telemetry, or
    -- latching voltage-based inference as a fallback) is Step 3's shared
    -- telemetry/battery.lua module; see tests/spec/battery_spec.lua for
    -- those cases, including the 6S@21.0V and 4S@13.05V regressions.
    t.it("reports OK for a healthy cell voltage (4.10V/cell)", function()
      t.assertEqual(state.evaluateBattery(4.10), state.OK)
    end)

    t.it("reports CRITICAL for a low cell voltage (3.30V/cell)", function()
      t.assertEqual(state.evaluateBattery(3.30), state.CRITICAL)
    end)

    t.it("reports UNKNOWN when cell voltage is absent, but CRITICAL for a real 0V reading", function()
      -- A real 0V reading from a discovered sensor is critically
      -- dead/disconnected, not "unknown" -- see render/sticks.lua's
      -- batteryIconKey for the matching icon behavior. Only a missing
      -- (nil) or nonsensical (negative) value is truly UNKNOWN.
      t.assertEqual(state.evaluateBattery(nil), state.UNKNOWN)
      t.assertEqual(state.evaluateBattery(-1), state.UNKNOWN)
      t.assertEqual(state.evaluateBattery(0), state.CRITICAL)
    end)
  end)

  t.describe("telemetry/state.lua link quality", function()
    t.it("reports OK above 90", function()
      t.assertEqual(state.evaluateLinkQuality(98, true), state.OK)
    end)
    t.it("reports WARNING between 70 and 90", function()
      t.assertEqual(state.evaluateLinkQuality(80, true), state.WARNING)
    end)
    t.it("reports CRITICAL below 70", function()
      t.assertEqual(state.evaluateLinkQuality(40, true), state.CRITICAL)
    end)
    t.it("reports UNKNOWN when unavailable", function()
      t.assertEqual(state.evaluateLinkQuality(98, false), state.UNKNOWN)
      t.assertEqual(state.evaluateLinkQuality(nil, true), state.UNKNOWN)
    end)
  end)

  t.describe("telemetry/state.lua RSSI", function()
    t.it("reports OK above -65 dBm", function()
      t.assertEqual(state.evaluateRSSI(-50, true), state.OK)
    end)
    t.it("reports WARNING between -65 and -85 dBm", function()
      t.assertEqual(state.evaluateRSSI(-75, true), state.WARNING)
    end)
    t.it("reports CRITICAL below -85 dBm", function()
      t.assertEqual(state.evaluateRSSI(-95, true), state.CRITICAL)
    end)
    t.it("reports UNKNOWN for a zero reading", function()
      t.assertEqual(state.evaluateRSSI(0, true), state.UNKNOWN)
    end)
  end)

  t.describe("telemetry/state.lua satellites", function()
    -- Thresholds (Step 10): OK >= 8, WARNING 5-7, CRITICAL < 5. Matches
    -- render/context.lua's satStateColor and the README's documented
    -- tiers -- previously state.lua alone used OK>=10/WARNING 6-9/
    -- CRITICAL<6, disagreeing with both.
    t.it("reports OK at the 8-satellite boundary and above", function()
      t.assertEqual(state.evaluateSatellites(8, true), state.OK)
      t.assertEqual(state.evaluateSatellites(12, true), state.OK)
    end)
    t.it("reports WARNING from 5 up to (not including) 8", function()
      t.assertEqual(state.evaluateSatellites(5, true), state.WARNING)
      t.assertEqual(state.evaluateSatellites(7, true), state.WARNING)
    end)
    t.it("reports CRITICAL below 5", function()
      t.assertEqual(state.evaluateSatellites(4, true), state.CRITICAL)
      t.assertEqual(state.evaluateSatellites(0, true), state.CRITICAL)
    end)
    t.it("reports UNKNOWN when unavailable", function()
      t.assertEqual(state.evaluateSatellites(12, false), state.UNKNOWN)
    end)
  end)

  t.describe("telemetry/state.lua evaluate() snapshot", function()
    t.it("marks every field DISCONNECTED when snapshot.connected is false", function()
      local result = state.evaluate({ connected = false })
      t.assertEqual(result.battery, state.DISCONNECTED)
      t.assertEqual(result.linkQuality, state.DISCONNECTED)
      t.assertEqual(result.packetRate, state.DISCONNECTED)
    end)

    t.it("marks every field DISCONNECTED when snapshot is nil", function()
      local result = state.evaluate(nil)
      t.assertEqual(result.battery, state.DISCONNECTED)
    end)

    t.it("evaluates each field from a connected snapshot", function()
      local result = state.evaluate({
        connected = true,
        batteryCellVoltage = 4.10,
        linkQuality = 98,
        rssi = -55,
        current = 8.2,
        satellites = 12,
        txPower = 100,
        packetRate = 100,
        available = {
          linkQuality = true, rssi = true, current = true,
          satellites = true, packetRate = true,
        },
      })
      t.assertEqual(result.battery, state.OK)
      t.assertEqual(result.linkQuality, state.OK)
      t.assertEqual(result.satellites, state.OK)
      t.assertEqual(result.sats, state.OK)
      t.assertEqual(result.packetRate, state.OK)
    end)
  end)
end
