-- Renderer-level layout regression coverage for render/sticks.lua and
-- render/topbar.lua's grid refactor (Grid-aligned top bar and sticks,
-- Task 4). Task 1's tests/spec/primitives_geometry_spec.lua covers the
-- gridCells/centerGroup math in isolation; this file exercises the actual
-- renderers end-to-end so future visual tuning cannot silently reintroduce
-- arbitrary per-element placement without a test noticing.
return function(t, mock, paths)
  local primitives = paths.loadWidgetModule("render/primitives.lua")

  -- Icon pixel sizes mirror the private constants of the same name inside
  -- render/sticks.lua and render/topbar.lua. Kept here (not exported) so a
  -- deliberate icon-size change is a one-line update to both files, and an
  -- accidental one is caught as a containment failure below.
  local LQ_ICON_W, LQ_ICON_H = 30, 30
  local RX_BATTERY_ICON_W, RX_BATTERY_ICON_H = 20, 32
  local LINK_ICON_W, LINK_ICON_H = 24, 24
  local TX_BATTERY_ICON_W, TX_BATTERY_ICON_H = 30, 32
  local DATE_TIME_TEXT_CHAR_W = 7
  local DATE_TIME_SEPARATOR = "   "

  local THEME = { textColor = 0xFFFF, iconFolder = "dark", isLight = false }

  local function drawBitmapCalls(mockRef)
    local calls = {}
    for _, call in ipairs(mockRef.lcdCalls or {}) do
      if call.name == "drawBitmap" then
        calls[#calls + 1] = { bitmap = call[1], x = call[2], y = call[3] }
      end
    end
    return calls
  end

  local function drawTextCalls(mockRef)
    local calls = {}
    for _, call in ipairs(mockRef.lcdCalls or {}) do
      if call.name == "drawText" then
        calls[#calls + 1] = { x = call[1], y = call[2], text = call[3] }
      end
    end
    return calls
  end

  -- The stick pads (background fill, calibrated grid, and border) are
  -- all drawn as lcd.drawFilledRectangle calls, not lcd.drawLine (see
  -- docs/platform/compatibility-matrix.md Section 12 -- lcd.drawLine
  -- stopped rendering on real hardware once it followed a
  -- drawFilledRectangle call in the same widget refresh).
  local function drawFilledRectangleCalls(mockRef)
    local calls = {}
    for _, call in ipairs(mockRef.lcdCalls or {}) do
      if call.name == "drawFilledRectangle" then
        calls[#calls + 1] = { x = call[1], y = call[2], w = call[3], h = call[4] }
      end
    end
    return calls
  end

  local function bitmapCallContaining(calls, needle)
    for _, call in ipairs(calls) do
      if type(call.bitmap) == "table" and type(call.bitmap.__mockBitmap) == "string"
        and call.bitmap.__mockBitmap:find(needle, 1, true) then
        return call
      end
    end
    return nil
  end

  local function textCallContaining(calls, needle)
    for _, call in ipairs(calls) do
      if type(call.text) == "string" and call.text:find(needle, 1, true) then
        return call
      end
    end
    return nil
  end

  local function withinCellX(x, w, cell)
    return x >= cell.x and (x + w) <= (cell.x + cell.w)
  end

  local function withinCellY(y, h, cell)
    return y >= cell.y and (y + h) <= (cell.y + cell.h)
  end

  local function forceIconsMissing()
    Bitmap.open = function() return nil end
  end

  -- ---------------------------------------------------------------------
  -- render/sticks.lua: LQ (30%) / Sticks (40%) / Receiver Battery (30%)
  -- ---------------------------------------------------------------------

  local TELEMETRY_CONNECTED = {
    connected = true,
    available = { linkQuality = true, battery = true },
    linkQuality = 92,
    txPower = 100,
    batteryCellVoltage = 3.85, -- "ok" tier
    batteryCells = 4,
  }

  local TELEMETRY_DISCONNECTED = { connected = false }

  t.describe("render/sticks.lua grid layout", function()
    t.it("renders LQ / Sticks / Receiver Battery in the confirmed 30/40/30 order, each within its own cell", function()
      mock.withInstall({ sensors = {} }, function()
        local BOUNDS = { x = 0, y = 0, w = 480, h = 130 }
        local expected = primitives.gridCells(BOUNDS.x, BOUNDS.y, BOUNDS.w, BOUNDS.h, { 30, 40, 30 })
        t.assertEqual(expected[1].w, 144)
        t.assertEqual(expected[2].w, 192)
        t.assertEqual(expected[3].w, 144)

        local sticks = paths.loadWidgetModule("render/sticks.lua")
        sticks.draw(BOUNDS, TELEMETRY_CONNECTED, {}, THEME)

        local bitmaps = drawBitmapCalls(mock)
        local lqIcon = bitmapCallContaining(bitmaps, "connection-ok.png")
        local rxIcon = bitmapCallContaining(bitmaps, "battery-ok.png")
        t.assertNotNil(lqIcon, "expected the LQ connection icon to be drawn")
        t.assertNotNil(rxIcon, "expected the receiver battery icon to be drawn")

        t.assertTrue(withinCellX(lqIcon.x, LQ_ICON_W, expected[1]), "LQ icon stays within cell 1 (LQ, 30%)")
        t.assertTrue(withinCellY(lqIcon.y, LQ_ICON_H, expected[1]), "LQ icon stays vertically within cell 1")
        t.assertTrue(withinCellX(rxIcon.x, RX_BATTERY_ICON_W, expected[3]),
          "receiver battery icon stays within cell 3 (Receiver Battery, 30%)")
        t.assertTrue(withinCellY(rxIcon.y, RX_BATTERY_ICON_H, expected[3]),
          "receiver battery icon stays vertically within cell 3")

        -- Both stick pads (background fill, grid, and border -- all
        -- drawn as filled rectangles) stay within the middle Sticks cell
        -- (40%), strictly between the two side cells -- confirming cell
        -- order LQ / Sticks / RX Battery.
        local rects = drawFilledRectangleCalls(mock)
        t.assertTrue(#rects > 0, "expected stick pad rectangles to be drawn")
        for _, r in ipairs(rects) do
          t.assertTrue(r.x >= expected[2].x and (r.x + r.w) <= expected[2].x + expected[2].w,
            "stick pad rectangle stays within cell 2 (Sticks, 40%)")
        end
        t.assertTrue(lqIcon.x < expected[2].x, "LQ cell is left of the Sticks cell")
        t.assertTrue(rxIcon.x >= expected[2].x + expected[2].w, "Receiver Battery cell is right of the Sticks cell")
      end)
    end)

    t.it("keeps the 30/40/30 cell order and containment for an odd, non-evenly-divisible width", function()
      mock.withInstall({ sensors = {} }, function()
        local BOUNDS = { x = 0, y = 0, w = 481, h = 131 }
        local expected = primitives.gridCells(BOUNDS.x, BOUNDS.y, BOUNDS.w, BOUNDS.h, { 30, 40, 30 })

        local sticks = paths.loadWidgetModule("render/sticks.lua")
        sticks.draw(BOUNDS, TELEMETRY_CONNECTED, {}, THEME)

        local bitmaps = drawBitmapCalls(mock)
        local lqIcon = bitmapCallContaining(bitmaps, "connection-ok.png")
        local rxIcon = bitmapCallContaining(bitmaps, "battery-ok.png")
        t.assertTrue(withinCellX(lqIcon.x, LQ_ICON_W, expected[1]), "LQ icon still contained after odd-width rounding")
        t.assertTrue(withinCellX(rxIcon.x, RX_BATTERY_ICON_W, expected[3]),
          "receiver battery icon still contained after odd-width rounding")

        -- Cells still tile the full width exactly (Task 1's contract),
        -- verified again here at the renderer's own bounds.
        t.assertEqual(expected[1].x, 0)
        t.assertEqual(expected[3].x + expected[3].w, 481)
      end)
    end)

    t.it("draws no LQ or receiver-battery icon/text while disconnected, leaving the Sticks cell unaffected", function()
      mock.withInstall({ sensors = {} }, function()
        local BOUNDS = { x = 0, y = 0, w = 480, h = 130 }
        local sticks = paths.loadWidgetModule("render/sticks.lua")
        sticks.draw(BOUNDS, TELEMETRY_DISCONNECTED, {}, THEME)

        local bitmaps = drawBitmapCalls(mock)
        t.assertNil(bitmapCallContaining(bitmaps, "connection-"), "no LQ icon while disconnected")
        t.assertNil(bitmapCallContaining(bitmaps, "battery-"), "no receiver battery icon while disconnected")

        -- The stick pads themselves are not gated on connection state.
        t.assertTrue(#drawFilledRectangleCalls(mock) > 0, "stick pads still render while disconnected")
      end)
    end)

    t.it("falls back to centered text (no icon) in both side cells when bitmaps are unavailable", function()
      mock.withInstall({ sensors = {} }, function()
        forceIconsMissing()
        local BOUNDS = { x = 0, y = 0, w = 480, h = 130 }
        local expected = primitives.gridCells(BOUNDS.x, BOUNDS.y, BOUNDS.w, BOUNDS.h, { 30, 40, 30 })

        local sticks = paths.loadWidgetModule("render/sticks.lua")
        sticks.draw(BOUNDS, TELEMETRY_CONNECTED, {}, THEME)

        t.assertEqual(#drawBitmapCalls(mock), 0, "no bitmaps were available to draw")

        local texts = drawTextCalls(mock)
        local lqText = textCallContaining(texts, "92%")
        local rxText = textCallContaining(texts, "V")
        t.assertNotNil(lqText, "LQ value still renders as text")
        t.assertNotNil(rxText, "receiver battery value still renders as text")
        t.assertTrue(withinCellX(lqText.x, 0, expected[1]), "fallback LQ text stays within cell 1")
        t.assertTrue(withinCellX(rxText.x, 0, expected[3]), "fallback battery text stays within cell 3")
      end)
    end)

    t.it("renders without error and keeps all drawing within bounds at a narrow representative width", function()
      mock.withInstall({ sensors = {} }, function()
        local BOUNDS = { x = 10, y = 5, w = 220, h = 90 }
        local sticks = paths.loadWidgetModule("render/sticks.lua")
        sticks.draw(BOUNDS, TELEMETRY_CONNECTED, {}, THEME)

        for _, call in ipairs(drawBitmapCalls(mock)) do
          t.assertTrue(call.x >= BOUNDS.x and call.x <= BOUNDS.x + BOUNDS.w,
            "narrow layout: bitmap x stays within the overall widget bounds")
        end
        for _, call in ipairs(drawTextCalls(mock)) do
          t.assertTrue(call.x >= BOUNDS.x and call.x <= BOUNDS.x + BOUNDS.w,
            "narrow layout: text x stays within the overall widget bounds")
        end
      end)
    end)
  end)

  -- ---------------------------------------------------------------------
  -- render/topbar.lua: Logo (10%) / Model (36%) / TX Battery (20%) /
  -- Connection (16%) / Date-Time (18%)
  -- ---------------------------------------------------------------------

  t.describe("render/topbar.lua grid layout", function()
    t.it("renders Model / TX Battery / Connection / Date-Time in the confirmed order, each within its own cell", function()
      mock.withInstall({
        sensors = { ["tx-voltage"] = { value = 7.6 } },
        modelName = "MyQuad",
        dateTime = { hour = 14, min = 5, day = 3, mon = 8 },
      }, function()
        local BOUNDS = { x = 0, y = 0, w = 480, h = 36 }
        local expected = primitives.gridCells(BOUNDS.x, BOUNDS.y, BOUNDS.w, BOUNDS.h, { 10, 36, 20, 16, 18 })
        t.assertEqual(expected[1].w, 48)
        t.assertEqual(expected[2].w, 173)
        t.assertEqual(expected[3].w, 96)
        t.assertEqual(expected[4].w, 77)
        t.assertEqual(expected[5].w, 86)

        local topbar = paths.loadWidgetModule("render/topbar.lua")
        topbar.draw(BOUNDS, { connected = true }, {}, THEME)

        local texts = drawTextCalls(mock)
        local modelCall = textCallContaining(texts, "MyQuad")
        t.assertNotNil(modelCall, "model name renders as text")
        t.assertTrue(withinCellX(modelCall.x, 0, expected[2]), "model name stays within cell 2 (Model, 36%)")
        t.assertTrue(modelCall.x < expected[2].x + 20, "model name is left-aligned near cell 2's left edge, not centered")

        local bitmaps = drawBitmapCalls(mock)
        local txIcon = bitmapCallContaining(bitmaps, "battery-")
        t.assertNotNil(txIcon, "TX battery icon renders")
        t.assertTrue(withinCellX(txIcon.x, TX_BATTERY_ICON_W, expected[3]),
          "TX battery icon stays within cell 3 (TX Battery, 20%)")
        t.assertTrue(withinCellY(txIcon.y, TX_BATTERY_ICON_H, expected[3]),
          "TX battery icon stays vertically within cell 3")
        t.assertTrue(txIcon.x > expected[3].x + 20, "TX battery icon is right-aligned away from cell 3's left edge, not left-aligned")

        local linkIcon = bitmapCallContaining(bitmaps, "link")
        t.assertNotNil(linkIcon, "connection icon renders")
        t.assertTrue(withinCellX(linkIcon.x, LINK_ICON_W, expected[4]),
          "connection icon stays within cell 4 (Receiver Connection, 16%)")
        t.assertTrue(withinCellY(linkIcon.y, LINK_ICON_H, expected[4]),
          "connection icon stays vertically within cell 4")

        -- Date and time render as one line ("3 Aug" + separator + "14:05"),
        -- right-aligned, with extra spacing between date and time.
        local dateTimeText = "3 Aug" .. DATE_TIME_SEPARATOR .. "14:05"
        local dateTimeCall = textCallContaining(texts, dateTimeText)
        t.assertNotNil(dateTimeCall, "date and time render as a single line, date first, with the wider separator")
        t.assertTrue(withinCellX(dateTimeCall.x, 0, expected[5]), "date/time line stays within cell 5 (Date-Time, 18%)")
        t.assertTrue(dateTimeCall.x + (#dateTimeText * DATE_TIME_TEXT_CHAR_W) > expected[5].x + expected[5].w - 20,
          "date/time line is right-aligned near cell 5's right edge, not centered")

        t.assertTrue(modelCall.x < txIcon.x, "Model cell is left of TX Battery cell")
        t.assertTrue(txIcon.x < linkIcon.x, "TX Battery cell is left of Connection cell")
        t.assertTrue(linkIcon.x < dateTimeCall.x, "Connection cell is left of Date-Time cell")
      end)
    end)

    t.it("never draws into the reserved logo cell (cell 1)", function()
      mock.withInstall({
        sensors = {},
        modelName = "MyQuad",
        dateTime = { hour = 14, min = 5, day = 3, mon = 8 },
      }, function()
        local BOUNDS = { x = 0, y = 0, w = 480, h = 36 }
        local expected = primitives.gridCells(BOUNDS.x, BOUNDS.y, BOUNDS.w, BOUNDS.h, { 10, 36, 20, 16, 18 })
        local logoCell = expected[1]

        local topbar = paths.loadWidgetModule("render/topbar.lua")
        topbar.draw(BOUNDS, { connected = true }, {}, THEME)

        for _, call in ipairs(drawBitmapCalls(mock)) do
          t.assertFalse(call.x >= logoCell.x and call.x < logoCell.x + logoCell.w,
            "no bitmap draws into the reserved logo cell")
        end
        for _, call in ipairs(drawTextCalls(mock)) do
          t.assertFalse(call.x >= logoCell.x and call.x < logoCell.x + logoCell.w,
            "no text draws into the reserved logo cell")
        end
      end)
    end)

    t.it("keeps the five-cell order and containment for an odd, non-evenly-divisible width", function()
      mock.withInstall({
        sensors = { ["tx-voltage"] = { value = 7.6 } },
        modelName = "MyQuad",
        dateTime = { hour = 14, min = 5, day = 3, mon = 8 },
      }, function()
        local BOUNDS = { x = 0, y = 0, w = 471, h = 37 }
        local expected = primitives.gridCells(BOUNDS.x, BOUNDS.y, BOUNDS.w, BOUNDS.h, { 10, 36, 20, 16, 18 })
        t.assertEqual(expected[1].x, 0)
        t.assertEqual(expected[5].x + expected[5].w, 471)

        local topbar = paths.loadWidgetModule("render/topbar.lua")
        topbar.draw(BOUNDS, { connected = true }, {}, THEME)

        local bitmaps = drawBitmapCalls(mock)
        local txIcon = bitmapCallContaining(bitmaps, "battery-")
        t.assertTrue(withinCellX(txIcon.x, TX_BATTERY_ICON_W, expected[3]),
          "TX battery icon still contained after odd-width rounding")
      end)
    end)

    t.it("shows the connected icon when linked and the disconnected icon when not, both within the Connection cell", function()
      mock.withInstall({ sensors = {} }, function()
        local BOUNDS = { x = 0, y = 0, w = 480, h = 36 }
        local expected = primitives.gridCells(BOUNDS.x, BOUNDS.y, BOUNDS.w, BOUNDS.h, { 10, 36, 20, 16, 18 })

        local topbar = paths.loadWidgetModule("render/topbar.lua")
        topbar.draw(BOUNDS, { connected = true }, {}, THEME)
        local connectedIcon = bitmapCallContaining(drawBitmapCalls(mock), "link.png")
        t.assertNotNil(connectedIcon, "connected state draws link.png")
        t.assertTrue(withinCellX(connectedIcon.x, LINK_ICON_W, expected[4]))

        mock.lcdCalls = {}
        topbar.draw(BOUNDS, { connected = false }, {}, THEME)
        local disconnectedIcon = bitmapCallContaining(drawBitmapCalls(mock), "link_off.png")
        t.assertNotNil(disconnectedIcon, "disconnected state draws link_off.png")
        t.assertTrue(withinCellX(disconnectedIcon.x, LINK_ICON_W, expected[4]))
      end)
    end)

    t.it("falls back to a text link indicator and a vector TX battery glyph when bitmaps are unavailable", function()
      mock.withInstall({ sensors = { ["tx-voltage"] = { value = 7.6 } } }, function()
        forceIconsMissing()
        local BOUNDS = { x = 0, y = 0, w = 480, h = 36 }
        local expected = primitives.gridCells(BOUNDS.x, BOUNDS.y, BOUNDS.w, BOUNDS.h, { 10, 36, 20, 16, 18 })

        local topbar = paths.loadWidgetModule("render/topbar.lua")
        topbar.draw(BOUNDS, { connected = true }, {}, THEME)

        t.assertEqual(#drawBitmapCalls(mock), 0, "no bitmaps were available to draw")

        local linkText = textCallContaining(drawTextCalls(mock), "LINK")
        t.assertNotNil(linkText, "connection falls back to text")
        t.assertTrue(withinCellX(linkText.x, 0, expected[4]), "fallback connection text stays within cell 4")

        -- TX battery falls back to a drawn rectangle glyph (drawRectangle),
        -- not a bitmap -- confirm it still lands inside the TX Battery cell.
        local rectCalls = {}
        for _, call in ipairs(mock.lcdCalls or {}) do
          if call.name == "drawRectangle" then
            rectCalls[#rectCalls + 1] = { x = call[1], y = call[2] }
          end
        end
        t.assertTrue(#rectCalls > 0, "TX battery vector glyph fallback drew a rectangle")
        for _, r in ipairs(rectCalls) do
          t.assertTrue(r.x >= expected[3].x and r.x <= expected[3].x + expected[3].w,
            "TX battery glyph fallback stays within cell 3")
        end
      end)
    end)

    t.it("truncates a long model name so it still stays within the Model cell", function()
      mock.withInstall({
        sensors = {},
        modelName = "A Very Long Quadcopter Model Name That Will Not Fit",
      }, function()
        local BOUNDS = { x = 0, y = 0, w = 480, h = 36 }
        local expected = primitives.gridCells(BOUNDS.x, BOUNDS.y, BOUNDS.w, BOUNDS.h, { 10, 36, 20, 16, 18 })

        local topbar = paths.loadWidgetModule("render/topbar.lua")
        topbar.draw(BOUNDS, { connected = true }, {}, THEME)

        local texts = drawTextCalls(mock)
        local modelCall = nil
        for _, call in ipairs(texts) do
          if type(call.text) == "string" and call.text:find("...", 1, true) then
            modelCall = call
          end
        end
        t.assertNotNil(modelCall, "long model name is truncated with an ellipsis")
        t.assertTrue(withinCellX(modelCall.x, 0, expected[2]), "truncated model name stays within cell 2")
      end)
    end)

    t.it("renders without error and keeps all drawing within bounds at a narrow representative width", function()
      mock.withInstall({ sensors = {}, modelName = "Quad" }, function()
        local BOUNDS = { x = 10, y = 2, w = 240, h = 28 }
        local topbar = paths.loadWidgetModule("render/topbar.lua")
        topbar.draw(BOUNDS, { connected = true }, {}, THEME)

        for _, call in ipairs(drawBitmapCalls(mock)) do
          t.assertTrue(call.x >= BOUNDS.x and call.x <= BOUNDS.x + BOUNDS.w,
            "narrow layout: bitmap x stays within the overall widget bounds")
        end
        for _, call in ipairs(drawTextCalls(mock)) do
          t.assertTrue(call.x >= BOUNDS.x and call.x <= BOUNDS.x + BOUNDS.w,
            "narrow layout: text x stays within the overall widget bounds")
        end
      end)
    end)
  end)
end
