-- Unit tests for telemetry/battery.lua: the single shared cell-count /
-- per-cell-voltage resolver used by state.lua, sticks.lua, and cards.lua.
--
-- These are the regression fixtures Step 1's harness deliberately left
-- out (see tests/spec/state_spec.lua) so they could land together with
-- the actual Step 3 fix rather than as unexplained red tests.
return function(t, mock, paths)
  t.describe("telemetry/battery.lua", function()
    t.it("infers cell count from voltage when nothing is latched yet", function()
      local battery = paths.loadWidgetModule("telemetry/battery.lua")
      local cells, cellV = battery.resolve(16.8, nil) -- 4S at 4.20V/cell
      t.assertEqual(cells, 4)
      t.assertNear(cellV, 4.20, 0.01)
    end)

    t.it("keeps a 6S pack latched at 6S as it drains to 21.0V, never reporting it as full", function()
      local battery = paths.loadWidgetModule("telemetry/battery.lua")
      -- Pack starts near full charge: correctly inferred as 6S.
      local cells = battery.resolve(25.0, nil)
      t.assertEqual(cells, 6)

      -- Pack drains to 21.0V (3.50V/cell for a real 6S pack -- WARNING
      -- territory). Naive voltage-only inference recomputes
      -- ceil(21.0/4.35-eps) = 5, which would misreport a critical 6S
      -- pack as a "full" 5S pack at 4.20V/cell. The latch must prevent
      -- that by keeping the count at 6.
      local cellsAfterDrain, cellVAfterDrain = battery.resolve(21.0, nil)
      t.assertEqual(cellsAfterDrain, 6)
      t.assertNear(cellVAfterDrain, 3.50, 0.01)
    end)

    t.it("keeps a 4S pack latched at 4S as it drains below 13.05V", function()
      local battery = paths.loadWidgetModule("telemetry/battery.lua")
      battery.resolve(16.8, nil) -- 4S at full charge, correctly inferred
      local cells, cellV = battery.resolve(13.05, nil) -- 3.2625V/cell for a real 4S pack
      t.assertEqual(cells, 4)
      t.assertNear(cellV, 3.2625, 0.001)
    end)

    t.it("does not round an exact full-charge LiHV voltage up to the next pack size", function()
      local battery = paths.loadWidgetModule("telemetry/battery.lua")
      local cells2S = battery.resolve(8.70, nil) -- exact 2S LiHV full charge
      t.assertEqual(cells2S, 2)

      battery.reset()
      local cells4S = battery.resolve(17.40, nil) -- exact 4S LiHV full charge
      t.assertEqual(cells4S, 4)
    end)

    t.it("prefers explicit cell count over voltage inference and can move the latch in either direction", function()
      local battery = paths.loadWidgetModule("telemetry/battery.lua")
      -- Inference alone would say 4S from this voltage.
      local inferredCells = battery.resolve(16.8, nil)
      t.assertEqual(inferredCells, 4)

      -- Real per-cell telemetry (the "Cels" sensor) is a direct
      -- measurement, not a guess, so it must override the inferred
      -- latch even when it disagrees -- including downward. This is a
      -- synthetic voltage/cell-count pairing purely to exercise the
      -- override mechanism, not a claim about realistic pack chemistry.
      local explicitCells, explicitCellV = battery.resolve(16.8, 3)
      t.assertEqual(explicitCells, 3)
      t.assertNear(explicitCellV, 5.6, 0.01)
    end)

    t.it("returns nil/nil when nothing is known, rather than an optimistic guess", function()
      local battery = paths.loadWidgetModule("telemetry/battery.lua")
      local cells, cellV = battery.resolve(nil, nil)
      t.assertNil(cells)
      t.assertNil(cellV)
    end)

    t.it("reset() clears the latch so a newly connected pack is not pinned to the previous one", function()
      local battery = paths.loadWidgetModule("telemetry/battery.lua")
      battery.resolve(25.0, nil) -- latched at 6S
      battery.reset()
      -- A different (smaller) pack connects next. Without reset(), this
      -- would incorrectly stay latched at 6 (candidate 2 < latched 6).
      local cells = battery.resolve(8.4, nil) -- 2S at full charge
      t.assertEqual(cells, 2)
    end)
  end)
end
