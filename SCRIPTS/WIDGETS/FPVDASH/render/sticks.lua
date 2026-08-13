-- Stick monitor renderer.
-- Renders two gimbal monitors using live radio-side stick inputs.

local M = {}

-- Mirrors main.lua's own module-loading fallback order (see
-- telemetry/read.lua's loadSiblingModule for the same pattern) so this
-- file can load its sibling render/primitives.lua on both a real radio
-- and the desktop test harness.
local WIDGET_ROOTS = {
  "/SCRIPTS/WIDGETS/FPVDASH/",
  "/WIDGETS/FPVDASH/",
  "SCRIPTS/WIDGETS/FPVDASH/",
  "WIDGETS/FPVDASH/",
  "",
}

local function loadSiblingModule(relativePath)
  if not loadScript then
    return nil
  end

  -- Shared across every file with a copy of this loader: loadScript has
  -- no built-in caching the way Lua's require() does, so a module
  -- loaded from multiple call sites (e.g. render/primitives.lua,
  -- independently loaded by all five renderers) would otherwise execute
  -- -- and hold in memory -- one separate copy per caller instead of
  -- one shared copy (found in external review, 2026-08-07).
  _G.__FPVDASH_MODULE_CACHE__ = _G.__FPVDASH_MODULE_CACHE__ or {}
  local cache = _G.__FPVDASH_MODULE_CACHE__
  if cache[relativePath] ~= nil then
    return cache[relativePath] or nil
  end

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

local primitivesModule = loadSiblingModule("render/primitives.lua")

local _WHITE  = (type(WHITE) == "number") and WHITE or 0xFFFF
local _GREEN  = (type(GREEN) == "number") and GREEN or _WHITE
local _YELLOW = (type(YELLOW) == "number") and YELLOW or _WHITE
local _RED    = (type(RED) == "number") and RED or _YELLOW
local _BLACK  = 0x0000

local _SMLSIZE = (type(SMLSIZE) == "number") and SMLSIZE or 0

local BATTERY_ICON_W = 20
local BATTERY_ICON_H = 32
local LQ_ICON_W = 30
local LQ_ICON_H = 30

-- Sticks panel grid: Link Quality / Sticks / Receiver Battery, in that
-- order (Grid-aligned top bar and sticks, Task 2). Cells are adjacent with
-- no inter-cell gap -- spacing comes entirely from each cell's content
-- being a centered group smaller than the cell itself.
local GRID_WEIGHTS = { 30, 40, 30 }

-- Fallback when theme.stickMode is missing or invalid (e.g. a caller
-- that doesn't thread main.lua's resolved theme through) -- matches this
-- widget's original, always-Mode-2 behavior. See main.lua's
-- resolveStickMode() for how theme.stickMode itself is normally derived.
local DEFAULT_STICK_MODE = 2

-- Stick monitor visual tuning.
local SHOW_STICK_AXIS = false
local SHOW_STICK_VALUES = false
-- Both re-enabled (Improved Stick Grid project, 2026-08-13): the actual
-- root cause of the invisible grid/background was malformed color
-- values (raw RGB565 hex passed where EdgeTX expects lcd.RGB()'s packed
-- 32-bit flags -- see STICK_GRID_COLORS above and
-- docs/platform/compatibility-matrix.md Section 12), not primitive
-- choice or call count. The bisection toggles are kept (rather than
-- removed) so a future regression can isolate background vs. grid again
-- quickly if needed.
local DRAW_PAD_BACKGROUND = true
local DRAW_PAD_GRID = true
local STICK_BORDER_THICKNESS = 2
-- One-line border color override for visual testing.
-- Set to: "theme", "white", "red", "green", "yellow", "black", "gray", "grey"
-- or an already-packed EdgeTX color value, e.g. lcd.RGB(0xF8, 0x00, 0x00)
-- -- NOT a raw RGB565 hex literal like 0xF800 (see STICK_GRID_COLORS'
-- rgbColor() above and docs/platform/compatibility-matrix.md Section 12:
-- EdgeTX packs RGB565 into the upper half of a 32-bit flags value, so a
-- raw 16-bit literal here would be malformed the same way). nil behaves
-- like "theme".
local STICK_BORDER_COLOR = "white"
local STICK_BOX_SIZE_REDUCTION = 5
local STICK_VALUES_LINE_H = 8
local STICK_VALUES_LEFT_X_NUDGE = 20
local STICK_VALUES_RIGHT_X_NUDGE = -50
local STICK_VALUES_TOP_OUTSIDE_GAP = 7
local STICK_VALUES_BOTTOM_OUTSIDE_GAP = -1
local STICK_VALUES_TOP_NUDGE = 0
local STICK_VALUES_BOTTOM_NUDGE = 0

