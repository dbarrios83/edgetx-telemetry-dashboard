-- Card renderer.
-- M.draw renders live telemetry cards; P1 (battery) is fully implemented.
-- Remaining slots continue to render as skeleton until their cards are added.
-- M.drawSkeleton renders pure wireframe for all slots (debugging / layout pass).

local M = {}

-- ─── Color constants ──────────────────────────────────────────────────────────
-- Guard against monochrome builds where colour globals may be absent.
local _WHITE  = (type(WHITE)  == "number") and WHITE  or 0xFFFF
local _GREEN  = (type(GREEN)  == "number") and GREEN  or _WHITE
local _YELLOW = (type(YELLOW) == "number") and YELLOW or _WHITE
local _RED    = (type(RED)    == "number") and RED    or _WHITE

-- ─── Icon handles ─────────────────────────────────────────────────────────────
-- Loaded once at module startup; nil when asset is unavailable or Bitmap absent.
local ICON_BATTERY = nil
local ICON_SIGNAL = nil
local ICON_RFMD = nil
local ICON_CURRENT = nil
local ICON_SAT = nil
local ICON_ANTENNA = nil
local ICON_DRONE = nil
do
  if Bitmap then
    local roots = {
      "/WIDGETS/FPVDASH/icons/",
      "/SCRIPTS/WIDGETS/FPVDASH/icons/",
      "WIDGETS/FPVDASH/icons/",
      "SCRIPTS/WIDGETS/FPVDASH/icons/",
    }
    for _, root in ipairs(roots) do
      local bm = Bitmap.open(root .. "battery.png")
      if bm then
        ICON_BATTERY = bm
        break
      end
    end

    for _, root in ipairs(roots) do
      local bm = Bitmap.open(root .. "signal.png")
      if bm then
        ICON_SIGNAL = bm
        break
      end
    end

    for _, root in ipairs(roots) do
      local bm = Bitmap.open(root .. "rfmd.png")
      if bm then
        ICON_RFMD = bm
        break
      end
    end

    for _, root in ipairs(roots) do
      local bm = Bitmap.open(root .. "current.png")
      if bm then
        ICON_CURRENT = bm
        break
      end
    end

    for _, root in ipairs(roots) do
      local bm = Bitmap.open(root .. "sat.png")
      if bm then
        ICON_SAT = bm
        break
      end
    end

    for _, root in ipairs(roots) do
      local bm = Bitmap.open(root .. "antenna.png")
      if bm then
        ICON_ANTENNA = bm
        break
      end
    end

    for _, root in ipairs(roots) do
      local bm = Bitmap.open(root .. "drone.png")
      if bm then
        ICON_DRONE = bm
        break
      end
    end
  end
end

local icons = {
  battery = ICON_BATTERY,
  lq = ICON_SIGNAL,
  signal = ICON_SIGNAL,
  rfmd = ICON_RFMD,
  current = ICON_CURRENT,
  sat = ICON_SAT,
  antenna = ICON_ANTENNA,
  drone = ICON_DRONE,
}

-- ─── Slot order ───────────────────────────────────────────────────────────────
local PRIMARY_ORDER  = { "P1", "P2", "P3", "P4", "P5", "P6" }
local CONTEXT_ORDER  = { "C1", "C2" }
local OPTIONAL_ORDER = { "O1", "O2", "O3", "O4" }

-- ─── Helpers ──────────────────────────────────────────────────────────────────
local function clamp(v, lo, hi)
  if v < lo then return lo end
  if v > hi then return hi end
  return v
end

local function stateColor(s)
  if s == "OK"       then return _GREEN  end
  if s == "WARNING"  then return _YELLOW end
  if s == "CRITICAL" then return _RED    end
  return _WHITE
end

-- Combine a size flag with a colour flag safely.
local function tf(size, color)
  if type(color) == "number" then
    return size + color
  end
  return size
end

local function drawCenteredLabel(rect, label)
  local textW = #label * 4
  local textH = 8
  local tx = rect.x + math.floor((rect.w - textW) / 2)
  local ty = rect.y + math.floor((rect.h - textH) / 2)
  lcd.drawText(tx, ty, label, SMLSIZE)
end

