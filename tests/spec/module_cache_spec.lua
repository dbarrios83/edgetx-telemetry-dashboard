-- Verifies main.lua's loadModule() and every render/*.lua's/
-- telemetry/read.lua's loadSiblingModule() share one process-wide cache
-- (scoped to one runtime session -- see tests/mock_edgetx.lua's
-- uninstall(), which resets it between tests) instead of each caller
-- executing its own independent copy of a shared dependency.
--
-- Found via external review (2026-08-07): render/primitives.lua is a
-- single shared module in source, but was loaded independently by each
-- of the five renderers that depend on it -- five loadScript calls and
-- five separate module tables in memory, not one. See main.lua's/each
-- render file's loadModule/loadSiblingModule comment for the fix.
return function(t, mock, paths)
  local function countLoadScriptCallsEndingWith(suffix)
    local count = 0
    return {
      install = function(fixture)
        fixture = fixture or {}
        fixture.loadScript = function(path)
          if path:sub(-#suffix) == suffix then
            count = count + 1
          end
          return loadfile(path)
        end
        return fixture
      end,
      count = function() return count end,
    }
  end

  t.describe("shared module cache across renderers", function()
    t.it("loads render/primitives.lua's loadScript chain only once across five independent renderer loads", function()
      local spy = countLoadScriptCallsEndingWith("primitives.lua")

      mock.withInstall(spy.install({ sensors = {} }), function()
        -- Each of these is a fresh top-level chunk (paths.loadWidgetModule
        -- always uses plain loadfile for the file under test), but each
        -- one's own internal loadSiblingModule("render/primitives.lua")
        -- call goes through the spied loadScript above.
        paths.loadWidgetModule("render/topbar.lua")
        paths.loadWidgetModule("render/sticks.lua")
        paths.loadWidgetModule("render/context.lua")
        paths.loadWidgetModule("render/footer.lua")
        paths.loadWidgetModule("render/timers.lua")

        -- One full WIDGET_ROOTS probe for "render/primitives.lua" takes
        -- 3 loadScript calls on this filesystem (the two leading-slash
        -- candidates fail, the plain "SCRIPTS/WIDGETS/FPVDASH/..." one
        -- succeeds) -- that's the fixed cost of the *first* renderer's
        -- load. Without the cache fix, each of the other four renderers
        -- would repeat that same 3-call probe independently, for 15
        -- total. With the shared cache, only the first renderer's load
        -- actually reaches loadScript at all -- every later one is
        -- served from the cache before the WIDGET_ROOTS loop even runs.
        t.assertEqual(spy.count(), 3,
          "expected exactly one renderer's worth of loadScript(...primitives.lua) calls (3) across five renderer loads in the same session, got " .. spy.count())
      end)
    end)

    t.it("does not leak the cache across separate sessions (install()/uninstall() cycles)", function()
      local spyA = countLoadScriptCallsEndingWith("primitives.lua")
      mock.withInstall(spyA.install({ sensors = {} }), function()
        paths.loadWidgetModule("render/topbar.lua")
      end)
      t.assertEqual(spyA.count(), 3)

      -- A brand-new session (e.g. the radio power-cycling, or -- more to
      -- the point for this suite -- the next independent test) must not
      -- see the previous session's cached module: it needs its own
      -- fresh WIDGET_ROOTS probe, not a silent cache hit left over from
      -- a session that has already ended.
      local spyB = countLoadScriptCallsEndingWith("primitives.lua")
      mock.withInstall(spyB.install({ sensors = {} }), function()
        paths.loadWidgetModule("render/sticks.lua")
      end)
      t.assertEqual(spyB.count(), 3,
        "a new session must reload render/primitives.lua fresh, not reuse the previous session's cache")
    end)
  end)
end
