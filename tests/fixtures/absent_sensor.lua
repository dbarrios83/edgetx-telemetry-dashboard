-- Primary aliases (VFAS, RQly) were never discovered on this model; only
-- the secondary/generic aliases (RxBt, LQ) are present. Exercises alias
-- fallback rather than a fully-populated primary sensor set.
return {
  sensors = {
    RxBt   = { value = 15.2 },
    LQ     = { value = 95 },
    RFMD   = { value = 5 },   -- -> 250 Hz
    TPWR   = { value = 250 },
    ["1RSS"] = { value = -70 },
  },
  flightMode = nil,
  rssiStream = 60,
  time = 0,
}
