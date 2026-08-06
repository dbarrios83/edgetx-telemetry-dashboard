-- Luacheck configuration for the FPVDASH EdgeTX widget and its desktop
-- Lua test harness.
--
-- EdgeTX exposes its Lua API (getValue, lcd, Bitmap, color/draw-flag
-- constants, etc.) as globals -- that is how the EdgeTX Lua runtime
-- actually works, not a code smell, so luacheck needs to be told about
-- them explicitly rather than flagging every one as an undefined global.
-- The list below was built by grepping SCRIPTS/WIDGETS/FPVDASH for every
-- EdgeTX-provided identifier actually referenced (see the Architecture &
-- Packaging Hardening project's Task 4 for the audit); keep it in sync
-- when new EdgeTX APIs are used.

std = "max" -- union of Lua 5.1-5.4 stdlib, since the test harness runs on any of them (see README.md)

-- EdgeTX widgets are called through fixed lifecycle signatures
-- (create(zone, options), update(widget, options), refresh(widget, event,
-- touchState), background(widget)) and fixed renderer signatures
-- (M.draw(bounds, telemetry, state, theme)) -- an implementation not
-- needing every parameter (e.g. refresh() ignoring event/touchState,
-- background() ignoring widget) is normal here, not a real code-quality
-- issue, so unused-argument warnings would just be noise.
unused_args = false

read_globals = {
  -- Sensor / telemetry read API
  "getValue", "getFieldInfo", "getFlightMode", "getRSSI", "getTime",
  "getDateTime", "getVersion", "model",
  -- CRSF telemetry bus (ELRS device-info request/response)
  "crossfireTelemetryPush", "crossfireTelemetryPop",
  -- EdgeTX's substitute for require() -- see main.lua/telemetry/read.lua
  "loadScript",
  -- Drawing API
  "lcd", "Bitmap",
  -- Color constants
  "WHITE", "BLACK", "RED", "YELLOW", "GREEN",
  "GREY", "GRAY", "DARKGREY", "DARKGRAY", "LIGHTGREY", "LIGHTGRAY",
  "CUSTOM_COLOR", "TEXT_COLOR",
  "THEME_PRIMARY", "THEME_SECONDARY", "THEME_FOCUS", "THEME_WARNING",
  -- Text-size / draw-flag constants
  "SMLSIZE", "MIDSIZE", "DBLSIZE", "BOLD", "SHADOWED", "SOLID", "FORCE",
  -- Widget-option type constants
  "BOOL", "VALUE", "COMBO", "CHOICE",
}

files["tests/mock_edgetx.lua"] = {
  -- This file's entire job is installing (and removing) the EdgeTX
  -- globals above for the desktop test harness, so unlike every other
  -- file here, it legitimately assigns to them.
  globals = read_globals,
}
