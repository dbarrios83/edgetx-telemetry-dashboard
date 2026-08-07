-- Verifies render/context.lua, render/timers.lua, and render/topbar.lua
-- cache their theme-dependent icon sets by icon folder instead of
-- reloading on every draw() call, or thrashing whenever the theme
-- alternates between calls.
--
-- Found via external review (2026-08-07): the architecture doc claims
-- every renderer is stateless, but these three kept mutable
-- _iconsLoaded/_loadedIconFolder module locals. Two widget instances
-- using different themes (or one instance whose darkTheme option
-- changes) would repeatedly steal the cache from each other, reopening
-- every bitmap on every single refresh() -- not just on an actual theme
-- change. See each file's _iconSets/loadIconSet comment for the fix.
return function(t, mock, paths)
  local DARK_THEME = { textColor = 0xFFFF, iconFolder = "dark", isLight = false }
  local LIGHT_THEME = { textColor = 0x0000, iconFolder = "light", isLight = true }

  -- Wraps the already-installed mock Bitmap.open with a call counter.
  -- Must run after mock.withInstall() has set up Bitmap.
  local function countBitmapOpens()
    local counts = {}
    local original = Bitmap.open
    Bitmap.open = function(path)
      counts[path] = (counts[path] or 0) + 1
      return original(path)
    end
    return counts
  end

  local function totalOpens(counts)
    local total = 0
    for _, n in pairs(counts) do
      total = total + n
    end
    return total
  end

  -- Runs the same dark -> dark -> light -> dark drawing sequence against
  -- any of the three affected renderers and asserts the discriminating
  -- behavior: a third call, back on an already-cached theme, must not
  -- reopen any bitmap. Under the pre-fix code this failed, because
  -- _loadedIconFolder only remembers the single most recently drawn
  -- theme, not "have we ever loaded this one before."
  local function assertCachesIconsByTheme(moduleName, draw)
    mock.withInstall({ sensors = {} }, function()
      local renderer = paths.loadWidgetModule(moduleName)
      local counts = countBitmapOpens()

      draw(renderer, DARK_THEME)
      draw(renderer, DARK_THEME)
      local afterTwoDark = totalOpens(counts)
      t.assertTrue(afterTwoDark > 0, "expected at least one icon to have been opened for the dark theme")

      draw(renderer, DARK_THEME)
      t.assertEqual(totalOpens(counts), afterTwoDark,
        "a third draw() with the same already-cached theme must not reopen any bitmap")

      draw(renderer, LIGHT_THEME)
      local afterLight = totalOpens(counts)
      t.assertTrue(afterLight > afterTwoDark,
        "the first draw() with a new theme must load that theme's icon set")

      draw(renderer, DARK_THEME)
      t.assertEqual(totalOpens(counts), afterLight,
        "switching back to a theme that was already loaded before must not reopen any bitmap -- this is the thrash the fix targets")
    end)
  end

  t.describe("render/context.lua icon caching", function()
    t.it("caches icon sets by theme instead of thrashing on alternating themes", function()
      local RECT = { x = 0, y = 0, w = 320, h = 80 }
      assertCachesIconsByTheme("render/context.lua", function(context, theme)
        context.draw(RECT, {}, {}, theme)
      end)
    end)
  end)

  t.describe("render/timers.lua icon caching", function()
    t.it("caches its clock icon by theme instead of thrashing on alternating themes", function()
      local RECT = { x = 0, y = 0, w = 320, h = 40 }
      assertCachesIconsByTheme("render/timers.lua", function(timers, theme)
        timers.draw(RECT, {}, {}, theme)
      end)
    end)
  end)

  t.describe("render/topbar.lua icon caching", function()
    t.it("caches its link icons by theme instead of thrashing on alternating themes", function()
      local BOUNDS = { x = 0, y = 0, w = 480, h = 40 }
      assertCachesIconsByTheme("render/topbar.lua", function(topbar, theme)
        topbar.draw(BOUNDS, { connected = true }, {}, theme)
      end)
    end)

    t.it("still loads the theme-independent battery icons exactly once, regardless of theme changes", function()
      mock.withInstall({ sensors = {} }, function()
        local topbar = paths.loadWidgetModule("render/topbar.lua")
        local counts = countBitmapOpens()
        local BOUNDS = { x = 0, y = 0, w = 480, h = 40 }

        topbar.draw(BOUNDS, { connected = true }, {}, DARK_THEME)
        local batteryOpensAfterDark = counts["/WIDGETS/FPVDASH/icons/battery/battery-full.png"] or 0
        t.assertEqual(batteryOpensAfterDark, 1)

        topbar.draw(BOUNDS, { connected = true }, {}, LIGHT_THEME)
        topbar.draw(BOUNDS, { connected = true }, {}, DARK_THEME)
        t.assertEqual(counts["/WIDGETS/FPVDASH/icons/battery/battery-full.png"], 1,
          "battery icons are theme-independent and must load exactly once, never per-theme")
      end)
    end)
  end)
end
