-- Tests for render/topbar.lua. Written alongside the Step 9 allocation
-- cleanup (hoisting the month-name list, TX-voltage source-name list,
-- and icon-root paths out of per-frame functions) to give that refactor
-- a behavioral baseline, since the file had no prior coverage.
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
  local BOUNDS = { x = 0, y = 0, w = 480, h = 36 }

  t.describe("render/topbar.lua", function()
    t.it("formats the clock and date from getDateTime(), using the hoisted month-name table", function()
      mock.withInstall({
        sensors = {},
        dateTime = { hour = 14, min = 5, day = 3, mon = 8 },
      }, function()
        local topbar = paths.loadWidgetModule("render/topbar.lua")
        topbar.draw(BOUNDS, { connected = false }, nil, THEME)

        t.assertTrue(drawnTextContains("14:05"))
        t.assertTrue(drawnTextContains("3 Aug"))
      end)
    end)

    t.it("falls back to placeholders when getDateTime() has no data", function()
      mock.withInstall({ sensors = {}, dateTime = nil }, function()
        local topbar = paths.loadWidgetModule("render/topbar.lua")
        topbar.draw(BOUNDS, { connected = false }, nil, THEME)

        t.assertTrue(drawnTextContains("--:--"))
      end)
    end)

    t.it("displays the model name from model.getInfo()", function()
      mock.withInstall({ sensors = {}, modelName = "MyQuad" }, function()
        local topbar = paths.loadWidgetModule("render/topbar.lua")
        topbar.draw(BOUNDS, { connected = false }, nil, THEME)

        t.assertTrue(drawnTextContains("MyQuad"))
      end)
    end)

    t.it("reads TX battery voltage from the first candidate in the hoisted source-name list", function()
      -- NOTE: readTxVoltage() calls getValue(name) directly with a raw
      -- sensor name, not through read.lua's getFieldInfo-gated
      -- resolution. Real EdgeTX (and this mock) returns 0 for an
      -- unrecognized sensor *name*, which satisfies this loop's
      -- `n >= 0` check -- so it actually stops at the first candidate
      -- ("tx-voltage") rather than truly falling through the list.
      -- Pre-existing behavior, out of scope for this step; this test
      -- only verifies the hoisted table itself still works correctly.
      mock.withInstall({ sensors = { ["tx-voltage"] = { value = 7.6 } } }, function()
        local topbar = paths.loadWidgetModule("render/topbar.lua")
        topbar.draw(BOUNDS, { connected = false }, nil, THEME)

        t.assertTrue(drawnTextContains("7.6V"))
      end)
    end)

    t.it("renders without error across repeated calls and a theme change (icon reload path)", function()
      mock.withInstall({ sensors = {} }, function()
        local topbar = paths.loadWidgetModule("render/topbar.lua")
        topbar.draw(BOUNDS, { connected = true }, nil, THEME)
        topbar.draw(BOUNDS, { connected = true }, nil, THEME)
        topbar.draw(BOUNDS, { connected = false }, nil, { textColor = 0x0000, iconFolder = "light", isLight = true })
        t.assertTrue(true) -- reaching here without a Lua error is the assertion
      end)
    end)
  end)
end
