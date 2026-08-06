-- Integration tests for render/context.lua: verifies it renders from the
-- normalized telemetry snapshot rather than reading sensors itself (Step
-- 4). Drives the real read.lua -> state.lua -> context.lua pipeline and
-- inspects the mocked lcd.drawText calls the renderer actually made.
return function(t, mock, paths)
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
  local RECT = { x = 0, y = 0, w = 320, h = 80 }

  t.describe("render/context.lua", function()
    t.it("renders the current reading from the normalized snapshot", function()
      mock.withInstall({
        sensors = {
          RQly = { value = 95 },
          Curr = { value = 12.5 },
        },
      }, function()
        local read = paths.loadWidgetModule("telemetry/read.lua")
        local state = paths.loadWidgetModule("telemetry/state.lua")
        local context = paths.loadWidgetModule("render/context.lua")

        local snap = read.snapshot()
        local evaluated = state.evaluate(snap)

        context.draw(RECT, snap, evaluated, THEME)

        t.assertTrue(drawnTextContains("12.5A"))
      end)
    end)

    t.it("shows a placeholder for a genuinely absent sensor instead of a phantom zero", function()
      mock.withInstall({
        sensors = {
          RQly = { value = 95 },
          -- Curr is intentionally not discovered on this model. Before
          -- Step 4, context.lua called getValue("Curr") directly, and
          -- the mock (matching real EdgeTX) returns 0 for an unknown
          -- sensor *name* -- which would have rendered as "0.0A", a
          -- fabricated reading, not "sensor absent".
        },
      }, function()
        local read = paths.loadWidgetModule("telemetry/read.lua")
        local state = paths.loadWidgetModule("telemetry/state.lua")
        local context = paths.loadWidgetModule("render/context.lua")

        local snap = read.snapshot()
        t.assertFalse(snap.available.current)

        local evaluated = state.evaluate(snap)
        context.draw(RECT, snap, evaluated, THEME)

        t.assertFalse(drawnTextContains("0.0A"))
        t.assertTrue(drawnTextContains("--.-A"))
      end)
    end)

    t.it("falls back from RSNR to SNR when only the secondary alias is discovered", function()
      mock.withInstall({
        sensors = {
          RQly = { value = 95 },
          SNR = { value = 12 },
        },
      }, function()
        local read = paths.loadWidgetModule("telemetry/read.lua")
        local state = paths.loadWidgetModule("telemetry/state.lua")
        local context = paths.loadWidgetModule("render/context.lua")

        local snap = read.snapshot()
        t.assertTrue(snap.available.rsnr)
        t.assertEqual(snap.rsnr, 12)

        local evaluated = state.evaluate(snap)
        context.draw(RECT, snap, evaluated, THEME)

        t.assertTrue(drawnTextContains("12dBm"))
      end)
    end)

    t.it("shows satellites as N/A when GPS has no fix, regardless of the Sats reading", function()
      mock.withInstall({
        sensors = {
          RQly = { value = 95 },
          Sats = { value = 11 },
          Capa = { value = 450 }, -- keeps capacity's own "N/A" path out of this assertion
          -- No "GPS" sensor discovered: readGpsValid() must return false.
        },
      }, function()
        local read = paths.loadWidgetModule("telemetry/read.lua")
        local state = paths.loadWidgetModule("telemetry/state.lua")
        local context = paths.loadWidgetModule("render/context.lua")

        local snap = read.snapshot()
        t.assertFalse(snap.gpsValid)

        local evaluated = state.evaluate(snap)
        context.draw(RECT, snap, evaluated, THEME)

        t.assertTrue(drawnTextContains("N/A"))
        t.assertFalse(drawnTextContains("11"))
      end)
    end)

    t.it("renders the radio getFlightMode() fallback name end-to-end (Step 6)", function()
      mock.withInstall({ sensors = { RQly = { value = 95 } }, flightMode = { 2, "HORIZON" } }, function()
        local read = paths.loadWidgetModule("telemetry/read.lua")
        local state = paths.loadWidgetModule("telemetry/state.lua")
        local context = paths.loadWidgetModule("render/context.lua")

        local snap = read.snapshot()
        local evaluated = state.evaluate(snap)
        context.draw(RECT, snap, evaluated, THEME)

        t.assertTrue(drawnTextContains("HORIZON"))
      end)
    end)
  end)
end
