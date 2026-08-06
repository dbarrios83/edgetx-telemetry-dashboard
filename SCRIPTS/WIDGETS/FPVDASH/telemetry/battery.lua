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

-- Infer a candidate cell count from total pack voltage, ceiling against
-- max-charge voltage so exact full-charge readings (e.g. 8.70V for a 2S
-- LiHV pack) don't spill into the next larger pack size.
local function inferCellCount(voltage)
  if type(voltage) ~= "number" or voltage <= 0 then
    return nil
  end
  return math.max(1, math.ceil((voltage / MAX_CELL_VOLTAGE) - EPSILON))
end

-- Create and return a fresh per-widget-instance battery-resolution state
-- table. Call once in create() and pass the same state into every
-- M.resolve()/M.reset() call for that widget instance -- sharing state
-- across instances would let one instance's latched pack size leak into
-- another's (EdgeTX shares file-scope locals between every instance of a
-- widget script; this state must not live there). Mirrors
-- telemetry/elrs.lua's M.init()/M.update(state) shape.
function M.init()
  return {
    latchedCells = nil,
  }
end

-- Clears the latch. Call when telemetry disconnects: a new connection
-- may be a different pack, so inference should start fresh rather than
-- staying pinned to whatever was latched before.
function M.reset(state)
  state.latchedCells = nil
end

-- Resolves { cells, cellVoltage } for one frame.
--   state        - this widget instance's state, from M.init().
--   voltage      - total pack voltage (VFAS/RxBt/etc.), or nil if the
--                   sensor isn't discovered at all. 0 is a real,
--                   meaningful reading (see below), not "unknown".
--   explicitCells - real cell count from the "Cels" sensor (#getValue("Cels")),
--                    or nil when that sensor is not discovered/reporting.
-- Returns cells=nil, cellVoltage=nil only when the sensor is genuinely
-- absent or never reported anything usable -- never as an optimistic
-- guess.
function M.resolve(state, voltage, explicitCells)
  if type(explicitCells) == "number" and explicitCells > 0 then
    -- Real per-cell telemetry is ground truth: it can move the latch in
    -- either direction, unlike voltage-based inference.
    state.latchedCells = explicitCells
  else
    local candidate = inferCellCount(voltage)
    if candidate ~= nil and (state.latchedCells == nil or candidate > state.latchedCells) then
      state.latchedCells = candidate
    end
  end

  if type(voltage) ~= "number" or voltage < 0 then
    -- No usable reading at all (sensor absent, or a nonsensical
    -- negative value): nothing to report, regardless of any
    -- previously latched cell count.
    return state.latchedCells, nil
  end

  if state.latchedCells == nil then
    -- Cell count was never established (e.g. the very first reading
    -- this session is already 0V), but 0V itself is still a real
    -- measurement -- a pack reporting 0V is critically dead/
    -- disconnected regardless of how many cells it has. Report the
    -- raw pack voltage; cells stays nil so callers don't invent a
    -- cell count they don't actually know.
    return nil, voltage
  end

  return state.latchedCells, voltage / state.latchedCells
end

return M
