-- Context telemetry row renderer.
-- Draws a 2x4 grid of icon+value metrics using existing dashboard icons.

local M = {}

local _WHITE = (type(WHITE) == "number") and WHITE or 0xFFFF
local _BLACK = 0x0000
local _RED = (type(RED) == "number") and RED or 0xF800
local _YELLOW = (type(YELLOW) == "number") and YELLOW or 0xFFE0
local _GREEN = (type(GREEN) == "number") and GREEN or 0x07E0
local _SMLSIZE = (type(SMLSIZE) == "number") and SMLSIZE or 0
-- Set to nil to keep native icon colors.
-- Set to a color constant/value (e.g. WHITE, RED, GREEN, 0x7BEF) to tint.
local ICON_TINT_COLOR = nil
local ICON_SIZE = 24
local ICON_TEXT_GAP = 8
local TEXT_CHAR_W = 5
local TEXT_H = 8
local TEXT_Y_OFFSET = -4
local TEXT_SLOT_W = 34
local CONTEXT_X_OFFSET = -4

local _iconsLoaded = false
local ICON_CURRENT = nil
local ICON_RADIO = nil
local ICON_RFMD = nil
local ICON_SIGNAL = nil
local ICON_BATTERY = nil
local ICON_SAT = nil
local ICON_ANT = nil
local ICON_DRONE = nil

local PACKET_RATE_FROM_RFMD = {
  [1] = 25,
  [2] = 50,
  [3] = 100,
  [4] = 150,
  [5] = 250,
  [6] = 500,
  [7] = 1000,
}

local toNumber

local function openBitmapFromCandidates(roots, names)
  if not Bitmap or type(Bitmap.open) ~= "function" then
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

local function ensureIconsLoaded()
  if _iconsLoaded then
    return
  end

  local roots = {
    "/WIDGETS/FPVDASH/icons/",
    "/SCRIPTS/WIDGETS/FPVDASH/icons/",
    "WIDGETS/FPVDASH/icons/",
    "SCRIPTS/WIDGETS/FPVDASH/icons/",
  }

  ICON_CURRENT = openBitmapFromCandidates(roots, { "current.png" })
  ICON_RADIO = openBitmapFromCandidates(roots, { "radio.png" })
  ICON_RFMD = openBitmapFromCandidates(roots, { "rfmd.png" })
  ICON_SIGNAL = openBitmapFromCandidates(roots, { "signal.png" })
  ICON_BATTERY = openBitmapFromCandidates(roots, { "battery.png" })
  ICON_SAT = openBitmapFromCandidates(roots, { "sat.png", "sats.png" })
  ICON_ANT = openBitmapFromCandidates(roots, { "antenna.png" })
  ICON_DRONE = openBitmapFromCandidates(roots, { "drone.png" })

  _iconsLoaded = true
end

local function drawShadowText(x, y, text, size, color)
  if not lcd or type(lcd.drawText) ~= "function" then
    return
  end

  local hasCustomColor = type(CUSTOM_COLOR) == "number"

  if hasCustomColor and type(lcd.setColor) == "function" then
    lcd.setColor(CUSTOM_COLOR, _BLACK)
    lcd.drawText(x + 1, y + 1, text, size + CUSTOM_COLOR)

    lcd.setColor(CUSTOM_COLOR, color)
    lcd.drawText(x, y, text, size + CUSTOM_COLOR)
    return
  end

  lcd.drawText(x + 1, y + 1, text, size)
  lcd.drawText(x, y, text, size)
end

local function drawIconMetric(x, y, w, h, icon, text, color)
  if not lcd then
    return
  end

  local label = tostring(text or "---")
  local contentW = ICON_SIZE + ICON_TEXT_GAP + TEXT_SLOT_W

  local startX = x + math.floor((w - contentW) / 2)
  if startX < x then
    startX = x
  end

  local iconY = y + math.floor((h - ICON_SIZE) / 2)
  if iconY < y then
    iconY = y
  end

  local textY = y + math.floor((h - TEXT_H) / 2) + TEXT_Y_OFFSET
  if textY < y then
    textY = y
  end

  local metricColor = (type(color) == "number") and color or _WHITE

  if icon and type(lcd.drawBitmap) == "function" then
    if type(CUSTOM_COLOR) == "number" and type(lcd.setColor) == "function" then
      local iconColor = metricColor
      if type(ICON_TINT_COLOR) == "number" then
        iconColor = ICON_TINT_COLOR
      end
      lcd.setColor(CUSTOM_COLOR, iconColor)
      lcd.drawBitmap(icon, startX, iconY)
    else
      lcd.drawBitmap(icon, startX, iconY)
    end
    startX = startX + ICON_SIZE + ICON_TEXT_GAP
  end

  drawShadowText(startX, textY, label, _SMLSIZE, metricColor)
end

local function satStateColor(raw)
  local sats = toNumber(raw)
  if type(sats) ~= "number" then
    return _WHITE
  end

  if sats < 5 then
    return _RED
  elseif sats < 8 then
    return _YELLOW
  end

  return _GREEN
end

toNumber = function(v)
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

local function readValue(name)
  if not getValue then
    return nil
  end
  return getValue(name)
end

local function readValueFirst(names)
  for i = 1, #names do
    local v = readValue(names[i])
    if v ~= nil and v ~= "" then
      return v
    end
  end
  return nil
end

local function formatCurrent(raw)
  local n = toNumber(raw)
  if not n then
    return "--.-A"
  end
  return string.format("%.1fA", n)
end

