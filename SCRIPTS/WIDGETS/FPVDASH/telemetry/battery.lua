-- Single shared cell-count/cell-voltage resolver for all battery consumers
-- (telemetry/state.lua, render/sticks.lua).
--
-- Safety background (Reliability & Compatibility plan, Step 3): pack
-- voltage alone cannot reliably identify cell count. A depleted 6S pack
-- at 21.0V (3.50V/cell) divided by the wrong inferred cell count can
-- read back as a "full" smaller pack. This module fixes that by:
--   1. Preferring the EdgeTX "Cels" sensor (real per-cell voltages
--      reported by the FC) when present -- an explicit measurement,
--      never inferred.
--   2. Falling back to voltage-based inference only when Cels is
--      unavailable, and latching the highest credible inferred count
--      for as long as the link stays connected, so a pack cannot
--      "shrink" mid-flight as it drains. The latch resets on
--      disconnect, since a new connection may be a different pack.

local M = {}

local MAX_CELL_VOLTAGE = 4.35 -- LiHV full-charge ceiling
local EPSILON = 0.0001

local latchedCells = nil

-- Infer a candidate cell count from total pack voltage, ceiling against
-- max-charge voltage so exact full-charge readings (e.g. 8.70V for a 2S
-- LiHV pack) don't spill into the next larger pack size.
local function inferCellCount(voltage)
  if type(voltage) ~= "number" or voltage <= 0 then
    return nil
  end
  return math.max(1, math.ceil((voltage / MAX_CELL_VOLTAGE) - EPSILON))
end

-- Clears the latch. Call when telemetry disconnects: a new connection
-- may be a different pack, so inference should start fresh rather than
-- staying pinned to whatever was latched before.
function M.reset()
  latchedCells = nil
end

-- Resolves { cells, cellVoltage } for one frame.
--   voltage      - total pack voltage (VFAS/RxBt/etc.), or nil/0 if unknown.
--   explicitCells - real cell count from the "Cels" sensor (#getValue("Cels")),
--                    or nil when that sensor is not discovered/reporting.
-- Returns cells=nil when nothing credible is known (renders as UNKNOWN,
-- never as an optimistic guess).
function M.resolve(voltage, explicitCells)
  if type(explicitCells) == "number" and explicitCells > 0 then
    -- Real per-cell telemetry is ground truth: it can move the latch in
    -- either direction, unlike voltage-based inference.
    latchedCells = explicitCells
  else
    local candidate = inferCellCount(voltage)
    if candidate ~= nil and (latchedCells == nil or candidate > latchedCells) then
      latchedCells = candidate
    end
  end

  if latchedCells == nil then
    return nil, nil
  end

  local cellVoltage = nil
  if type(voltage) == "number" and voltage > 0 then
    cellVoltage = voltage / latchedCells
  end

  return latchedCells, cellVoltage
end

return M
