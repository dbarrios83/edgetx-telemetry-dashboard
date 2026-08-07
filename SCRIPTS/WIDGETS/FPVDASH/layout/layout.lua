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

-- The footer row is always shown, on every supported resolution (Multi-
-- Resolution Layout, Task 2) -- it used to be hidden below a 290px
-- height threshold, which excluded 480×272 (RadioMaster TX16S / TX16S
-- Mark II / Jumper T16 / T18). All five regions must now be visible on
-- every supported resolution, so the remaining regions shrink to make
-- room for it instead (see the shrink block below).
--
-- FOOTER_H_MIN is a floor, not a fixed size: footerH below is
-- percentage-of-height like stickH/contextH, so it also sizes up
-- generously on 800×480 instead of staying a fixed thin strip
-- (Multi-Resolution Layout, Task 6 -- Companion testing showed the
-- footer looked disproportionately thin against how generously
-- everything else scaled up on the larger screen).
local FOOTER_H_MIN = 16

-- The strip in the top-left corner (EdgeTX logo etc.) is not drawn by this
-- widget at all -- it's EdgeTX's own system TopBar, rendered above/around
-- whatever the App Mode widget draws (see render/topbar.lua's reserved
-- logo cell). Its real height, confirmed from EdgeTX firmware source
-- (Multi-Resolution Layout, Task 1):
--   WidgetsContainer(parent, {0, 0, LCD_W, EdgeTxStyles::MENU_HEADER_HEIGHT}, ...)
--     -- radio/src/gui/colorlcd/mainview/topbar.cpp
--   static LAYOUT_VAL_SCALED(MENU_HEADER_HEIGHT, 45)
--     -- radio/src/gui/colorlcd/libui/etx_lv_theme.h
-- LAYOUT_SCALE only changes the value for two specific landscape widths;
-- every other width (including both of this widget's 480-wide classes)
-- is unscaled:
--   LCD_W == 320  -> (x*8+5)/10
--   LCD_W == 800  -> (x*11+4)/8
--   otherwise     -> x
-- Mirrored exactly here (against zone width, this widget's analog of
-- LCD_W) rather than approximated, so the widget's own top bar can never
-- visibly mismatch the real logo it sits beside.
local MENU_HEADER_HEIGHT = 45

local function menuHeaderHeight(zoneWidth)
  if zoneWidth == 320 then
    return math.floor((MENU_HEADER_HEIGHT * 8 + 5) / 10)
  elseif zoneWidth == 800 then
    return math.floor((MENU_HEADER_HEIGHT * 11 + 4) / 8)
  end
  return MENU_HEADER_HEIGHT
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

  local gap = 2
  local footerH = math.max(FOOTER_H_MIN, math.floor(h * 0.05))
  local numGaps = 4

  -- Pinned exactly to the real EdgeTX logo height for this zone width --
  -- never approximated, and never shrunk under space pressure below (see
  -- the shrink block: topBarH is deliberately absent from that pool).
  local topBarH = menuHeaderHeight(w)
  local stickH  = math.max(58, math.floor(h * 0.32))
  local contextH = math.max(20, math.floor(h * 0.14))

  -- stickH/contextH/footerH/primaryH are all percentage-of-height, so
  -- they shrink and grow proportionally to the zone's actual height
  -- without any special-casing per resolution. Verified directly for all
  -- three supported resolutions (Multi-Resolution Layout, Tasks 3 and 6)
  -- that this satisfies every region-sizing goal with comfortable margin:
  --   480x320: stick=102 primary=105 context=44 footer=16 (unchanged)
  --   480x272: stick=87  primary=78  context=38  footer=16 (unchanged;
  --            shrink-under-pressure path never triggers -- primaryH=78
  --            stays well above its 40px minimum even with the pinned
  --            top bar + mandatory footer both claiming space here)
  --   800x480: stick=153 primary=166 context=67  footer=24 (visibly more
  --            generous than 480x272's proportions across every region,
  --            including the footer -- no extra logic required)
  local minimumPrimaryH = 40
  local primaryH = h - (topBarH + stickH + contextH + footerH + (gap * numGaps))

  if primaryH < minimumPrimaryH then
    local deficit = minimumPrimaryH - primaryH

    contextH, deficit = shrink(contextH, 16, deficit)
    stickH = shrink(stickH, 44, deficit)

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
    footerRow    = rect(x, y + h - footerH, w, footerH),
  }
end

return M
