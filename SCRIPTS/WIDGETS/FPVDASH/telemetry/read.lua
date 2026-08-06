-- Telemetry read and normalization entrypoint.
-- Reads EdgeTX sensor values once per frame and exposes a normalized snapshot.

local M = {}

local EMPTY_TEXT = "--"

-- Mirrors main.lua's own module-loading fallback order so this file can
-- load its sibling telemetry/battery.lua on both a real radio (via the
-- EdgeTX-provided loadScript global) and the desktop test harness (which
-- backs loadScript with plain loadfile against the real repo path).
local WIDGET_ROOTS = {
  "/SCRIPTS/WIDGETS/FPVDASH/",
  "/WIDGETS/FPVDASH/",
  "SCRIPTS/WIDGETS/FPVDASH/",
  "WIDGETS/FPVDASH/",
  "",
}

local function loadSiblingModule(relativePath)
  if not loadScript then
    return nil
  end
  for i = 1, #WIDGET_ROOTS do
    local chunk = loadScript(WIDGET_ROOTS[i] .. relativePath)
    if chunk then
      return chunk()
    end
  end
  return nil
end

local batteryModule = loadSiblingModule("telemetry/battery.lua")

-- RESCAN_INTERVAL: how often (in frames) each session's negative sensor-ID
-- cache is cleared so sensors discovered after initial link-up are
-- automatically retried. Shared, immutable across sessions; the cache and
-- frame counter it governs are per-session (see M.init()).
local RESCAN_INTERVAL = 90

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
  rsnr          = { "RSNR", "SNR" },
}

-- RFMD is the raw ExpressLRS firmware expresslrs_RFrates_e enum value, and
-- that enum was reshaped between the 3.x and 4.x firmware lines -- the same
-- raw index means a different rate depending on version. Both tables below
-- are pulled directly from tagged ExpressLRS firmware source
-- (src/include/common.h), not inferred; see docs/platform/compatibility-
-- matrix.md Section 4 for the full sourcing and version range verified.
--
-- ELRS 3.x: one flat table, same indexes regardless of RF band.
-- Verified identical from tag 3.0.0 through 3.6.4 (the last 3.x release);
-- the enum only ever grew new entries at higher indexes across that range,
-- so this table is a safe superset for any 3.x firmware.
local PACKET_RATE_FROM_RFMD_3X = {
  [0]  = 4,     -- LoRa (failsafe/low-rate beacon)
  [1]  = 25,    -- LoRa
  [2]  = 50,    -- LoRa
  [3]  = 100,   -- LoRa
  [4]  = 100,   -- LoRa, 8ch
  [5]  = 150,   -- LoRa
  [6]  = 200,   -- LoRa
  [7]  = 250,   -- LoRa
  [8]  = 333,   -- LoRa, 8ch
  [9]  = 500,   -- LoRa
  [10] = 250,   -- FLRC, DVDA
  [11] = 500,   -- FLRC, DVDA
  [12] = 500,   -- FLRC
  [13] = 1000,  -- FLRC
  [14] = 50,    -- LoRa, DVDA
  [15] = 200,   -- LoRa, 8ch
  [16] = 500,   -- FSK 2.4GHz, DVDA
  [17] = 1000,  -- FSK 2.4GHz
  [18] = 1000,  -- FSK 900MHz
  [19] = 1000,  -- FSK 900MHz, 8ch
}

-- ELRS 4.x: disjoint index ranges per band, so the RFMD value's own range
-- identifies the band -- no separate band signal is needed. Verified
-- identical from tag 4.0.0 through 4.1.0 (latest at time of writing).
local PACKET_RATE_FROM_RFMD_4X = {
  -- 900 MHz (0-11)
  [0]  = 25, [1]  = 50,  [2]  = 100, [3]  = 100, [4]  = 150, [5]  = 200,
  [6]  = 200, [7] = 250, [8]  = 333, [9]  = 500, [10] = 50,  [11] = 1000,
  -- 2.4 GHz (20-36)
  [20] = 25, [21] = 50,  [22] = 100, [23] = 100, [24] = 150, [25] = 200,
  [26] = 200, [27] = 250, [28] = 333, [29] = 500, [30] = 250, [31] = 500,
  [32] = 500, [33] = 1000, [34] = 250, [35] = 500, [36] = 1000,
  -- Dual-band (100-101)
  [100] = 100, [101] = 150,
}

