local ICON_BASE_PATH = "/SCRIPTS/WIDGETS/TELEMETRY/icons/"

local ICON_FILES = {
  battery = "battery.png",
  signal = "signal.png",
  sat = "sat.png",
  antenna = "antenna.png",
  current = "current.png",
  radio = "radio.png",
  link = "link.png",
  link_off = "link_off.png",
  clock = "clock.png",
  drone = "drone.png",
  rfmd = "rfmd.png",
}

local function loadIcons()
  local icons = {}
  for name, fileName in pairs(ICON_FILES) do
    icons[name] = Bitmap.open(ICON_BASE_PATH .. fileName)
  end

  return icons
end

local function create(zone, options)
  return {
    zone = zone,
    options = options,
    icons = loadIcons(),
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
