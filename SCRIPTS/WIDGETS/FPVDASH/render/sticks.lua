-- Stick monitor renderer.
-- Renders two gimbal monitors using live radio-side stick inputs.

local M = {}

local _WHITE  = (type(WHITE) == "number") and WHITE or 0xFFFF
local _GREEN  = (type(GREEN) == "number") and GREEN or _WHITE
local _YELLOW = (type(YELLOW) == "number") and YELLOW or _WHITE
local _RED    = (type(RED) == "number") and RED or _YELLOW
local _BLACK  = 0x0000
local _SHADOWED = (type(SHADOWED) == "number") and SHADOWED or 0

local _SMLSIZE = (type(SMLSIZE) == "number") and SMLSIZE or 0
local _MIDSIZE = (type(MIDSIZE) == "number") and MIDSIZE or _SMLSIZE

local BATTERY_ICON_W = 20
local BATTERY_ICON_H = 32
local LQ_ICON_W = 30
local LQ_ICON_H = 30
local STICK_SIDE_GAP = 6

-- Stick monitor visual tuning.
local SHOW_STICK_AXIS = false
local SHOW_STICK_VALUES = false
local STICK_DOT_SIZE = 7
local STICK_DOT_BORDER_THICKNESS = 1
local STICK_ACTIVE_DEADZONE = 6
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

-- RX battery block alignment (kept identical to user-tuned visual result).
local RX_BAT_TEXT_CHAR_W = 7
local RX_BAT_TEXT_H = 0
local RX_BAT_ICON_TEXT_GAP = 4
local RX_BAT_TEXT_X_NUDGE = -60
local RX_BAT_TEXT_Y_NUDGE = 10
local RX_BAT_ICON_X_NUDGE = 10
local RX_BAT_ICON_Y_NUDGE = -15

-- Link-quality block keeps exact vertical alignment with RX battery block.
local LQ_TEXT_CHAR_W = RX_BAT_TEXT_CHAR_W
local LQ_TEXT_H = RX_BAT_TEXT_H
local LQ_ICON_TEXT_GAP = RX_BAT_ICON_TEXT_GAP
local LQ_TEXT_X_NUDGE = -10
local LQ_TEXT_Y_NUDGE = RX_BAT_TEXT_Y_NUDGE
local LQ_ICON_X_NUDGE = 30
local LQ_ICON_Y_NUDGE = RX_BAT_ICON_Y_NUDGE

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
local _THEME_WARNING = themeColor((type(THEME_WARNING) == "number") and THEME_WARNING or _YELLOW, _YELLOW)

local function tf(size, color)
  if type(color) == "number" and lcd and type(lcd.setColor) == "function" and type(CUSTOM_COLOR) == "number" then
    lcd.setColor(CUSTOM_COLOR, color)
    return size + CUSTOM_COLOR
  end
  return size
end

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
local _loadedIconFolder = nil
local _TEXT_COLOR = _WHITE
local _TEXT_SHADOW_COLOR = _BLACK
local _LIGHT_TEXT_SHADOW = _WHITE

local function drawShadowText(x, y, text, size, color)
  if not lcd or type(lcd.drawText) ~= "function" then
    return
  end

  local txtColor = (type(color) == "number") and color or _WHITE
  local shadowColor = (type(_TEXT_SHADOW_COLOR) == "number") and _TEXT_SHADOW_COLOR or _BLACK

  if type(TEXT_COLOR) == "number" and type(lcd.setColor) == "function" then
    lcd.setColor(TEXT_COLOR, shadowColor)
    lcd.drawText(x + 1, y + 1, text, size)

    lcd.setColor(TEXT_COLOR, txtColor)
    lcd.drawText(x, y, text, size)
    return
  end

  if type(CUSTOM_COLOR) == "number" and type(lcd.setColor) == "function" then
    lcd.setColor(CUSTOM_COLOR, shadowColor)
    lcd.drawText(x + 1, y + 1, text, size + CUSTOM_COLOR)

    lcd.setColor(CUSTOM_COLOR, txtColor)
    lcd.drawText(x, y, text, size + CUSTOM_COLOR)
    return
  end

  local okShadow = pcall(lcd.drawText, x + 1, y + 1, text, size, shadowColor)
  if not okShadow then
    lcd.drawText(x + 1, y + 1, text, size)
  end

  local okText = pcall(lcd.drawText, x, y, text, size, txtColor)
  if not okText then
    lcd.drawText(x, y, text, size)
  end
end

local function openBitmapFromCandidates(roots, names)
  if not Bitmap then
    return nil
  end

  for i = 1, #names do
    for j = 1, #roots do
      local bm = Bitmap.open(roots[j] .. names[i])
      if bm then
        return bm
      end
    end
  end

  return nil
end

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

local function toNumber(v)
  if type(v) == "number" then
    return v
  end

  if type(v) == "table" then
    if type(v.value) == "number" then
      return v.value
    end
    if type(v.val) == "number" then
      return v.val
    end
  end

  if type(v) == "string" then
    local n = tonumber(v:match("%-?%d+%.?%d*"))
    if n then
      return n
    end
  end

  return nil
end

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

