-- Top bar renderer.
-- Renders model name, transmitter battery, telemetry link status, and time.

local M = {}

local _WHITE    = (type(WHITE)    == "number") and WHITE    or 0xFFFF
local _GREEN    = (type(GREEN)    == "number") and GREEN    or 0x07E0
local _YELLOW   = (type(YELLOW)   == "number") and YELLOW   or 0xFFE0
local _RED      = (type(RED)      == "number") and RED      or 0xF800
local _BLACK    = 0x0000
local _BOLD     = (type(BOLD)     == "number") and BOLD     or 0
local _SHADOWED = (type(SHADOWED) == "number") and SHADOWED or 0
local LINK_ICON_W = 24
local LINK_ICON_H = 24
local TX_TEXT_H = 12
local TX_TEXT_NUDGE_Y = -8
local TOPBAR_STATUS_X_OFFSET = 50

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
local _THEME_WARNING = themeColor((type(THEME_WARNING) == "number") and THEME_WARNING or nil, _YELLOW)

local function tf(size, color)
  if type(color) == "number" and lcd and type(lcd.setColor) == "function" and type(CUSTOM_COLOR) == "number" then
    lcd.setColor(CUSTOM_COLOR, color)
    return size + CUSTOM_COLOR
  end
  return size
end

local ICON_LINK_ON = nil
local ICON_LINK_OFF = nil
local ICON_TX_BATTERY = nil
local BATTERY_ICONS = {
  full = nil,
  ok = nil,
  warn = nil,
  low = nil,
  dead = nil,
}

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

-- Icons are loaded lazily on the first draw call so that the Bitmap API is
-- guaranteed to be available (EdgeTX only exposes it inside widget callbacks).
local _iconsLoaded = false

local function ensureIconsLoaded()
  if _iconsLoaded then return end
  if not Bitmap or type(Bitmap.open) ~= "function" then return end

  local roots = {
    "/WIDGETS/FPVDASH/icons/",
    "WIDGETS/FPVDASH/icons/",
  }

  local batteryRoots = {
    "/WIDGETS/FPVDASH/icons/battery/",
    "WIDGETS/FPVDASH/icons/battery/",
  }

  ICON_TX_BATTERY = openBitmapFromCandidates(roots, {
    "tx_battery.png",
    "battery.png",
  })

  BATTERY_ICONS.full = openBitmapFromCandidates(batteryRoots, { "battery-full.png" })
  BATTERY_ICONS.ok   = openBitmapFromCandidates(batteryRoots, { "battery-ok.png" })
  BATTERY_ICONS.warn = openBitmapFromCandidates(batteryRoots, { "battery-warn.png" })
  BATTERY_ICONS.low  = openBitmapFromCandidates(batteryRoots, { "battery-low.png" })
  BATTERY_ICONS.dead = openBitmapFromCandidates(batteryRoots, { "battery-dead.png" })

  if not BATTERY_ICONS.ok then
    BATTERY_ICONS.ok = ICON_TX_BATTERY
  end

  ICON_LINK_ON = openBitmapFromCandidates(roots, {
    "link.png",
  })

  ICON_LINK_OFF = openBitmapFromCandidates(roots, {
    "link_off.png",
  })

  _iconsLoaded = true
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

local function truncateText(text, maxWidth, charW)
  charW = charW or 4
  local maxChars = math.max(1, math.floor(maxWidth / charW))

  if #text <= maxChars then
    return text
  end

  if maxChars <= 3 then
    return text:sub(1, maxChars)
  end

  return text:sub(1, maxChars - 3) .. "..."
end

local function readModelName()
  if model and model.getInfo then
    local info = model.getInfo()
    if info and type(info.name) == "string" and info.name ~= "" then
      return info.name
    end
  end

  return "MODEL"
end

local function readTxVoltage()
  if not getValue then
    return nil
  end

  local names = {
    "tx-voltage",
    "tx voltage",
    "TxBt",
    "TXBAT",
    "A1",
  }

  for i = 1, #names do
    local n = toNumber(getValue(names[i]))
    if n and n > 0 then
      return n
    end
  end

  return nil
end

local function readTxBatteryInfo()
  if utils and type(utils.txBatteryInfo) == "function" then
    local v, state = utils.txBatteryInfo()
    local parsedV = toNumber(v)
    if not parsedV then
      parsedV = readTxVoltage()
    end

    if type(state) ~= "string" or state == "" then
      state = nil
    end

    return parsedV, state
  end

  local v = readTxVoltage()
  if not v then
    return nil, "low"
  end

  if v >= 7.9 then
    return v, "full"
  elseif v >= 7.5 then
    return v, "ok"
  elseif v >= 7.1 then
    return v, "yellow"
  end

  return v, "low"