local function drawLabelAbove(rect, label)
  local textW = #label * 4
  local textH = 8
  local tx = rect.x + math.floor((rect.w - textW) / 2)
  local ty = rect.y - textH - 1
  if ty < 0 then ty = rect.y + 1 end
  lcd.drawText(tx, ty, label, SMLSIZE)
end

local function drawBox(rect, label)
  if not rect then return end
  lcd.drawRectangle(rect.x, rect.y, rect.w, rect.h)
  if label then drawCenteredLabel(rect, label) end
end

local function drawSlots(group, order)
  if not group then return end
  for i = 1, #order do
    local id   = order[i]
    local slot = group[id]
    if slot then drawBox(slot, id) end
  end
end

-- Draw one telemetry card with centralized styling and layout behavior.
-- Example:
-- drawCard(rect, { icon = icons.signal, value = telemetry.rssi, unit = "dBm", state = state.rssi })
local function drawCard(rect, spec)
  if not rect or not spec then
    return
  end

  lcd.drawRectangle(rect.x, rect.y, rect.w, rect.h)

  local padX = spec.padX or 2
  local padY = spec.padY or 2
  local textTop = rect.y + padY
  local value = spec.value

  local isAvailable = true
  if spec.isAvailable then
    isAvailable = spec.isAvailable(value, spec)
  else
    isAvailable = value ~= nil and value ~= ""
  end

  if not isAvailable then
    drawCenteredLabel(rect, spec.placeholder or "---")
    return
  end

  local iconAreaW = 0
  if spec.icon then
    local iconH = clamp(rect.h - padY * 2, 8, 32)
    local scale = math.max(1, math.floor(iconH / 32 * 100))
    lcd.drawBitmap(spec.icon, rect.x + padX, rect.y + padY, scale)
    iconAreaW = iconH + padX + 2
  end

  local textX = rect.x + iconAreaW + padX

  local color = stateColor(spec.state)
  local valueText
  if spec.formatValue then
    valueText = spec.formatValue(value)
  else
    valueText = tostring(value)
  end

  lcd.drawText(textX, textTop, valueText, tf(spec.valueFlags or MIDSIZE, color))

  local subText = spec.secondaryText
  if not subText and spec.unit then
    subText = spec.unit
  end

  if subText then
    local subY = textTop + (spec.unitOffset or 16)
    if subY + 8 <= rect.y + rect.h then
      lcd.drawText(textX, subY, subText, spec.secondaryFlags or SMLSIZE)
    end
  end
end

local function availablePositive(v)
  return type(v) == "number" and v > 0
end

local function availableNonZero(v)
  return type(v) == "number" and v ~= 0
end

local function availableNotDisconnected(v, spec)
  return type(v) == "number" and spec and spec.state ~= "DISCONNECTED"
end

local function availableText(v)
  return type(v) == "string" and v ~= "" and v ~= "--"
end

local function formatBatteryValue(v)
  return string.format("%.2fV", v)
end

local function formatRSSIValue(v)
  local value
  if v >= 0 then
    value = math.floor(v + 0.5)
  else
    value = math.ceil(v - 0.5)
  end
  return tostring(value)
end

local function formatRateValue(v)
  return tostring(math.floor(v + 0.5))
end

local function formatPercentValue(v)
  return tostring(math.floor(v + 0.5))
end

local function formatCurrentValue(v)
  return string.format("%.1f", v)
end

local function formatSatValue(v)
  return tostring(math.floor(v + 0.5))
end

local function formatTxPowerValue(v)
  return tostring(math.floor(v + 0.5))
end

local function formatFlightModeValue(v)
  return tostring(v)
end

local function formatDiagRSSIValue(v)
  return string.format("%sdBm", formatRSSIValue(v))
end

local function formatCapacityValue(v)
  return string.format("%dmAh", math.floor(v + 0.5))
end

local function formatAntennaValue(v)
  return "ANT" .. tostring(math.floor(v + 0.5))
end

local BATTERY_CARD_SPEC = {
  icon = icons.battery,
  state = "UNKNOWN",
  value = 0,
  isAvailable = availablePositive,
  formatValue = formatBatteryValue,
  valueFlags = MIDSIZE,
  secondaryFlags = SMLSIZE,
  secondaryText = nil,
  unitOffset = 16,
  placeholder = "---",
}

