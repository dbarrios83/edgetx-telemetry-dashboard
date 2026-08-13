-- Geometry, draw-order, and containment tests for the calibrated stick
-- pads (Improved Stick Grid, Task 5). Pure math coverage exercises
-- render/sticks.lua's exposed geometry helpers directly (Task 1); the
-- render-level coverage below exercises M.draw() through the mock and
-- inspects mock.lcdCalls -- no screenshot pixel matching, per this
-- task's own acceptance criteria.
--
-- The pad background, calibrated grid, and border are all drawn as
-- lcd.drawFilledRectangle calls with colors produced via lcd.RGB()
-- (code-review finding, 2026-08-13, see
-- docs/platform/compatibility-matrix.md Section 12: EdgeTX packs the
-- 16-bit RGB565 color into the UPPER half of a 32-bit flags value, so a
-- raw RGB565 hex literal passed directly is a malformed color, not
-- merely off-color -- this, not primitive choice or call count, was the
-- actual cause of every invisible-grid/border screenshot during this
-- project's hardware testing). Because colors now depend on lcd.RGB(),
-- every test below that needs real color values loads its own
-- render/sticks.lua module *inside* mock.withInstall(), where lcd.RGB
-- exists -- the module-level `sticks` loaded once below (outside any
-- mock install) is only used for the pure-math helpers
-- (stickGridCoords/markerSizeForPad), which don't touch lcd at all.
return function(t, mock, paths)
  local sticks = paths.loadWidgetModule("render/sticks.lua")

  t.describe("render/sticks.lua stickGridCoords (pure geometry)", function()
    t.it("derives 25/75 percentage-rounded and an exact-floor 50% coordinate, for an even pad size", function()
      local rect = { x = 10, y = 20, w = 74, h = 74 } -- ~480x272 class pad
      local g = sticks.stickGridCoords(rect)

      t.assertEqual(g.x50, 10 + 37, "50% of an even width lands exactly on the midpoint")
      t.assertEqual(g.y50, 20 + 37)
      t.assertTrue(g.x25 > rect.x and g.x25 < g.x50, "x25 sits strictly between the left edge and center")
      t.assertTrue(g.x75 > g.x50 and g.x75 < rect.x + rect.w, "x75 sits strictly between center and the right edge")
      t.assertTrue(g.y25 > rect.y and g.y25 < g.y50)
      t.assertTrue(g.y75 > g.y50 and g.y75 < rect.y + rect.h)
    end)

    t.it("aligns x50/y50 exactly with math.floor(length/2) -- the same center marker/center-reference use -- on an odd pad size", function()
      -- Code-review finding (2026-08-13): x50/y50 used to come from the
      -- same percentage-rounding helper as x25/x75, which disagrees with
      -- math.floor(length/2) by 1px whenever the pad dimension is odd
      -- (e.g. 77px, the 480x320 class) -- the cyan center axis would sit
      -- 1px off from where a centered marker/center-reference actually
      -- draws. x50/y50 now use math.floor(length/2) directly so they can
      -- never drift from that other center-based geometry.
      local rect = { x = 3, y = 5, w = 77, h = 77 } -- ~480x320 class pad, odd
      local g = sticks.stickGridCoords(rect)

      t.assertEqual(g.x50, rect.x + math.floor(rect.w / 2), "x50 matches the marker/center-reference center exactly")
      t.assertEqual(g.y50, rect.y + math.floor(rect.h / 2), "y50 matches the marker/center-reference center exactly")
    end)

    t.it("derives deterministic 25/50/75 coordinates for an odd pad size", function()
      local rect = { x = 3, y = 5, w = 77, h = 77 } -- ~480x320 class pad
      local a = sticks.stickGridCoords(rect)
      local b = sticks.stickGridCoords(rect)

      t.assertEqual(a.x25, b.x25, "repeated calls agree (deterministic rounding)")
      t.assertEqual(a.x50, b.x50)
      t.assertEqual(a.x75, b.x75)
      t.assertEqual(a.y25, b.y25)
      t.assertEqual(a.y50, b.y50)
      t.assertEqual(a.y75, b.y75)

      t.assertTrue(a.x25 < a.x50 and a.x50 < a.x75, "x quarter/center/quarter stay in order")
      t.assertTrue(a.y25 < a.y50 and a.y50 < a.y75, "y quarter/center/quarter stay in order")
      t.assertTrue(a.x75 <= rect.x + rect.w - 1, "x75 stays inside the pad")
      t.assertTrue(a.y75 <= rect.y + rect.h - 1, "y75 stays inside the pad")
    end)

    t.it("produces geometrically identical relative offsets for two pads sharing a size but not an origin", function()
      -- Mirrors the real left/right pad relationship: same boxSize,
      -- different x. Both must compute the same offsets from their own
      -- origin, i.e. a symmetric grid.
      local left = sticks.stickGridCoords({ x = 0, y = 0, w = 74, h = 74 })
      local right = sticks.stickGridCoords({ x = 200, y = 0, w = 74, h = 74 })

      t.assertEqual(right.x25 - 200, left.x25 - 0)
      t.assertEqual(right.x50 - 200, left.x50 - 0)
      t.assertEqual(right.x75 - 200, left.x75 - 0)
      t.assertEqual(right.y25, left.y25, "y is unaffected by the x-only origin shift")
    end)
  end)

  t.describe("render/sticks.lua markerSizeForPad", function()
    t.it("selects the small marker tier below the breakpoint, at both an even and odd pad size", function()
      local i74, o74 = sticks.markerSizeForPad(74)
      local i77, o77 = sticks.markerSizeForPad(77)
      local i119, o119 = sticks.markerSizeForPad(119)
      t.assertEqual(i74, 7); t.assertEqual(o74, 9)
      t.assertEqual(i77, 7); t.assertEqual(o77, 9)
      t.assertEqual(i119, 7); t.assertEqual(o119, 9)
    end)

    t.it("selects the large marker tier at and above the breakpoint", function()
      local i120, o120 = sticks.markerSizeForPad(120)
      local i140, o140 = sticks.markerSizeForPad(140)
      t.assertEqual(i120, 11); t.assertEqual(o120, 13)
      t.assertEqual(i140, 11); t.assertEqual(o140, 13)
    end)

    t.it("depends only on the pad size argument, never on LCD_W or a named resolution", function()
      -- markerSizeForPad takes a single boxSize number -- there is no
      -- LCD_W/resolution parameter it could branch on even if it wanted
      -- to. This test documents that contract so a future signature
      -- change would have to deliberately break it.
      local ok = pcall(function() return sticks.markerSizeForPad(74) end)
      t.assertTrue(ok)
    end)
  end)

  t.describe("render/sticks.lua STICK_GRID_COLORS come from lcd.RGB(), not raw hex literals", function()
    -- Code-review finding (2026-08-13): the mock's lcd.RGB() packs its
    -- result as rgb565 * 65536 (RGB565 in the upper 16 bits of a 32-bit
    -- value, matching real EdgeTX -- see mock_edgetx.lua's own comment).
    -- Any color that is a multiple of 65536 came from lcd.RGB(); a raw
    -- RGB565 hex literal like 0x0845 (2117) never would be (2117 %
    -- 65536 ~= 0). This guards against ever reintroducing the bug this
    -- project's hardware testing found.
    local function colorsFrom(fn)
      local colors
      mock.withInstall({}, function()
        local widget = paths.loadWidgetModule("render/sticks.lua")
        colors = fn(widget)
      end)
      return colors
    end

    t.it("bg/quarterGrid/centerAxis/centerRef/markerInner are all lcd.RGB()-packed values", function()
      local colors = colorsFrom(function(widget) return widget.stickGridColors end)
      for _, key in ipairs({ "bg", "quarterGrid", "centerAxis", "centerRef", "markerInner" }) do
        local c = colors[key]
        t.assertEqual(type(c), "number", key .. " is a number")
        t.assertEqual(c % 65536, 0, key .. " is packed via lcd.RGB(), not a raw RGB565 hex literal")
      end
    end)

    -- Coverage gap flagged in code review (2026-08-13): the
    -- gray/darkgray/lightgray fallback branches inside
    -- resolveStickBorderColor() were fixed alongside STICK_GRID_COLORS
    -- (same malformed-raw-hex defect) but weren't directly exercised by
    -- any test -- resolveStickBorderColor() is only ever called with no
    -- arguments in production (STICK_BORDER_COLOR defaults to "white"),
    -- so these branches were unreachable from the outside. The optional
    -- `override` parameter exists solely to make them reachable here.
    -- tests/mock_edgetx.lua doesn't define GREY/GRAY/DARKGREY/DARKGRAY/
    -- LIGHTGREY/LIGHTGRAY, so calling with these overrides always
    -- exercises the rgbColor() fallback path, not the "if a real EdgeTX
    -- build defines the constant" branch above it.
    t.it("gray/darkgray/lightgray border-color fallbacks are lcd.RGB()-packed values, and distinct from each other", function()
      local values = colorsFrom(function(widget)
        return {
          gray = widget.resolveStickBorderColor("gray"),
          grey = widget.resolveStickBorderColor("grey"),
          darkgray = widget.resolveStickBorderColor("darkgray"),
          lightgray = widget.resolveStickBorderColor("lightgray"),
        }
      end)

      for key, c in pairs(values) do
        t.assertEqual(type(c), "number", key .. " is a number")
        t.assertEqual(c % 65536, 0, key .. " is packed via lcd.RGB(), not a raw RGB565 hex literal")
      end
      t.assertEqual(values.gray, values.grey, "\"gray\" and \"grey\" spellings resolve identically")
      t.assertNotEqual(values.darkgray, values.gray, "darkgray is a distinct shade from gray")
      t.assertNotEqual(values.lightgray, values.gray, "lightgray is a distinct shade from gray")
      t.assertNotEqual(values.darkgray, values.lightgray, "darkgray and lightgray are distinct from each other")
    end)
  end)

  local BOUNDS = { x = 0, y = 0, w = 480, h = 130 } -- 480x272-class sticks panel
  local THEME = { textColor = 0xFFFF, iconFolder = "dark", isLight = false }
  local DISCONNECTED = { connected = false }
  local BORDER_COLOR = 0xFFFF -- STICK_BORDER_COLOR = "white" (render/sticks.lua's debug-override default); an EdgeTX-provided constant, already correctly formatted

  local function drawAndCapture(bounds, theme, telemetry)
    local calls, colors
    mock.withInstall({ sensors = {} }, function()
      local widget = paths.loadWidgetModule("render/sticks.lua")
      widget.draw(bounds, telemetry or DISCONNECTED, {}, theme or THEME)
      calls = mock.lcdCalls
      colors = widget.stickGridColors
    end)
    return calls, colors
  end

  -- lcd.drawFilledRectangle(x, y, w, h, color) -- color is the 5th
  -- positional arg, i.e. call[5].
  local function filterRect(calls, color)
    local out = {}
    for i, call in ipairs(calls) do
      if call.name == "drawFilledRectangle" and (color == nil or call[5] == color) then
        out[#out + 1] = { index = i, x = call[1], y = call[2], w = call[3], h = call[4] }
      end
    end
    return out
  end

  -- lcd.drawFilledCircle(x, y, radius, color) -- color is call[4].
  local function filterCircle(calls, color)
    local out = {}
    for i, call in ipairs(calls) do
      if call.name == "drawFilledCircle" and (color == nil or call[4] == color) then
        out[#out + 1] = { index = i, x = call[1], y = call[2], r = call[3] }
      end
    end
    return out
  end

  local function within(list, lo, hi)
    local out = {}
    for _, c in ipairs(list) do
      if c.index >= lo and c.index < hi then out[#out + 1] = c end
    end
    return out
  end

  local function minIndex(list)
    local m = math.huge
    for _, c in ipairs(list) do if c.index < m then m = c.index end end
    return m
  end

  local function maxIndex(list)
    local m = -math.huge
    for _, c in ipairs(list) do if c.index > m then m = c.index end end
    return m
  end

  t.describe("render/sticks.lua drawStickPadBackground / drawStickGrid (direct)", function()
    local RECT = { x = 10, y = 20, w = 74, h = 74 }

    local function captureDirect(fn)
      local calls, colors, weight
      mock.withInstall({}, function()
        local widget = paths.loadWidgetModule("render/sticks.lua")
        fn(widget)
        calls = mock.lcdCalls
        colors = widget.stickGridColors
        weight = widget.stickGridLineWeight
      end)
      return calls, colors, weight
    end

    t.it("drawStickPadBackground fills exactly the given rect with the bg color", function()
      local calls, colors = captureDirect(function(widget) widget.drawStickPadBackground(RECT) end)
      local fills = filterRect(calls, colors.bg)
      t.assertEqual(#fills, 1)
      t.assertEqual(fills[1].x, RECT.x)
      t.assertEqual(fills[1].y, RECT.y)
      t.assertEqual(fills[1].w, RECT.w)
      t.assertEqual(fills[1].h, RECT.h)
    end)

    t.it("drawStickGrid draws 4 quarter-grid lines then 2 center-axis lines, all at the documented 1px weight, inside the pad", function()
      local calls, colors, weight = captureDirect(function(widget) widget.drawStickGrid(RECT) end)
      t.assertEqual(weight, 1)

      local quarterLines = filterRect(calls, colors.quarterGrid)
      local axisLines = filterRect(calls, colors.centerAxis)
      t.assertEqual(#quarterLines, 4, "four quarter-grid lines (25%/75% on both axes)")
      t.assertEqual(#axisLines, 2, "two center-axis lines (50% on both axes)")
      t.assertTrue(maxIndex(quarterLines) < minIndex(axisLines), "quarter grid precedes center axes")

      local g = sticks.stickGridCoords(RECT)
      local verticalXs = {}
      for _, c in ipairs(quarterLines) do
        if c.h == RECT.h then verticalXs[c.x] = true end
      end
      for _, c in ipairs(axisLines) do
        if c.h == RECT.h then verticalXs[c.x] = true end
      end
      t.assertTrue(verticalXs[g.x25], "x25 vertical line is present")
      t.assertTrue(verticalXs[g.x50], "x50 vertical line is present")
      t.assertTrue(verticalXs[g.x75], "x75 vertical line is present")

      for _, c in ipairs(quarterLines) do
        t.assertTrue(c.w == weight or c.h == weight, "quarter line is exactly stickGridLineWeight thick")
        t.assertTrue(c.x >= RECT.x and c.x + c.w <= RECT.x + RECT.w, "line stays within pad x bounds")
        t.assertTrue(c.y >= RECT.y and c.y + c.h <= RECT.y + RECT.h, "line stays within pad y bounds")
      end
      for _, c in ipairs(axisLines) do
        t.assertTrue(c.w == weight or c.h == weight, "center axis line is exactly stickGridLineWeight thick")
      end
    end)
  end)

  t.describe("render/sticks.lua calibrated pad rendering: draw order and geometry", function()
    t.it("draws each pad in the confirmed order: fill, quarter grid, center axes, border, center reference, marker", function()
      local calls, colors = drawAndCapture(BOUNDS)

      local bgFills = filterRect(calls, colors.bg)
      t.assertEqual(#bgFills, 2, "expected one background fill per pad")

      -- Slice the call stream into "left pad" (from its own bg fill up
      -- to, but not including, the right pad's bg fill) so ordering is
      -- checked per pad, not just globally.
      local leftStart, rightStart = bgFills[1].index, bgFills[2].index
      t.assertTrue(leftStart < rightStart, "left pad is drawn before the right pad")

      local quarterLines = within(filterRect(calls, colors.quarterGrid), leftStart, rightStart)
      local axisLines = within(filterRect(calls, colors.centerAxis), leftStart, rightStart)
      local borderRects = within(filterRect(calls, BORDER_COLOR), leftStart, rightStart)
      local centerRef = within(filterCircle(calls, colors.centerRef), leftStart, rightStart)
      local markerOuter = within(filterCircle(calls, colors.markerOuter), leftStart, rightStart)
      local markerInner = within(filterCircle(calls, colors.markerInner), leftStart, rightStart)

      t.assertEqual(#quarterLines, 4, "four quarter-grid lines per pad (25%/75% on both axes)")
      t.assertEqual(#axisLines, 2, "two center-axis lines per pad (50% on both axes)")
      t.assertEqual(#borderRects, 4, "border is drawn as four filled rectangles (top/bottom/left/right) per pad")
      t.assertEqual(#centerRef, 1, "exactly one round center reference per pad")
      t.assertEqual(#markerOuter, 1, "exactly one marker outer circle per pad")
      t.assertEqual(#markerInner, 1, "exactly one marker inner circle per pad")

      t.assertTrue(leftStart < minIndex(quarterLines), "fill precedes quarter grid")
      t.assertTrue(maxIndex(quarterLines) < minIndex(axisLines), "quarter grid precedes center axes")
      t.assertTrue(maxIndex(axisLines) < minIndex(borderRects), "center axes precede the border")
      t.assertTrue(maxIndex(borderRects) < centerRef[1].index, "border precedes the center reference")
      t.assertTrue(centerRef[1].index < markerOuter[1].index, "center reference precedes the marker")
      t.assertTrue(markerOuter[1].index < markerInner[1].index, "marker outer circle precedes the inner circle")
    end)

    t.it("centers the round center reference exactly on each pad's center", function()
      local calls, colors = drawAndCapture(BOUNDS)
      local bgFills = filterRect(calls, colors.bg)
      local centerRefs = filterCircle(calls, colors.centerRef)
      t.assertEqual(#centerRefs, 2)

      for i, bg in ipairs(bgFills) do
        local expectedCx = bg.x + math.floor(bg.w / 2)
        local expectedCy = bg.y + math.floor(bg.h / 2)
        t.assertEqual(centerRefs[i].x, expectedCx, "center reference x is exactly the pad center")
        t.assertEqual(centerRefs[i].y, expectedCy, "center reference y is exactly the pad center")
      end
    end)

    t.it("aligns the center axes exactly with the center reference and a centered marker (no 1px drift on odd pad sizes)", function()
      -- Regression test for the code-review finding above: exercised at
      -- the render level (480-wide BOUNDS -> even 74px pads) and via the
      -- direct stickGridCoords equivalence test above (odd 77px case).
      local calls, colors = drawAndCapture(BOUNDS)
      local bgFills = filterRect(calls, colors.bg)
      local axisLines = filterRect(calls, colors.centerAxis)
      local centerRefs = filterCircle(calls, colors.centerRef)

      for i, bg in ipairs(bgFills) do
        local expectedCx = bg.x + math.floor(bg.w / 2)
        local expectedCy = bg.y + math.floor(bg.h / 2)
        t.assertEqual(centerRefs[i].x, expectedCx)
        t.assertEqual(centerRefs[i].y, expectedCy)

        local sawVerticalAtCx, sawHorizontalAtCy = false, false
        for _, c in ipairs(axisLines) do
          if c.x == expectedCx and c.h == bg.h then sawVerticalAtCx = true end
          if c.y == expectedCy and c.w == bg.w then sawHorizontalAtCy = true end
        end
        t.assertTrue(sawVerticalAtCx, "vertical center axis lands exactly on the center reference's x")
        t.assertTrue(sawHorizontalAtCy, "horizontal center axis lands exactly on the center reference's y")
      end
    end)

    t.it("keeps both pads symmetric in size and confined to the sticks cell, not crossing into LQ/RX battery", function()
      local primitives = paths.loadWidgetModule("render/primitives.lua")
      local cells = primitives.gridCells(BOUNDS.x, BOUNDS.y, BOUNDS.w, BOUNDS.h, { 30, 40, 30 })
      local sticksArea = cells[2]

      local calls, colors = drawAndCapture(BOUNDS)
      local bgFills = filterRect(calls, colors.bg)
      local left, right = bgFills[1], bgFills[2]

      t.assertEqual(left.w, right.w, "both pads share the same width")
      t.assertEqual(left.h, right.h, "both pads share the same height")
      t.assertTrue(left.x + left.w <= right.x, "pads do not overlap")
      t.assertTrue(left.x >= sticksArea.x, "left pad stays inside the sticks cell (not the LQ cell)")
      t.assertTrue(right.x + right.w <= sticksArea.x + sticksArea.w, "right pad stays inside the sticks cell (not the RX battery cell)")
    end)
  end)

  t.describe("render/sticks.lua marker containment at input extremes", function()
    local CORNERS = {
      { rud = 1024, thr = 1024, ail = 1024, ele = 1024 },
      { rud = 1024, thr = -1024, ail = 1024, ele = -1024 },
      { rud = -1024, thr = 1024, ail = -1024, ele = 1024 },
      { rud = -1024, thr = -1024, ail = -1024, ele = -1024 },
    }

    for i, values in ipairs(CORNERS) do
      t.it("corner " .. i .. ": both markers' outer circles remain fully inside their pad", function()
        local calls, colors
        mock.withInstall({
          sensors = {
            rud = { value = values.rud }, thr = { value = values.thr },
            ail = { value = values.ail }, ele = { value = values.ele },
          },
        }, function()
          local widget = paths.loadWidgetModule("render/sticks.lua")
          widget.draw(BOUNDS, DISCONNECTED, {}, THEME)
          calls = mock.lcdCalls
          colors = widget.stickGridColors
        end)

        local bgFills = filterRect(calls, colors.bg)
        local markerOuters = filterCircle(calls, colors.markerOuter)
        t.assertEqual(#bgFills, 2)
        t.assertEqual(#markerOuters, 2)

        for p = 1, 2 do
          local rect = bgFills[p]
          local marker = markerOuters[p]
          local cx, cy, r = marker.x, marker.y, marker.r
          t.assertTrue(cx - r >= rect.x, "marker does not overflow the pad's left edge")
          t.assertTrue(cx + r <= rect.x + rect.w - 1, "marker does not overflow the pad's right edge")
          t.assertTrue(cy - r >= rect.y, "marker does not overflow the pad's top edge")
          t.assertTrue(cy + r <= rect.y + rect.h - 1, "marker does not overflow the pad's bottom edge")
        end
      end)
    end
  end)

  t.describe("render/sticks.lua small fallback bounds", function()
    t.it("shows the 'Sticks' label instead of pads when boxSize falls below 16px, drawing no pad background", function()
      local SMALL_BOUNDS = { x = 0, y = 0, w = 120, h = 40 }
      local calls, colors = drawAndCapture(SMALL_BOUNDS)

      local sawSticksLabel = false
      for _, call in ipairs(calls) do
        if call.name == "drawText" then
          for _, arg in ipairs(call) do
            if arg == "Sticks" then sawSticksLabel = true end
          end
        end
      end

      t.assertEqual(#filterRect(calls, colors.bg), 0, "no calibrated pad background is drawn in the fallback state")
      t.assertTrue(sawSticksLabel, "the 'Sticks' label is shown instead")
    end)
  end)
end
