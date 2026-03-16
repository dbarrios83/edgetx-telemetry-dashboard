-- Footer renderer.
-- Renders ELRS version bottom-left and EdgeTX version bottom-right.
-- Shown only on 480×320 class radios; omitted on 480×272 class.

local M = {}

local _WHITE   = (type(WHITE)   == "number") and WHITE   or 0xFFFF
local _BLACK   = 0x0000
local _SMLSIZE = (type(SMLSIZE) == "number") and SMLSIZE or 0

-- Horizontal margin from the rect edges.
local MARGIN_H = 4
-- Right margin is wider to keep EdgeTX text clear of the screen edge.
local MARGIN_H_RIGHT = 7
-- Estimated pixel width per SMLSIZE character.
-- Slightly over-estimated so right-aligned text stays inside the zone.
local CHAR_W   = 6

-- EdgeTX version is static — resolve once and cache.
local _edgeTxVersionCached = nil

local function resolveEdgeTxVersion()
  if _edgeTxVersionCached then
    return _edgeTxVersionCached
  end

  if type(getVersion) == "function" then
    local ok, _, _, major, minor, rev, osname = pcall(getVersion)
    if ok and type(major) == "number" and type(minor) == "number" and type(rev) == "number" then
      local name = (type(osname) == "string" and #osname > 0) and osname or "EdgeTX"
      _edgeTxVersionCached = string.format("%s %d.%d.%d", name, major, minor, rev)
      return _edgeTxVersionCached
    end
  end

  _edgeTxVersionCached = "EdgeTX"
  return _edgeTxVersionCached
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

local function estimateTextW(text)
  return #text * CHAR_W
end

function M.draw(rect, telemetry, state, theme)
  if not rect then
    return
  end

  local textColor = (theme and theme.textColor) or _WHITE

  -- ELRS version: full string supplied by elrsModule (e.g. "ELRS 3.4.0").
  local elrsText = (telemetry and type(telemetry.elrsVersion) == "string" and #telemetry.elrsVersion > 0)
    and telemetry.elrsVersion
    or  "ELRS"

  local edgeTxText = resolveEdgeTxVersion()

  -- Sit text 2 px above the bottom-anchored rect so it clears the screen edge.
  local ty = rect.y - 1

  -- Bottom-left: ELRS version.
  drawShadowText(rect.x + MARGIN_H, ty, elrsText, _SMLSIZE, textColor)

  -- Bottom-right: EdgeTX version, right-aligned.
  local edgeTxW = estimateTextW(edgeTxText)
  drawShadowText(rect.x + rect.w - edgeTxW - MARGIN_H_RIGHT, ty, edgeTxText, _SMLSIZE, textColor)
end

return M
