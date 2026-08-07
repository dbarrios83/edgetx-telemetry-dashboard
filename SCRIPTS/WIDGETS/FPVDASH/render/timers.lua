-- Timer row renderer.
-- Draws three timer cells with clock icon + shadowed MM:SS value.

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

  -- Shared across every file with a copy of this loader: loadScript has
  -- no built-in caching the way Lua's require() does, so a module
  -- loaded from multiple call sites (e.g. render/primitives.lua,
  -- independently loaded by all five renderers) would otherwise execute
  -- -- and hold in memory -- one separate copy per caller instead of
  -- one shared copy (found in external review, 2026-08-07).
  _G.__FPVDASH_MODULE_CACHE__ = _G.__FPVDASH_MODULE_CACHE__ or {}
  local cache = _G.__FPVDASH_MODULE_CACHE__
  if cache[relativePath] ~= nil then
    return cache[relativePath] or nil
  end

  for i = 1, #WIDGET_ROOTS do
    local chunk = loadScript(WIDGET_ROOTS[i] .. relativePath)
    if chunk then
      local result = chunk()
      cache[relativePath] = result or false
      return result
    end
  end

  cache[relativePath] = false
  return nil
end

local primitivesModule = loadSiblingModule("render/primitives.lua")

local _WHITE = (type(WHITE) == "number") and WHITE or 0xFFFF
local _BLACK = 0x0000
local _SMLSIZE = (type(SMLSIZE) == "number") and SMLSIZE or 0

local ICON_SIZE = 24
local ICON_TEXT_GAP = 8
local TEXT_H = 8
local TIMER_TEXT_SLOT_W = 34
local TIMER_TEXT_Y_OFFSET = -4

local _TEXT_COLOR = _WHITE

local openBitmapFromCandidates = (primitivesModule and primitivesModule.openBitmapFromCandidates)
  or function() return nil end

-- Icon sets are cached by icon folder ("dark"/"light"), not loaded into
-- a shared module-level ICON_CLOCK local -- see render/context.lua's
-- identical comment for why (two instances on different themes used to
-- fight over one variable, reopening the bitmap every refresh()).
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
    ICON_CLOCK = openBitmapFromCandidates(roots, { "clock.png" }),
  }
end

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

local toNumber = (primitivesModule and primitivesModule.toNumber) or function() return nil end

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
  local icons = ensureIconsLoaded(theme)

  local colW = math.floor(rect.w / 3)
  local col0 = rect.x
  local col1 = rect.x + colW
  local col2 = rect.x + (colW * 2)

  local timer1Text = formatTimer(readTimer("timer1"))
  local timer2Text = formatTimer(readTimer("timer2"))
  local timer3Text = formatTimer(readTimer("timer3"))

  drawTimerMetric(col0, rect.y, colW, rect.h, icons.ICON_CLOCK, timer1Text)
  drawTimerMetric(col1, rect.y, colW, rect.h, icons.ICON_CLOCK, timer2Text)
  drawTimerMetric(col2, rect.y, rect.w - (colW * 2), rect.h, icons.ICON_CLOCK, timer3Text)
end

function M.drawSkeleton(rect)
  if not rect or not lcd or type(lcd.drawText) ~= "function" then
    return
  end

  lcd.drawText(rect.x + 2, rect.y + 2, "Timers", _SMLSIZE)
end

return M
