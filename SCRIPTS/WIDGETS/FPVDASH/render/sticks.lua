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
local _MIDSIZE = (type(MIDSIZE) == "number") and MIDSIZE or _SMLSIZE

local BATTERY_ICON_W = 20
local BATTERY_ICON_H = 32
local LQ_ICON_W = 30
local LQ_ICON_H = 30

-- Sticks panel grid: Link Quality / Sticks / Receiver Battery, in that
-- order (Grid-aligned top bar and sticks, Task 2). Cells are adjacent with
-- no inter-cell gap -- spacing comes entirely from each cell's content
-- being a centered group smaller than the cell itself.
local GRID_WEIGHTS = { 30, 40, 30 }

-- Stick monitor visual tuning.
local SHOW_STICK_AXIS = false
local SHOW_STICK_VALUES = false
local STICK_DOT_SIZE = 7
local STICK_DOT_BORDER_THICKNESS = 1
local STICK_BORDER_THICKNESS = 2
-- One-line border color override for visual testing.
-- Set to: "theme", "white", "red", "green", "yellow", "black", "gray", "grey"
-- or any numeric color value (for example 0xF800). nil behaves like "theme".
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

local _THEME_PRIMARY = themeColor((type(THEME_PRIMARY) == "number") and THEME_PRIMARY or nil, _WHITE)
local _THEME_SECONDARY = themeColor((type(THEME_SECONDARY) == "number") and THEME_SECONDARY or nil, _WHITE)
local _THEME_FOCUS = themeColor((type(THEME_FOCUS) == "number") and THEME_FOCUS or nil, _GREEN)

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

local function drawIndicator(x, y, size, fillColor)
  local s = size or STICK_DOT_SIZE
  if s < 1 then s = 1 end

  local borderSize = s + (STICK_DOT_BORDER_THICKNESS * 2)

  -- White outline for better readability on busy backgrounds.
  drawFilledSquare(x, y, borderSize, _WHITE)

  drawFilledSquare(x, y, s, fillColor or _THEME_FOCUS)
end

local function drawStickBorder(rect, color)
  local x = rect.x
  local y = rect.y
  local w = rect.w
  local h = rect.h

  local c = (type(color) == "number") and color or _THEME_PRIMARY

  -- Use CUSTOM_COLOR flag when available so arbitrary RGB565 values
  -- (e.g. gray 0x7BEF) render correctly on radios that ignore raw color
  -- values in lcd.drawLine's last argument.
  local drawColor = c
  if type(CUSTOM_COLOR) == "number" and lcd and type(lcd.setColor) == "function" then
    lcd.setColor(CUSTOM_COLOR, c)
    drawColor = CUSTOM_COLOR
  end

  local x2 = x + w - 1
  local y2 = y + h - 1

  lcd.drawLine(x,  y,  x2, y,  SOLID, drawColor)
  lcd.drawLine(x,  y2, x2, y2, SOLID, drawColor)
  lcd.drawLine(x,  y,  x,  y2, SOLID, drawColor)
  lcd.drawLine(x2, y,  x2, y2, SOLID, drawColor)

  if STICK_BORDER_THICKNESS > 1 then
    lcd.drawLine(x + 1,  y + 1,  x2 - 1, y + 1,  SOLID, drawColor)
    lcd.drawLine(x + 1,  y2 - 1, x2 - 1, y2 - 1, SOLID, drawColor)
    lcd.drawLine(x + 1,  y + 1,  x + 1,  y2 - 1, SOLID, drawColor)
    lcd.drawLine(x2 - 1, y + 1,  x2 - 1, y2 - 1, SOLID, drawColor)
  end
end

local function resolveStickBorderColor()
  local c = STICK_BORDER_COLOR
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
  if c == "gray" or c == "grey" then
    if type(GREY) == "number" then return GREY end
    if type(GRAY) == "number" then return GRAY end
    -- Darker medium gray fallback so it stays visibly gray on bright themes.
    return 0x8410
  end
  if c == "darkgray" or c == "darkgrey" then
    if type(DARKGREY) == "number" then return DARKGREY end
    if type(DARKGRAY) == "number" then return DARKGRAY end
    return 0x4208
  end
  if c == "lightgray" or c == "lightgrey" then
    if type(LIGHTGREY) == "number" then return LIGHTGREY end
    if type(LIGHTGRAY) == "number" then return LIGHTGRAY end
    return 0xC618
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

local function drawStickValues(leftRect, rightRect, yaw, throttle, roll, pitch)
  local tText = string.format("T:%d", roundedInt(throttle))
  local rText = string.format("R:%d", roundedInt(yaw))
  local eText = string.format("E:%d", roundedInt(pitch))
  local aText = string.format("A:%d", roundedInt(roll))

  -- Fixed anchors: text X does not depend on digit count.
  local leftX = leftRect.x + STICK_VALUES_LEFT_X_NUDGE
  local rightX = rightRect.x + rightRect.w + STICK_VALUES_RIGHT_X_NUDGE
  if leftX < 0 then leftX = 0 end

  local topY = leftRect.y - STICK_VALUES_LINE_H - STICK_VALUES_TOP_OUTSIDE_GAP + STICK_VALUES_TOP_NUDGE
  local bottomY = leftRect.y + leftRect.h + STICK_VALUES_BOTTOM_OUTSIDE_GAP + STICK_VALUES_BOTTOM_NUDGE
  if topY < 0 then topY = 0 end

  drawShadowText(leftX, topY, tText, _SMLSIZE, _TEXT_COLOR)
  drawShadowText(leftX, bottomY, rText, _SMLSIZE, _TEXT_COLOR)
  drawShadowText(rightX, topY, eText, _SMLSIZE, _TEXT_COLOR)
  drawShadowText(rightX, bottomY, aText, _SMLSIZE, _TEXT_COLOR)
end

local function drawStickAxes(rect)
  local cx = rect.x + math.floor(rect.w / 2)
  local cy = rect.y + math.floor(rect.h / 2)

  lcd.drawLine(cx, rect.y + 2, cx, rect.y + rect.h - 3, SOLID, FORCE)
  lcd.drawLine(rect.x + 2, cy, rect.x + rect.w - 3, cy, SOLID, FORCE)
end

local function drawStickHud(rect, xValue, yValue, label)
  local borderColor = resolveStickBorderColor()
  drawStickBorder(rect, borderColor)

  if SHOW_STICK_AXIS then
    setCustomColor(_THEME_SECONDARY)
    drawStickAxes(rect)
  end

  local dotHalf = math.floor((STICK_DOT_SIZE + (STICK_DOT_BORDER_THICKNESS * 2)) / 2)

  -- Keep the full dot (including white border) inside the inner stick area.
  local minX = rect.x + 2 + dotHalf
  local maxX = rect.x + rect.w - 3 - dotHalf
  local minY = rect.y + 2 + dotHalf
  local maxY = rect.y + rect.h - 3 - dotHalf

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

  local dotColor = _BLACK
  drawIndicator(dotX, dotY, STICK_DOT_SIZE, dotColor)

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

  -- Left stick: X=rudder, Y=throttle.
  -- Right stick: X=aileron, Y=elevator.
  drawStickHud(leftRect, yaw, throttle, nil)
  drawStickHud(rightRect, roll, pitch, nil)

  if SHOW_STICK_VALUES then
    drawStickValues(leftRect, rightRect, yaw, throttle, roll, pitch)
  end

  drawLinkQualitySection(leftSection, telemetry, state)
  drawRxBatterySection(rightSection, telemetry, state)
end

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
