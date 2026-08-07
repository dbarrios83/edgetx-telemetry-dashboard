-- Context telemetry row renderer.
-- Draws a 2x4 grid of icon+value metrics using existing dashboard icons.

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
  for i = 1, #WIDGET_ROOTS do
    local chunk = loadScript(WIDGET_ROOTS[i] .. relativePath)
    if chunk then
      return chunk()
    end
  end
  return nil
end

local primitivesModule = loadSiblingModule("render/primitives.lua")

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
local _TEXT_COLOR = _WHITE

local toNumber = (primitivesModule and primitivesModule.toNumber) or function() return nil end

local openBitmapFromCandidates = (primitivesModule and primitivesModule.openBitmapFromCandidates)
  or function() return nil end

-- Icon sets are cached by icon folder ("dark"/"light"), not loaded into
-- shared module-level ICON_* locals. Two widget instances using
-- different themes (or one instance whose theme option changes) used to
-- fight over a single set of module-level variables, reopening every
-- bitmap on every refresh() whenever the two instances' folders
-- disagreed. The underlying files are static, theme-keyed assets, so
-- every instance sharing a theme can safely share the same loaded
-- bitmaps -- only the *load* needs to happen once per folder.
local _iconSets = {}

local function loadIconSet(iconFolder)
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

  return {
    ICON_CURRENT = openBitmapFromCandidates(roots, { "current.png" }),
    ICON_RADIO = openBitmapFromCandidates(roots, { "radio.png" }),
    ICON_RFMD = openBitmapFromCandidates(roots, { "rfmd.png" }),
    ICON_SIGNAL = openBitmapFromCandidates(roots, { "signal.png" }),
    ICON_NOISE = openBitmapFromCandidates(roots, { "noise.png" }),
    ICON_BATTERY = openBitmapFromCandidates(roots, { "battery.png" }),
    ICON_SAT = openBitmapFromCandidates(roots, { "sat.png", "sats.png" }),
    ICON_ANT = openBitmapFromCandidates(roots, { "antenna.png" }),
    ICON_DRONE = openBitmapFromCandidates(roots, { "drone.png" }),
  }
end

-- Returns this theme's icon set, loading and caching it on first request.
local function ensureIconsLoaded(theme)
  local iconFolder = (theme and theme.iconFolder) or "dark"
  local set = _iconSets[iconFolder]
  if not set then
    set = loadIconSet(iconFolder)
    _iconSets[iconFolder] = set
  end
  return set
end

-- Shadow color here is a simple txtColor-based heuristic -- deliberately
-- different from render/sticks.lua's/topbar.lua's theme-aware
-- _TEXT_SHADOW_COLOR; see render/primitives.lua's header comment for why
-- that's preserved per-renderer rather than unified.
local function drawShadowText(x, y, text, size, color)
  local txtColor = (type(color) == "number") and color or _WHITE
  local shadowColor = (txtColor == _WHITE) and _BLACK or _WHITE
  if primitivesModule and primitivesModule.drawShadowText then
    primitivesModule.drawShadowText(x, y, text, size, color, shadowColor)
  end
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

  local metricColor = (type(color) == "number") and color or _TEXT_COLOR

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
    return _TEXT_COLOR
  end

  if sats < 5 then
    return _RED
  elseif sats < 8 then
    return _YELLOW
  end

  return _GREEN
end

-- Returns telemetry[field] only when the normalized snapshot marks it
-- available, nil otherwise. This is the one place this renderer touches
-- telemetry data -- no direct getValue()/getFlightMode() calls here, so
-- a sensor that doesn't exist on a given model can never be silently
-- rendered as a valid zero (see telemetry/read.lua for how availability
-- is actually resolved, including alias fallback and the negative-cache
-- rescan).
local function avail(telemetry, field)
  if telemetry and telemetry.available and telemetry.available[field] then
    return telemetry[field]
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
    return "N/A"
  end

  -- Packet-rate resolution is centralized in telemetry/read.lua.
  -- The context renderer only formats the normalized numeric rate.
  return tostring(math.floor(n + 0.5)) .. "Hz"
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

local function bestRssi(v1, v2)
  local n1 = toNumber(v1)
  local n2 = toNumber(v2)

  -- In EdgeTX telemetry, 0 often means missing/not-updated for RSSI.
  -- Ignore zero so an absent antenna value does not mask a valid negative dBm.
  if n1 == 0 then n1 = nil end
  if n2 == 0 then n2 = nil end

  if n1 and n2 then
    return (n1 > n2) and n1 or n2
  end

  return n1 or n2
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

