-- Unit tests for telemetry/elrs.lua's CRSF device-info polling/parsing.
return function(t, mock, paths)
  t.describe("telemetry/elrs.lua", function()
    t.it("init() returns a fresh, not-done state", function()
      local elrs = paths.loadWidgetModule("telemetry/elrs.lua")
      local state = elrs.init()
      t.assertFalse(state.done)
      t.assertNil(state.vStr)
    end)

    t.it("getString() falls back to 'ELRS' before any device-info frame arrives", function()
      local elrs = paths.loadWidgetModule("telemetry/elrs.lua")
      local state = elrs.init()
      t.assertEqual(elrs.getString(state), "ELRS")
    end)

    t.it("parses a CRSF device-info response into a version string", function()
      -- Byte layout: [1]=dest [2]=src(0xEE) [3..6]="ELRS" [7]=NUL
      -- [8..16]=9 filler bytes (unused device-info fields)
      -- [17..19]=major.minor.revision
      local data = {}
      data[1] = 0x00
      data[2] = 0xEE
      data[3], data[4], data[5], data[6], data[7] = 69, 76, 82, 83, 0
      for i = 8, 16 do
        data[i] = 0
      end
      data[17], data[18], data[19] = 3, 4, 0

      mock.withInstall({ crsfIncoming = { { command = 0x29, data = data } } }, function()
        local elrs = paths.loadWidgetModule("telemetry/elrs.lua")
        local state = elrs.init()

        elrs.update(state)

        t.assertTrue(state.done)
        t.assertEqual(elrs.getString(state), "ELRS 3.4.0")
      end)
    end)

    t.it("exposes the parsed major version for RFMD table selection", function()
      local data = {}
      data[1] = 0x00
      data[2] = 0xEE
      data[3], data[4], data[5], data[6], data[7] = 69, 76, 82, 83, 0
      for i = 8, 16 do
        data[i] = 0
      end
      data[17], data[18], data[19] = 4, 1, 0 -- ELRS 4.1.0

      mock.withInstall({ crsfIncoming = { { command = 0x29, data = data } } }, function()
        local elrs = paths.loadWidgetModule("telemetry/elrs.lua")
        local state = elrs.init()

        t.assertNil(elrs.getMajorVersion(state))

        elrs.update(state)

        t.assertEqual(elrs.getMajorVersion(state), 4)
      end)
    end)

    t.it("ignores frames not addressed to the TX module (address != 0xEE)", function()
      local data = { 0x00, 0xC8, 88, 0 } -- source 0xC8, not 0xEE
      mock.withInstall({ crsfIncoming = { { command = 0x29, data = data } } }, function()
        local elrs = paths.loadWidgetModule("telemetry/elrs.lua")
        local state = elrs.init()

        elrs.update(state)

        t.assertFalse(state.done)
        t.assertEqual(elrs.getString(state), "ELRS")
      end)
    end)

    t.it("throttles device-info requests to roughly once per second", function()
      -- Start the mock clock well past zero so the "send if stale" check
      -- (lastUpd + 100 < now) is true on the very first poll.
      mock.withInstall({ crsfIncoming = {}, time = 1000 }, function()
        local elrs = paths.loadWidgetModule("telemetry/elrs.lua")
        local state = elrs.init()

        elrs.update(state)
        t.assertEqual(#mock.crsfPushed, 1)
        t.assertEqual(mock.crsfPushed[1].command, 0x28)

        elrs.update(state) -- no time has passed: must not resend yet
        t.assertEqual(#mock.crsfPushed, 1)

        mock.advanceTime(150)
        elrs.update(state) -- past the ~1s throttle window: resend
        t.assertEqual(#mock.crsfPushed, 2)
      end)
    end)

    t.it("stops polling once a device-info response has been parsed", function()
      local data = {}
      data[1] = 0x00
      data[2] = 0xEE
      data[3], data[4], data[5], data[6], data[7] = 69, 76, 82, 83, 0
      for i = 8, 16 do
        data[i] = 0
      end
      data[17], data[18], data[19] = 3, 4, 0

      mock.withInstall({ crsfIncoming = { { command = 0x29, data = data } }, time = 1000 }, function()
        local elrs = paths.loadWidgetModule("telemetry/elrs.lua")
        local state = elrs.init()

        elrs.update(state)
        t.assertTrue(state.done)

        local pushedBefore = #mock.crsfPushed
        mock.advanceTime(500)
        elrs.update(state)
        t.assertEqual(#mock.crsfPushed, pushedBefore)
      end)
    end)
  end)
end
