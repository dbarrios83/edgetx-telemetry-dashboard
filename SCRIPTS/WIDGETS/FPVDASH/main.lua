local WIDGET_ROOTS = {
  "/SCRIPTS/WIDGETS/FPVDASH/",
  "/WIDGETS/FPVDASH/",
  "SCRIPTS/WIDGETS/FPVDASH/",
  "WIDGETS/FPVDASH/",
  "",
}

local function loadModule(relativePath)
  if not loadScript then return nil end

  for i = 1, #WIDGET_ROOTS do
    local chunk = loadScript(WIDGET_ROOTS[i] .. relativePath)
    if chunk then return chunk() end
  end

  return nil
end

local layoutModule    = loadModule("layout/layout.lua")
local slotsModule     = loadModule("layout/slots.lua")
local telemetryRead   = loadModule("telemetry/read.lua")
local telemetryState  = loadModule("telemetry/state.lua")

local topbarRenderer  = loadModule("render/topbar.lua")
local sticksRenderer  = loadModule("render/sticks.lua")
local cardsRenderer   = loadModule("render/cards.lua")
local contextRenderer = loadModule("render/context.lua")
local timersRenderer  = loadModule("render/timers.lua")
local footerRenderer  = loadModule("render/footer.lua")

local _WHITE = (type(WHITE) == "number") and WHITE or 0xFFFF
local _BLACK = 0x0000

local LIGHT_TEXT_COLOR = 0x9CF3

--------------------------------------------------
-- Transparency mapping
--------------------------------------------------

local TRANSP_VALUES = {6, 8, 10, 12}

--------------------------------------------------
-- Widget options
--------------------------------------------------

local OPTION_COMBO = (type(COMBO) == "number" and COMBO) or (type(CHOICE) == "number" and CHOICE)

local WIDGET_OPTIONS

if OPTION_COMBO then
  WIDGET_OPTIONS = {
    { "darkTheme", BOOL, 1 },
    { "transpLevel", OPTION_COMBO, 1, { "1","2","3","4" } },
  }
else
  WIDGET_OPTIONS = {
    { "darkTheme", BOOL, 1 },
    { "transpLevel", VALUE, 1, 0, 3 },
  }
end

--------------------------------------------------
-- Transparency resolver
--------------------------------------------------

local function resolveTransparencyValue(raw)

  local v = raw

  if type(v) == "table" then
    v = v.value or v.val
  end

  if type(v) == "string" then
    v = tonumber(v)
  end

  if type(v) ~= "number" then
    return 8
  end

  local n = math.floor(v + 0.5)

  -- user values (1..4)
  if n >= 1 and n <= 4 then
    return TRANSP_VALUES[n]
  end

  -- combo index (0..3)
  if n >= 0 and n <= 3 then
    return TRANSP_VALUES[n + 1]
  end

  return 8
end

--------------------------------------------------
-- Theme resolver
--------------------------------------------------

local function resolveTheme(options)

  local isDark = true

  if options and (options.darkTheme == 0 or options.darkTheme == false) then
    isDark = false
  end

  local transparency_value = resolveTransparencyValue(options and options.transpLevel or 1)

  return {
    isLight = not isDark,
    bgColor = isDark and _BLACK or _WHITE,
    textColor = isDark and _WHITE or LIGHT_TEXT_COLOR,
    iconFolder = isDark and "dark" or "light",
    transparency = transparency_value,
  }
end

--------------------------------------------------
-- Transparency background
--------------------------------------------------

local function drawSectionWash(rect, theme)

  if not rect or not lcd.drawFilledRectangle then return end

  if type(CUSTOM_COLOR) == "number" and lcd.setColor then

    lcd.setColor(CUSTOM_COLOR, theme.bgColor)

    -- REQUIRED transparency line
    pcall(
      lcd.drawFilledRectangle,
      rect.x,
      rect.y,
      rect.w,
      rect.h,
      CUSTOM_COLOR,
      theme.transparency
    )

  end
end

--------------------------------------------------
-- Layout detection
--------------------------------------------------

local function zoneChanged(widget)

  local z = widget.zone
  local c = widget.cachedZone

  if not c then return true end

  return z.x ~= c.x or z.y ~= c.y or z.w ~= c.w or z.h ~= c.h
end

--------------------------------------------------
-- Layout compute
--------------------------------------------------

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

--------------------------------------------------
-- Create
--------------------------------------------------

local function create(zone, options)

  local theme = resolveTheme(options)

  return {
    zone = zone,
    options = options,
    telemetry = nil,
    state = nil,
    layout = nil,
    slots = nil,
    cachedZone = nil,
    theme = theme,
  }
end

--------------------------------------------------
-- Update
--------------------------------------------------

local function update(widget, options)

  widget.options = options
  widget.theme = resolveTheme(options)

  if zoneChanged(widget) then
    recomputeLayout(widget)
  end
end

--------------------------------------------------
-- Background
--------------------------------------------------

local function background(widget)
end

--------------------------------------------------
-- Refresh
--------------------------------------------------

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

  local theme = resolveTheme(widget.options)
  widget.theme = theme

  if topbarRenderer and topbarRenderer.draw then
    drawSectionWash(widget.layout.topBar, theme)
    topbarRenderer.draw(widget.layout.topBar, widget.telemetry, widget.state, theme)
  end

  if sticksRenderer and sticksRenderer.draw then
    drawSectionWash(widget.layout.stickMonitor, theme)
    sticksRenderer.draw(widget.layout.stickMonitor, widget.telemetry, widget.state, theme)
  end

  if contextRenderer and contextRenderer.draw and widget.layout.primaryGrid then

    drawSectionWash(widget.layout.primaryGrid, theme)
    contextRenderer.draw(widget.layout.primaryGrid, widget.telemetry, widget.state, theme)

    drawSectionWash(widget.layout.contextRow, theme)

    if timersRenderer and timersRenderer.draw then
      timersRenderer.draw(widget.layout.contextRow, widget.telemetry, widget.state, theme)
    end

    if widget.layout.footerRow then
      drawSectionWash(widget.layout.footerRow, theme)

      if footerRenderer and footerRenderer.draw then
        footerRenderer.draw(widget.layout.footerRow, widget.telemetry, widget.state, theme)
      end
    end
  end
end

return {
  name = "Telemetry Dashboard",
  options = WIDGET_OPTIONS,
  create = create,
  update = update,
  refresh = refresh,
  background = background,
}