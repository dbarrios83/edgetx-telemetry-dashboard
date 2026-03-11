local function create(zone, options)
  return {
    zone = zone,
    options = options,
  }
end

local function update(widget, options)
  widget.options = options
end

local function background(widget)
  -- Placeholder for background telemetry processing.
end

local function refresh(widget, event, touchState)
  -- Placeholder render routine.
  lcd.drawText(widget.zone.x, widget.zone.y, "EdgeTX Dashboard", SMLSIZE)
end

return {
  name = "Telemetry Dashboard",
  options = {},
  create = create,
  update = update,
  refresh = refresh,
  background = background,
}