-- Builds a fresh, empty snapshot table with the same shape M.snapshot()
-- populates every frame.
local function newSnapshot()
  return {
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
    rsnr = 0,

    -- Whether the "GPS" sensor is reporting a real fix table (lat/lon),
    -- as opposed to being absent or mid-acquisition. See readGpsValid().
    gpsValid = false,

    -- Resolved by telemetry/battery.lua; nil until a connected snapshot
    -- has been evaluated. See M.snapshot() below.
    batteryCells = nil,
    batteryCellVoltage = nil,

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
      rsnr = false,
    },

    connected = false,
  }
end

-- Creates and returns a fresh per-widget-instance telemetry-reading
-- session: the sensor-ID cache, rescan counter, the mutable snapshot
-- table M.snapshot() returns, and (if telemetry/battery.lua loaded) its
-- own battery-latch state. Call once in create() and pass the same
-- session into every M.snapshot() call for that widget instance --
-- sharing a session across instances would leak one instance's
-- discovered sensors/battery latch into another's (EdgeTX shares
-- file-scope locals between every instance of a widget script; this
-- state must not live there).
function M.init()
  return {
    sourceIdCache = {},
    frameCount = 0,
    snapshot = newSnapshot(),
    batteryState = batteryModule and batteryModule.init() or nil,
  }
end

local function validValue(v)
  if v == nil then
    return false
  end

  if v == "" then
    return false
  end

  return true
end

-- Clear a session's negative-cache entries so late-discovered sensors are
-- retried.
local function clearNegativeCache(session)
  for k, v in pairs(session.sourceIdCache) do
    if v == false then
      session.sourceIdCache[k] = nil
    end
  end
end

-- Resolve a sensor name to its numeric source-ID, using this session's
-- own cache. Returns false when getFieldInfo confirms the sensor is not
-- in the model.
local function resolveId(session, name)
  local cached = session.sourceIdCache[name]
  if cached ~= nil then
    return cached
  end

  if getFieldInfo then
    local info = getFieldInfo(name)
    if info and info.id then
      session.sourceIdCache[name] = info.id
      return info.id
    end
  end

  -- Confirmed absent: cache false so we skip it on subsequent frames.
  session.sourceIdCache[name] = false
  return false
end

-- Read the first sensor in `names` that getFieldInfo confirms exists.
-- Does NOT fall back to getValue(name) to avoid EdgeTX returning 0
-- for sensors that are not in the model.
local function readFirst(session, names)
  if not getValue then
    return nil
  end

  for i = 1, #names do
    local id = resolveId(session, names[i])
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

local function resolvePacketRateFromRfmd(rfmd, elrsMajorVersion)
  if rfmd == nil then
    return nil
  end

  -- RFMD index 0 is commonly reported during telemetry loss/startup, so
  -- we avoid mapping it to a real rate (4Hz on 3.x, 25Hz-900MHz on 4.x)
  -- to prevent a false "valid" packet-rate display. This is a
  -- deliberately conservative policy applied regardless of version --
  -- see docs/platform/compatibility-matrix.md Section 4.
  if rfmd == 0 then
    return nil
  end

  local rateTable
  if elrsMajorVersion == 4 then
    rateTable = PACKET_RATE_FROM_RFMD_4X
  elseif elrsMajorVersion == 3 then
    rateTable = PACKET_RATE_FROM_RFMD_3X
  else
    -- Unknown/undetected ELRS version: never guess which table applies.
    return nil
  end

  -- Unknown indexes within a known version's table must also stay
  -- unresolved rather than rendering an incorrect "N Hz" value.
  return rateTable[rfmd]
