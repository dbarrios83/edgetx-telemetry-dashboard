-- Unit tests for layout/layout.lua's pure geometry computation across the
-- two supported display classes.
return function(t, mock, paths)
  t.describe("layout/layout.lua", function()
    local layout = paths.loadWidgetModule("layout/layout.lua")

    -- All five regions, including the footer, are shown on every
    -- supported resolution (Multi-Resolution Layout, Task 2) -- the
    -- footer used to be hidden below a 290px height threshold, which
    -- excluded this class.
    t.it("shows a bottom-anchored footer row on 480x272 (TX16S/T16-class) zones too", function()
      local zone = paths.loadFixture("screen_480x272")
      local result = layout.compute(zone)
      t.assertNotNil(result)
      t.assertNotNil(result.footerRow)
      t.assertEqual(result.footerRow.y + result.footerRow.h, zone.y + zone.h)
    end)

    t.it("shows a bottom-anchored footer row on 480x320 (TX15/T15-class) zones", function()
      local zone = paths.loadFixture("screen_480x320")
      local result = layout.compute(zone)
      t.assertNotNil(result)
      t.assertNotNil(result.footerRow)
      t.assertEqual(result.footerRow.y + result.footerRow.h, zone.y + zone.h)
    end)

    t.it("keeps every region within the zone bounds on both display classes", function()
      local fixtures = { "screen_480x272", "screen_480x320" }
      for _, name in ipairs(fixtures) do
        local zone = paths.loadFixture(name)
        local result = layout.compute(zone)
        local regions = {
          result.topBar, result.stickMonitor, result.primaryGrid,
          result.contextRow, result.footerRow,
        }
        for _, r in ipairs(regions) do
          if r then
            t.assertTrue(r.x >= zone.x, name .. ": region x within bounds")
            t.assertTrue(r.y >= zone.y, name .. ": region y within bounds")
            t.assertTrue(r.x + r.w <= zone.x + zone.w, name .. ": region right edge within bounds")
            t.assertTrue(r.y + r.h <= zone.y + zone.h, name .. ": region bottom edge within bounds")
          end
        end
      end
    end)

    t.it("returns nil for a degenerate zero-size zone", function()
      t.assertNil(layout.compute({ x = 0, y = 0, w = 0, h = 0 }))
    end)

    t.it("returns nil when no zone is given", function()
      t.assertNil(layout.compute(nil))
    end)
  end)
end
