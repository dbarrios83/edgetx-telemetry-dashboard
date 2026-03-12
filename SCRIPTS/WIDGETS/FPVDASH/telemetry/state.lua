-- Telemetry state evaluation.
-- Categorises telemetry values into predefined health states consumed by renderers.
-- Each evaluator returns one of: OK, WARNING, LOW, CRITICAL, UNKNOWN, DISCONNECTED.

local M = {}

-- State constants.
M.OK           = "OK"
M.WARNING      = "WARNING"
M.LOW          = "LOW"
M.CRITICAL     = "CRITICAL"
M.UNKNOWN      = "UNKNOWN"
M.DISCONNECTED = "DISCONNECTED"

-- Detect approximate LiPo cell count from total pack voltage.
-- Uses max-charge voltage of 4.2 V per cell.
local function detectCellCount(voltage)
  if not voltage or voltage <= 0 then
    return 1
  end
  return math.floor(voltage / 4.2) + 1
end

-- Evaluate battery state from total pack voltage.
-- Per-cell thresholds: OK > 3.7 V, WARNING 3.5–3.7 V, CRITICAL < 3.5 V
function M.evaluateBattery(voltage)
  if not voltage or voltage <= 0 then
    return M.UNKNOWN
  end
  local cells = detectCellCount(voltage)
  local cellV = voltage / cells
  if cellV > 3.7 then
    return M.OK
  elseif cellV >= 3.5 then
    return M.WARNING
  else
    return M.CRITICAL
  end
end

-- Evaluate link quality state from percentage (0–100).
-- Thresholds: OK > 90, WARNING 70–90, CRITICAL < 70
function M.evaluateLinkQuality(lq, isAvailable)
  if not isAvailable or lq == nil then
    return M.UNKNOWN
  end
  if lq > 90 then
    return M.OK
  elseif lq >= 70 then
    return M.WARNING
  else
    return M.CRITICAL
  end
end

-- Evaluate RSSI state from a dBm value (typically negative for CRSF/ELRS).
-- Thresholds: OK > -65 dBm, WARNING -65 to -85 dBm, CRITICAL < -85 dBm
function M.evaluateRSSI(rssi, isAvailable)
  if not isAvailable or rssi == nil or rssi == 0 then
    return M.UNKNOWN
  end
  if rssi > -65 then
    return M.OK
  elseif rssi >= -85 then
    return M.WARNING
  else
    return M.CRITICAL
  end
end

-- Evaluate satellite count state.
-- Thresholds: OK >= 10, WARNING 6–9, CRITICAL < 6
function M.evaluateSatellites(sats, isAvailable)
  if not isAvailable or sats == nil then
    return M.UNKNOWN
  end
  if sats >= 10 then
    return M.OK
  elseif sats >= 6 then
    return M.WARNING
  else
    return M.CRITICAL
  end
end

-- Evaluate current draw state.
-- Current is primarily informational for now, so available readings map to OK.
function M.evaluateCurrent(current, isAvailable)
  if not isAvailable or current == nil then
    return M.UNKNOWN
  end

  if current < 0 then
    return M.UNKNOWN
  end

  return M.OK
end

-- Evaluate TX power state.
-- Any positive power level means the link is active (OK); zero or nil is UNKNOWN.
function M.evaluateTxPower(txPower)
  if txPower == nil then
    return M.UNKNOWN
  end
  if txPower > 0 then
    return M.OK
  end
  return M.UNKNOWN
end

-- Evaluate packet rate state.
-- Any positive packet rate is OK; zero or nil is UNKNOWN.
function M.evaluatePacketRate(rate, isAvailable)
  if not isAvailable or rate == nil or rate <= 0 then
    return M.UNKNOWN
  end
  return M.OK
end

-- Evaluate the full telemetry snapshot and return a per-field state table.
-- All fields return DISCONNECTED when the telemetry link is not active.
function M.evaluate(snapshot)
  if not snapshot or not snapshot.connected then
    return {
      battery     = M.DISCONNECTED,
      linkQuality = M.DISCONNECTED,
      rssi        = M.DISCONNECTED,
      current     = M.DISCONNECTED,
      satellites  = M.DISCONNECTED,
      sats        = M.DISCONNECTED,
      txPower     = M.DISCONNECTED,
      packetRate  = M.DISCONNECTED,
    }
  end

  local available = snapshot.available or {}
  local satellitesState = M.evaluateSatellites(snapshot.satellites, available.satellites)

  return {
    battery     = M.evaluateBattery(snapshot.battery),
    linkQuality = M.evaluateLinkQuality(snapshot.linkQuality, available.linkQuality),
    rssi        = M.evaluateRSSI(snapshot.rssi, available.rssi),
    current     = M.evaluateCurrent(snapshot.current, available.current),
    satellites  = satellitesState,
    sats        = satellitesState,
    txPower     = M.evaluateTxPower(snapshot.txPower),
    packetRate  = M.evaluatePacketRate(snapshot.packetRate, available.packetRate),
  }
end

return M
