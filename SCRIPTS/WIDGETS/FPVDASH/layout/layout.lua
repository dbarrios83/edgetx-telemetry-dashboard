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

  local gap = 4

  local topBarH = math.max(22, math.floor(h * 0.12))
  local stickH = math.max(58, math.floor(h * 0.30))
  local contextH = math.max(20, math.floor(h * 0.11))
  local diagnosticsH = math.max(20, math.floor(h * 0.14))

  local minimumPrimaryH = 40
  local primaryH = h - (topBarH + stickH + contextH + diagnosticsH + (gap * 4))

  if primaryH < minimumPrimaryH then
    local deficit = minimumPrimaryH - primaryH

    diagnosticsH, deficit = shrink(diagnosticsH, 14, deficit)
    contextH, deficit = shrink(contextH, 16, deficit)
    stickH, deficit = shrink(stickH, 44, deficit)
    topBarH, deficit = shrink(topBarH, 18, deficit)

    primaryH = h - (topBarH + stickH + contextH + diagnosticsH + (gap * 4))
  end

  local topBarY = y
  local stickY = topBarY + topBarH + gap
  local primaryY = stickY + stickH + gap
  local contextY = primaryY + primaryH + gap
  local diagnosticsY = contextY + contextH + gap

  return {
    zone = rect(x, y, w, h),
    gap = gap,
    topBar = rect(x, topBarY, w, topBarH),
    stickMonitor = rect(x, stickY, w, stickH),
    primaryGrid = rect(x, primaryY, w, primaryH),
    contextRow = rect(x, contextY, w, contextH),
    diagnostics = rect(x, diagnosticsY, w, diagnosticsH),
  }
end

return M