end

local function normalizePacketRate(raw, elrsMajorVersion)
  local n = toNumber(raw)
  if not n then
    return nil
  end

  return resolvePacketRateFromRfmd(n, elrsMajorVersion)
end

-- FC telemetry flight mode (FM/FMODE) takes precedence when present; the
-- radio's own getFlightMode() is only a fallback for models with no FC
-- flight-mode sensor. getFlightMode() returns (index, name) in that
-- order -- capturing only the first value silently drops the name and
-- always fails the `type(mode) == "string"` check, which is why this
-- fallback previously never resolved to anything.
local function normalizeFlightMode(raw)
  if type(raw) == "string" and raw ~= "" then
    return raw
  end

  if getFlightMode then
    local _, name = getFlightMode()
    if type(name) == "string" and name ~= "" then
      return name
    end
  end

  return nil
end

local function assignNumeric(session, field, normalizer, extra)
  local raw = readFirst(session, FIELD_SENSORS[field])
  local value = nil

  if normalizer then
    value = normalizer(raw, extra)
  else
    value = toNumber(raw)
  end

  local snapshot = session.snapshot
  if value == nil then
    snapshot[field] = 0
    snapshot.available[field] = false
  else
    snapshot[field] = value
    snapshot.available[field] = true
  end
end

local function assignText(session, field, normalizer)
  local raw = readFirst(session, FIELD_SENSORS[field])
  local value = nil

  if normalizer then
    value = normalizer(raw)
  elseif type(raw) == "string" then
    value = raw
  end

  local snapshot = session.snapshot
  if value == nil then
    snapshot[field] = EMPTY_TEXT
    snapshot.available[field] = false
  else
    snapshot[field] = value
    snapshot.available[field] = true
  end
end

-- Real per-cell voltages, when the FC/receiver reports them. EdgeTX's
-- "Cels" sensor returns a table keyed 1..N by cell number, or the number
-- 0 when no cells are detected -- #table is the true, measured cell
-- count and is always preferred over voltage-based inference.
local function readExplicitCellCount(session)
  if not getValue then
    return nil
  end

  local id = resolveId(session, "Cels")
  if id == false then
    return nil
  end

  local cels = getValue(id)
  if type(cels) ~= "table" then
    return nil
  end

  local count = #cels
  if count <= 0 then
    return nil
  end

  return count
end

-- A GPS sensor reports a real fix as a table (lat/lon); anything else
-- (absent, or mid-acquisition on some FCs) is not a usable fix.
local function readGpsValid(session)
  if not getValue then
    return false
  end

  local id = resolveId(session, "GPS")
  if id == false then
    return false
  end

  return type(getValue(id)) == "table"
end

-- EdgeTX's own getRSSI() is protocol-agnostic: its first return value is
-- nonzero only while the firmware's internal TELEMETRY_STREAMING() flag
-- is true, for whatever telemetry protocol/sensors are actually in use
-- -- not just ELRS. Sourced from EdgeTX firmware
-- (radio/src/lua/api_general.cpp, luaGetRSSI); see
-- docs/platform/compatibility-matrix.md for the full citation. This is
-- what lets a model exposing only generic sensors (VFAS/current/GPS/
-- RSSI) and no ELRS-specific LQ/TxPower/RFMD be correctly detected as
-- connected. Independent of any session -- reads the global directly.
local function isTelemetryStreaming()
  if not getRSSI then
    return false
  end
  local rssi = getRSSI()
  return type(rssi) == "number" and rssi > 0
end

