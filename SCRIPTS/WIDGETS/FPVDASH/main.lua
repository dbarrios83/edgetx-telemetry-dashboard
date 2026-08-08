local WIDGET_ROOTS = {
  "/SCRIPTS/WIDGETS/FPVDASH/",
  "/WIDGETS/FPVDASH/",
  "SCRIPTS/WIDGETS/FPVDASH/",
  "WIDGETS/FPVDASH/",
  "",
}

local function loadModule(relativePath)
  if not loadScript then return nil end

  -- Shared across every file with a copy of this loader: loadScript has
  -- no built-in caching the way Lua's require() does, so a module
  -- loaded from multiple call sites (e.g. render/primitives.lua,
  -- independently loaded by all five renderers) would otherwise execute
  -- -- and hold in memory -- one separate copy per caller instead of
  -- one shared copy (found in external review, 2026-08-07).
  _G.__FPVDASH_MODULE_CACHE__ = _G.__FPVDASH_MODULE_CACHE__ or {}
  local cache = _G.__FPVDASH_MODULE_CACHE__
  if cache[relativePath] ~= nil then return cache[relativePath] or nil end

  for i = 1, #WIDGET_ROOTS do
    local chunk = loadScript(WIDGET_ROOTS[i] .. relativePath)
    if chunk then
      local result = chunk()
      cache[relativePath] = result or false
      return result
    end
  end

  cache[relativePath] = false
  return nil
end

-- Deferred: EdgeTX loads every installed widget's top-level chunk whenever
-- a model is selected, even widgets never placed in a zone (see EdgeTX's
-- widget-scripts documentation: "All widget scripts on the SD card are
-- loaded into memory when the model is selected, even widgets that are
-- not used" -- and its guidance to use loadScript() to load code
-- dynamically rather than loading everything at the top level). Loading
-- all nine submodules unconditionally here paid that cost for every
-- installed-but-unused instance. They now stay nil until
-- ensureModulesLoaded() runs them, on first create().
local layoutModule
local telemetryRead
local telemetryState
local elrsModule

local topbarRenderer
local sticksRenderer
local contextRenderer
local timersRenderer
local footerRenderer

local modulesLoaded = false

-- Loads every submodule exactly once. Safe to call from both create() and
-- refresh() -- the flag makes repeat calls a no-op. name/options below do
-- not depend on any of these, so EdgeTX can read widget metadata (before
-- the widget is ever instantiated) without triggering a load.
local function ensureModulesLoaded()
  if modulesLoaded then return end
  modulesLoaded = true

  layoutModule    = loadModule("layout/layout.lua")
  telemetryRead   = loadModule("telemetry/read.lua")
  telemetryState  = loadModule("telemetry/state.lua")
  elrsModule      = loadModule("telemetry/elrs.lua")

  topbarRenderer  = loadModule("render/topbar.lua")
  sticksRenderer  = loadModule("render/sticks.lua")
  contextRenderer = loadModule("render/context.lua")
  timersRenderer  = loadModule("render/timers.lua")
  footerRenderer  = loadModule("render/footer.lua")
end

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
    { "transpLvl", OPTION_COMBO, 1, { "1","2","3","4" } },
    { "stickMode", OPTION_COMBO, 1, { "Auto","1","2","3","4" } },
  }
else
  WIDGET_OPTIONS = {
    { "darkTheme", BOOL, 1 },
    { "transpLvl", VALUE, 1, 0, 3 },
    { "stickMode", VALUE, 0, 0, 4 },
  }
end

--------------------------------------------------
-- Transparency resolver
--------------------------------------------------

-- EdgeTX stores a Choice/Combo option's value 1-based: the settings
-- screen's Choice control is 0-based internally, but reads/writes it via
-- `getUnsignedValue(optIdx) - 1` (radio/src/gui/colorlcd/mainview/
-- widget_settings.cpp), so Lua receives 1..N -- matching our choice
-- labels "1".."4". A plain VALUE option, declared here with min=0, is
-- genuinely 0-based. These two conventions must not be guessed from the
-- raw number's range (the old code tried 1..4 first, which silently
-- misread the VALUE option's 0-based range) -- the already-known
-- OPTION_COMBO flag says which convention actually applies.
local function resolveTransparencyValue(raw)

  local v = raw

  if type(v) == "table" then
    v = v.value or v.val
  end

  if type(v) == "string" then
    v = tonumber(v)
  end

  if type(v) ~= "number" then
    return TRANSP_VALUES[1]
  end

  local n = math.floor(v + 0.5)

  if OPTION_COMBO then
    if n >= 1 and n <= 4 then
      return TRANSP_VALUES[n]
    end
  else
    if n >= 0 and n <= 3 then
      return TRANSP_VALUES[n + 1]
    end
  end

  return TRANSP_VALUES[1]
end

--------------------------------------------------
-- Stick mode resolver
--------------------------------------------------