local function formatTxPower(raw)
  local n = toNumber(raw)
  if n then
    return string.format("%dmW", math.floor(n + 0.5))
  end

  if type(raw) == "string" and raw ~= "" then
    return raw
  end

  return "--mW"
end

local function formatPacketRate(raw)
  local n = toNumber(raw)
  if not n then
    return "--Hz"
  end

  local rate = PACKET_RATE_FROM_RFMD[n] or n
  return string.format("%dHz", math.floor(rate + 0.5))
end

local function formatRssi(raw)
  local n = toNumber(raw)
  if not n or n == 0 then
    return "--"
  end

  if n >= 0 then
    return tostring(math.floor(n + 0.5)) .. "dBm"
  end

  return tostring(math.ceil(n - 0.5)) .. "dBm"
end

local function formatSat(raw)
  local n = toNumber(raw)
  if not n then
    return "--"
  end
  return tostring(math.floor(n + 0.5))
end

local function formatAntenna(raw)
  local n = toNumber(raw)
  if n then
    return "ANT" .. tostring(math.floor(n + 0.5))
  end

  if type(raw) == "string" and raw ~= "" then
    return raw
  end

  return "ANT-"
end

local function formatFlightMode(raw)
  if type(raw) == "string" and raw ~= "" then
    return raw
  end

  if getFlightMode then
    local mode = getFlightMode()
    if type(mode) == "string" and mode ~= "" then
      return mode
    end
  end

  return "---"
end

function M.draw(rect, telemetry, state)
  if not rect then
    return
  end

  ensureIconsLoaded()

  local x = rect.x + CONTEXT_X_OFFSET
  local y = rect.y
  local w = rect.w
  local h = rect.h

  local colW = math.floor(w / 4)
  local rowH = math.floor(h / 2)

  local connected = telemetry and telemetry.connected == true

  local curr, tpwr, rfmd, rssi1, sats, ant, fm, rssi2
  if connected then
    curr = readValue("Curr")
    tpwr = readValue("TPWR")
    rfmd = readValue("RFMD")
    rssi1 = readValueFirst({ "1RSS", "RSSI" })
    sats = readValueFirst({ "Sats", "SATS", "SAT" })
    ant = readValue("ANT")
    fm = readValue("FM")
    rssi2 = readValueFirst({ "2RSS", "RSSI2" })

    if curr == nil and telemetry then curr = telemetry.current end
    if tpwr == nil and telemetry then tpwr = telemetry.txPower end
    if rfmd == nil and telemetry then rfmd = telemetry.packetRate end
    if telemetry then
      local n1 = toNumber(rssi1)
      local n2 = toNumber(rssi2)

      if (rssi1 == nil or n1 == 0) and telemetry.available and telemetry.available.rssi1 then
        rssi1 = telemetry.rssi1
      elseif (rssi1 == nil or n1 == 0) and telemetry.available and telemetry.available.rssi then
        rssi1 = telemetry.rssi
      end

      if (rssi2 == nil or n2 == 0) and telemetry.available and telemetry.available.rssi2 then
        rssi2 = telemetry.rssi2
      end
    end
    if sats == nil and telemetry then sats = telemetry.sats or telemetry.satellites end
    if ant == nil and telemetry then ant = telemetry.activeAntenna end
    if fm == nil and telemetry then fm = telemetry.flightMode end
    if rssi2 == nil and telemetry then rssi2 = telemetry.rssi2 end
  end

  local curText, pwrText, rateText, rssi1Text
  local satText, antText, fmodeText, rssi2Text
  local satColor = _WHITE

  if connected then
    curText = formatCurrent(curr)
    pwrText = formatTxPower(tpwr)
    rateText = formatPacketRate(rfmd)
    rssi1Text = formatRssi(rssi1)
    satText = formatSat(sats)
    satColor = satStateColor(sats)
    antText = formatAntenna(ant)
    fmodeText = formatFlightMode(fm)
    rssi2Text = formatRssi(rssi2)
  else
    -- Disconnected view: keep placeholders compact (no units / no ANT prefix).
    curText = "--"
    pwrText = "--"
    rateText = "--"
    rssi1Text = "--"
    satText = "--"
    antText = "--"
    fmodeText = "--"
    rssi2Text = "--"
  end

  local row1Y = y
  local row2Y = y + rowH
  local row2H = h - rowH

  local c0x = x
  local c1x = x + colW
  local c2x = x + (colW * 2)
  local c3x = x + (colW * 3)
  local c3w = w - (colW * 3)

  drawIconMetric(c0x, row1Y, colW, rowH, ICON_CURRENT, curText)
  drawIconMetric(c1x, row1Y, colW, rowH, ICON_RADIO, pwrText)
  drawIconMetric(c2x, row1Y, colW, rowH, ICON_RFMD, rateText)
  drawIconMetric(c3x, row1Y, c3w, rowH, ICON_SIGNAL, rssi1Text)

  drawIconMetric(c0x, row2Y, colW, row2H, ICON_SAT or ICON_BATTERY, satText, satColor)
  drawIconMetric(c1x, row2Y, colW, row2H, ICON_ANT, antText)
  drawIconMetric(c2x, row2Y, colW, row2H, ICON_DRONE, fmodeText)
  drawIconMetric(c3x, row2Y, c3w, row2H, ICON_SIGNAL, rssi2Text)
end

function M.drawSkeleton(rect)
  if not rect or not lcd or not lcd.drawText then
    return
  end

  lcd.drawText(rect.x + 2, rect.y + 2, "Context", _SMLSIZE)
end

return M