local RSSI_CARD_SPEC = {
  icon = icons.signal,
  state = "UNKNOWN",
  value = 0,
  isAvailable = availableNonZero,
  formatValue = formatRSSIValue,
  unit = "dBm",
  valueFlags = MIDSIZE,
  secondaryFlags = SMLSIZE,
  unitOffset = 16,
  placeholder = "---",
}

local RATE_CARD_SPEC = {
  icon = icons.rfmd,
  state = "UNKNOWN",
  value = 0,
  isAvailable = availablePositive,
  formatValue = formatRateValue,
  unit = "Hz",
  valueFlags = MIDSIZE,
  secondaryFlags = SMLSIZE,
  unitOffset = 16,
  placeholder = "---",
}

local LQ_CARD_SPEC = {
  icon = icons.lq,
  state = "UNKNOWN",
  value = 0,
  isAvailable = availableNotDisconnected,
  formatValue = formatPercentValue,
  unit = "%",
  valueFlags = MIDSIZE,
  secondaryFlags = SMLSIZE,
  unitOffset = 16,
  placeholder = "---",
}

local CURRENT_CARD_SPEC = {
  icon = icons.current,
  state = "UNKNOWN",
  value = 0,
  isAvailable = availableNotDisconnected,
  formatValue = formatCurrentValue,
  unit = "A",
  valueFlags = MIDSIZE,
  secondaryFlags = SMLSIZE,
  unitOffset = 16,
  placeholder = "---",
}

local SAT_CARD_SPEC = {
  icon = icons.sat,
  state = "UNKNOWN",
  value = 0,
  isAvailable = availableNotDisconnected,
  formatValue = formatSatValue,
  secondaryText = "SAT",
  valueFlags = MIDSIZE,
  secondaryFlags = SMLSIZE,
  unitOffset = 16,
  placeholder = "---",
}

local TX_POWER_CARD_SPEC = {
  icon = icons.antenna,
  state = "UNKNOWN",
  value = 0,
  isAvailable = availablePositive,
  formatValue = formatTxPowerValue,
  unit = "mW",
  valueFlags = MIDSIZE,
  secondaryFlags = SMLSIZE,
  unitOffset = 16,
  placeholder = "---",
}

local FLIGHT_MODE_CARD_SPEC = {
  icon = icons.drone,
  state = nil,
  value = "",
  isAvailable = availableText,
  formatValue = formatFlightModeValue,
  valueFlags = SMLSIZE,
  secondaryFlags = SMLSIZE,
  unitOffset = 16,
  placeholder = "---",
}

local DIAG_RSSI1_CARD_SPEC = {
  icon = icons.signal,
  state = nil,
  value = 0,
  isAvailable = availableNonZero,
  formatValue = formatDiagRSSIValue,
  valueFlags = SMLSIZE,
  placeholder = "",
}

local DIAG_RSSI2_CARD_SPEC = {
  icon = icons.signal,
  state = nil,
  value = 0,
  isAvailable = availableNonZero,
  formatValue = formatDiagRSSIValue,
  valueFlags = SMLSIZE,
  placeholder = "",
}

local DIAG_CAPACITY_CARD_SPEC = {
  icon = icons.battery,
  state = nil,
  value = 0,
  isAvailable = availablePositive,
  formatValue = formatCapacityValue,
  valueFlags = SMLSIZE,
  placeholder = "",
}

local DIAG_ANTENNA_CARD_SPEC = {
  icon = icons.antenna,
  state = nil,
  value = 0,
  isAvailable = availablePositive,
  formatValue = formatAntennaValue,
  valueFlags = SMLSIZE,
  placeholder = "",
}

-- ─── Battery card (P1) ────────────────────────────────────────────────────────
-- Displays average per-cell voltage and detected cell count inside the P1 slot.
-- Cell count uses: cells = floor(voltage / 4.2) + 1  (LiPo max 4.2 V/cell)
local function drawBattery(slot, telemetry, state)
  if not slot then return end
  local packVoltage = (telemetry and telemetry.battery) or 0

  -- Auto-detect cell count from max-charge voltage (4.2 V/cell).
  local cells = 1
  if packVoltage > 0 then
    cells = math.max(1, math.floor(packVoltage / 4.2) + 1)
  end

  local cellVoltage = 0
  if packVoltage > 0 and cells > 0 then
    cellVoltage = packVoltage / cells
  end

  BATTERY_CARD_SPEC.icon = icons.battery
  BATTERY_CARD_SPEC.value = cellVoltage
  BATTERY_CARD_SPEC.state = (state and state.battery) or "UNKNOWN"
  BATTERY_CARD_SPEC.secondaryText = cells .. "S"

  drawCard(slot, BATTERY_CARD_SPEC)
