-- Tests for render/sticks.lua's stick-mode-aware left/right box
-- assignment (Stick Modes feature).
--
-- Root cause this fixes: the renderer used to hardcode Left box =
-- rudder(X)+throttle(Y), Right box = aileron(X)+elevator(Y) -- which is
-- exactly EdgeTX Stick Mode 2's physical layout (verified against EdgeTX
-- firmware's radio/src/input_mapping.cpp mode table and radio/src/
-- keys.cpp's ailRight/eleRight flags) baked in as a constant, so it only
-- matched reality for Mode 2 and put the wrong stick's motion on screen
-- for Modes 1/3/4.
--
-- getValue("ail")/"ele"/"thr"/"rud" already report the mode-corrected
-- logical channel (confirmed against radio/src/mixer.cpp), so these
-- tests don't need to fake raw ADC channels -- only theme.stickMode and
-- the four channel values.
return function(t, mock, paths)
  local BOUNDS = { x = 0, y = 0, w = 480, h = 130 }
  local DISCONNECTED = { connected = false }

  local function themeWithMode(stickMode)
    return { textColor = 0xFFFF, iconFolder = "dark", isLight = false, stickMode = stickMode }
  end

  -- The live marker is a two-layer round indicator drawn via
  -- lcd.drawFilledCircle (Improved Stick Grid, Task 4; was previously two
  -- nested lcd.drawFilledRectangle calls). Filtering on the inner
  -- circle's color (markerInner, a fixed near-black distinct from the
  -- pad background/grid/border/center-reference colors) isolates just
  -- the two marker centers -- and unlike the old drawFilledRectangle
  -- filter, lcd.drawFilledCircle's own (x, y, radius, color) arguments
  -- give the true center directly, not just a monotonic top-left corner.
  local function dotPositions(mockRef, markerInnerColor)
    local dots = {}
    for _, call in ipairs(mockRef.lcdCalls or {}) do
      if call.name == "drawFilledCircle" and call[4] == markerInnerColor then
        dots[#dots + 1] = { x = call[1], y = call[2] }
      end
    end
    -- leftRect always precedes rightRect in x (render/sticks.lua's
    -- centerGroup lays them out left-to-right), and per-box deflection
    -- never approaches the gap between boxes, so sorting by x reliably
    -- labels dots[1]=left box, dots[2]=right box regardless of mode.
    table.sort(dots, function(a, b) return a.x < b.x end)
    return dots
  end

  local function draw(sensors, stickMode)
    local dots
    mock.withInstall({ sensors = sensors }, function()
      local sticks = paths.loadWidgetModule("render/sticks.lua")
      sticks.draw(BOUNDS, DISCONNECTED, {}, themeWithMode(stickMode))
      dots = dotPositions(mock, sticks.stickGridColors.markerInner)
    end)
    return dots
  end

  local CENTERED = { ail = { value = 0 }, ele = { value = 0 }, thr = { value = 0 }, rud = { value = 0 } }
  local AIL_DEFLECTED = { ail = { value = 1024 }, ele = { value = 0 }, thr = { value = 0 }, rud = { value = 0 } }
  local ELE_DEFLECTED = { ail = { value = 0 }, ele = { value = 1024 }, thr = { value = 0 }, rud = { value = 0 } }

  -- All four channels centered: box geometry (and therefore both dots'
  -- positions) does not depend on stickMode, so one baseline works for
  -- every mode below.
  local baseline = draw(CENTERED, 2)
  t.assertEqual(#baseline, 2, "expected exactly two stick indicator dots")

  local MODE_EXPECTATIONS = {
    -- mode -> which box (1=left, 2=right) aileron's X and elevator's Y drive
    [1] = { ailBox = 2, eleBox = 1 }, -- Mode 1: Left=Rud+Ele, Right=Thr+Ail
    [2] = { ailBox = 2, eleBox = 2 }, -- Mode 2: Left=Rud+Thr, Right=Ail+Ele (this widget's original assumption)
    [3] = { ailBox = 1, eleBox = 1 }, -- Mode 3: Left=Ail+Ele, Right=Rud+Thr
    [4] = { ailBox = 1, eleBox = 2 }, -- Mode 4: Left=Ail+Thr, Right=Rud+Ele
  }

  t.describe("render/sticks.lua stick-mode-aware box assignment", function()
    for mode, expect in pairs(MODE_EXPECTATIONS) do
      t.it("Mode " .. mode .. ": aileron deflection moves only the expected box's X", function()
        local dots = draw(AIL_DEFLECTED, mode)
        t.assertEqual(#dots, 2)

        local movedBox, staticBox
        if expect.ailBox == 1 then
          movedBox, staticBox = 1, 2
        else
          movedBox, staticBox = 2, 1
        end

        t.assertTrue(dots[movedBox].x ~= baseline[movedBox].x,
          "Mode " .. mode .. ": expected box " .. movedBox .. " to move horizontally on aileron deflection")
        t.assertEqual(dots[staticBox].x, baseline[staticBox].x,
          "Mode " .. mode .. ": box " .. staticBox .. " must not move on aileron deflection")
      end)

      t.it("Mode " .. mode .. ": elevator deflection moves only the expected box's Y", function()
        local dots = draw(ELE_DEFLECTED, mode)
        t.assertEqual(#dots, 2)

        local movedBox, staticBox
        if expect.eleBox == 1 then
          movedBox, staticBox = 1, 2
        else
          movedBox, staticBox = 2, 1
        end

        t.assertTrue(dots[movedBox].y ~= baseline[movedBox].y,
          "Mode " .. mode .. ": expected box " .. movedBox .. " to move vertically on elevator deflection")
        t.assertEqual(dots[staticBox].y, baseline[staticBox].y,
          "Mode " .. mode .. ": box " .. staticBox .. " must not move on elevator deflection")
      end)
    end

    t.it("falls back to Mode 2 (this widget's original behavior) when theme.stickMode is missing", function()
      local dots
      mock.withInstall({ sensors = AIL_DEFLECTED }, function()
        local sticks = paths.loadWidgetModule("render/sticks.lua")
        sticks.draw(BOUNDS, DISCONNECTED, {}, { textColor = 0xFFFF, iconFolder = "dark", isLight = false }) -- no stickMode field
        dots = dotPositions(mock, sticks.stickGridColors.markerInner)
      end)
      -- Mode 2: aileron drives the right box (index 2).
      t.assertTrue(dots[2].x ~= baseline[2].x, "expected the right box to move on aileron deflection")
      t.assertEqual(dots[1].x, baseline[1].x, "expected the left box to stay put on aileron deflection")
    end)

    t.it("falls back to Mode 2 when theme.stickMode is out of range", function()
      local dots
      mock.withInstall({ sensors = AIL_DEFLECTED }, function()
        local sticks = paths.loadWidgetModule("render/sticks.lua")
        sticks.draw(BOUNDS, DISCONNECTED, {}, themeWithMode(99))
        dots = dotPositions(mock, sticks.stickGridColors.markerInner)
      end)
      t.assertTrue(dots[2].x ~= baseline[2].x, "expected the right box to move on aileron deflection")
      t.assertEqual(dots[1].x, baseline[1].x, "expected the left box to stay put on aileron deflection")
    end)

    t.it("stick pads keep rendering when receiver telemetry is disconnected (radio-side input, not aircraft telemetry)", function()
      -- DISCONNECTED is used for every draw() in this file already;
      -- this test makes that requirement explicit and asserts it
      -- directly, rather than only relying on it implicitly holding
      -- throughout every other assertion above.
      local dots = draw(AIL_DEFLECTED, 2)
      t.assertEqual(#dots, 2, "both pads still render their marker while telemetry is disconnected")
    end)
  end)

  -- Multi-resolution renderer coverage (Improved Stick Grid, Task 6).
  -- Feeds each supported screen fixture through the real
  -- layout/layout.lua computation (not a hand-picked bounds table) so
  -- the stickMonitor rect tested here is exactly what main.lua would
  -- hand render/sticks.lua on that display class, then asserts the
  -- resulting pad size and marker tier -- proving there is no
  -- LCD_W/resolution-name branch anywhere in the path (FR-8, and the
  -- project's "no renderer branches directly on LCD_W" acceptance
  -- criterion).
  t.describe("render/sticks.lua multi-resolution pad size and marker tier", function()
    local RESOLUTIONS = {
      { name = "480x272 (RadioMaster TX16S class)", fixture = "screen_480x272", expectedBoxSize = 74, expectedTier = "small" },
      { name = "480x320 (RadioMaster TX15 class)", fixture = "screen_480x320", expectedBoxSize = 77, expectedTier = "small" },
      { name = "800x480 (RadioMaster TX16S Mark III class)", fixture = "screen_800x480", expectedBoxSize = 140, expectedTier = "large" },
    }

    local CONNECTED_SENSORS = {
      RQly = { value = 90 },
      VFAS = { value = 15.2 },
      ail = { value = 0 }, ele = { value = 0 }, thr = { value = 0 }, rud = { value = 0 },
    }
    local CONNECTED = { connected = true, available = { linkQuality = true, battery = true },
      linkQuality = 90, batteryCellVoltage = 3.80, batteryCells = 4, txPower = 100 }

    for _, res in ipairs(RESOLUTIONS) do
      t.it(res.name .. ": pad size and marker tier match the documented responsive table", function()
        local zone = paths.loadFixture(res.fixture)
        local layout = paths.loadWidgetModule("layout/layout.lua")
        local regions = layout.compute(zone)
        t.assertNotNil(regions.stickMonitor)

        local bgFills, markerOuters, colors
        local bitmapCount
        mock.withInstall({ sensors = CONNECTED_SENSORS }, function()
          local sticks = paths.loadWidgetModule("render/sticks.lua")
          sticks.draw(regions.stickMonitor, CONNECTED, {}, themeWithMode(2))
          colors = sticks.stickGridColors

          bgFills, markerOuters, bitmapCount = {}, {}, 0
          for _, call in ipairs(mock.lcdCalls) do
            if call.name == "drawFilledRectangle" and call[5] == colors.bg then
              bgFills[#bgFills + 1] = { w = call[3], h = call[4] }
            elseif call.name == "drawFilledCircle" and call[4] == colors.markerOuter then
              markerOuters[#markerOuters + 1] = { radius = call[3] }
            elseif call.name == "drawBitmap" then
              bitmapCount = bitmapCount + 1
            end
          end
        end)

        t.assertEqual(#bgFills, 2, res.name .. ": both pads render at this resolution")
        t.assertEqual(bgFills[1].w, res.expectedBoxSize, res.name .. ": pad width matches the documented responsive table")
        t.assertEqual(bgFills[1].h, res.expectedBoxSize, res.name .. ": pad height matches the documented responsive table")
        t.assertEqual(bgFills[2].w, res.expectedBoxSize)
        t.assertEqual(bgFills[2].h, res.expectedBoxSize)

        local expectedOuterRadius = (res.expectedTier == "large") and 6 or 4 -- floor(13/2)=6, floor(9/2)=4
        t.assertEqual(#markerOuters, 2)
        t.assertEqual(markerOuters[1].radius, expectedOuterRadius, res.name .. ": marker tier matches boxSize, not a resolution name")
        t.assertEqual(markerOuters[2].radius, expectedOuterRadius)

        -- LQ and RX battery icons still render at every resolution
        -- (recheck: their placement/visibility rules are unaffected by
        -- the calibrated pad rendering added alongside them).
        t.assertTrue(bitmapCount >= 2, res.name .. ": LQ and RX battery icons still draw when telemetry is connected")
      end)
    end
  end)
end
