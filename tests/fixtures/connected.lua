-- Healthy, fully connected 4S link with every primary sensor discovered.
return {
  sensors = {
    VFAS   = { value = 16.8 },   -- 4S @ 4.20V/cell
    ["1RSS"] = { value = -55 },
    ["2RSS"] = { value = -60 },
    RQly   = { value = 98 },
    RFMD   = { value = 3 },      -- -> 100 Hz per PACKET_RATE_FROM_RFMD
    Curr   = { value = 8.2 },
    Sats   = { value = 12 },
    TPWR   = { value = 100 },
    FM     = { value = "ACRO" },
    ANT    = { value = 0 },
    Capa   = { value = 450 },
  },
  flightMode = { 0, "ACRO" },
  time = 0,
}
