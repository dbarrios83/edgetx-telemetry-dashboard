-- Tests for tests/mock_edgetx.lua's circular-primitive recorder
-- (Improved Stick Grid, Task 2), added ahead of the round marker/center
-- reference so later renderer work (Tasks 3-4) has an already-verified
-- way to assert on lcd.drawCircle/lcd.drawFilledCircle calls -- the same
-- {name, x, y, radius, color} recorded-call shape mock_edgetx.lua already
-- uses for drawLine/drawRectangle/drawFilledRectangle (see
-- stick_mode_spec.lua's dotPositions(), which filters
-- drawFilledRectangle calls the same way).
--
-- EdgeTX's real color-LCD signature is (x, y, radius, color) for both
-- primitives -- matching drawFilledRectangle's own (x, y, w, h, color)
-- convention already relied on elsewhere in this repo, not the
-- flags-based monochrome API.
return function(t, mock, paths)
  t.describe("mock_edgetx.lua circular drawing primitives", function()
    t.it("records lcd.drawFilledCircle calls with center, radius, and color, filterable independently", function()
      mock.withInstall({}, function()
        lcd.drawFilledCircle(40, 60, 6, 0xFFFF) -- e.g. marker outer ring
        lcd.drawFilledCircle(40, 60, 4, 0x0841) -- e.g. marker inner fill
        lcd.drawFilledCircle(100, 60, 2, 0x8410) -- e.g. center reference, different center

        local filled = {}
        for _, call in ipairs(mock.lcdCalls) do
          if call.name == "drawFilledCircle" then
            filled[#filled + 1] = call
          end
        end
        t.assertEqual(#filled, 3)

        -- Filter by radius: isolates the outer ring from the inner fill
        -- at the same center, the way a marker-containment test would.
        local byRadius6 = {}
        for _, call in ipairs(filled) do
          if call[3] == 6 then byRadius6[#byRadius6 + 1] = call end
        end
        t.assertEqual(#byRadius6, 1)
        t.assertEqual(byRadius6[1][1], 40)
        t.assertEqual(byRadius6[1][2], 60)
        t.assertEqual(byRadius6[1][4], 0xFFFF)

        -- Filter by center coordinates: isolates the differently
        -- positioned center-reference circle from the marker circles.
        local atCenterX100 = {}
        for _, call in ipairs(filled) do
          if call[1] == 100 then atCenterX100[#atCenterX100 + 1] = call end
        end
        t.assertEqual(#atCenterX100, 1)
        t.assertEqual(atCenterX100[1][3], 2)
        t.assertEqual(atCenterX100[1][4], 0x8410)

        -- Filter by color flag: isolates the near-black inner fill from
        -- the white outer ring, independent of center or radius.
        local byInnerColor = {}
        for _, call in ipairs(filled) do
          if call[4] == 0x0841 then byInnerColor[#byInnerColor + 1] = call end
        end
        t.assertEqual(#byInnerColor, 1)
        t.assertEqual(byInnerColor[1][3], 4)
      end)
    end)

    t.it("records lcd.drawCircle (outline-only) separately from lcd.drawFilledCircle", function()
      mock.withInstall({}, function()
        lcd.drawCircle(10, 10, 5, 0x8410)

        local drawCircleCalls, drawFilledCircleCalls = 0, 0
        for _, call in ipairs(mock.lcdCalls) do
          if call.name == "drawCircle" then drawCircleCalls = drawCircleCalls + 1 end
          if call.name == "drawFilledCircle" then drawFilledCircleCalls = drawFilledCircleCalls + 1 end
        end
        t.assertEqual(drawCircleCalls, 1)
        t.assertEqual(drawFilledCircleCalls, 0)
      end)
    end)

    t.it("uninstall() removes drawCircle/drawFilledCircle like every other mocked lcd function", function()
      mock.install({})
      t.assertEqual(type(lcd.drawCircle), "function")
      t.assertEqual(type(lcd.drawFilledCircle), "function")
      mock.uninstall()
      t.assertNil(lcd)
    end)
  end)
end
