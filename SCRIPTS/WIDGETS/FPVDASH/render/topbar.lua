-- Top bar renderer.
-- Renders model name, transmitter battery, telemetry link status, and time.

local M = {}

local ICON_LINK_ON = nil
local ICON_LINK_OFF = nil

do
  if Bitmap then
    local roots = {
      "/WIDGETS/FPVDASH/icons/",
      "/SCRIPTS/WIDGETS/FPVDASH/icons/",
      "WIDGETS/FPVDASH/icons/",
      "SCRIPTS/WIDGETS/FPVDASH/icons/",
    }

    for _, root in ipairs(roots) do
      local bm = Bitmap.open(root .. "link.png")
      if bm then
        ICON_LINK_ON = bm
        break
      end
    end

    for _, root in ipairs(roots) do
      local bm = Bitmap.open(root .. "link_off.png")
      if bm then
        ICON_LINK_OFF = bm
        break
      end
    end
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

local function truncateText(text, maxWidth)
  local charW = 4
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

local function readClockText()
  if getDateTime then
    local dt = getDateTime()
    if dt and dt.hour ~= nil and dt.min ~= nil then
      return string.format("%02d:%02d", dt.hour, dt.min)
    end
  end

  return "--:--"
end

local function drawLinkIcon(rect, connected)
  local icon = connected and ICON_LINK_ON or ICON_LINK_OFF

  if icon then
    local iconH = math.max(8, math.min(rect.h - 4, 32))
    local scale = math.max(1, math.floor(iconH / 32 * 100))
    lcd.drawBitmap(icon, rect.x + 2, rect.y + 2, scale)
    return
  end

  lcd.drawText(rect.x + 2, rect.y + 2, connected and "LINK" or "NO", SMLSIZE)
end

function M.draw(bounds, telemetry)
  if not bounds then
    return
  end

  lcd.drawRectangle(bounds.x, bounds.y, bounds.w, bounds.h)

  local x = bounds.x
  local y = bounds.y
  local w = bounds.w
  local h = bounds.h

  local modelW = math.floor(w * 0.42)
  local txW = math.floor(w * 0.20)
  local linkW = math.floor(w * 0.14)
  local timeW = w - modelW - txW - linkW

  local modelRect = { x = x, y = y, w = modelW, h = h }
  local txRect = { x = x + modelW, y = y, w = txW, h = h }
  local linkRect = { x = txRect.x + txW, y = y, w = linkW, h = h }
  local timeRect = { x = linkRect.x + linkW, y = y, w = timeW, h = h }

  lcd.drawLine(txRect.x, y + 1, txRect.x, y + h - 2, SOLID, FORCE)
  lcd.drawLine(linkRect.x, y + 1, linkRect.x, y + h - 2, SOLID, FORCE)
  lcd.drawLine(timeRect.x, y + 1, timeRect.x, y + h - 2, SOLID, FORCE)

  local modelText = truncateText(readModelName(), modelRect.w - 4)
  lcd.drawText(modelRect.x + 2, modelRect.y + 2, modelText, SMLSIZE)

  local txV = readTxVoltage()
  local txText = txV and string.format("%.1fV", txV) or "--.-V"
  lcd.drawText(txRect.x + 2, txRect.y + 2, txText, SMLSIZE)

  local connected = telemetry and telemetry.connected
  drawLinkIcon(linkRect, connected)

  local timeText = readClockText()
  lcd.drawText(timeRect.x + 2, timeRect.y + 2, timeText, SMLSIZE)
end

function M.drawSkeleton(bounds)
  if not bounds then
    return
  end

  lcd.drawRectangle(bounds.x, bounds.y, bounds.w, bounds.h)
  lcd.drawText(bounds.x + 2, bounds.y + 2, "Top Bar", SMLSIZE)
end

return M
