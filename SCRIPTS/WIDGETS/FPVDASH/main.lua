local WIDGET_ROOTS = {
  "/WIDGETS/FPVDASH/",
  "/SCRIPTS/WIDGETS/FPVDASH/",
  "WIDGETS/FPVDASH/",
  "SCRIPTS/WIDGETS/FPVDASH/",
  "",
}

local function loadModule(relativePath)
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

local layoutModule    = loadModule("layout/layout.lua")
local slotsModule     = loadModule("layout/slots.lua")
local telemetryRead   = loadModule("telemetry/read.lua")
local telemetryState  = loadModule("telemetry/state.lua")

local topbarRenderer = loadModule("render/topbar.lua")
local sticksRenderer = loadModule("render/sticks.lua")
local cardsRenderer  = loadModule("render/cards.lua")

local function zoneChanged(widget)
  local z = widget.zone
  local c = widget.cachedZone

  if not c then
    return true
  end

  return z.x ~= c.x or z.y ~= c.y or z.w ~= c.w or z.h ~= c.h
end

local function recomputeLayout(widget)
  if not layoutModule or not slotsModule then
    widget.layout = nil
    widget.slots = nil
    return
  end

  widget.layout = layoutModule.compute(widget.zone)
  widget.slots = slotsModule.compute(widget.layout)
  widget.cachedZone = {
    x = widget.zone.x,
    y = widget.zone.y,
    w = widget.zone.w,
    h = widget.zone.h,
  }
end

local function create(zone, options)
  return {
    zone = zone,
    options = options,
    telemetry = nil,
    state = nil,
    layout = nil,
    slots = nil,
    cachedZone = nil,
  }
end

local function update(widget, options)
  widget.options = options

  if zoneChanged(widget) then
    recomputeLayout(widget)
  end
end

local function background(widget)
  -- No background work for layout skeleton pass.
end

local function refresh(widget, event, touchState)
  if telemetryRead and telemetryRead.snapshot then
    widget.telemetry = telemetryRead.snapshot()
  else
    widget.telemetry = nil
  end

  if telemetryState and telemetryState.evaluate then
    widget.state = telemetryState.evaluate(widget.telemetry)
  else
    widget.state = nil
  end

  if zoneChanged(widget) or not widget.layout or not widget.slots then
    recomputeLayout(widget)
  end

  if not widget.layout then
    lcd.drawText(widget.zone.x + 2, widget.zone.y + 2, "Layout module unavailable", SMLSIZE)
    return
  end

  lcd.drawRectangle(widget.zone.x, widget.zone.y, widget.zone.w, widget.zone.h)

  if topbarRenderer and topbarRenderer.drawSkeleton then
    topbarRenderer.drawSkeleton(widget.layout.topBar, widget.telemetry, widget.state)
  end

  if sticksRenderer and sticksRenderer.drawSkeleton then
    sticksRenderer.drawSkeleton(widget.layout.stickMonitor, widget.telemetry, widget.state)
  end

  if cardsRenderer and cardsRenderer.draw then
    cardsRenderer.draw(widget.layout, widget.slots, widget.telemetry, widget.state)
  end

  local debugY = widget.zone.y + widget.zone.h - 10
  local debugX = widget.zone.x + 2

  if widget.telemetry and widget.telemetry.connected then
    local line = string.format(
      "LQ:%d RSSI:%d BAT:%.1fV SAT:%d TXP:%dmW",
      widget.telemetry.linkQuality or 0,
      widget.telemetry.rssi or 0,
      widget.telemetry.battery or 0,
      widget.telemetry.satellites or 0,
      widget.telemetry.txPower or 0
    )
    lcd.drawText(debugX, debugY, line, SMLSIZE)
  else
    -- Show which sensor names the radio actually exposes to help diagnose
    -- sensor-name mismatches between receivers / firmware versions.
    local scanLine = "NO RX TELEMETRY"

    if telemetryRead and telemetryRead.scanSensors then
      local found = telemetryRead.scanSensors()
      if #found > 0 then
        local parts = {}
        for i = 1, math.min(#found, 5) do
          parts[i] = found[i]
        end
        scanLine = table.concat(parts, " ")
      end
    end

    lcd.drawText(debugX, debugY, scanLine, SMLSIZE)
  end
end

return {
  name = "Telemetry Dashboard",
  options = {},
  create = create,
  update = update,
  refresh = refresh,
  background = background,
}
