-- Slot geometry computation for dashboard components.
-- Maps fixed slot identifiers to rectangles within precomputed regions.

local M = {}

local function rect(x, y, w, h)
  return {
    x = x,
    y = y,
    w = w,
    h = h,
  }
end

local function splitColumns(area, columns, gap)
  local cells = {}
  local innerW = area.w - ((columns - 1) * gap)
  local baseW = math.floor(innerW / columns)
  local x = area.x

  for i = 1, columns do
    local cellW = baseW
    if i == columns then
      cellW = (area.x + area.w) - x
    end

    cells[i] = rect(x, area.y, cellW, area.h)
    x = x + cellW + gap
  end

  return cells
end

local function splitRows(area, rows, gap)
  local cells = {}
  local innerH = area.h - ((rows - 1) * gap)
  local baseH = math.floor(innerH / rows)
  local y = area.y

  for i = 1, rows do
    local cellH = baseH
    if i == rows then
      cellH = (area.y + area.h) - y
    end

    cells[i] = rect(area.x, y, area.w, cellH)
    y = y + cellH + gap
  end

  return cells
end

local function withSlot(id, metric, r)
  return {
    id = id,
    metric = metric,
    x = r.x,
    y = r.y,
    w = r.w,
    h = r.h,
  }
end

function M.compute(layout)
  if not layout then
    return nil
  end

  local gap = layout.gap or 4
  local slots = {
    primary = {},
    context = {},
    optional = {},
    byId = {},
  }

  local primaryRows = splitRows(layout.primaryGrid, 2, gap)
  local primaryTop = splitColumns(primaryRows[1], 3, gap)
  local primaryBottom = splitColumns(primaryRows[2], 3, gap)

  slots.primary.P1 = withSlot("P1", "battery", primaryTop[1])
  slots.primary.P2 = withSlot("P2", "lq", primaryTop[2])
  slots.primary.P3 = withSlot("P3", "packetRate", primaryTop[3])
  slots.primary.P4 = withSlot("P4", "rssi", primaryBottom[1])
  slots.primary.P5 = withSlot("P5", "current", primaryBottom[2])
  slots.primary.P6 = withSlot("P6", "satellites", primaryBottom[3])

  local contextCols = splitColumns(layout.contextRow, 2, gap)
  slots.context.C1 = withSlot("C1", "txPower", contextCols[1])
  slots.context.C2 = withSlot("C2", "flightMode", contextCols[2])

  local optionalCols = splitColumns(layout.diagnostics, 4, gap)
  slots.optional.O1 = withSlot("O1", "rssi1", optionalCols[1])
  slots.optional.O2 = withSlot("O2", "rssi2", optionalCols[2])
  slots.optional.O3 = withSlot("O3", "capacity", optionalCols[3])
  slots.optional.O4 = withSlot("O4", "activeAntenna", optionalCols[4])

  slots.byId.P1 = slots.primary.P1
  slots.byId.P2 = slots.primary.P2
  slots.byId.P3 = slots.primary.P3
  slots.byId.P4 = slots.primary.P4
  slots.byId.P5 = slots.primary.P5
  slots.byId.P6 = slots.primary.P6
  slots.byId.C1 = slots.context.C1
  slots.byId.C2 = slots.context.C2
  slots.byId.O1 = slots.optional.O1
  slots.byId.O2 = slots.optional.O2
  slots.byId.O3 = slots.optional.O3
  slots.byId.O4 = slots.optional.O4

  return slots
end

return M