end

-- ─── Link Quality card (P2) ─────────────────────────────────────────────────
local function drawLinkQuality(slot, telemetry, state)
  if not slot then return end

  LQ_CARD_SPEC.icon = icons.lq
  LQ_CARD_SPEC.value = (telemetry and telemetry.linkQuality) or 0
  LQ_CARD_SPEC.state = (state and state.linkQuality) or "UNKNOWN"

  drawCard(slot, LQ_CARD_SPEC)
end

-- ─── RSSI card (P4) ──────────────────────────────────────────────────────────
-- Displays RSSI as stacked value + unit inside the P4 slot.
-- Example layout:
--   -65
--   dBm
local function drawRSSI(slot, telemetry, state)
  if not slot then return end

  RSSI_CARD_SPEC.icon = icons.signal
  RSSI_CARD_SPEC.value = (telemetry and telemetry.rssi) or 0
  RSSI_CARD_SPEC.state = (state and state.rssi) or "UNKNOWN"

  drawCard(slot, RSSI_CARD_SPEC)
end

-- ─── Packet Rate card (P3) ───────────────────────────────────────────────────
-- Displays packet rate as stacked value + unit inside the P3 slot.
-- Example layout:
--   500
--   Hz
local function drawPacketRate(slot, telemetry, state)
  if not slot then return end

  RATE_CARD_SPEC.icon = icons.rfmd
  RATE_CARD_SPEC.value = (telemetry and telemetry.packetRate) or 0
  RATE_CARD_SPEC.state = (state and state.packetRate) or "UNKNOWN"

  drawCard(slot, RATE_CARD_SPEC)
end

-- ─── Current card (P5) ──────────────────────────────────────────────────────
local function drawCurrent(slot, telemetry, state)
  if not slot then return end

  CURRENT_CARD_SPEC.icon = icons.current
  CURRENT_CARD_SPEC.value = (telemetry and telemetry.current) or 0
  CURRENT_CARD_SPEC.state = (state and state.current) or "UNKNOWN"

  drawCard(slot, CURRENT_CARD_SPEC)
end

-- ─── Satellites card (P6) ───────────────────────────────────────────────────
local function drawSatellites(slot, telemetry, state)
  if not slot then return end

  SAT_CARD_SPEC.icon = icons.sat
  SAT_CARD_SPEC.value = (telemetry and (telemetry.sats or telemetry.satellites)) or 0
  SAT_CARD_SPEC.state = (state and (state.sats or state.satellites)) or "UNKNOWN"

  drawCard(slot, SAT_CARD_SPEC)
end

-- ─── TX Power card (C1) ─────────────────────────────────────────────────────
local function drawTxPower(slot, telemetry, state)
  if not slot then return end

  TX_POWER_CARD_SPEC.icon = icons.antenna
  TX_POWER_CARD_SPEC.value = (telemetry and telemetry.txPower) or 0
  TX_POWER_CARD_SPEC.state = (state and state.txPower) or "UNKNOWN"

  drawCard(slot, TX_POWER_CARD_SPEC)
end

-- ─── Flight Mode card (C2) ──────────────────────────────────────────────────
local function drawFlightMode(slot, telemetry)
  if not slot then return end

  FLIGHT_MODE_CARD_SPEC.icon = icons.drone
  FLIGHT_MODE_CARD_SPEC.value = (telemetry and telemetry.flightMode) or ""
  FLIGHT_MODE_CARD_SPEC.state = nil

  drawCard(slot, FLIGHT_MODE_CARD_SPEC)
end

-- ─── Diagnostic optional cards (O1..O4) ─────────────────────────────────────
local function sensorAvailable(telemetry, field)
  return telemetry
    and telemetry.available
    and telemetry.available[field] == true
end

local function drawDiagRSSI1(slot, telemetry)
  if not slot or not sensorAvailable(telemetry, "rssi1") then
    return
  end

  DIAG_RSSI1_CARD_SPEC.icon = icons.signal
  DIAG_RSSI1_CARD_SPEC.value = telemetry.rssi1 or 0

  drawCard(slot, DIAG_RSSI1_CARD_SPEC)
