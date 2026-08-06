-- Sensors were discovered at some point (IDs resolve) but the live link is
-- down: LQ, TX power, and packet rate have all dropped to zero.
return {
  sensors = {
    VFAS = { value = 16.8 },
    RQly = { value = 0 },
    RFMD = { value = 0 },
    TPWR = { value = 0 },
    Curr = { value = 0 },
    Sats = { value = 0 },
  },
  flightMode = nil,
  rssiStream = 0, -- EdgeTX TELEMETRY_STREAMING() is false: no link at all
  time = 0,
}