-- RX battery block: icon stacked above value/text, both centered as one
-- vertical group (render/primitives.lua's centerGroupVertical) inside the
-- Receiver Battery cell. Second Companion pass (2026-08-07): the prior
-- horizontal icon+text layout at _MIDSIZE both mis-centered vertically
-- (RX_BAT_TEXT_H's estimate was still off) and, at this cell's width
-- (30% of the widget), ran the longer battery strings (e.g. "3.68V
-- (6S)") off the right edge of the screen. Stacking vertically and
-- dropping to _SMLSIZE fixes both: the group is far narrower, and each
-- part's own height drives centering, with no horizontal overflow risk
-- left to guess at. EdgeTX widget text has no runtime glyph-metrics API,
-- so RX_BAT_TEXT_CHAR_W/RX_BAT_TEXT_H remain documented estimates rather
-- than measured values.
local RX_BAT_TEXT_CHAR_W = 5
local RX_BAT_TEXT_H = 8
local RX_BAT_ICON_TEXT_GAP = 4

-- Link-quality block uses the same stacked layout and text metrics as
-- the RX battery block, centered the same way inside its own cell.
local LQ_TEXT_CHAR_W = RX_BAT_TEXT_CHAR_W
local LQ_TEXT_H = RX_BAT_TEXT_H
local LQ_ICON_TEXT_GAP = RX_BAT_ICON_TEXT_GAP

local function themeColor(themeToken, fallback)
  if lcd and type(lcd.getThemeColor) == "function" and type(themeToken) == "number" then
    local ok, c = pcall(lcd.getThemeColor, themeToken)
    if ok and type(c) == "number" then
      return c
    end
  end
  return fallback
end

-- Produces a correctly packed EdgeTX color via lcd.RGB(r, g, b) (8-bit
-- components), falling back to a provided EdgeTX-safe value (a named
-- constant, never another raw hex literal) if lcd.RGB isn't available.
-- Real-hardware finding (Improved Stick Grid project, 2026-08-13, see
-- docs/platform/compatibility-matrix.md Section 12): EdgeTX packs the
-- 16-bit RGB565 color into the upper half of a 32-bit flags value, so a
-- raw RGB565 hex literal passed directly to an lcd draw function is a
-- malformed color, not merely the wrong shade. Every custom (non-
-- EdgeTX-constant) color in this renderer -- grid/background colors
-- below, and the gray border-color fallbacks further down -- goes
-- through this rather than a hard-coded hex value.
local function rgbColor(r, g, b, fallback)
  if lcd and type(lcd.RGB) == "function" then
    local ok, c = pcall(lcd.RGB, r, g, b)
    if ok and type(c) == "number" then
      return c
    end
  end
  return fallback
end

local _THEME_PRIMARY = themeColor((type(THEME_PRIMARY) == "number") and THEME_PRIMARY or nil, _WHITE)
local _THEME_SECONDARY = themeColor((type(THEME_SECONDARY) == "number") and THEME_SECONDARY or nil, _WHITE)

local function setCustomColor(color)
  if lcd and type(lcd.setColor) == "function" and type(CUSTOM_COLOR) == "number" and type(color) == "number" then
    lcd.setColor(CUSTOM_COLOR, color)
  end
end

local BATTERY_ICONS = {
  full = nil,
  ok = nil,
  warn = nil,
  low = nil,
  dead = nil,
}

local CONNECTION_ICONS = {
  ok = nil,
  warn = nil,
  low = nil,
  dead = nil,
}

local _iconsLoaded = false
local _TEXT_COLOR = _WHITE
local _TEXT_SHADOW_COLOR = _BLACK
local _LIGHT_TEXT_SHADOW = _WHITE

-- Shadow color here is theme-aware (see _TEXT_SHADOW_COLOR, set from
-- theme.isLight in M.draw()) -- deliberately different from render/
-- context.lua's/footer.lua's/timers.lua's simpler heuristic; see
-- render/primitives.lua's header comment for why that's preserved
-- per-renderer rather than unified.
local function drawShadowText(x, y, text, size, color)
  local shadowColor = (type(_TEXT_SHADOW_COLOR) == "number") and _TEXT_SHADOW_COLOR or _BLACK
  if primitivesModule and primitivesModule.drawShadowText then
    primitivesModule.drawShadowText(x, y, text, size, color, shadowColor)
  end
end

local openBitmapFromCandidates = (primitivesModule and primitivesModule.openBitmapFromCandidates)
  or function() return nil end

local gridCells = (primitivesModule and primitivesModule.gridCells)
  or function() return {} end
local centerGroup = (primitivesModule and primitivesModule.centerGroup)
  or function() return {} end
local centerGroupVertical = (primitivesModule and primitivesModule.centerGroupVertical)
  or function() return {} end

local function ensureIconsLoaded(theme)
  if _iconsLoaded then return end
  if not Bitmap or type(Bitmap.open) ~= "function" then return end

  local roots = {
    "/WIDGETS/FPVDASH/icons/",
    "/SCRIPTS/WIDGETS/FPVDASH/icons/",
    "WIDGETS/FPVDASH/icons/",
    "SCRIPTS/WIDGETS/FPVDASH/icons/",
  }

  local linkRoots = {
    "/WIDGETS/FPVDASH/icons/link/",
    "/SCRIPTS/WIDGETS/FPVDASH/icons/link/",
    "WIDGETS/FPVDASH/icons/link/",
    "SCRIPTS/WIDGETS/FPVDASH/icons/link/",
  }

  local batteryRoots = {
    "/WIDGETS/FPVDASH/icons/battery/",
    "/SCRIPTS/WIDGETS/FPVDASH/icons/battery/",
    "WIDGETS/FPVDASH/icons/battery/",
    "SCRIPTS/WIDGETS/FPVDASH/icons/battery/",
  }

  BATTERY_ICONS.full = openBitmapFromCandidates(batteryRoots, { "battery-full.png" })
  BATTERY_ICONS.ok = openBitmapFromCandidates(batteryRoots, { "battery-ok.png" })
  BATTERY_ICONS.warn = openBitmapFromCandidates(batteryRoots, { "battery-warn.png" })
  BATTERY_ICONS.low = openBitmapFromCandidates(batteryRoots, { "battery-low.png" })
  BATTERY_ICONS.dead = openBitmapFromCandidates(batteryRoots, { "battery-dead.png" })

  CONNECTION_ICONS.ok = openBitmapFromCandidates(linkRoots, { "connection-ok.png" })
  CONNECTION_ICONS.warn = openBitmapFromCandidates(linkRoots, { "connection-warn.png" })
  CONNECTION_ICONS.low = openBitmapFromCandidates(linkRoots, { "connection-low.png" })
  CONNECTION_ICONS.dead = openBitmapFromCandidates(linkRoots, { "connection-dead.png" })

  if not CONNECTION_ICONS.ok then
    -- Backward-compatible fallback when the new link folder is missing.
    CONNECTION_ICONS.ok = openBitmapFromCandidates(roots, {
      "link_connected.png",
      "link.png",
    })
  end

  if not CONNECTION_ICONS.dead then
    CONNECTION_ICONS.dead = openBitmapFromCandidates(roots, {
      "link_disconnected.png",
      "link_off.png",
    })
  end

  if not CONNECTION_ICONS.warn then CONNECTION_ICONS.warn = CONNECTION_ICONS.ok end
  if not CONNECTION_ICONS.low then CONNECTION_ICONS.low = CONNECTION_ICONS.dead or CONNECTION_ICONS.ok end

  _iconsLoaded = true
end

local INPUT_SOURCES = {
  roll = { "ail", "Ail", "AIL" },
  pitch = { "ele", "Ele", "ELE" },
  throttle = { "thr", "Thr", "THR" },
  yaw = { "rud", "Rud", "RUD" },
}

local function clamp(v, lo, hi)
  if v < lo then return lo end
  if v > hi then return hi end
  return v
end

local toNumber = (primitivesModule and primitivesModule.toNumber) or function() return nil end

local function normalizeStickValue(v)
  if v == nil then
    return 0
  end

  -- EdgeTX stick aliases (`ail`, `ele`, `thr`, `rud`) report raw stick values
  -- around +/-1024, so normalize deterministically to +/-100.
  local n = (v * 100) / 1024

  -- Small deadband reduces indicator jitter from ADC noise.
  if math.abs(n) < 0.8 then
    n = 0
  end

  return clamp(n, -100, 100)
end

local function readInput(names)
  if not getValue then
    return 0
  end

  for i = 1, #names do
    local n = toNumber(getValue(names[i]))
    if n ~= nil then
      return normalizeStickValue(n)
    end
  end

  return 0
end

local function mapAxis(value, minPixel, maxPixel, invert)
  local t = (value + 100) / 200
  if invert then
    t = 1 - t
  end
  local pixel = minPixel + (t * (maxPixel - minPixel))
  return math.floor(pixel + 0.5)
end

-- Cell count / per-cell voltage are resolved once per frame by the
-- shared telemetry/battery.lua module (see telemetry/read.lua) so every
-- battery consumer classifies the same numbers the same way -- no local
-- re-inference here.
local function batteryIconKey(telemetry, state)
  local cellV = telemetry and telemetry.batteryCellVoltage
  if type(cellV) ~= "number" or cellV < 0 then
    -- Genuinely no reading at all (sensor absent, or a nonsensical
    -- negative value): no icon (see BATTERY_ICONS -- "unknown" has no
    -- entry, so drawRxBatterySection's `if icon then` skips it). No
    -- existing icon asset represents "unknown" (only full/ok/warn/low/
    -- dead), so omitting the icon is the only option that doesn't
    -- assert something false.
    return "unknown"
  end

  -- LiHV-aware per-cell thresholds.
  -- 4.35V max-charge should be "full", and 4.20V must remain green.
  -- A real 0V reading falls through every branch to "dead" here, same
  -- as any other critically-low voltage -- found via Step 11 simulator
  -- testing that this used to short-circuit on `cellV <= 0` and return
  -- "ok" (later "unknown"), when a discovered sensor genuinely
  -- reporting 0V is exactly the "dead" case this icon exists for.
  if cellV > 4.00 then
    return "full"
  elseif cellV > 3.70 then
    return "ok"
  elseif cellV > 3.50 then
    return "warn"
  elseif cellV > 3.30 then
    return "low"
  end

  return "dead"
end

local function formatBatteryText(telemetry)
  if not telemetry or not telemetry.available or not telemetry.available.battery then
    return "--.--V"
  end

  local perCellV = telemetry and telemetry.batteryCellVoltage
  if type(perCellV) ~= "number" then
    return "--.--V"
  end

  local text = string.format("%.2fV", perCellV)

  local cells = telemetry.batteryCells
  if cells and cells >= 1 then
    text = text .. " (" .. tostring(cells) .. "S)"
  end
  -- No "(NS)" suffix when cell count was never established (e.g. the
  -- very first reading this session is already 0V) -- showing "(1S)"
  -- would be an invented, likely-wrong claim; the raw voltage alone is
  -- still real and worth showing.

  return text
end

local function formatLinkQualityText(telemetry)
  if not telemetry or not telemetry.available or not telemetry.available.linkQuality then
    return "--%"
  end

  local v = telemetry.linkQuality
  if type(v) ~= "number" then
    return "--%"
  end

  return string.format("%d%%", math.floor(v + 0.5))
end

-- `utils` is not an EdgeTX API global and no module in this repo defines
-- it -- this is a speculative, never-yet-used optional-extension hook
-- (Architecture & Packaging Hardening, Task 4 audit). It's safely guarded
-- (the `utils and ...` check short-circuits when nil, so this never
-- errors), but flagged rather than silently fixed: a future task should
-- decide whether to remove it or actually wire up a `utils` module.
-- luacheck: push ignore utils
local function connectionIconState(tpwr, rqly)
  if utils and type(utils.connectionIconState) == "function" then
    local key = utils.connectionIconState(tpwr, rqly)
    if key == "dead" or key == "low" or key == "warn" or key == "ok" then
      return key
    end
  end

  if (tpwr or 0) <= 0 then
    return "dead"
  end

  rqly = rqly or 0
  if rqly < 60 then
    return "low"
  elseif rqly < 80 then
    return "warn"
  else
    return "ok"
  end
end
-- luacheck: pop

local function drawLinkQualitySection(rect, telemetry, state)
  if not telemetry or telemetry.connected ~= true then
    return
  end

  local text = formatLinkQualityText(telemetry)
  local color = _TEXT_COLOR

  local tpwr = telemetry and toNumber(telemetry.txPower) or 0
  local rqly = telemetry and toNumber(telemetry.linkQuality) or 0
  local iconKey = connectionIconState(tpwr, rqly)
  local icon = CONNECTION_ICONS[iconKey] or CONNECTION_ICONS.ok

  local textW = #text * LQ_TEXT_CHAR_W

  -- Icon stacked above text, both centered as one vertical group, so a
  -- digit-count change (100% -> 99%) only re-centers that one row
  -- horizontally -- it can never push the group's width past the cell.
  local parts
  if icon then
    parts = { { w = LQ_ICON_W, h = LQ_ICON_H }, { w = 0, h = LQ_ICON_TEXT_GAP }, { w = textW, h = LQ_TEXT_H } }
  else
    parts = { { w = textW, h = LQ_TEXT_H } }
  end
  local placed = centerGroupVertical(rect, parts)

  if icon then
    -- Preserve original icon PNG colors.
    lcd.drawBitmap(icon, placed[1].x, placed[1].y)
    drawShadowText(placed[3].x, placed[3].y, text, _SMLSIZE, color)
  else
    drawShadowText(placed[1].x, placed[1].y, text, _SMLSIZE, color)
  end
end

local function drawRxBatterySection(rect, telemetry, state)
  if not telemetry or telemetry.connected ~= true then
    return
  end

  local batteryState = state and state.battery or nil
  local text = formatBatteryText(telemetry)
  local color = _TEXT_COLOR

  local icon = BATTERY_ICONS[batteryIconKey(telemetry, batteryState)]
  local textW = #text * RX_BAT_TEXT_CHAR_W

  -- Icon stacked above text, both centered as one vertical group -- see
  -- RX_BAT_TEXT_H's comment above for why (a horizontal layout ran the
  -- longer battery strings, e.g. "3.68V (6S)", off the screen at this
  -- cell's width).
  local parts
  if icon then
    parts = { { w = BATTERY_ICON_W, h = BATTERY_ICON_H }, { w = 0, h = RX_BAT_ICON_TEXT_GAP }, { w = textW, h = RX_BAT_TEXT_H } }
  else
    parts = { { w = textW, h = RX_BAT_TEXT_H } }
  end
  local placed = centerGroupVertical(rect, parts)

  if icon then
    -- Keep native PNG colors; no CUSTOM_COLOR tint for battery icons.
    lcd.drawBitmap(icon, placed[1].x, placed[1].y)
    drawShadowText(placed[3].x, placed[3].y, text, _SMLSIZE, color)
  else
    drawShadowText(placed[1].x, placed[1].y, text, _SMLSIZE, color)
  end
end

local function drawFilledSquare(cx, cy, size, color)
  local s = size or 1
  if s < 1 then return end
  local half = math.floor(s / 2)
  local dim = (half * 2) + 1
  local x = cx - half
  local y = cy - half

  if lcd and type(lcd.drawFilledRectangle) == "function" and type(color) == "number" then
    lcd.drawFilledRectangle(x, y, dim, dim, color)
    return
  end

  if type(color) == "number" then
    setCustomColor(color)
  end

  local lineColor = (type(color) == "number") and color or FORCE
  for dy = 0, dim - 1 do
    lcd.drawLine(x, y + dy, x + dim - 1, y + dy, SOLID, lineColor)
  end
end

-- Drawn as four filled rectangles rather than lcd.drawLine strokes,
-- consistent with the rest of the pad chrome (background fill, grid
-- lines below) -- all confirmed rendering correctly together on real
-- hardware once STICK_GRID_COLORS' colors were fixed to go through
-- lcd.RGB() instead of raw RGB565 hex literals (see
-- docs/platform/compatibility-matrix.md Section 12 for the full
-- investigation; an earlier, now-corrected theory blamed lcd.drawLine
-- itself, which was a red herring).
local function drawStickBorder(rect, color)
  if not (lcd and type(lcd.drawFilledRectangle) == "function") then
    return
  end

  local x, y, w, h = rect.x, rect.y, rect.w, rect.h
  local c = (type(color) == "number") and color or _THEME_PRIMARY
  local t = STICK_BORDER_THICKNESS

  lcd.drawFilledRectangle(x, y, w, t, c)          -- top
  lcd.drawFilledRectangle(x, y + h - t, w, t, c)  -- bottom
  lcd.drawFilledRectangle(x, y, t, h, c)          -- left
  lcd.drawFilledRectangle(x + w - t, y, t, h, c)  -- right
end

-- `override`, when provided, is used instead of the module-level
-- STICK_BORDER_COLOR default -- lets tests exercise every branch (e.g.
-- "gray"/"darkgray"/"lightgray") directly via M.resolveStickBorderColor
-- without needing a second module instance configured differently.
-- Production always calls this with no argument (see drawStickHud
-- below), so this is purely a testability seam, not a behavior change.
local function resolveStickBorderColor(override)
  local c = override or STICK_BORDER_COLOR
  if type(c) == "string" then
    if string and type(string.lower) == "function" then
      c = string.lower(c)
    end
    if string and type(string.gsub) == "function" then
      c = string.gsub(c, "^%s+", "")
      c = string.gsub(c, "%s+$", "")
    end
  end

  if c == nil or c == "theme" then
    return _THEME_PRIMARY
  end

  if c == "white" then return (type(WHITE) == "number") and WHITE or _WHITE end
  if c == "red" then return (type(RED) == "number") and RED or _RED end
  if c == "green" then return (type(GREEN) == "number") and GREEN or _GREEN end
  if c == "yellow" then return (type(YELLOW) == "number") and YELLOW or _YELLOW end
  if c == "black" then return (type(BLACK) == "number") and BLACK or _BLACK end
  -- Fallbacks below go through rgbColor() (real EdgeTX-packed values),
  -- not a raw RGB565 hex literal -- code-review finding, 2026-08-13: the
  -- previous 0x8410/0x4208/0xC618 literals here had the exact same
  -- malformed-color defect as the original STICK_GRID_COLORS (see
  -- docs/platform/compatibility-matrix.md Section 12), just never
  -- reported because "gray"/"darkgray"/"lightgray" aren't the default
  -- border color.
  if c == "gray" or c == "grey" then
    if type(GREY) == "number" then return GREY end
    if type(GRAY) == "number" then return GRAY end
    return rgbColor(128, 128, 128, _WHITE) -- medium gray, visible on bright themes
  end
  if c == "darkgray" or c == "darkgrey" then
    if type(DARKGREY) == "number" then return DARKGREY end
    if type(DARKGRAY) == "number" then return DARKGRAY end
    return rgbColor(64, 64, 64, _BLACK)
  end
  if c == "lightgray" or c == "lightgrey" then
    if type(LIGHTGREY) == "number" then return LIGHTGREY end
    if type(LIGHTGRAY) == "number" then return LIGHTGRAY end
    return rgbColor(198, 198, 198, _WHITE)
  end

  return c
end

local function roundedInt(v)
  if not v then return 0 end
  if v >= 0 then
    return math.floor(v + 0.5)
  end
  return math.ceil(v - 0.5)
end

-- Calibrated stick-grid visual constants and geometry helpers (Improved
-- Stick Grid, Task 1). Pure/stateless: they turn an existing pad rect or
-- pad size into colors/coordinates without touching M.draw's current
-- behavior, so later tasks (background+grid, round marker) can wire them
-- in without this task itself changing what's on screen. Exposed on M
-- (like render/primitives.lua's gridCells/centerGroup) so tests can
-- assert on the geometry directly, per the project's Testability NFR.
--
-- Colors are solid (no gradients/alpha), chosen from the confirmed
-- visual spec and produced via lcd.RGB() above:
--   bg: very dark navy (pad fill)
--   quarterGrid: dark desaturated blue, 1px, at 25%/75% -- subordinate to axes
--   centerAxis: muted cyan, 1px, at 50% -- brighter than the quarter grid
--   centerRef: neutral gray -- round, lighter than the live marker
--   markerOuter / markerInner: white outline over a near-black fill,
--     never pure black so the marker still reads against the navy bg
-- Fallbacks (when lcd.RGB isn't available) use EdgeTX-provided constants
-- directly rather than another raw hex literal, for the same reason.
local STICK_GRID_COLORS = {
  bg          = rgbColor(8, 8, 20, _BLACK),
  quarterGrid = rgbColor(40, 48, 88, _THEME_SECONDARY),
  centerAxis  = rgbColor(56, 176, 200, _THEME_SECONDARY),
  centerRef   = rgbColor(132, 130, 132, _WHITE),
  markerOuter = _WHITE,
  markerInner = rgbColor(8, 8, 8, _BLACK),
}

-- Line weights, named rather than inlined, so draw-order code (Task 3)
-- and tests (Task 5) reference one definition each.
local STICK_GRID_LINE_WEIGHT = 1
local STICK_CENTER_REF_RADIUS = 2

-- Marker size is selected from the pad's own boxSize, never from LCD_W
-- or a named resolution, so one code path covers 480x272, 480x320,
-- 800x480, and any intermediate size (FR-8).
local STICK_MARKER_SIZE_BREAKPOINT = 120
local STICK_MARKER_SMALL_INNER, STICK_MARKER_SMALL_OUTER = 7, 9
local STICK_MARKER_LARGE_INNER, STICK_MARKER_LARGE_OUTER = 11, 13

local function markerSizeForPad(boxSize)
  if (boxSize or 0) >= STICK_MARKER_SIZE_BREAKPOINT then
    return STICK_MARKER_LARGE_INNER, STICK_MARKER_LARGE_OUTER
  end
  return STICK_MARKER_SMALL_INNER, STICK_MARKER_SMALL_OUTER
end

-- Deterministic percentage-to-pixel helper: rounds each requested
-- percentage independently (via roundedInt above) so odd and even pad
-- dimensions both produce a stable, repeatable position -- never
-- dependent on iteration order or accumulated rounding error.
local function pctPixel(origin, length, pct)
  return roundedInt((origin or 0) + ((length or 0) * pct))
end

-- Quarter/center grid coordinates for one pad rectangle, derived only
-- from the rect passed in. Both pads share boxSize (only x/y differ), so
-- calling this once per pad always yields geometrically symmetric grids.
--
-- x50/y50 deliberately use math.floor(length/2) -- the same center
-- definition drawStickCenterReference and drawStickHud's marker mapping
-- use -- rather than pctPixel's independent percentage rounding.
-- Code-review finding (2026-08-13): on an odd pad dimension (e.g. 77px,
-- the 480x320 class), pctPixel(origin, 77, 0.5) rounds to origin+39
-- while floor(77/2) is origin+38 -- a real 1px mismatch between the
-- cyan center axis and where a centered stick's marker/center-reference
-- actually sit. Quarter positions (25%/75%) keep percentage rounding;
-- only the exact center needs to match the other center-based geometry.
local function stickGridCoords(rect)
  return {
    x25 = pctPixel(rect.x, rect.w, 0.25),
    x50 = rect.x + math.floor(rect.w / 2),
    x75 = pctPixel(rect.x, rect.w, 0.75),
    y25 = pctPixel(rect.y, rect.h, 0.25),
    y50 = rect.y + math.floor(rect.h / 2),
    y75 = pctPixel(rect.y, rect.h, 0.75),
  }
end

-- Labels/values are passed in already resolved to each box's actual
-- top (Y-axis) and bottom (X-axis) channel -- see the call site, which
-- derives them from the same ailOnRight/eleOnRight flags M.draw() uses
-- for the dots themselves, so this debug overlay can't drift back out
-- of sync with which physical stick moves which box (found in review:
-- this used to hardcode T/R under the left box and E/A under the right,
-- which only matched Stick Mode 2).
local function drawStickValues(leftRect, rightRect,
  leftTopLabel, leftTopValue, leftBottomLabel, leftBottomValue,
  rightTopLabel, rightTopValue, rightBottomLabel, rightBottomValue)

  local leftTopText = string.format("%s:%d", leftTopLabel, roundedInt(leftTopValue))
  local leftBottomText = string.format("%s:%d", leftBottomLabel, roundedInt(leftBottomValue))
  local rightTopText = string.format("%s:%d", rightTopLabel, roundedInt(rightTopValue))
  local rightBottomText = string.format("%s:%d", rightBottomLabel, roundedInt(rightBottomValue))

  -- Fixed anchors: text X does not depend on digit count.
  local leftX = leftRect.x + STICK_VALUES_LEFT_X_NUDGE
  local rightX = rightRect.x + rightRect.w + STICK_VALUES_RIGHT_X_NUDGE
  if leftX < 0 then leftX = 0 end

  local topY = leftRect.y - STICK_VALUES_LINE_H - STICK_VALUES_TOP_OUTSIDE_GAP + STICK_VALUES_TOP_NUDGE
  local bottomY = leftRect.y + leftRect.h + STICK_VALUES_BOTTOM_OUTSIDE_GAP + STICK_VALUES_BOTTOM_NUDGE
  if topY < 0 then topY = 0 end

  drawShadowText(leftX, topY, leftTopText, _SMLSIZE, _TEXT_COLOR)
  drawShadowText(leftX, bottomY, leftBottomText, _SMLSIZE, _TEXT_COLOR)
  drawShadowText(rightX, topY, rightTopText, _SMLSIZE, _TEXT_COLOR)
  drawShadowText(rightX, bottomY, rightBottomText, _SMLSIZE, _TEXT_COLOR)
end

local function drawStickAxes(rect)
  local cx = rect.x + math.floor(rect.w / 2)
  local cy = rect.y + math.floor(rect.h / 2)

  lcd.drawLine(cx, rect.y + 2, cx, rect.y + rect.h - 3, SOLID, FORCE)
  lcd.drawLine(rect.x + 2, cy, rect.x + rect.w - 3, cy, SOLID, FORCE)
end

-- Draw order step 1 (Improved Stick Grid, Task 3): solid pad fill,
-- covering the full rect -- the border and grid lines drawn afterward
-- paint over its edges/center, so this can be one unconditional fill
-- rather than an inset one.
local function drawStickPadBackground(rect)
  if lcd and type(lcd.drawFilledRectangle) == "function" then
    lcd.drawFilledRectangle(rect.x, rect.y, rect.w, rect.h, STICK_GRID_COLORS.bg)
  end
end

-- Draw order steps 2-3: quarter-grid lines (25%/75%), then the brighter
-- center axes (50%) -- drawn as 1px-wide/tall filled rectangles rather
-- than lcd.drawLine strokes, for the same reason documented on
-- drawStickBorder above (docs/platform/compatibility-matrix.md
-- Section 12).
--
-- Lines run the pad's full width/height rather than stopping short of
-- the border -- the border is redrawn on top afterward (step 4), so it
-- stays crisp regardless of what the grid painted underneath it.
local function drawStickGrid(rect)
  if not (lcd and type(lcd.drawFilledRectangle) == "function") then
    return
  end

  local g = stickGridCoords(rect)
  local weight = STICK_GRID_LINE_WEIGHT

  local quarterColor = STICK_GRID_COLORS.quarterGrid
  lcd.drawFilledRectangle(g.x25, rect.y, weight, rect.h, quarterColor)
  lcd.drawFilledRectangle(g.x75, rect.y, weight, rect.h, quarterColor)
  lcd.drawFilledRectangle(rect.x, g.y25, rect.w, weight, quarterColor)
  lcd.drawFilledRectangle(rect.x, g.y75, rect.w, weight, quarterColor)

  local axisColor = STICK_GRID_COLORS.centerAxis
  lcd.drawFilledRectangle(g.x50, rect.y, weight, rect.h, axisColor)
  lcd.drawFilledRectangle(rect.x, g.y50, rect.w, weight, axisColor)
end

-- Draw order step 5: tiny round gray center reference, exactly centered.
-- Guarded fallback to a small filled square when lcd.drawFilledCircle
-- isn't available (see docs/platform/compatibility-matrix.md Section 11)
-- -- less round, but keeps the reference present and centered rather
-- than missing entirely.
local function drawStickCenterReference(rect)
  local cx = rect.x + math.floor(rect.w / 2)
  local cy = rect.y + math.floor(rect.h / 2)
  local color = STICK_GRID_COLORS.centerRef

  if lcd and type(lcd.drawFilledCircle) == "function" then
    lcd.drawFilledCircle(cx, cy, STICK_CENTER_REF_RADIUS, color)
    return
  end

  drawFilledSquare(cx, cy, (STICK_CENTER_REF_RADIUS * 2) + 1, color)
end

-- Draw order step 6 (final): the live-position marker, a two-layer round
-- indicator -- white outer circle first, near-black inner circle second
-- -- replacing the previous bordered square (Improved Stick Grid, Task 4).
-- innerDiameter/outerDiameter come from markerSizeForPad(), so sizing
-- tracks the pad's own boxSize rather than display resolution (FR-8).
-- Guarded fallback to the previous square-layer technique when
-- lcd.drawFilledCircle isn't available (see
-- docs/platform/compatibility-matrix.md Section 11).
local function drawMarker(cx, cy, innerDiameter, outerDiameter)
  local outerRadius = math.floor(outerDiameter / 2)
  local innerRadius = math.floor(innerDiameter / 2)

  if lcd and type(lcd.drawFilledCircle) == "function" then
    lcd.drawFilledCircle(cx, cy, outerRadius, STICK_GRID_COLORS.markerOuter)
    lcd.drawFilledCircle(cx, cy, innerRadius, STICK_GRID_COLORS.markerInner)
    return
  end

  drawFilledSquare(cx, cy, outerDiameter, STICK_GRID_COLORS.markerOuter)
  drawFilledSquare(cx, cy, innerDiameter, STICK_GRID_COLORS.markerInner)
end

local function drawStickHud(rect, xValue, yValue, label)
  -- Confirmed draw order (Improved Stick Grid project): fill, quarter
  -- grid, center axes, border, center reference, then the live marker
  -- below. Keeps the border crisp on top of the fill/grid, and guarantees
  -- the marker (drawn last) stays visible over everything else.
  --
  -- DRAW_PAD_BACKGROUND/DRAW_PAD_GRID (both true) were used as bisection
  -- toggles while diagnosing an invisible-grid/border bug on real
  -- hardware; the actual cause turned out to be malformed color values,
  -- not these two layers themselves (see docs/platform/
  -- compatibility-matrix.md Section 12). Kept, rather than removed, in
  -- case a future regression needs the same isolation approach.
  if DRAW_PAD_BACKGROUND then
    drawStickPadBackground(rect)
  end
  if DRAW_PAD_GRID then
    drawStickGrid(rect)
  end

  local borderColor = resolveStickBorderColor()
  drawStickBorder(rect, borderColor)

  drawStickCenterReference(rect)

  if SHOW_STICK_AXIS then
    setCustomColor(_THEME_SECONDARY)
    drawStickAxes(rect)
  end

  -- Marker sizing/containment uses the complete marker's outer radius
  -- (Task 4), selected from this pad's own boxSize (rect.w == rect.h) --
  -- never from LCD_W or a named resolution (FR-8).
  local innerDiameter, outerDiameter = markerSizeForPad(rect.w)
  local outerRadius = math.floor(outerDiameter / 2)

  -- Keep the complete marker (including its white outline) inside the
  -- inner stick area.
  local minX = rect.x + 2 + outerRadius
  local maxX = rect.x + rect.w - 3 - outerRadius
  local minY = rect.y + 2 + outerRadius
  local maxY = rect.y + rect.h - 3 - outerRadius

  if minX > maxX then
    local cx = rect.x + math.floor(rect.w / 2)
    minX = cx
    maxX = cx
  end
  if minY > maxY then
    local cy = rect.y + math.floor(rect.h / 2)
    minY = cy
    maxY = cy
  end

  local dotX = mapAxis(xValue, minX, maxX, false)
  local dotY = mapAxis(yValue, minY, maxY, true)

  drawMarker(dotX, dotY, innerDiameter, outerDiameter)

  if label and label ~= "" then
    drawShadowText(rect.x + 2, rect.y + 1, label, _SMLSIZE, _TEXT_COLOR)
  end
end

function M.draw(bounds, telemetry, state, theme)
  if not bounds then
    return
  end

  local textColor = (theme and theme.textColor) or _WHITE
  _TEXT_COLOR = textColor
  _TEXT_SHADOW_COLOR = (theme and theme.isLight) and _LIGHT_TEXT_SHADOW or _BLACK
  ensureIconsLoaded(theme)

  local cells = gridCells(bounds.x, bounds.y, bounds.w, bounds.h, GRID_WEIGHTS)
  local leftSection, sticksArea, rightSection = cells[1], cells[2], cells[3]

  if not leftSection or not sticksArea or not rightSection then
    return
  end

  local pad = 4
  local gap = 20
  local innerW = sticksArea.w - (pad * 2)
  local innerH = sticksArea.h - (pad * 2)

  local boxSize = math.min(innerH, math.floor((innerW - gap) / 2)) - STICK_BOX_SIZE_REDUCTION

  if boxSize < 16 then
    drawShadowText(sticksArea.x + 2, sticksArea.y + 2, "Sticks", _SMLSIZE, _TEXT_COLOR)
    drawLinkQualitySection(leftSection, telemetry, state)
    drawRxBatterySection(rightSection, telemetry, state)
    return
  end

  -- Both stick boxes move as one centered group within the Sticks cell,
  -- same as the icon+text groups in the side cells.
  local placedSticks = centerGroup(sticksArea, {
    { w = boxSize, h = boxSize },
    { w = gap },
    { w = boxSize, h = boxSize },
  })

  local leftRect = {
    x = placedSticks[1].x,
    y = placedSticks[1].y,
    w = boxSize,
    h = boxSize,
  }

  local rightRect = {
    x = placedSticks[3].x,
    y = placedSticks[3].y,
    w = boxSize,
    h = boxSize,
  }

  local yaw = readInput(INPUT_SOURCES.yaw)
  local throttle = readInput(INPUT_SOURCES.throttle)
  local roll = readInput(INPUT_SOURCES.roll)
  local pitch = readInput(INPUT_SOURCES.pitch)

  local stickMode = theme and theme.stickMode
  if type(stickMode) ~= "number" or stickMode < 1 or stickMode > 4 then
    stickMode = DEFAULT_STICK_MODE
  end

  -- Which physical stick carries aileron/rudder and elevator/throttle
  -- flips per EdgeTX's Stick Mode setting (verified against EdgeTX
  -- firmware's radio/src/input_mapping.cpp mode table and radio/src/
  -- keys.cpp's ailRight/eleRight flags) -- getValue("ail")/"ele"/"thr"/
  -- "rud" already report the mode-corrected logical channel, so only
  -- which on-screen box each one lands in needs to track the mode.
  local ailOnRight = (stickMode == 1 or stickMode == 2)
  local eleOnRight = (stickMode == 2 or stickMode == 4)

  local leftX, rightX = roll, yaw
  if ailOnRight then leftX, rightX = yaw, roll end

  local leftY, rightY = pitch, throttle
  if eleOnRight then leftY, rightY = throttle, pitch end

  drawStickHud(leftRect, leftX, leftY, nil)
  drawStickHud(rightRect, rightX, rightY, nil)

  if SHOW_STICK_VALUES then
    local leftTopLabel, rightTopLabel = "E", "T"
    if eleOnRight then leftTopLabel, rightTopLabel = "T", "E" end

    local leftBottomLabel, rightBottomLabel = "A", "R"
    if ailOnRight then leftBottomLabel, rightBottomLabel = "R", "A" end

    drawStickValues(leftRect, rightRect,
      leftTopLabel, leftY, leftBottomLabel, leftX,
      rightTopLabel, rightY, rightBottomLabel, rightX)
  end

  drawLinkQualitySection(leftSection, telemetry, state)
  drawRxBatterySection(rightSection, telemetry, state)
end

-- Exposed for tests (geometry/draw-order/containment coverage, Task 5),
-- the same way render/primitives.lua exposes its own geometry helpers --
-- also used internally by M.draw's drawStickHud, below.
M.stickGridColors = STICK_GRID_COLORS
M.stickGridLineWeight = STICK_GRID_LINE_WEIGHT
M.stickCenterRefRadius = STICK_CENTER_REF_RADIUS
M.markerSizeForPad = markerSizeForPad
M.stickGridCoords = stickGridCoords

-- Exposed so tests can exercise the pad background/grid drawing logic
-- directly and independently of each other, in addition to the
-- full-M.draw() coverage in tests/spec/sticks_grid_spec.lua.
M.drawStickPadBackground = drawStickPadBackground
M.drawStickGrid = drawStickGrid
M.resolveStickBorderColor = resolveStickBorderColor

function M.drawSkeleton(bounds)
  if not bounds then
    return
  end

  local x1 = bounds.x
  local y1 = bounds.y
  local x2 = bounds.x + bounds.w - 1
  local y2 = bounds.y + bounds.h - 1
  lcd.drawLine(x1, y1, x2, y1, SOLID, FORCE)
  lcd.drawLine(x1, y2, x2, y2, SOLID, FORCE)
  lcd.drawLine(x1, y1, x1, y2, SOLID, FORCE)
  lcd.drawLine(x2, y1, x2, y2, SOLID, FORCE)
  lcd.drawText(bounds.x + 2, bounds.y + 2, "Stick Monitor", SMLSIZE)
end

return M
