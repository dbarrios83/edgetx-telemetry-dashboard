-- Timer row renderer.
-- Draws three timer cells with clock icon + shadowed MM:SS value.

local M = {}

local _WHITE = (type(WHITE) == "number") and WHITE or 0xFFFF
local _BLACK = 0x0000
local _SMLSIZE = (type(SMLSIZE) == "number") and SMLSIZE or 0

local ICON_SIZE = 24
local ICON_TEXT_GAP = 8
local TEXT_H = 8
local TIMER_TEXT_SLOT_W = 34
local TIMER_TEXT_Y_OFFSET = -4

local ICON_CLOCK = nil
local _iconsLoaded = false
local _loadedIconFolder = nil
local _TEXT_COLOR = _WHITE

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

local function ensureIconsLoaded(theme)
  local iconFolder = (theme and theme.iconFolder) or "dark"
  if _iconsLoaded and _loadedIconFolder == iconFolder then
    return
  end
  _loadedIconFolder = iconFolder

  local roots = {
    "/WIDGETS/FPVDASH/icons/" .. iconFolder .. "/",
    "/SCRIPTS/WIDGETS/FPVDASH/icons/" .. iconFolder .. "/",
    "WIDGETS/FPVDASH/icons/" .. iconFolder .. "/",
    "SCRIPTS/WIDGETS/FPVDASH/icons/" .. iconFolder .. "/",
    "/WIDGETS/FPVDASH/icons/",
    "/SCRIPTS/WIDGETS/FPVDASH/icons/",
    "WIDGETS/FPVDASH/icons/",
    "SCRIPTS/WIDGETS/FPVDASH/icons/",
  }

  ICON_CLOCK = openBitmapFromCandidates(roots, { "clock.png" })
  _iconsLoaded = true
end

local function drawShadowText(x, y, text, size, color)
  if not lcd or type(lcd.drawText) ~= "function" then
    return
  end

  local txtColor = (type(color) == "number") and color or _WHITE
  local shadowColor = (txtColor == _WHITE) and _BLACK or _WHITE

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

local function formatTimer(raw)
  local n = toNumber(raw)
  if type(n) ~= "number" then
    return "--:--"
  end

  local total = math.floor(n)
  if total < 0 then
    total = 0
  end

  local m = math.floor(total / 60)
  local s = total % 60
  return string.format("%02d:%02d", m, s)
end

local function drawTimerMetric(x, y, w, h, icon, text)
  if not lcd then
    return
  end

  local contentW = ICON_SIZE + ICON_TEXT_GAP + TIMER_TEXT_SLOT_W
  local startX = x + math.floor((w - contentW) / 2)
  if startX < x then
    startX = x
  end

  local iconY = y + math.floor((h - ICON_SIZE) / 2)
  if iconY < y then
    iconY = y
  end

  local textY = y + math.floor((h - TEXT_H) / 2) + TIMER_TEXT_Y_OFFSET
  if textY < y then
    textY = y
  end

  if icon and type(lcd.drawBitmap) == "function" then
    lcd.drawBitmap(icon, startX, iconY)
  end

  drawShadowText(startX + ICON_SIZE + ICON_TEXT_GAP, textY, text, _SMLSIZE, _TEXT_COLOR)
end

local function readTimer(name)
  if not getValue then
    return nil
  end
  return getValue(name)
end

function M.draw(rect, telemetry, state, theme)
  if not rect then
    return
  end

  local textColor = (theme and theme.textColor) or _WHITE
  _TEXT_COLOR = textColor
  ensureIconsLoaded(theme)

  local colW = math.floor(rect.w / 3)
  local col0 = rect.x
  local col1 = rect.x + colW
  local col2 = rect.x + (colW * 2)

  local timer1Text = formatTimer(readTimer("timer1"))
  local timer2Text = formatTimer(readTimer("timer2"))
  local timer3Text = formatTimer(readTimer("timer3"))

  drawTimerMetric(col0, rect.y, colW, rect.h, ICON_CLOCK, timer1Text)
  drawTimerMetric(col1, rect.y, colW, rect.h, ICON_CLOCK, timer2Text)
  drawTimerMetric(col2, rect.y, rect.w - (colW * 2), rect.h, ICON_CLOCK, timer3Text)
end

function M.drawSkeleton(rect)
  if not rect or not lcd or type(lcd.drawText) ~= "function" then
    return
  end

  lcd.drawText(rect.x + 2, rect.y + 2, "Timers", _SMLSIZE)
end

return M
