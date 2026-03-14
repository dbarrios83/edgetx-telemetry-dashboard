local WIDGET_ROOTS = {
  "/SCRIPTS/WIDGETS/FPVDASH/",
  "/WIDGETS/FPVDASH/",
  "SCRIPTS/WIDGETS/FPVDASH/",
  "WIDGETS/FPVDASH/",
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

local _WHITE  = (type(WHITE)  == "number") and WHITE  or 0xFFFF

local function themeColor(themeToken, fallback)
  if lcd and type(lcd.getThemeColor) == "function" and type(themeToken) == "number" then
    local ok, c = pcall(lcd.getThemeColor, themeToken)
    if ok and type(c) == "number" then
      return c
    end
  end
  return fallback
end

local _THEME_BG = themeColor((type(THEME_BG) == "number") and THEME_BG or nil, _WHITE)

local function drawSectionWash(rect)
  if not rect or not lcd.drawFilledRectangle then
    return
  end

  if type(CUSTOM_COLOR) == "number" and lcd.setColor then
    lcd.setColor(CUSTOM_COLOR, _THEME_BG)
    pcall(lcd.drawFilledRectangle, rect.x, rect.y, rect.w, rect.h, CUSTOM_COLOR,10)
  end
end

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

  if topbarRenderer and topbarRenderer.draw then
    drawSectionWash(widget.layout.topBar)
    topbarRenderer.draw(widget.layout.topBar, widget.telemetry, widget.state)
  elseif topbarRenderer and topbarRenderer.drawSkeleton then
    topbarRenderer.drawSkeleton(widget.layout.topBar, widget.telemetry, widget.state)
  end

  if sticksRenderer and sticksRenderer.draw then
    drawSectionWash(widget.layout.stickMonitor)
    sticksRenderer.draw(widget.layout.stickMonitor, widget.telemetry, widget.state)
  elseif sticksRenderer and sticksRenderer.drawSkeleton then
    sticksRenderer.drawSkeleton(widget.layout.stickMonitor, widget.telemetry, widget.state)
  end

  if cardsRenderer and cardsRenderer.draw then
    drawSectionWash(widget.layout.primaryGrid)
    drawSectionWash(widget.layout.contextRow)
    drawSectionWash(widget.layout.diagnostics)
    cardsRenderer.draw(widget.layout, widget.slots, widget.telemetry, widget.state)
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