-- Base connection on live telemetry values, not just sensor presence.
-- Sensor IDs remain available even when RX link drops, so availability flags
-- alone can keep connected=true incorrectly.
local function updateConnectionFlag(session)
  local snapshot = session.snapshot
  local hasStreamingTelemetry = isTelemetryStreaming()
  local hasLQ = snapshot.available.linkQuality and snapshot.linkQuality > 0
  local hasTxPower = snapshot.available.txPower and snapshot.txPower > 0
  local hasPacketRate = snapshot.available.packetRate and snapshot.packetRate > 0

  -- getRSSI() is the primary, protocol-agnostic signal. The ELRS-specific
  -- checks remain as a fallback in case getRSSI() is ever unavailable or
  -- behaves unexpectedly on a given firmware build.
  snapshot.connected = hasStreamingTelemetry or hasLQ or hasTxPower or hasPacketRate

  if not snapshot.connected then
    -- Prevent stale/invalid values from being rendered while disconnected.
    snapshot.packetRate = 0
    snapshot.available.packetRate = false
  end
end

-- session: this widget instance's telemetry-reading session, from
-- M.init(). Must not be shared across widget instances -- see M.init().
-- elrsMajorVersion (optional): the ELRS firmware major version (3 or 4),
-- resolved from CRSF device-info by telemetry/elrs.lua and passed in by
-- main.lua. Selects which RFMD rate table to decode packet rate with;
-- omitted or unrecognized versions leave packetRate unavailable rather
-- than guessing.
function M.snapshot(session, elrsMajorVersion)
  session.frameCount = session.frameCount + 1
  if session.frameCount >= RESCAN_INTERVAL then
    session.frameCount = 0
    clearNegativeCache(session)
  end

  assignNumeric(session, "battery")
  assignNumeric(session, "rssi")
  assignNumeric(session, "linkQuality")
  assignNumeric(session, "packetRate", normalizePacketRate, elrsMajorVersion)
  assignNumeric(session, "current")
  assignNumeric(session, "satellites")
  session.snapshot.sats = session.snapshot.satellites
  session.snapshot.available.sats = session.snapshot.available.satellites
  assignNumeric(session, "txPower")

  assignText(session, "flightMode", normalizeFlightMode)

  assignNumeric(session, "rssi1")
  assignNumeric(session, "rssi2")
  assignNumeric(session, "capacity")
  assignNumeric(session, "activeAntenna")
  assignNumeric(session, "rsnr")

  session.snapshot.gpsValid = readGpsValid(session)

  updateConnectionFlag(session)

  local snapshot = session.snapshot

  if batteryModule and session.batteryState then
    if snapshot.connected then
      local explicitCells = readExplicitCellCount(session)
      -- snapshot.battery defaults to 0 when the sensor is undiscovered
      -- (see assignNumeric), which battery.lua must not mistake for a
      -- real 0V reading -- pass nil so it can tell "absent" from
      -- "present, genuinely reads zero" apart.
      local batteryVoltage = snapshot.available.battery and snapshot.battery or nil
      local cells, cellVoltage = batteryModule.resolve(session.batteryState, batteryVoltage, explicitCells)
      snapshot.batteryCells = cells
      snapshot.batteryCellVoltage = cellVoltage
    else
      -- A new connection may be a different pack; do not carry a stale
      -- latched cell count across a disconnect.
      batteryModule.reset(session.batteryState)
      snapshot.batteryCells = nil
      snapshot.batteryCellVoltage = nil
    end
  end

  return snapshot
end

-- Probe a fixed list of known sensor names and return those found on this model.
-- Used for debug display only; safe to call every frame but designed for
-- occasional use. Independent of any session -- reads getFieldInfo/getValue
-- directly and does not use or affect a session's sensor-ID cache.
local PROBE_NAMES = {
  "VFAS", "RxBt", "Bat", "A4",
  "1RSS", "2RSS", "TRSS",
  "RQly", "LQ", "TQly",
  "RFMD", "TPWR", "TxPw",
  "Curr", "CUR",
  "Sats", "SATS",
  "FM", "FMODE",
  "ANT", "Capa", "CAP",
  "RSNR", "SNR", "GPS", "Cels",
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