-- Estimate voltage per cell and cell count from total RX battery voltage.
-- Mirrors the provided formula and falls back safely when pack voltage is
-- too low or outside expected per-cell bounds.
local function getVoltagePerCell(totalVoltage)
  if utils and type(utils.getVoltagePerCell) == "function" then
    local perCell, cellCount = utils.getVoltagePerCell(totalVoltage)
    if type(perCell) == "number" and type(cellCount) == "number" and cellCount > 0 then
      return perCell, cellCount
    end
  end

  local maxCellVoltage = 4.35
  local minCellVoltage = 3.0

  if (totalVoltage or 0) > 5 then
    local estimatedCellCount = math.floor(totalVoltage / maxCellVoltage) + 1
    local averageVoltagePerCell = totalVoltage / estimatedCellCount

    if averageVoltagePerCell >= minCellVoltage and averageVoltagePerCell <= maxCellVoltage then
      return averageVoltagePerCell, estimatedCellCount
    end
  end

  return totalVoltage or 0, 1
end

local function batteryIconKey(telemetry, state)
  local batteryV = telemetry and telemetry.battery
  if type(batteryV) ~= "number" or batteryV < 0 then
    return "ok"
  end

  if batteryV == 0 then
    return "dead"
  end

  local cellV = getVoltagePerCell(batteryV)
  if type(cellV) ~= "number" then
    return "ok"
  end

  if cellV <= 0 then
    return "dead"
  end

  -- LiHV-aware per-cell thresholds.
  -- 4.35V max-charge should be "full", and 4.20V must remain green.
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

  local v = telemetry.battery
  if type(v) ~= "number" or v < 0 then
    return "--.--V"
  end

  local perCellV, cells = getVoltagePerCell(v)
  local text = string.format("%.2fV", perCellV)
  if not cells or cells < 1 then
    cells = 1
  end
  text = text .. " (" .. tostring(cells) .. "S)"

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
  local textH = LQ_TEXT_H
  local gap = LQ_ICON_TEXT_GAP

  -- Keep icon at a fixed anchor so digit-count changes (100% -> 99%)
  -- do not shift icon alignment.
  local iconX = rect.x + math.floor((rect.w - LQ_ICON_W) / 2)
  if iconX < rect.x then
    iconX = rect.x
  end

  local textX
  if icon then
    textX = iconX + LQ_ICON_W + gap + LQ_TEXT_X_NUDGE
  else
    -- Fallback text-only mode stays centered when icon is unavailable.
    textX = rect.x + math.floor((rect.w - textW) / 2) + LQ_TEXT_X_NUDGE
    if textX < rect.x then
      textX = rect.x
    end
  end

  -- Keep same vertical alignment behavior as RX battery icon+text.
  local textY = rect.y + math.floor((rect.h - textH) / 2) + LQ_TEXT_Y_NUDGE
  if textY < rect.y then
    textY = rect.y
  end

  if icon then
    local iconY = rect.y + math.floor((rect.h - LQ_ICON_H) / 2) + LQ_ICON_Y_NUDGE
    if iconY < rect.y then
      iconY = rect.y
    end
    -- Preserve original icon PNG colors.
    lcd.drawBitmap(icon, iconX + LQ_ICON_X_NUDGE, iconY)
  end

  drawShadowText(textX, textY, text, _MIDSIZE, color)
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
  local textH = RX_BAT_TEXT_H
  local gap = RX_BAT_ICON_TEXT_GAP

  local totalW = textW
  if icon then
    totalW = BATTERY_ICON_W + gap + textW
  end

  local startX = rect.x + math.floor((rect.w - totalW) / 2)
  if startX < rect.x then
    startX = rect.x
  end

  local textX = startX
  if icon then
    textX = startX + BATTERY_ICON_W + gap + RX_BAT_TEXT_X_NUDGE
  end

  local textY = rect.y + math.floor((rect.h - textH) / 2) + RX_BAT_TEXT_Y_NUDGE
  if textY < rect.y then
    textY = rect.y
  end

  if icon then
    local iconY = rect.y + math.floor((rect.h - BATTERY_ICON_H) / 2) + RX_BAT_ICON_Y_NUDGE
    if iconY < rect.y then
      iconY = rect.y
    end
    -- Keep native PNG colors; no CUSTOM_COLOR tint for battery icons.
    lcd.drawBitmap(icon, startX + RX_BAT_ICON_X_NUDGE, iconY)
  end

  drawShadowText(textX, textY, text, _MIDSIZE, color)
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

local function isStickActive(xValue, yValue)
  return math.abs(xValue) > STICK_ACTIVE_DEADZONE or math.abs(yValue) > STICK_ACTIVE_DEADZONE
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

  local sideW = math.max(84, math.floor(bounds.w * 0.19))
  sideW = math.min(sideW, 116)

  local rightSection = {
    x = bounds.x + bounds.w - sideW,
    y = bounds.y,
    w = sideW,
    h = bounds.h,
  }

  local leftSection = {
    x = bounds.x,
    y = bounds.y,
    w = sideW,
    h = bounds.h,
  }

  local sticksArea = {
    x = bounds.x + sideW + STICK_SIDE_GAP,
    y = bounds.y,
    w = bounds.w - (sideW * 2) - (STICK_SIDE_GAP * 2),
    h = bounds.h,
  }

  if sticksArea.w < 64 then
    sticksArea.x = bounds.x
    sticksArea.w = bounds.w - sideW - STICK_SIDE_GAP
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

  local totalW = boxSize * 2 + gap
  local startX = sticksArea.x + math.floor((sticksArea.w - totalW) / 2)
  local startY = sticksArea.y + math.floor((sticksArea.h - boxSize) / 2)

  local leftRect = {
    x = startX,
    y = startY,
    w = boxSize,
    h = boxSize,
  }

  local rightRect = {
    x = startX + boxSize + gap,
    y = startY,
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
