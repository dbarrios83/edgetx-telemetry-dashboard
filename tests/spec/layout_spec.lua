-- Unit tests for layout/layout.lua's pure geometry computation across the
-- three supported display classes (Multi-Resolution Layout plan).
return function(t, mock, paths)
  t.describe("layout/layout.lua", function()
    local layout = paths.loadWidgetModule("layout/layout.lua")

    local ALL_FIXTURES = { "screen_480x272", "screen_480x320", "screen_800x480" }

    -- EdgeTX's own system TopBar (the logo strip this widget's top bar
    -- must match, per the confirmed spec) is unscaled at LCD_W==480 and
    -- scaled to 62 at LCD_W==800 -- see layout.lua's menuHeaderHeight()
    -- for the firmware source citations.
    local EXPECTED_TOPBAR_H = {
      screen_480x272 = 45,
      screen_480x320 = 45,
      screen_800x480 = 62,
    }

    t.it("pins the top-bar height to the exact real EdgeTX logo height for every resolution", function()
      for _, name in ipairs(ALL_FIXTURES) do
        local zone = paths.loadFixture(name)
        local result = layout.compute(zone)
        t.assertNotNil(result, name)
        t.assertEqual(result.topBar.h, EXPECTED_TOPBAR_H[name], name .. ": topBar height")
      end
    end)

    -- All five regions, including the footer, are shown on every
    -- supported resolution (Multi-Resolution Layout, Task 2) -- the
    -- footer used to be hidden below a 290px height threshold, which
    -- excluded the 480x272 class.
    t.it("shows a bottom-anchored footer row on every supported resolution", function()
      for _, name in ipairs(ALL_FIXTURES) do
        local zone = paths.loadFixture(name)
        local result = layout.compute(zone)
        t.assertNotNil(result, name)
        t.assertNotNil(result.footerRow, name .. ": footerRow")
        t.assertEqual(result.footerRow.y + result.footerRow.h, zone.y + zone.h, name .. ": footer bottom-anchored")
      end
    end)

    t.it("keeps every region within the zone bounds on all three display classes", function()
      for _, name in ipairs(ALL_FIXTURES) do
        local zone = paths.loadFixture(name)
        local result = layout.compute(zone)
        local regions = {
          result.topBar, result.stickMonitor, result.primaryGrid,
          result.contextRow, result.footerRow,
        }
        for _, r in ipairs(regions) do
          t.assertNotNil(r, name)
          t.assertTrue(r.x >= zone.x, name .. ": region x within bounds")
          t.assertTrue(r.y >= zone.y, name .. ": region y within bounds")
          t.assertTrue(r.x + r.w <= zone.x + zone.w, name .. ": region right edge within bounds")
          t.assertTrue(r.y + r.h <= zone.y + zone.h, name .. ": region bottom edge within bounds")
        end
      end
    end)

    t.it("never overlaps two regions vertically, on any of the three display classes", function()
      for _, name in ipairs(ALL_FIXTURES) do
        local zone = paths.loadFixture(name)
        local result = layout.compute(zone)
        -- Stacking order top to bottom; footer is separately bottom-anchored
        -- so it's checked only against contextRow, not chained from it.
        local stacked = { result.topBar, result.stickMonitor, result.primaryGrid, result.contextRow }
        for i = 1, #stacked - 1 do
          t.assertTrue(stacked[i].y + stacked[i].h <= stacked[i + 1].y,
            name .. ": region " .. i .. " does not overlap region " .. (i + 1))
        end
        t.assertTrue(result.contextRow.y + result.contextRow.h <= result.footerRow.y,
          name .. ": contextRow does not overlap footerRow")
      end
    end)

    t.it("has every region with a positive, non-degenerate size, on all three display classes", function()
      for _, name in ipairs(ALL_FIXTURES) do
        local zone = paths.loadFixture(name)
        local result = layout.compute(zone)
        local regions = {
          topBar = result.topBar, stickMonitor = result.stickMonitor,
          primaryGrid = result.primaryGrid, contextRow = result.contextRow,
          footerRow = result.footerRow,
        }
        for regionName, r in pairs(regions) do
          t.assertTrue(r.h > 0, name .. ": " .. regionName .. " has positive height")
          t.assertTrue(r.w > 0, name .. ": " .. regionName .. " has positive width")
        end
      end
    end)

    t.it("gives 800x480 visibly more room per region than 480x272's tighter budget", function()
      local tight = layout.compute(paths.loadFixture("screen_480x272"))
      local roomy = layout.compute(paths.loadFixture("screen_800x480"))
      t.assertTrue(roomy.stickMonitor.h > tight.stickMonitor.h, "sticks region sizes up on the larger screen")
      t.assertTrue(roomy.primaryGrid.h > tight.primaryGrid.h, "primary grid sizes up on the larger screen")
      t.assertTrue(roomy.contextRow.h > tight.contextRow.h, "context row sizes up on the larger screen")
    end)

    t.it("returns nil for a degenerate zero-size zone", function()
      t.assertNil(layout.compute({ x = 0, y = 0, w = 0, h = 0 }))
    end)

    t.it("returns nil when no zone is given", function()
      t.assertNil(layout.compute(nil))
    end)
  end)
end
