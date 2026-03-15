-- Dashboard layout region computation.
-- This module only computes geometry and does not render.

local M = {}

local function rect(x, y, w, h)
  return {
    x = x,
    y = y,
    w = w,
    h = h,
  }
end

local function shrink(value, minimum, deficit)
  if deficit <= 0 then
    return value, 0
  end

  local available = value - minimum
  if available <= 0 then
    return value, deficit
  end

  local take = math.min(available, deficit)
  return value - take, deficit - take
end

-- Height threshold that separates the two supported color-screen display classes:
--   480×320 (RadioMaster TX15 / TX15 Max / Jumper T15 / T15 Pro)  → h >= FOOTER_THRESHOLD
--   480×272 (RadioMaster TX16S / TX16S Mark II / Jumper T16 / T18) → h <  FOOTER_THRESHOLD
-- The footer row is shown on the taller class only.
local FOOTER_THRESHOLD = 290
local FOOTER_H = 16

function M.compute(zone)
  if not zone then
    return nil
  end

  local x = zone.x or 0
  local y = zone.y or 0
  local w = zone.w or 0
  local h = zone.h or 0

  if w <= 0 or h <= 0 then
    return nil
  end

  local gap = 2

  -- Detect display class from zone height and decide whether to include footer.
  local showFooter = (h >= FOOTER_THRESHOLD)
  local footerH    = showFooter and FOOTER_H or 0
  local numGaps    = showFooter and 4 or 3

  local topBarH = math.max(36, math.floor(h * 0.14))
  local stickH  = math.max(58, math.floor(h * 0.32))
  local contextH = math.max(20, math.floor(h * 0.14))

  local minimumPrimaryH = 40
  local primaryH = h - (topBarH + stickH + contextH + footerH + (gap * numGaps))

  if primaryH < minimumPrimaryH then
    local deficit = minimumPrimaryH - primaryH

    contextH, deficit = shrink(contextH, 16, deficit)
    stickH,   deficit = shrink(stickH,   44, deficit)
    topBarH,  deficit = shrink(topBarH,  18, deficit)

    primaryH = h - (topBarH + stickH + contextH + footerH + (gap * numGaps))
  end

  local topBarY  = y
  local stickY   = topBarY + topBarH + gap
  local primaryY = stickY  + stickH  + gap
  local contextY = primaryY + primaryH + gap

  return {
    zone         = rect(x, y, w, h),
    gap          = gap,
    topBar       = rect(x, topBarY,  w, topBarH),
    stickMonitor = rect(x, stickY,   w, stickH),
    primaryGrid  = rect(x, primaryY, w, primaryH),
    contextRow   = rect(x, contextY, w, contextH),
    -- Footer is bottom-anchored so rounding never pushes it outside the zone.
    footerRow    = showFooter and rect(x, y + h - FOOTER_H, w, FOOTER_H) or nil,
  }
end

return M
