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
    local ok, v = pcall(getVersion)
    if ok and type(v) == "string" and #v > 0 then
      _edgeTxVersionCached = "EdgeTX " .. v
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

local function estimateTextW(text)
  return #text * CHAR_W
end

function M.draw(rect, telemetry, state)
  if not rect then
    return
  end

  -- ELRS version: prefer telemetry field, fallback to bare label.
  local elrsText = "ELRS"
  if telemetry and type(telemetry.elrsVersion) == "string" and #telemetry.elrsVersion > 0 then
    elrsText = "ELRS " .. telemetry.elrsVersion
  end

  local edgeTxText = resolveEdgeTxVersion()

  -- Sit text 2 px above the bottom-anchored rect so it clears the screen edge.
  local ty = rect.y - 1

  -- Bottom-left: ELRS version.
  drawShadowText(rect.x + MARGIN_H, ty, elrsText, _SMLSIZE, _WHITE)

  -- Bottom-right: EdgeTX version, right-aligned.
  local edgeTxW = estimateTextW(edgeTxText)
  drawShadowText(rect.x + rect.w - edgeTxW - MARGIN_H_RIGHT, ty, edgeTxText, _SMLSIZE, _WHITE)
end

return M
