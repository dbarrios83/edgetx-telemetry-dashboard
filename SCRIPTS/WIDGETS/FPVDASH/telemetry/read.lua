-- Telemetry read and normalization entrypoint.
-- Reads EdgeTX sensor values once per frame and exposes a normalized snapshot.

local M = {}

local EMPTY_TEXT = "--"

-- Maps sensor-name -> numeric source-ID, or false when confirmed absent.
-- Negative entries are cleared every RESCAN_INTERVAL frames so sensors
-- discovered after initial link-up are automatically retried.
local SOURCE_ID_CACHE = {}
local RESCAN_INTERVAL = 90
local frameCount = 0

-- Preferred ELRS/CRSF names first, generic fallbacks after.
-- NOTE: "RSSI" intentionally omitted from rssi field to avoid
-- reading EdgeTX's internal radio RSSI instead of telemetry RSSI.
local FIELD_SENSORS = {
  battery       = { "VFAS", "RxBt", "Bat", "BATT", "A4" },
  rssi          = { "1RSS", "2RSS", "TRSS" },
  linkQuality   = { "RQly", "LQ",   "TQly" },
  packetRate    = { "RFMD" },
  current       = { "Curr", "CUR" },
  satellites    = { "Sats", "SATS", "SAT" },
  txPower       = { "TPWR", "TxPw" },
  flightMode    = { "FM",   "FMODE" },
  rssi1         = { "1RSS" },
  rssi2         = { "2RSS" },
  capacity      = { "Capa", "CAP" },
  activeAntenna = { "ANT" },
}

local PACKET_RATE_FROM_RFMD = {
  -- Keep legacy mappings 1..7 exactly as the widget already expects today.
  -- Some newer ELRS RFMD tables reuse these indexes with different meanings,
  -- but changing them here would regress users who currently see correct rates.
  [1] = 25,
  [2] = 50,
  [3] = 100,
  [4] = 150,
  [5] = 250,
  [6] = 500,
  [7] = 1000,

  -- Additional exact mappings that do not conflict with the widget's
  -- existing 1..7 behavior. RFMD decoding must remain exact-only:
  -- never approximate, infer, or guess packet rates.
  [8] = 333,
  [9] = 500,
  [10] = 50,
  [11] = 100,
  [12] = 150,
  [13] = 200,
  [14] = 250,
  [15] = 333,
  [16] = 500,
  [25] = 50,
  [26] = 100,
  [27] = 150,
  [28] = 250,
  [29] = 500,
  [30] = 250,
  [31] = 500,
  [32] = 500,
}

local snapshot = {
  battery = 0,
  rssi = 0,
  linkQuality = 0,
  packetRate = 0,
  current = 0,
  satellites = 0,
  sats = 0,
  txPower = 0,
  flightMode = EMPTY_TEXT,

  rssi1 = 0,
  rssi2 = 0,
  capacity = 0,
  activeAntenna = 0,

  available = {
    battery = false,
    rssi = false,
    linkQuality = false,
    packetRate = false,
    current = false,
    satellites = false,
    sats = false,
    txPower = false,
    flightMode = false,
    rssi1 = false,
    rssi2 = false,
    capacity = false,
    activeAntenna = false,
  },

  connected = false,
}

local function validValue(v)
  if v == nil then
    return false
  end

  if v == "" then
    return false
  end

  return true
end

-- Clear negative-cache entries so late-discovered sensors are retried.
local function clearNegativeCache()
  for k, v in pairs(SOURCE_ID_CACHE) do
    if v == false then
      SOURCE_ID_CACHE[k] = nil
    end
  end
end

-- Resolve a sensor name to its numeric source-ID.
-- Returns false when getFieldInfo confirms the sensor is not in the model.
local function resolveId(name)
  local cached = SOURCE_ID_CACHE[name]
  if cached ~= nil then
    return cached
  end

  if getFieldInfo then
    local info = getFieldInfo(name)
    if info and info.id then
      SOURCE_ID_CACHE[name] = info.id
      return info.id
    end
  end

  -- Confirmed absent: cache false so we skip it on subsequent frames.
  SOURCE_ID_CACHE[name] = false
  return false
end

-- Read the first sensor in `names` that getFieldInfo confirms exists.
-- Does NOT fall back to getValue(name) to avoid EdgeTX returning 0
-- for sensors that are not in the model.
local function readFirst(names)
  if not getValue then
    return nil
  end

  for i = 1, #names do
    local id = resolveId(names[i])
    if id ~= false then
      local value = getValue(id)
      if validValue(value) then
        return value
      end
    end
  end

  return nil
