-- Unit tests for telemetry/read.lua: sensor alias resolution, the
-- absent-vs-valid-zero distinction, RFMD packet-rate mapping, connection
-- detection, and the negative sensor-ID cache rescan behavior.
return function(t, mock, paths)
  t.describe("telemetry/read.lua alias resolution", function()
    t.it("prefers the primary alias when both primary and secondary are present", function()
      mock.withInstall(paths.loadFixture("connected"), function()
        local read = paths.loadWidgetModule("telemetry/read.lua")
        local session = read.init()
        local snap = read.snapshot(session)

        t.assertTrue(snap.available.battery)
        t.assertEqual(snap.battery, 16.8) -- from VFAS
        t.assertTrue(snap.connected)
      end)
    end)

    t.it("falls back to the secondary alias when the primary is not discovered", function()
      mock.withInstall(paths.loadFixture("absent_sensor"), function()
        local read = paths.loadWidgetModule("telemetry/read.lua")
        local session = read.init()
        local snap = read.snapshot(session)

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
        local session = read.init()
        local snap = read.snapshot(session)

        -- Capacity has no sensor defined anywhere in this fixture.
        t.assertFalse(snap.available.capacity)
        t.assertEqual(snap.capacity, 0)
      end)
    end)

    t.it("keeps a real zero reading available and distinct from an absent sensor", function()
      mock.withInstall(paths.loadFixture("valid_zero"), function()
        local read = paths.loadWidgetModule("telemetry/read.lua")
        local session = read.init()
        local snap = read.snapshot(session)

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
        local session = read.init()
        snap = read.snapshot(session, elrsMajorVersion)
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
        local session = read.init()
        t.assertTrue(read.snapshot(session).connected)
      end)
    end)

    t.it("reports disconnected when LQ, TX power, and packet rate are all zero", function()
      mock.withInstall(paths.loadFixture("disconnected"), function()
        local read = paths.loadWidgetModule("telemetry/read.lua")
        local session = read.init()
        t.assertFalse(read.snapshot(session).connected)
      end)
    end)

    -- Step 7 fix: connection detection no longer depends solely on
    -- ELRS-specific LQ/TX power/packet rate. EdgeTX's own getRSSI() is
    -- nonzero whenever the firmware's TELEMETRY_STREAMING() flag is
    -- true, for any protocol -- so a model exposing only generic
    -- sensors (voltage/current/GPS) is correctly treated as connected.
    t.it("connects via EdgeTX's protocol-agnostic getRSSI() even with no LQ/TxPower/RFMD", function()
      mock.withInstall({
        sensors = {
          VFAS = { value = 16.8 },
          Curr = { value = 5.0 },
          Sats = { value = 10 },
        },
        rssiStream = 70,
      }, function()
        local read = paths.loadWidgetModule("telemetry/read.lua")
        local session = read.init()
        t.assertTrue(read.snapshot(session).connected)
      end)
    end)

    t.it("stays disconnected when getRSSI() reports no stream and no ELRS signal is present either", function()
      mock.withInstall({
        sensors = {
          VFAS = { value = 16.8 },
          Curr = { value = 5.0 },
        },
        rssiStream = 0,
      }, function()
        local read = paths.loadWidgetModule("telemetry/read.lua")
        local session = read.init()
        t.assertFalse(read.snapshot(session).connected)
      end)
    end)

    t.it("transitions from connected to disconnected as telemetry is lost across frames", function()
      local fixture = {
        sensors = { VFAS = { value = 16.8 }, RQly = { value = 95 } },
        rssiStream = 80,
      }
      mock.withInstall(fixture, function()
        local read = paths.loadWidgetModule("telemetry/read.lua")
        local session = read.init()
        t.assertTrue(read.snapshot(session).connected)

        -- Link drops: both the ELRS signal and the streaming flag fall.
        fixture.sensors.RQly.value = 0
        fixture.rssiStream = 0
        t.assertFalse(read.snapshot(session).connected)
      end)
    end)

    t.it("restores values on reconnect without a stale intermediate read", function()
      local fixture = {
        sensors = { VFAS = { value = 16.8 }, RQly = { value = 0 } },
        rssiStream = 0,
      }
      mock.withInstall(fixture, function()
        local read = paths.loadWidgetModule("telemetry/read.lua")
        local session = read.init()
        t.assertFalse(read.snapshot(session).connected)

        fixture.sensors.RQly.value = 95
        fixture.rssiStream = 80
        local reconnected = read.snapshot(session)
        t.assertTrue(reconnected.connected)
        t.assertEqual(reconnected.battery, 16.8)
      end)
    end)

    t.it("the OR-condition mechanism: a live getRSSI() keeps connected=true even with LQ=0", function()
      -- This exercises the OR logic itself, not a claim about real CRSF
      -- hardware: on an actual ELRS link, EdgeTX's telemetryStreaming
      -- (what getRSSI() reads) is set/cleared by the same CRSF Link
      -- Statistics value as the LQ sensor (radio/src/telemetry/
      -- crossfire.cpp), so LQ=0 and getRSSI()=0 happen together for
      -- CRSF -- confirmed via Step 11 simulator testing, see
      -- compatibility-matrix.md Section 7. getRSSI() staying live while
      -- LQ=0 is a real, independent condition for non-CRSF protocols
      -- (e.g. FrSky S.Port's separate RSSI_ID sensor), which this test
      -- fixture represents.
      mock.withInstall({
        sensors = {
          VFAS = { value = 14.5 },
          RQly = { value = 0 },
          Curr = { value = 3.0 },
        },
        rssiStream = 55,
      }, function()
        local read = paths.loadWidgetModule("telemetry/read.lua")
        local session = read.init()
        local snap = read.snapshot(session)
        t.assertTrue(snap.connected)
        t.assertTrue(snap.available.linkQuality)
        t.assertEqual(snap.linkQuality, 0)
        t.assertTrue(snap.available.current)
        t.assertEqual(snap.current, 3.0)
      end)
    end)
  end)

  t.describe("telemetry/read.lua flight mode", function()
    t.it("uses the FM sensor directly when present", function()
      mock.withInstall({ sensors = { FM = { value = "ACRO" } } }, function()
        local read = paths.loadWidgetModule("telemetry/read.lua")
        local session = read.init()
        local snap = read.snapshot(session)
        t.assertEqual(snap.flightMode, "ACRO")
        t.assertTrue(snap.available.flightMode)
      end)
    end)

    -- Step 6 fix: EdgeTX's getFlightMode() returns (index, name); the
    -- radio fallback must use the name, not the index it used to
    -- silently capture and then fail a `type() == "string"` check on.
    t.it("resolves the radio getFlightMode() fallback to the mode name when no FC sensor is discovered", function()
      mock.withInstall({ sensors = {}, flightMode = { 3, "ACRO" } }, function()
        local read = paths.loadWidgetModule("telemetry/read.lua")
        local session = read.init()
        local snap = read.snapshot(session)
        t.assertEqual(snap.flightMode, "ACRO")
        t.assertTrue(snap.available.flightMode)
      end)
    end)

    t.it("prefers the FC telemetry mode over the radio fallback when both are present", function()
      mock.withInstall({ sensors = { FM = { value = "HORIZON" } }, flightMode = { 1, "ACRO" } }, function()
        local read = paths.loadWidgetModule("telemetry/read.lua")
        local session = read.init()
        local snap = read.snapshot(session)
        t.assertEqual(snap.flightMode, "HORIZON")
      end)
    end)

    t.it("renders a neutral placeholder when neither an FC sensor nor a radio fallback name is available", function()
      mock.withInstall({ sensors = {}, flightMode = nil }, function()
        local read = paths.loadWidgetModule("telemetry/read.lua")
        local session = read.init()
        local snap = read.snapshot(session)
        t.assertEqual(snap.flightMode, "--")
        t.assertFalse(snap.available.flightMode)
      end)
    end)

    t.it("renders a neutral placeholder when getFlightMode() returns an index but an empty name", function()
      mock.withInstall({ sensors = {}, flightMode = { 0, "" } }, function()
        local read = paths.loadWidgetModule("telemetry/read.lua")
        local session = read.init()
        local snap = read.snapshot(session)
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
        local session = read.init()
        local snap = read.snapshot(session)
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
        local session = read.init()
        local snap = read.snapshot(session)
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
        local session = read.init()
        local first = read.snapshot(session)
        t.assertEqual(first.batteryCells, 6)

        -- Pack drains mid-flight; the link stays up across frames.
        fixture.sensors.VFAS.value = 21.0
        local drained = read.snapshot(session)
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
        local session = read.init()
        local first = read.snapshot(session)
        t.assertEqual(first.batteryCells, 6)

        -- Telemetry drops.
        fixture.sensors.RQly.value = 0
        local disconnected = read.snapshot(session)
        t.assertFalse(disconnected.connected)
        t.assertNil(disconnected.batteryCells)

        -- A different, smaller pack connects next.
        fixture.sensors.RQly.value = 95
        fixture.sensors.VFAS.value = 8.4 -- 2S at full charge
        local reconnected = read.snapshot(session)
        t.assertEqual(reconnected.batteryCells, 2)
      end)
    end)
  end)

  t.describe("telemetry/read.lua negative-cache rescan", function()
    t.it("retries a sensor that becomes available after the rescan interval", function()
      local fixture = { sensors = {} } -- Curr starts undiscovered
      mock.withInstall(fixture, function()
        local read = paths.loadWidgetModule("telemetry/read.lua")
        local session = read.init()

        local first = read.snapshot(session)
        t.assertFalse(first.available.current)

        -- Simulate the sensor being discovered mid-session (e.g. a rebind).
        fixture.sensors.Curr = { id = 501, value = 6.5 }

        -- RESCAN_INTERVAL is 90 frames; until then the negative cache
        -- should keep skipping the now-available sensor.
        local stillCached
        for _ = 1, 88 do
          stillCached = read.snapshot(session)
        end
        t.assertFalse(stillCached.available.current)

        -- The rescan-interval frame clears the cache and re-resolves.
        local rescanned = read.snapshot(session)
        t.assertTrue(rescanned.available.current)
        t.assertEqual(rescanned.current, 6.5)
      end)
    end)
  end)

  -- Architecture & Packaging Hardening, Task 3: the sensor-ID cache and
  -- rescan counter used to live as module-level locals, shared by every
  -- M.snapshot() caller. EdgeTX shares a widget script's file-scope
  -- locals across every instance of that widget, so two widget instances
  -- would have corrupted each other's negative-cache state. M.init() now
  -- hands each caller its own session.
  t.describe("telemetry/read.lua per-instance session isolation (Task 3)", function()
    t.it("does not share a sensor-ID negative cache between two independently-init()'d sessions", function()
      -- Curr is undiscovered under sessionA's fixture but discovered
      -- under sessionB's -- if the negative cache were shared, sessionB
      -- would incorrectly inherit sessionA's "Curr is absent" result.
      mock.withInstall({ sensors = {} }, function()
        local read = paths.loadWidgetModule("telemetry/read.lua")
        local sessionA = read.init()
        local snapA = read.snapshot(sessionA)
        t.assertFalse(snapA.available.current)
      end)

      mock.withInstall({ sensors = { Curr = { value = 6.5 } } }, function()
        local read = paths.loadWidgetModule("telemetry/read.lua")
        local sessionB = read.init()
        local snapB = read.snapshot(sessionB)
        t.assertTrue(snapB.available.current,
          "a fresh session must resolve its own sensors, not inherit another session's negative cache")
        t.assertEqual(snapB.current, 6.5)
      end)
    end)

    t.it("does not share a battery latch between two independently-init()'d sessions", function()
      local fixture = {
        sensors = {
          VFAS = { value = 25.0 }, -- 6S near-full
          RQly = { value = 95 },
        },
      }
      mock.withInstall(fixture, function()
        local read = paths.loadWidgetModule("telemetry/read.lua")

        -- sessionA sees the pack from near-full charge and correctly
        -- latches 6S, then holds that latch as the pack drains.
        local sessionA = read.init()
        t.assertEqual(read.snapshot(sessionA).batteryCells, 6)

        fixture.sensors.VFAS.value = 21.0
        t.assertEqual(read.snapshot(sessionA).batteryCells, 6)

        -- A second widget instance is created now, mid-flight, and sees
        -- this already-drained 21.0V for the very first time. If
        -- sessionB's state were accidentally shared with sessionA's (the
        -- bug this task fixes), it would incorrectly inherit the
        -- already-latched 6. A properly isolated session has no prior
        -- history, so it infers fresh from the only reading it has ever
        -- seen -- 5, not 6.
        local sessionB = read.init()
        local snapB = read.snapshot(sessionB)
        t.assertEqual(snapB.batteryCells, 5,
          "a brand-new session must infer fresh from its own first reading, not inherit another session's already-established 6S latch")

        -- sessionA's own latch must remain completely unaffected by
        -- sessionB's existence.
        fixture.sensors.VFAS.value = 18.0
        t.assertEqual(read.snapshot(sessionA).batteryCells, 6)
      end)
    end)
  end)
end
