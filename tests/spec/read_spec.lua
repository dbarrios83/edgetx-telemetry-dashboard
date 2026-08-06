-- Unit tests for telemetry/read.lua: sensor alias resolution, the
-- absent-vs-valid-zero distinction, RFMD packet-rate mapping, connection
-- detection, and the negative sensor-ID cache rescan behavior.
return function(t, mock, paths)
  t.describe("telemetry/read.lua alias resolution", function()
    t.it("prefers the primary alias when both primary and secondary are present", function()
      mock.withInstall(paths.loadFixture("connected"), function()
        local read = paths.loadWidgetModule("telemetry/read.lua")
        local snap = read.snapshot()

        t.assertTrue(snap.available.battery)
        t.assertEqual(snap.battery, 16.8) -- from VFAS
        t.assertTrue(snap.connected)
      end)
    end)

    t.it("falls back to the secondary alias when the primary is not discovered", function()
      mock.withInstall(paths.loadFixture("absent_sensor"), function()
        local read = paths.loadWidgetModule("telemetry/read.lua")
        local snap = read.snapshot()

        -- VFAS is absent in this fixture; RxBt must be used instead.
        t.assertTrue(snap.available.battery)
        t.assertEqual(snap.battery, 15.2) -- from RxBt

        -- RQly is absent; LQ must be used instead.
        t.assertTrue(snap.available.linkQuality)
        t.assertEqual(snap.linkQuality, 95)
      end)
    end)
  end)

  t.describe("telemetry/read.lua absent-sensor vs valid-zero", function()
    t.it("marks a field unavailable when no alias resolves, rather than reporting zero", function()
      mock.withInstall(paths.loadFixture("absent_sensor"), function()
        local read = paths.loadWidgetModule("telemetry/read.lua")
        local snap = read.snapshot()

        -- Capacity has no sensor defined anywhere in this fixture.
        t.assertFalse(snap.available.capacity)
        t.assertEqual(snap.capacity, 0)
      end)
    end)

    t.it("keeps a real zero reading available and distinct from an absent sensor", function()
      mock.withInstall(paths.loadFixture("valid_zero"), function()
        local read = paths.loadWidgetModule("telemetry/read.lua")
        local snap = read.snapshot()

        t.assertTrue(snap.available.current)
        t.assertEqual(snap.current, 0)

        t.assertTrue(snap.available.activeAntenna)
        t.assertEqual(snap.activeAntenna, 0)
      end)
    end)
  end)

  t.describe("telemetry/read.lua RFMD packet-rate mapping (version-aware)", function()
    local function snapshotWithRfmd(rfmdValue, elrsMajorVersion)
      local fixture = paths.loadFixture("connected")
      fixture.sensors.RFMD.value = rfmdValue
      local snap
      mock.withInstall(fixture, function()
        local read = paths.loadWidgetModule("telemetry/read.lua")
        snap = read.snapshot(elrsMajorVersion)
      end)
      return snap
    end

    t.it("maps ELRS 3.x indexes using the flat, band-independent table", function()
      local snap = snapshotWithRfmd(9, 3) -- RATE_LORA_500HZ
      t.assertTrue(snap.available.packetRate)
      t.assertEqual(snap.packetRate, 500)
    end)

    t.it("maps ELRS 4.x indexes in the 900MHz range (0-11)", function()
      local snap = snapshotWithRfmd(4, 4) -- RATE_LORA_900_150HZ
      t.assertTrue(snap.available.packetRate)
      t.assertEqual(snap.packetRate, 150)
    end)

    t.it("maps ELRS 4.x indexes in the 2.4GHz range (20-36)", function()
      local snap = snapshotWithRfmd(29, 4) -- RATE_LORA_2G4_500HZ
      t.assertTrue(snap.available.packetRate)
      t.assertEqual(snap.packetRate, 500)
    end)

    t.it("maps ELRS 4.x dual-band indexes (100-101)", function()
      local snap = snapshotWithRfmd(101, 4) -- RATE_LORA_DUAL_150HZ
      t.assertTrue(snap.available.packetRate)
      t.assertEqual(snap.packetRate, 150)
    end)

    t.it("resolves the same raw RFMD index differently depending on ELRS major version", function()
      -- This is the exact protocol ambiguity the plan warns about: index 4
      -- means "100Hz (8ch)" on 3.x but "150Hz (900MHz)" on 4.x. Getting
      -- this wrong silently is precisely what the old flat table did.
      local snap3x = snapshotWithRfmd(4, 3)
      local snap4x = snapshotWithRfmd(4, 4)
      t.assertEqual(snap3x.packetRate, 100)
      t.assertEqual(snap4x.packetRate, 150)
    end)

    t.it("treats RFMD 0 as unavailable regardless of version, not a real rate", function()
      t.assertFalse(snapshotWithRfmd(0, 3).available.packetRate)
      t.assertFalse(snapshotWithRfmd(0, 4).available.packetRate)
    end)

    t.it("treats an index that falls in a band gap of a known version's table as unavailable", function()
      local snap = snapshotWithRfmd(15, 4) -- between the 900MHz (0-11) and 2.4GHz (20-36) ranges
      t.assertFalse(snap.available.packetRate)
      t.assertEqual(snap.packetRate, 0)
    end)

    t.it("never guesses a rate when the ELRS version is unknown", function()
      -- RFMD 9 would resolve to 500Hz on 3.x, but with no version
      -- detected yet, guessing which table applies is exactly what the
      -- plan prohibits.
      local snap = snapshotWithRfmd(9, nil)
      t.assertFalse(snap.available.packetRate)
    end)
  end)

  t.describe("telemetry/read.lua connection detection", function()
    t.it("reports connected when link quality is live", function()
      mock.withInstall(paths.loadFixture("connected"), function()
        local read = paths.loadWidgetModule("telemetry/read.lua")
        t.assertTrue(read.snapshot().connected)
      end)
    end)

    t.it("reports disconnected when LQ, TX power, and packet rate are all zero", function()
      mock.withInstall(paths.loadFixture("disconnected"), function()
        local read = paths.loadWidgetModule("telemetry/read.lua")
        t.assertFalse(read.snapshot().connected)
      end)
    end)

    -- Documents the current baseline for the Step 7 gap: connection
    -- detection only looks at LQ/TX power/packet rate today, so a model
    -- exposing nothing but generic telemetry (voltage/current/GPS) is
    -- currently reported as disconnected even though it has live data.
    -- Step 7 ("Redesign telemetry connection detection") is expected to
    -- change this assertion.
    t.it("[Step 7 baseline] generic-only telemetry with no LQ/TxPower/RFMD is NOT yet treated as connected", function()
      mock.withInstall({
        sensors = {
          VFAS = { value = 16.8 },
          Curr = { value = 5.0 },
          Sats = { value = 10 },
        },
      }, function()
        local read = paths.loadWidgetModule("telemetry/read.lua")
        t.assertFalse(read.snapshot().connected)
      end)
    end)
  end)

  t.describe("telemetry/read.lua flight mode", function()
    t.it("uses the FM sensor directly when present", function()
      mock.withInstall({ sensors = { FM = { value = "ACRO" } } }, function()
        local read = paths.loadWidgetModule("telemetry/read.lua")
        local snap = read.snapshot()
        t.assertEqual(snap.flightMode, "ACRO")
        t.assertTrue(snap.available.flightMode)
      end)
    end)

    -- Documents the current baseline for the Step 6 gap: EdgeTX's
    -- getFlightMode() returns (index, name), but normalizeFlightMode()
    -- only captures the first return value, so the name is dropped and
    -- the fallback never resolves. Step 6 ("Correct flight-mode
    -- normalization") is expected to change this assertion.
    t.it("[Step 6 baseline] the getFlightMode() mode-name fallback is currently dropped", function()
      mock.withInstall({ sensors = {}, flightMode = { 3, "ACRO" } }, function()
        local read = paths.loadWidgetModule("telemetry/read.lua")
        local snap = read.snapshot()
        t.assertEqual(snap.flightMode, "--")
        t.assertFalse(snap.available.flightMode)
      end)
    end)
  end)

  t.describe("telemetry/read.lua battery cell resolution", function()
    t.it("uses the Cels sensor as the explicit cell count when present", function()
      mock.withInstall({
        sensors = {
          VFAS = { value = 16.8 },
          RQly = { value = 95 },
          Cels = { value = { 4.20, 4.20, 4.20, 4.20 } }, -- explicit 4S
        },
      }, function()
        local read = paths.loadWidgetModule("telemetry/read.lua")
        local snap = read.snapshot()
        t.assertEqual(snap.batteryCells, 4)
        t.assertNear(snap.batteryCellVoltage, 4.20, 0.01)
      end)
    end)

    t.it("falls back to voltage-based inference when Cels is not discovered", function()
      mock.withInstall({
        sensors = {
          VFAS = { value = 16.8 },
          RQly = { value = 95 },
        },
      }, function()
        local read = paths.loadWidgetModule("telemetry/read.lua")
        local snap = read.snapshot()
        t.assertEqual(snap.batteryCells, 4)
      end)
    end)

    t.it("keeps a 6S pack latched at 6S as it drains across frames, never reporting it as full", function()
      local fixture = {
        sensors = {
          VFAS = { value = 25.0 }, -- 6S near-full
          RQly = { value = 95 },
        },
      }
      mock.withInstall(fixture, function()
        local read = paths.loadWidgetModule("telemetry/read.lua")
        local first = read.snapshot()
        t.assertEqual(first.batteryCells, 6)

        -- Pack drains mid-flight; the link stays up across frames.
        fixture.sensors.VFAS.value = 21.0
        local drained = read.snapshot()
        t.assertEqual(drained.batteryCells, 6)
        t.assertNear(drained.batteryCellVoltage, 3.50, 0.01)
      end)
    end)

    t.it("resets the latch on disconnect so a newly connected pack is not pinned to the previous one", function()
      local fixture = {
        sensors = {
          VFAS = { value = 25.0 },
          RQly = { value = 95 },
        },
      }
      mock.withInstall(fixture, function()
        local read = paths.loadWidgetModule("telemetry/read.lua")
        local first = read.snapshot()
        t.assertEqual(first.batteryCells, 6)

        -- Telemetry drops.
        fixture.sensors.RQly.value = 0
        local disconnected = read.snapshot()
        t.assertFalse(disconnected.connected)
        t.assertNil(disconnected.batteryCells)

        -- A different, smaller pack connects next.
        fixture.sensors.RQly.value = 95
        fixture.sensors.VFAS.value = 8.4 -- 2S at full charge
        local reconnected = read.snapshot()
        t.assertEqual(reconnected.batteryCells, 2)
      end)
    end)
  end)

  t.describe("telemetry/read.lua negative-cache rescan", function()
    t.it("retries a sensor that becomes available after the rescan interval", function()
      local fixture = { sensors = {} } -- Curr starts undiscovered
      mock.withInstall(fixture, function()
        local read = paths.loadWidgetModule("telemetry/read.lua")

        local first = read.snapshot()
        t.assertFalse(first.available.current)

        -- Simulate the sensor being discovered mid-session (e.g. a rebind).
        fixture.sensors.Curr = { id = 501, value = 6.5 }

        -- RESCAN_INTERVAL is 90 frames; until then the negative cache
        -- should keep skipping the now-available sensor.
        local stillCached
        for _ = 1, 88 do
          stillCached = read.snapshot()
        end
        t.assertFalse(stillCached.available.current)

        -- The rescan-interval frame clears the cache and re-resolves.
        local rescanned = read.snapshot()
        t.assertTrue(rescanned.available.current)
        t.assertEqual(rescanned.current, 6.5)
      end)
    end)
  end)
end