end

local function drawDiagRSSI2(slot, telemetry)
  if not slot or not sensorAvailable(telemetry, "rssi2") then
    return
  end

  DIAG_RSSI2_CARD_SPEC.icon = icons.signal
  DIAG_RSSI2_CARD_SPEC.value = telemetry.rssi2 or 0

  drawCard(slot, DIAG_RSSI2_CARD_SPEC)
end

local function drawDiagCapacity(slot, telemetry)
  if not slot or not sensorAvailable(telemetry, "capacity") then
    return
  end

  DIAG_CAPACITY_CARD_SPEC.icon = icons.battery
  DIAG_CAPACITY_CARD_SPEC.value = telemetry.capacity or 0

  drawCard(slot, DIAG_CAPACITY_CARD_SPEC)
end

local function drawDiagAntenna(slot, telemetry)
  if not slot or not sensorAvailable(telemetry, "activeAntenna") then
    return
  end

  DIAG_ANTENNA_CARD_SPEC.icon = icons.antenna
  DIAG_ANTENNA_CARD_SPEC.value = telemetry.activeAntenna or 0

  drawCard(slot, DIAG_ANTENNA_CARD_SPEC)
end

-- ─── Public API ───────────────────────────────────────────────────────────────

M.icons = icons
M.drawCard = drawCard

-- Live card rendering pipeline.
-- P1 shows the battery card; all remaining slots render skeleton until
-- their respective widgets are implemented.
function M.draw(layout, slots, telemetry, state)
  if not layout or not slots then return end

  -- Region outlines.
  lcd.drawRectangle(layout.primaryGrid.x,  layout.primaryGrid.y,
                    layout.primaryGrid.w,  layout.primaryGrid.h)
  lcd.drawRectangle(layout.contextRow.x,  layout.contextRow.y,
                    layout.contextRow.w,  layout.contextRow.h)
  lcd.drawRectangle(layout.diagnostics.x, layout.diagnostics.y,
                    layout.diagnostics.w, layout.diagnostics.h)

  -- P1: battery card (fully implemented by issue #38).
  drawBattery(slots.primary and slots.primary.P1, telemetry, state)

  -- P2: link quality card (implemented by issue #56).
  drawLinkQuality(slots.primary and slots.primary.P2, telemetry, state)

  -- P3: packet-rate card (implemented by issue #41).
  drawPacketRate(slots.primary and slots.primary.P3, telemetry, state)

  -- P4: RSSI card (implemented by issue #43).
  drawRSSI(slots.primary and slots.primary.P4, telemetry, state)

  -- P5: current card (implemented by issue #56).
  drawCurrent(slots.primary and slots.primary.P5, telemetry, state)

  -- P6: satellites card (implemented by issue #56).
  drawSatellites(slots.primary and slots.primary.P6, telemetry, state)

  -- Remaining primary slots: skeleton placeholder until their cards are added.
  for i = 2, #PRIMARY_ORDER do
    local id   = PRIMARY_ORDER[i]
    local slot = slots.primary and slots.primary[id]
    if slot and id ~= "P2" and id ~= "P3" and id ~= "P4" and id ~= "P5" and id ~= "P6" then
      drawBox(slot, id)
    end
  end

  -- C1/C2: context row cards (implemented by issue #57).
  drawTxPower(slots.context and slots.context.C1, telemetry, state)
  drawFlightMode(slots.context and slots.context.C2, telemetry)

  -- O1..O4: diagnostics optional cards (implemented by issue #58).
  drawDiagRSSI1(slots.optional and slots.optional.O1, telemetry)
  drawDiagRSSI2(slots.optional and slots.optional.O2, telemetry)
  drawDiagCapacity(slots.optional and slots.optional.O3, telemetry)
  drawDiagAntenna(slots.optional and slots.optional.O4, telemetry)
end

-- Pure wireframe for layout verification / development.
function M.drawSkeleton(layout, slots)
  if not layout or not slots then return end

  drawBox(layout.primaryGrid)
  drawBox(layout.contextRow, "Context Row")
  drawBox(layout.diagnostics, "Diagnostics")

  drawSlots(slots.primary,  PRIMARY_ORDER)
  drawSlots(slots.context,  CONTEXT_ORDER)
  drawSlots(slots.optional, OPTIONAL_ORDER)
end

return M
