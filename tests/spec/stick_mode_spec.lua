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
  local STICK_DOT_SIZE = 7 -- mirrors render/sticks.lua's own constant

  local function themeWithMode(stickMode)
    return { textColor = 0xFFFF, iconFolder = "dark", isLight = false, stickMode = stickMode }
  end

  -- drawIndicator draws a larger white border square before the colored
  -- dot itself; filtering on STICK_DOT_SIZE isolates just the dot centers
  -- (top-left corners, but that's monotonic with the true center, which
  -- is all a before/after position comparison needs).
  local function dotPositions(mockRef)
    local dots = {}
    for _, call in ipairs(mockRef.lcdCalls or {}) do
      if call.name == "drawFilledRectangle" and call[3] == STICK_DOT_SIZE and call[4] == STICK_DOT_SIZE then
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
      dots = dotPositions(mock)
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
        dots = dotPositions(mock)
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
        dots = dotPositions(mock)
      end)
      t.assertTrue(dots[2].x ~= baseline[2].x, "expected the right box to move on aileron deflection")
      t.assertEqual(dots[1].x, baseline[1].x, "expected the left box to stay put on aileron deflection")
    end)
  end)
end
