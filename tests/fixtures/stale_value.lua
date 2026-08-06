-- Link was connected and has just been lost: generic sensors (VFAS, Curr,
-- Sats) still hold their last received reading while the link-quality
-- fields have already fallen to zero. Used for connection/staleness tests.
return {
  sensors = {
    VFAS = { value = 15.9 },
    Curr = { value = 4.1 },
    Sats = { value = 9 },
    RQly = { value = 0 },
    TPWR = { value = 0 },
    RFMD = { value = 0 },
  },
  flightMode = nil,
  rssiStream = 0, -- link is actually down; generic sensor values are stale
  time = 0,
}