-- EdgeTX's Stick Mode (Radio Setup > Stick Mode) determines which
-- physical gimbal drives Rudder/Elevator/Throttle/Aileron -- render/
-- sticks.lua needs to know it to put the right axis in the right on-
-- screen box. `getStickMode()` returns it directly (1-4). Its own doc
-- comment in EdgeTX's source (radio/src/lua/api_general.cpp) says
-- "Introduced in 3.0", but that's stale: checked directly against the
-- tagged v2.12.0 and v2.12.1 source, `getStickMode`/`luaGetStickMode`
-- is already present and registered there -- this project's documented
-- 2.12 floor (compatibility-matrix.md Section 1) already has it. So
-- "Auto" (the default) resolves via `getStickMode()` for every
-- supported version in practice. The explicit 1-4 override still exists
-- as a manual escape hatch -- same pattern `transpLvl` above already
-- establishes -- for any firmware that doesn't provide it, falling back
-- to Mode 2 (this widget's original, always-Mode-2 behavior) if neither
-- is available.
local DEFAULT_STICK_MODE = 2

local function resolveStickModeOption(raw)

  local v = raw

  if type(v) == "table" then
    v = v.value or v.val
  end

  if type(v) == "string" then
    v = tonumber(v)
  end

  if type(v) ~= "number" then
    return nil
  end

  local n = math.floor(v + 0.5)

  if OPTION_COMBO then
    -- Choice labels are {"Auto","1","2","3","4"}, 1-based; n==1 is Auto.
    if n >= 2 and n <= 5 then
      return n - 1
    end
  else
    -- Plain VALUE option, 0-based; n==0 is Auto.
    if n >= 1 and n <= 4 then
      return n
    end
  end

  return nil
end

local function resolveStickMode(options)

  local override = resolveStickModeOption(options and options.stickMode)
  if override then
    return override
  end

  if type(getStickMode) == "function" then
    local ok, mode = pcall(getStickMode)
    if ok and type(mode) == "number" and mode >= 1 and mode <= 4 then
      return mode
    end
  end

  return DEFAULT_STICK_MODE
end

--------------------------------------------------
-- Theme resolver
--------------------------------------------------

local function resolveTheme(options)

  local isDark = true

  if options and (options.darkTheme == 0 or options.darkTheme == false) then
    isDark = false
  end

  local transparency_value = resolveTransparencyValue(options and options.transpLvl or 1)

  return {
    isLight = not isDark,
    bgColor = isDark and _BLACK or _WHITE,
    textColor = isDark and _WHITE or LIGHT_TEXT_COLOR,
    iconFolder = isDark and "dark" or "light",
    transparency = transparency_value,
    stickMode = resolveStickMode(options),
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

  if not layoutModule then
    widget.layout = nil
    return
  end

  widget.layout = layoutModule.compute(widget.zone)

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

  ensureModulesLoaded()

  local theme = resolveTheme(options)

  return {
    zone = zone,
    options = options,
    telemetry = nil,
    state = nil,
    layout = nil,
    cachedZone = nil,
    theme = theme,
    elrsState = elrsModule and elrsModule.init() or nil,
    -- Own telemetry-reading session (sensor-ID cache, battery latch) --
    -- must not be shared with any other widget instance. See
    -- telemetry/read.lua's M.init().
    telemetrySession = telemetryRead and telemetryRead.init() or nil,
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

  -- Defensive: EdgeTX always calls create() before refresh() for a given
  -- instance, so modules are normally already loaded by here. This guard
  -- is a single boolean check (see ensureModulesLoaded()) and only matters
  -- if refresh() is ever reached without a preceding create() call.
  ensureModulesLoaded()

  -- Advance ELRS version polling (CRSF device-info request/response).
  if elrsModule and widget.elrsState then
    elrsModule.update(widget.elrsState)
  end

  -- Resolved before the snapshot so RFMD decoding can pick the correct
  -- version-specific rate table (see telemetry/read.lua).
  local elrsMajorVersion = nil
  if elrsModule and widget.elrsState and elrsModule.getMajorVersion then
    elrsMajorVersion = elrsModule.getMajorVersion(widget.elrsState)
  end

  if telemetryRead and telemetryRead.snapshot and widget.telemetrySession then
    widget.telemetry = telemetryRead.snapshot(widget.telemetrySession, elrsMajorVersion)
  else
    widget.telemetry = nil
  end

  -- Attach resolved ELRS version so footer renderer can display it.
  if widget.telemetry and elrsModule then
    widget.telemetry.elrsVersion = elrsModule.getString(widget.elrsState)
  end

  if telemetryState and telemetryState.evaluate then
    widget.state = telemetryState.evaluate(widget.telemetry)
  else
    widget.state = nil
  end

  if zoneChanged(widget) or not widget.layout then
    recomputeLayout(widget)
  end

  if not widget.layout then
    lcd.drawText(widget.zone.x + 2, widget.zone.y + 2, "Layout module unavailable", SMLSIZE)
    return
  end

  -- widget.theme is already current: create()/update() resolve it from
  -- options whenever EdgeTX calls them, which is the only time options
  -- can actually change. Recomputing it here every frame regardless was
  -- pure per-frame allocation churn for a value that hadn't changed.
  local theme = widget.theme

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

    -- footerRow is always present now (layout.lua no longer hides it
    -- below a height threshold -- Multi-Resolution Layout, Task 2).
    drawSectionWash(widget.layout.footerRow, theme)

    if footerRenderer and footerRenderer.draw then
      footerRenderer.draw(widget.layout.footerRow, widget.telemetry, widget.state, theme)
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