local function formatCapacity(raw)
  local n = toNumber(raw)
  if not n then
    return "N/A"
  end

  return tostring(math.floor(n + 0.5)) .. "mAh"
end

-- Flight-mode resolution (including the radio getFlightMode() fallback)
-- lives entirely in telemetry/read.lua; this only formats the already-
-- normalized string.
local function formatFlightMode(raw)
  if type(raw) == "string" and raw ~= "" and raw ~= "--" then
    return raw
  end
  return "---"
end

function M.draw(rect, telemetry, state, theme)
  if not rect then
    return
  end

  local textColor = (theme and theme.textColor) or _WHITE
  _TEXT_COLOR = textColor
  local icons = ensureIconsLoaded(theme)

  local x = rect.x + CONTEXT_X_OFFSET
  local y = rect.y
  local w = rect.w
  local h = rect.h

  local colW = math.floor(w / 4)
  local rowH = math.floor(h / 2)

  local connected = telemetry and telemetry.connected == true

  local curr, packetRate, tpwr, rssi1, rssi2, sats, fm, rsnr, cap
  if connected then
    curr = avail(telemetry, "current")
    packetRate = avail(telemetry, "packetRate")
    tpwr = avail(telemetry, "txPower")
    -- Antenna-1 RSSI intentionally falls back to the generic `rssi`
    -- field only, never to a bare "RSSI" sensor name -- that would read
    -- EdgeTX's internal radio RSSI instead of telemetry RSSI (see
    -- telemetry/read.lua's FIELD_SENSORS.rssi comment).
    rssi1 = avail(telemetry, "rssi1") or avail(telemetry, "rssi")
    rssi2 = avail(telemetry, "rssi2")
    sats = avail(telemetry, "sats") or avail(telemetry, "satellites")
    fm = avail(telemetry, "flightMode")
    rsnr = avail(telemetry, "rsnr")
    cap = avail(telemetry, "capacity")
  end

  local curText, rateText, pwrText, rssiText
  local satText, fmText, snrText, capText
  local satColor = _TEXT_COLOR

  if connected then
    local gpsValid = telemetry and telemetry.gpsValid == true
    local rssiBest = bestRssi(rssi1, rssi2)

    curText = formatCurrent(curr)
    rateText = formatPacketRate(packetRate)
    pwrText = formatTxPower(tpwr)
    rssiText = formatRssi(rssiBest)
    if gpsValid then
      satText = formatSat(sats)
      satColor = satStateColor(sats)
    else
      satText = "N/A"
      satColor = _TEXT_COLOR
    end
    fmText = formatFlightMode(fm)
    snrText = formatRssi(rsnr)
    capText = formatCapacity and formatCapacity(cap) or (toNumber(cap) and tostring(math.floor(toNumber(cap) + 0.5)) .. "mAh" or "N/A")
  else
    -- Disconnected view: keep placeholders compact (no units / no ANT prefix).
    curText = "--"
    rateText = "--"
    pwrText = "--"
    rssiText = "--"
    satText = "--"
    fmText = "--"
    snrText = "--"
    capText = "--"
  end

  local row1Y = y
  local row2Y = y + rowH
  local row2H = h - rowH

  local c0x = x
  local c1x = x + colW
  local c2x = x + (colW * 2)
  local c3x = x + (colW * 3)
  local c3w = w - (colW * 3)

  drawIconMetric(c0x, row1Y, colW, rowH, icons.ICON_CURRENT, curText)
  drawIconMetric(c1x, row1Y, colW, rowH, icons.ICON_RFMD, rateText)
  drawIconMetric(c2x, row1Y, colW, rowH, icons.ICON_RADIO, pwrText)
  drawIconMetric(c3x, row1Y, c3w, rowH, icons.ICON_SIGNAL, rssiText)

  drawIconMetric(c0x, row2Y, colW, row2H, icons.ICON_SAT or icons.ICON_BATTERY, satText, satColor)
  drawIconMetric(c1x, row2Y, colW, row2H, icons.ICON_DRONE, fmText)
  drawIconMetric(c2x, row2Y, colW, row2H, icons.ICON_NOISE or icons.ICON_SIGNAL, snrText)
  drawIconMetric(c3x, row2Y, c3w, row2H, icons.ICON_BATTERY, capText)
end

function M.drawSkeleton(rect)
  if not rect or not lcd or not lcd.drawText then
    return
  end

  lcd.drawText(rect.x + 2, rect.y + 2, "Context", _SMLSIZE)
end

return M
