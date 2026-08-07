-- Tests for render/primitives.lua's grid/centering geometry contract
-- (Grid-aligned top bar and sticks, Task 1). Pure math -- no lcd/Bitmap
-- globals required, so these load the module directly without
-- mock.withInstall.
return function(t, mock, paths)
  local primitives = paths.loadWidgetModule("render/primitives.lua")

  local function assertTiles(cells, x, w)
    -- No gaps or overlap: each cell's right edge is the next cell's left
    -- edge, the first cell starts at x, and the last cell ends at x + w.
    t.assertEqual(cells[1].x, x, "first cell starts at the input x")
    for i = 1, #cells - 1 do
      t.assertEqual(cells[i].x + cells[i].w, cells[i + 1].x,
        "cell " .. i .. " right edge meets cell " .. (i + 1) .. " left edge")
    end
    local last = cells[#cells]
    t.assertEqual(last.x + last.w, x + w, "last cell ends at x + w")
  end

  t.describe("render/primitives.lua gridCells", function()
    t.it("produces sticks-panel 30/40/30 columns covering the full width with no gaps or overlap", function()
      local cells = primitives.gridCells(0, 0, 480, 130, { 30, 40, 30 })
      t.assertEqual(#cells, 3)
      assertTiles(cells, 0, 480)
      t.assertEqual(cells[1].w, 144)
      t.assertEqual(cells[2].w, 192)
      t.assertEqual(cells[3].w, 144)
      for i = 1, 3 do
        t.assertEqual(cells[i].y, 0)
        t.assertEqual(cells[i].h, 130)
      end
    end)

    t.it("produces top-bar 10/36/20/16/18 columns covering the full width with no gaps or overlap", function()
      local cells = primitives.gridCells(10, 5, 470, 36, { 10, 36, 20, 16, 18 })
      t.assertEqual(#cells, 5)
      assertTiles(cells, 10, 470)
      for i = 1, 5 do
        t.assertEqual(cells[i].y, 5)
        t.assertEqual(cells[i].h, 36)
      end
    end)

    t.it("assigns rounding-remainder pixels deterministically across an odd width", function()
      -- 481px total does not divide evenly by 30/40/30 -- verify the
      -- proportions still tile exactly and repeated calls agree.
      local cellsA = primitives.gridCells(0, 0, 481, 130, { 30, 40, 30 })
      local cellsB = primitives.gridCells(0, 0, 481, 130, { 30, 40, 30 })
      assertTiles(cellsA, 0, 481)
      for i = 1, 3 do
        t.assertEqual(cellsA[i].x, cellsB[i].x, "deterministic across repeated calls")
        t.assertEqual(cellsA[i].w, cellsB[i].w, "deterministic across repeated calls")
      end
    end)

    t.it("preserves the input y and h on every cell", function()
      local cells = primitives.gridCells(3, 7, 100, 42, { 1, 1, 1 })
      for i = 1, 3 do
        t.assertEqual(cells[i].y, 7)
        t.assertEqual(cells[i].h, 42)
      end
    end)

    t.it("returns an empty table for an empty weights list", function()
      local cells = primitives.gridCells(0, 0, 100, 20, {})
      t.assertEqual(#cells, 0)
    end)
  end)

  t.describe("render/primitives.lua centerStart", function()
    t.it("centers a smaller span within a larger one", function()
      t.assertEqual(primitives.centerStart(0, 100, 40), 30)
    end)

    t.it("clamps to the outer start when the inner span is larger", function()
      t.assertEqual(primitives.centerStart(10, 20, 50), 10)
    end)

    t.it("offsets by the outer start", function()
      t.assertEqual(primitives.centerStart(200, 100, 40), 230)
    end)
  end)

  t.describe("render/primitives.lua centerGroup", function()
    local rect = { x = 100, y = 50, w = 200, h = 40 }

    t.it("centers an icon+gap+text group as one horizontal block", function()
      local parts = { { w = 20, h = 20 }, { w = 4 }, { w = 30, h = 8 } }
      local placed = primitives.centerGroup(rect, parts)
      t.assertEqual(#placed, 3)

      local totalW = 20 + 4 + 30
      local expectedStartX = rect.x + math.floor((rect.w - totalW) / 2)
      t.assertEqual(placed[1].x, expectedStartX, "icon starts at the group's centered left edge")
      t.assertEqual(placed[2].x, expectedStartX + 20, "gap immediately follows the icon")
      t.assertEqual(placed[3].x, expectedStartX + 20 + 4, "text immediately follows the gap")

      t.assertEqual(placed[1].y, rect.y + math.floor((rect.h - 20) / 2), "icon centered on its own height")
      t.assertEqual(placed[3].y, rect.y + math.floor((rect.h - 8) / 2), "text centered on its own height")
    end)

    t.it("centers a lone part for the icon-only/text-only fallback case", function()
      local placed = primitives.centerGroup(rect, { { w = 50, h = 10 } })
      t.assertEqual(#placed, 1)
      t.assertEqual(placed[1].x, rect.x + math.floor((rect.w - 50) / 2))
      t.assertEqual(placed[1].y, rect.y + math.floor((rect.h - 10) / 2))
    end)

    t.it("keeps the group inside the rect when it is wider than the rect", function()
      local placed = primitives.centerGroup(rect, { { w = 400, h = 10 } })
      t.assertEqual(placed[1].x, rect.x, "oversized group stays left-aligned inside its cell, not pushed outside")
    end)

    t.it("returns an empty table for an empty parts list", function()
      t.assertEqual(#primitives.centerGroup(rect, {}), 0)
    end)
  end)

  t.describe("render/primitives.lua centerGroupVertical", function()
    local rect = { x = 100, y = 50, w = 200, h = 40 }

    t.it("stacks rows as one vertical block, each row centered on its own width", function()
      local parts = { { w = 40, h = 10 }, { w = 24, h = 10 } }
      local placed = primitives.centerGroupVertical(rect, parts)
      t.assertEqual(#placed, 2)

      local totalH = 10 + 10
      local expectedStartY = rect.y + math.floor((rect.h - totalH) / 2)
      t.assertEqual(placed[1].y, expectedStartY, "first row starts at the group's centered top edge")
      t.assertEqual(placed[2].y, expectedStartY + 10, "second row immediately follows the first")

      t.assertEqual(placed[1].x, rect.x + math.floor((rect.w - 40) / 2), "row 1 centered on its own width")
      t.assertEqual(placed[2].x, rect.x + math.floor((rect.w - 24) / 2), "row 2 centered on its own width")
    end)
  end)
end
