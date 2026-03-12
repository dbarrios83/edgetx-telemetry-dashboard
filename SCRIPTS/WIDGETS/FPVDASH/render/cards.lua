-- Card renderer.
-- M.draw renders live telemetry cards; P1 (battery) is fully implemented.
-- Remaining slots continue to render as skeleton until their cards are added.
-- M.drawSkeleton renders pure wireframe for all slots (debugging / layout pass).

local M = {}

-- ─── Color constants ──────────────────────────────────────────────────────────
-- Guard against monochrome builds where colour globals may be absent.
local function rgb(r, g, b, fallback)
  if lcd and lcd.RGB then
    return lcd.RGB(r, g, b)
  end
  return fallback
end

local _WHITE  = (type(WHITE)  == "number") and WHITE or 0xFFFF
local _GREEN  = (type(GREEN)  == "number") and GREEN or rgb(80, 220, 120, _WHITE)
local _ORANGE = rgb(255, 165, 0, (type(YELLOW) == "number") and YELLOW or _WHITE)
local _RED    = (type(RED)    == "number") and RED   or rgb(255, 70, 70, _WHITE)

-- ─── Icon handles ─────────────────────────────────────────────────────────────
-- Loaded once at module startup; nil when asset is unavailable or Bitmap absent.
local ICON_BATTERY = nil
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
  end
end

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
  if s == "WARNING"  then return _ORANGE end
  if s == "LOW"      then return _ORANGE end
  if s == "CRITICAL" then return _RED    end
  return _WHITE
end

-- Combine a size flag with a colour flag safely.
local function tf(size, color)
  if type(color) == "number" then
    if bit32 and bit32.bor then
      return bit32.bor(size, color)
    end
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

-- ─── Battery card (P1) ────────────────────────────────────────────────────────
-- Displays total pack voltage and detected cell count inside the P1 slot.
-- Cell count uses: cells = floor(voltage / 4.2) + 1  (LiPo max 4.2 V/cell)
local function drawBattery(slot, telemetry, state)
  if not slot then return end

  lcd.drawRectangle(slot.x, slot.y, slot.w, slot.h)

  local voltage = (telemetry and telemetry.battery) or 0
  local batState = (state and state.battery) or "UNKNOWN"
  local color    = stateColor(batState)

  -- Auto-detect cell count from max-charge voltage (4.2 V/cell).
  local cells = 1
  if voltage > 0 then
    cells = math.max(1, math.floor(voltage / 4.2) + 1)
  end

  local padX = 2
  local padY = 2

  -- Optional battery icon at left edge, scaled to fit card height.
  local iconAreaW = 0
  if ICON_BATTERY then
    -- Icons are designed at 32 px; scale proportionally to card interior.
    local iconH = clamp(slot.h - padY * 2, 8, 32)
    local scale = math.max(1, math.floor(iconH / 32 * 100))
    lcd.drawBitmap(ICON_BATTERY, slot.x + padX, slot.y + padY, scale)
    iconAreaW = iconH + padX + 2
  end

  local textX = slot.x + iconAreaW + padX

  -- Per-cell voltage is the primary readout for state-awareness.
  local cellVoltage = (cells > 0) and (voltage / cells) or 0

  -- Primary value: per-cell voltage in MIDSIZE with state colour.
  -- MIDSIZE glyphs are ~16 px tall.
  local voltStr = string.format("%.2fV", cellVoltage)
  lcd.drawText(textX, slot.y + padY, voltStr, tf(MIDSIZE, color))

  -- Secondary value: cell config ("4S") in small text below voltage.
  local subY = slot.y + padY + 16
  if subY + 8 <= slot.y + slot.h then
    local cellStr = cells .. "S"
    lcd.drawText(textX, subY, cellStr, SMLSIZE)
  end

  -- Show "---" when telemetry is absent so the card never looks stale.
  if voltage <= 0 then
    drawCenteredLabel(slot, "---")
  end
end

-- ─── Public API ───────────────────────────────────────────────────────────────

-- Live card rendering pipeline.
-- P1 shows the battery card; all remaining slots render skeleton until
-- their respective widgets are implemented.
function M.draw(layout, slots, telemetry, state)
  if not layout or not slots then return end

  -- Region outlines.
  lcd.drawRectangle(layout.primaryGrid.x,  layout.primaryGrid.y,
                    layout.primaryGrid.w,  layout.primaryGrid.h)
  drawLabelAbove(layout.primaryGrid, "Primary Grid")
  lcd.drawRectangle(layout.contextRow.x,  layout.contextRow.y,
                    layout.contextRow.w,  layout.contextRow.h)
  lcd.drawRectangle(layout.diagnostics.x, layout.diagnostics.y,
                    layout.diagnostics.w, layout.diagnostics.h)

  -- P1: battery card (fully implemented by issue #38).
  drawBattery(slots.primary and slots.primary.P1, telemetry, state)

  -- P2–P6: skeleton placeholder until their cards are added.
  for i = 2, #PRIMARY_ORDER do
    local id   = PRIMARY_ORDER[i]
    local slot = slots.primary and slots.primary[id]
    if slot then drawBox(slot, id) end
  end

  -- Context row and diagnostics: skeleton.
  drawSlots(slots.context,  CONTEXT_ORDER)
  drawSlots(slots.optional, OPTIONAL_ORDER)
end

-- Pure wireframe for layout verification / development.
function M.drawSkeleton(layout, slots)
  if not layout or not slots then return end

  drawBox(layout.primaryGrid)
  drawLabelAbove(layout.primaryGrid, "Primary Grid")
  drawBox(layout.contextRow, "Context Row")
  drawBox(layout.diagnostics, "Diagnostics")

  drawSlots(slots.primary,  PRIMARY_ORDER)
  drawSlots(slots.context,  CONTEXT_ORDER)
  drawSlots(slots.optional, OPTIONAL_ORDER)
end

return M
