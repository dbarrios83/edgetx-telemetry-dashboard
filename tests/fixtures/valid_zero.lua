-- Sensors are discovered and connected, but some legitimately report an
-- exact zero reading (idle current draw, antenna index 0). These must be
-- rendered as real values, not confused with "sensor absent".
return {
  sensors = {
    VFAS = { value = 16.8 },
    RQly = { value = 95 },
    RFMD = { value = 1 },   -- -> 25 Hz
    TPWR = { value = 100 },
    Curr = { value = 0 },   -- valid idle current
    ANT  = { value = 0 },   -- valid antenna index (ANT1)
  },
  flightMode = nil,
  time = 0,
}