end

local function toNumber(v)
  if type(v) == "number" then
    return v
  end

  if type(v) == "table" then
    if type(v.value) == "number" then
      return v.value
    end

    if type(v.val) == "number" then
      return v.val
    end
  end

  if type(v) == "string" then
    local n = tonumber(v:match("%-?%d+%.?%d*"))
    if n then
      return n
    end
  end

  return nil
end

local function resolvePacketRateFromRfmd(rfmd)
  if rfmd == nil then
    return nil
  end

  -- RFMD index 0 is commonly reported during telemetry loss, so we avoid
  -- mapping it to 4 Hz to prevent false "valid" packet-rate display.
  if rfmd == 0 then
    return nil
  end

  local mappedRate = PACKET_RATE_FROM_RFMD[rfmd]
  if mappedRate ~= nil then
    return mappedRate
  end

  -- Unknown RFMD values must stay unresolved so the existing UI fallback
  -- renders a neutral missing state rather than an incorrect "N Hz" value.
  return nil
end

local function normalizePacketRate(raw)
  local n = toNumber(raw)
  if not n then
    return nil
  end

  return resolvePacketRateFromRfmd(n)
end

local function normalizeFlightMode(raw)
  if type(raw) == "string" and raw ~= "" then
    return raw
  end

  if getFlightMode then
    local mode = getFlightMode()
    if type(mode) == "string" and mode ~= "" then
      return mode
    end
  end

  return nil
end

local function assignNumeric(field, normalizer)
  local raw = readFirst(FIELD_SENSORS[field])
  local value = nil

  if normalizer then
    value = normalizer(raw)
  else
    value = toNumber(raw)
  end

  if value == nil then
    snapshot[field] = 0
    snapshot.available[field] = false
  else
    snapshot[field] = value
    snapshot.available[field] = true
  end
end

local function assignText(field, normalizer)
  local raw = readFirst(FIELD_SENSORS[field])
  local value = nil

  if normalizer then
    value = normalizer(raw)
  elseif type(raw) == "string" then
    value = raw
  end

  if value == nil then
    snapshot[field] = EMPTY_TEXT
    snapshot.available[field] = false
  else
    snapshot[field] = value
    snapshot.available[field] = true
  end
end

-- Base connection on live telemetry values, not just sensor presence.
-- Sensor IDs remain available even when RX link drops, so availability flags
-- alone can keep connected=true incorrectly.
local function updateConnectionFlag()
  local hasLQ = snapshot.available.linkQuality and snapshot.linkQuality > 0
  local hasTxPower = snapshot.available.txPower and snapshot.txPower > 0
  local hasPacketRate = snapshot.available.packetRate and snapshot.packetRate > 0

  snapshot.connected = hasLQ or hasTxPower or hasPacketRate

  if not snapshot.connected then
    -- Prevent stale/invalid values from being rendered while disconnected.
    snapshot.packetRate = 0
    snapshot.available.packetRate = false
  end
end

function M.snapshot()
  frameCount = frameCount + 1
  if frameCount >= RESCAN_INTERVAL then
    frameCount = 0
    clearNegativeCache()
  end

  assignNumeric("battery")
  assignNumeric("rssi")
  assignNumeric("linkQuality")
  assignNumeric("packetRate", normalizePacketRate)
  assignNumeric("current")
  assignNumeric("satellites")
  snapshot.sats = snapshot.satellites
  snapshot.available.sats = snapshot.available.satellites
  assignNumeric("txPower")

  assignText("flightMode", normalizeFlightMode)

  assignNumeric("rssi1")
  assignNumeric("rssi2")
  assignNumeric("capacity")
  assignNumeric("activeAntenna")

  updateConnectionFlag()

  return snapshot
end

-- Probe a fixed list of known sensor names and return those found on this model.
-- Used for debug display only; safe to call every frame but designed for occasional use.
local PROBE_NAMES = {
  "VFAS", "RxBt", "Bat", "A4",
  "1RSS", "2RSS", "TRSS",
  "RQly", "LQ", "TQly",
  "RFMD", "TPWR", "TxPw",
  "Curr", "CUR",
  "Sats", "SATS",
  "FM", "FMODE",
  "ANT", "Capa", "CAP",
}

function M.scanSensors()
  if not getFieldInfo or not getValue then
    return {}
  end

  local found = {}
  for i = 1, #PROBE_NAMES do
    local name = PROBE_NAMES[i]
    local info = getFieldInfo(name)
    if info and info.id then
      found[#found + 1] = name .. "=" .. tostring(getValue(info.id))
    end
  end

  return found
end

return M