end

local function readClockText()
  if getDateTime then
    local dt = getDateTime()
    if dt and dt.hour ~= nil and dt.min ~= nil then
      return string.format("%02d:%02d", dt.hour, dt.min)
    end
  end

  return "--:--"
end

local function readDateText()
  if not getDateTime then
    return "-- ---"
  end

  local dt = getDateTime()
  if not dt then
    return "-- ---"
  end

  local day = tonumber(dt.day)
  if not day then
    return "-- ---"
  end

  local months = { "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" }
  local monthToken = dt.mon
  if monthToken == nil then
    monthToken = dt.month
  end

  local monthText = "---"
  if type(monthToken) == "number" then
    monthText = months[monthToken] or "---"
  elseif type(monthToken) == "string" and monthToken ~= "" then
    monthText = monthToken:sub(1, 3)
  end

  return string.format("%d %s", day, monthText)
end

local function drawLinkIcon(rect, connected)
  local isConnected = (connected == true)
  local icon = isConnected and ICON_LINK_ON or ICON_LINK_OFF
  local text = isConnected and "LINK" or "NO"
  local textColor = _THEME_WARNING
  local iconX = rect.x
  local iconY = rect.y

  if type(rect.w) == "number" then
    iconX = rect.x + math.floor((rect.w - LINK_ICON_W) / 2)
  end
  if type(rect.h) == "number" then
    iconY = rect.y + math.floor((rect.h - LINK_ICON_H) / 2)
  end

  if icon then
    if iconX < rect.x then
      iconX = rect.x
    end
    if iconY < rect.y then
      iconY = rect.y
    end
    -- Link status is determined only by icon choice; use one fixed draw color
    -- to avoid inheriting previous CUSTOM_COLOR state from text rendering.
    if lcd and type(lcd.setColor) == "function" and type(CUSTOM_COLOR) == "number" then
      lcd.setColor(CUSTOM_COLOR, _BLACK)
    end
    lcd.drawBitmap(icon, iconX, iconY)
    return
  end

  local textX = rect.x + math.floor((rect.w - (#text * 4)) / 2)
  if textX < rect.x then
    textX = rect.x
  end
  local textY = rect.y + 1
  if type(rect.h) == "number" then
    textY = rect.y + math.floor((rect.h - 8) / 2)
  end
  lcd.drawText(textX, textY, text, tf(SMLSIZE, textColor))
end

local function resolveTxBatteryIcon(state)
  local key = state

  if key == "yellow" then
    key = "warn"
  end

  if key ~= "full" and key ~= "ok" and key ~= "warn" and key ~= "low" and key ~= "dead" then
    key = "ok"
  end

  return BATTERY_ICONS[key] or BATTERY_ICONS.ok or ICON_TX_BATTERY
end

local function batteryLevelFromState(state)
  if state == "full" then
    return 3
  elseif state == "ok" then
    return 2
  elseif state == "warn" or state == "yellow" then
    return 1
  end
  return 0
end

local function drawBatteryGlyph(x, y, state)
  if not lcd then return false end

  local bw = 16
  local bh = 9
  local outline = _WHITE

  if lcd.drawRectangle then
    lcd.drawRectangle(x, y, bw, bh, outline)
    -- Positive terminal nub
    if lcd.drawFilledRectangle then
      local tipY = y + math.floor((bh - 3) / 2)
      lcd.drawFilledRectangle(x + bw, tipY, 2, 3, outline)
    end
    -- Fill reflecting battery level
    local level = batteryLevelFromState(state)
    if lcd.drawFilledRectangle and level > 0 then
      local fillColor
      if state == "low" or state == "dead" then
        fillColor = _RED
      elseif state == "warn" or state == "yellow" then
        fillColor = _YELLOW
      else
        fillColor = _GREEN
      end
      local maxFill = bw - 4
      local fillW = math.floor(maxFill * level / 3)
      if fillW > 0 then
        lcd.drawFilledRectangle(x + 2, y + 2, fillW, bh - 4, fillColor)
      end
    end
    return true
  elseif lcd.drawLine then
    -- Line-based fallback with explicit color (not FORCE)
    lcd.drawLine(x,        y,        x + bw, y,        SOLID, outline)
    lcd.drawLine(x,        y + bh,   x + bw, y + bh,   SOLID, outline)
    lcd.drawLine(x,        y,        x,      y + bh,   SOLID, outline)
    lcd.drawLine(x + bw,   y,        x + bw, y + bh,   SOLID, outline)
    return true
  end

  return false
end

local function drawTxBattery(rect, txV, txState)
  local txText = txV and string.format("%.1fV", txV) or "--.-V"
  local txColor = txV and _THEME_PRIMARY or _THEME_WARNING
  local textX = rect.x
  local textY = rect.y + 1

  if type(rect.h) == "number" then
    textY = rect.y + math.floor((rect.h - TX_TEXT_H) / 2) + TX_TEXT_NUDGE_Y
  end

  local drewIcon = false

  -- Try PNG state icon.
  local icon = resolveTxBatteryIcon(txState)
  if icon then
    local iconH = 32
    local iconY = rect.y
    if type(rect.h) == "number" then
      iconY = rect.y + math.floor((rect.h - iconH) / 2)
    end
    if iconY < rect.y then iconY = rect.y end
    lcd.drawBitmap(icon, rect.x, iconY)
    drewIcon = true
  end

  -- Vector fallback when no PNG is available.
  if not drewIcon then
    local glyphH = 9
    local glyphY = rect.y
    if type(rect.h) == "number" then
      glyphY = rect.y + math.floor((rect.h - glyphH) / 2)
    end
    drewIcon = drawBatteryGlyph(rect.x + 1, glyphY, txState)
  end

  if drewIcon then
    textX = rect.x + 30
  end

  lcd.drawText(textX, textY, txText, tf(MIDSIZE, txColor) + _SHADOWED)
end

function M.draw(bounds, telemetry)
  if not bounds then
    return
  end

  ensureIconsLoaded()

  local x = bounds.x
  local y = bounds.y
  local w = bounds.w
  local h = bounds.h

  local logoReserveW = 42
  local contentGap = 4
  local contentX = x + logoReserveW + contentGap
  local contentW = w - logoReserveW - contentGap
  if contentW < 80 then
    contentX = x + 2
    contentW = w - 4
  end

  local zone1W = math.floor(contentW * 0.45)
  local zone2W = math.floor(contentW * 0.20)
  local zone3W = math.floor(contentW * 0.10)
  local zone4W = contentW - zone1W - zone2W - zone3W

  local zone1 = { x = contentX, y = y, w = zone1W, h = h }
  local zone2 = { x = contentX + zone1W, y = y, w = zone2W, h = h }
  local zone3 = { x = zone2.x + zone2W, y = y, w = zone3W, h = h }
  local zone4 = { x = zone3.x + zone3W, y = y, w = zone4W, h = h }

  local timeText = readClockText()
  local dateText = readDateText()

  local smlCharW = 4
  local timeW = #timeText * smlCharW
  local dateW = #dateText * smlCharW

  local rightPad = 20
  local stackRight = zone4.x + zone4.w - rightPad

  local timeX = stackRight - timeW
  local dateX = stackRight - dateW

  local modelText = truncateText(readModelName(), zone1.w - 8, 6)

  -- Vertically center model name in full top bar height.
  local modelTextH = 35
  local modelY = y + math.floor((h - modelTextH) / 2)
  if modelY < y then
    modelY = y
  end

  lcd.drawText(zone1.x + 4, modelY, modelText, tf(MIDSIZE, _THEME_PRIMARY) + _BOLD + _SHADOWED)

  local txV, txState = readTxBatteryInfo()
  drawTxBattery({ x = zone2.x + 2 + TOPBAR_STATUS_X_OFFSET, y = y, h = h }, txV, txState)

  local connected = telemetry and telemetry.connected
  drawLinkIcon({ x = zone3.x + TOPBAR_STATUS_X_OFFSET, y = y, w = zone3.w, h = h }, connected)

  local timeY = y + 4
  local dateY = timeY + 13

  lcd.drawText(timeX, timeY, timeText, tf(SMLSIZE, _THEME_PRIMARY) + _SHADOWED)
  lcd.drawText(dateX, dateY, dateText, tf(SMLSIZE, _THEME_SECONDARY) + _SHADOWED)
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
  lcd.drawText(bounds.x + 2, bounds.y + 2, "Top Bar", SMLSIZE)
end

return M
