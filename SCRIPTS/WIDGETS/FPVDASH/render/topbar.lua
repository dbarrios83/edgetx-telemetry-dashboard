-- Top bar renderer.
-- Renders model name, transmitter battery, telemetry link status, and time.

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

local _WHITE    = (type(WHITE)    == "number") and WHITE    or 0xFFFF
local _GREEN    = (type(GREEN)    == "number") and GREEN    or 0x07E0
local _YELLOW   = (type(YELLOW)   == "number") and YELLOW   or 0xFFE0
local _RED      = (type(RED)      == "number") and RED      or 0xF800
local _BLACK    = 0x0000
local _BOLD     = (type(BOLD)     == "number") and BOLD     or 0
local LINK_ICON_W = 24
local LINK_ICON_H = 24

-- Top-bar grid: EdgeTX Logo / Model / TX Battery / Receiver Connection /
-- Date-Time, in that order (Grid-aligned top bar and sticks, Task 3).
-- Cell 1 (the logo) is reserved space only -- this renderer never draws
-- into it, since the EdgeTX telemetry-app layout supplies and positions
-- that asset itself.
local GRID_WEIGHTS = { 10, 36, 20, 16, 18 }

-- EdgeTX widget text has no runtime glyph-metrics API, so these are
-- documented per-character/line-height estimates used only to size
-- content for the group-centering math below, not measured values.
--
-- Third Companion pass (2026-08-07), per direct user instruction: model
-- name is now left-aligned in its cell rather than centered (still uses
-- MODEL_TEXT_CHAR_W to size the truncation budget, just not to compute a
-- centered X anymore). TX battery text drops to _SMLSIZE (from _MIDSIZE)
-- and stays vertically centered next to its icon. Date and time collapse
-- to one right-aligned line instead of a centered stacked pair.
local MODEL_TEXT_CHAR_W = 13
local MODEL_TEXT_H = 35
local MODEL_TEXT_PADDING = 12
local TX_TEXT_CHAR_W = 5
local TX_TEXT_H = 8
local TX_BATTERY_ICON_W = 30
local TX_BATTERY_ICON_H = 32
local TX_ICON_TEXT_GAP = 4
local DATE_TIME_TEXT_CHAR_W = 4
local DATE_TIME_TEXT_H = 8
local DATE_TIME_RIGHT_PADDING = 6

local _TEXT_COLOR = _WHITE
local _TEXT_SHADOW_COLOR = _BLACK
local _LIGHT_TEXT_SHADOW = _WHITE

local function themeColor(themeToken, fallback)
  if lcd and type(lcd.getThemeColor) == "function" and type(themeToken) == "number" then
    local ok, c = pcall(lcd.getThemeColor, themeToken)
    if ok and type(c) == "number" then
      return c
    end
  end
  return fallback
end

local _THEME_WARNING = themeColor((type(THEME_WARNING) == "number") and THEME_WARNING or nil, _YELLOW)

-- Shadow color here is theme-aware (see _TEXT_SHADOW_COLOR, set from
-- theme.isLight in M.draw()) -- deliberately different from render/
-- context.lua's/footer.lua's/timers.lua's simpler heuristic; see
-- render/primitives.lua's header comment for why that's preserved
-- per-renderer rather than unified.
local function drawShadowText(x, y, text, size, color, extraFlags)
  local shadowColor = (type(_TEXT_SHADOW_COLOR) == "number") and _TEXT_SHADOW_COLOR or _BLACK
  if primitivesModule and primitivesModule.drawShadowText then
    primitivesModule.drawShadowText(x, y, text, size, color, shadowColor, extraFlags)
  end
end

local ICON_TX_BATTERY = nil
local BATTERY_ICONS = {
  full = nil,
  ok = nil,
  warn = nil,
  low = nil,
  dead = nil,
}

-- Static icon-root path lists, hoisted so ensureIconsLoaded() does not
-- allocate them on every call (it used to build both unconditionally,
-- before even checking whether a reload was needed).
local ICON_ROOTS = {
  "/WIDGETS/FPVDASH/icons/",
  "/SCRIPTS/WIDGETS/FPVDASH/icons/",
  "WIDGETS/FPVDASH/icons/",
  "SCRIPTS/WIDGETS/FPVDASH/icons/",
}

local BATTERY_ICON_ROOTS = {
  "/WIDGETS/FPVDASH/icons/battery/",
  "/SCRIPTS/WIDGETS/FPVDASH/icons/battery/",
  "WIDGETS/FPVDASH/icons/battery/",
  "SCRIPTS/WIDGETS/FPVDASH/icons/battery/",
}

-- Static month abbreviations for readDateText(), hoisted so it is not
-- rebuilt every frame.
local MONTH_NAMES = { "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" }

-- Static candidate sensor names for readTxVoltage(), hoisted so it is
-- not rebuilt every frame.
local TX_VOLTAGE_SOURCE_NAMES = {
  "tx-voltage",
  "tx voltage",
  "TxBt",
  "TXBAT",
  "A1",
}

local openBitmapFromCandidates = (primitivesModule and primitivesModule.openBitmapFromCandidates)
  or function() return nil end

local gridCells = (primitivesModule and primitivesModule.gridCells)
  or function() return {} end
local centerGroup = (primitivesModule and primitivesModule.centerGroup)
  or function() return {} end
local centerStart = (primitivesModule and primitivesModule.centerStart)
  or function(outerStart) return outerStart end

-- Icons are loaded lazily on the first draw call so that the Bitmap API is
-- guaranteed to be available (EdgeTX only exposes it inside widget callbacks).
local _batteryIconsLoaded = false

-- Link icons are cached by icon folder ("dark"/"light"), not loaded into
-- shared module-level ICON_LINK_ON/ICON_LINK_OFF locals -- see
-- render/context.lua's identical comment for why (two instances on
-- different themes used to fight over the same variables, reopening
-- both bitmaps every refresh() whenever the two instances' folders
-- disagreed). Battery icons below are theme-independent and correctly
-- stay module-level, loaded once regardless of theme.
local _linkIconSets = {}

-- The only icon paths that depend on a runtime value (iconFolder), so
-- unlike ICON_ROOTS/BATTERY_ICON_ROOTS this can't be hoisted to a pure
-- module-level constant -- but it's still only built when actually
-- (re)loading icons, not on every ensureIconsLoaded() call.
local function buildThemedRoots(iconFolder)
  return {
    "/WIDGETS/FPVDASH/icons/" .. iconFolder .. "/",
    "/SCRIPTS/WIDGETS/FPVDASH/icons/" .. iconFolder .. "/",
    "WIDGETS/FPVDASH/icons/" .. iconFolder .. "/",
    "SCRIPTS/WIDGETS/FPVDASH/icons/" .. iconFolder .. "/",
    "/WIDGETS/FPVDASH/icons/",
    "/SCRIPTS/WIDGETS/FPVDASH/icons/",
    "WIDGETS/FPVDASH/icons/",
    "SCRIPTS/WIDGETS/FPVDASH/icons/",
  }
end

local function loadLinkIconSet(iconFolder)
  local themedRoots = buildThemedRoots(iconFolder)
  return {
    ICON_LINK_ON = openBitmapFromCandidates(themedRoots, { "link.png" }),
    ICON_LINK_OFF = openBitmapFromCandidates(themedRoots, { "link_off.png" }),
  }
end

-- Loads the theme-independent battery icons once (if not already), then
-- returns this theme's link icon set, loading and caching it on first
-- request.
local function ensureIconsLoaded(theme)
  if not Bitmap or type(Bitmap.open) ~= "function" then return nil end

  if not _batteryIconsLoaded then
    ICON_TX_BATTERY = openBitmapFromCandidates(ICON_ROOTS, {
      "tx_battery.png",
      "battery.png",
    })

    BATTERY_ICONS.full = openBitmapFromCandidates(BATTERY_ICON_ROOTS, { "battery-full.png" })
    BATTERY_ICONS.ok   = openBitmapFromCandidates(BATTERY_ICON_ROOTS, { "battery-ok.png" })
    BATTERY_ICONS.warn = openBitmapFromCandidates(BATTERY_ICON_ROOTS, { "battery-warn.png" })
    BATTERY_ICONS.low  = openBitmapFromCandidates(BATTERY_ICON_ROOTS, { "battery-low.png" })
    BATTERY_ICONS.dead = openBitmapFromCandidates(BATTERY_ICON_ROOTS, { "battery-dead.png" })

    if not BATTERY_ICONS.ok then
      BATTERY_ICONS.ok = ICON_TX_BATTERY
    end

    _batteryIconsLoaded = true
  end

  local iconFolder = (theme and theme.iconFolder) or "dark"
  local linkIcons = _linkIconSets[iconFolder]
  if not linkIcons then
    linkIcons = loadLinkIconSet(iconFolder)
    _linkIconSets[iconFolder] = linkIcons
  end
  return linkIcons
end

local toNumber = (primitivesModule and primitivesModule.toNumber) or function() return nil end

local function truncateText(text, maxWidth, charW)
  charW = charW or 4
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

  for i = 1, #TX_VOLTAGE_SOURCE_NAMES do
    local n = toNumber(getValue(TX_VOLTAGE_SOURCE_NAMES[i]))
    if n and n >= 0 then
      return n
    end
  end

  return nil
end

-- `utils` is not an EdgeTX API global and no module in this repo defines
-- it -- this is a speculative, never-yet-used optional-extension hook
-- (Architecture & Packaging Hardening, Task 4 audit). It's safely guarded
-- (the `utils and ...` check short-circuits when nil, so this never
-- errors), but flagged rather than silently fixed: a future task should
-- decide whether to remove it or actually wire up a `utils` module.
-- luacheck: push ignore utils
local function readTxBatteryInfo()
  if utils and type(utils.txBatteryInfo) == "function" then
    local v, state = utils.txBatteryInfo()
    local parsedV = toNumber(v)
    if type(parsedV) ~= "number" or parsedV < 0 then
      parsedV = readTxVoltage()
    end

    if type(state) ~= "string" or state == "" then
      state = nil
    end

    if type(parsedV) == "number" and parsedV == 0 then
      state = "dead"
    end

    return parsedV, state
  end

  local v = readTxVoltage()
  if type(v) ~= "number" or v < 0 then
    return nil, "low"
  end

  if v == 0 then
    return v, "dead"
  end

  if v >= 7.9 then
    return v, "full"
  elseif v >= 7.5 then
    return v, "ok"
  elseif v >= 7.1 then
    return v, "yellow"
  end

  return v, "low"
end
-- luacheck: pop

local function readClockText()
  if getDateTime then
    local dt = getDateTime()
    if dt and dt.hour ~= nil and dt.min ~= nil then
      return string.format("%02d:%02d", dt.hour, dt.min)
    end
  end

  return "--:--"
end

local function readDateText()
  if not getDateTime then
    return "-- ---"
  end

  local dt = getDateTime()
  if not dt then
    return "-- ---"
  end

  local day = tonumber(dt.day)
  if not day then
    return "-- ---"
  end

  local monthToken = dt.mon
  if monthToken == nil then
    monthToken = dt.month
  end

  local monthText = "---"
  if type(monthToken) == "number" then
    monthText = MONTH_NAMES[monthToken] or "---"
  elseif type(monthToken) == "string" and monthToken ~= "" then
    monthText = monthToken:sub(1, 3)
  end

  return string.format("%d %s", day, monthText)
end

local function drawLinkIcon(rect, connected, linkIcons)
  local isConnected = (connected == true)
  local icon = linkIcons and (isConnected and linkIcons.ICON_LINK_ON or linkIcons.ICON_LINK_OFF)
  local text = isConnected and "LINK" or "NO"
  local textColor = _TEXT_COLOR

  if icon then
    local placed = centerGroup(rect, { { w = LINK_ICON_W, h = LINK_ICON_H } })
    -- Link status is determined only by icon choice; use one fixed draw color
    -- to avoid inheriting previous CUSTOM_COLOR state from text rendering.
    if lcd and type(lcd.setColor) == "function" and type(CUSTOM_COLOR) == "number" then
      lcd.setColor(CUSTOM_COLOR, _BLACK)
    end
    lcd.drawBitmap(icon, placed[1].x, placed[1].y)
    return
  end

  local placed = centerGroup(rect, { { w = #text * 4, h = 8 } })
  drawShadowText(placed[1].x, placed[1].y, text, SMLSIZE, textColor)
end

local function resolveTxBatteryIcon(state)
  local key = state

  if key == "yellow" then
    key = "warn"
  end

  if key ~= "full" and key ~= "ok" and key ~= "warn" and key ~= "low" and key ~= "dead" then
    key = "ok"
  end

  return BATTERY_ICONS[key] or BATTERY_ICONS.ok or ICON_TX_BATTERY
end

local function batteryLevelFromState(state)
  if state == "full" then
    return 3
  elseif state == "ok" then
    return 2
  elseif state == "warn" or state == "yellow" then
    return 1
  end
  return 0
end

local function drawBatteryGlyph(x, y, state)
  if not lcd then return false end

  local bw = 16
  local bh = 9
  local outline = _WHITE

  if lcd.drawRectangle then
    lcd.drawRectangle(x, y, bw, bh, outline)
    -- Positive terminal nub
    if lcd.drawFilledRectangle then
      local tipY = y + math.floor((bh - 3) / 2)
      lcd.drawFilledRectangle(x + bw, tipY, 2, 3, outline)
    end
    -- Fill reflecting battery level
    local level = batteryLevelFromState(state)
    if lcd.drawFilledRectangle and level > 0 then
      local fillColor
      if state == "low" or state == "dead" then
        fillColor = _RED
      elseif state == "warn" or state == "yellow" then
        fillColor = _YELLOW
      else
        fillColor = _GREEN
      end
      local maxFill = bw - 4
      local fillW = math.floor(maxFill * level / 3)
      if fillW > 0 then
        lcd.drawFilledRectangle(x + 2, y + 2, fillW, bh - 4, fillColor)
      end
    end
    return true
  elseif lcd.drawLine then
    -- Line-based fallback with explicit color (not FORCE)
    lcd.drawLine(x,        y,        x + bw, y,        SOLID, outline)
    lcd.drawLine(x,        y + bh,   x + bw, y + bh,   SOLID, outline)
    lcd.drawLine(x,        y,        x,      y + bh,   SOLID, outline)
    lcd.drawLine(x + bw,   y,        x + bw, y + bh,   SOLID, outline)
    return true
  end

  return false
end

local function drawTxBattery(rect, txV, txState)
  local txText = txV and string.format("%.1fV", txV) or "--.-V"
  local txColor = txV and _TEXT_COLOR or _THEME_WARNING
  local textW = #txText * TX_TEXT_CHAR_W

  -- Icon + value move as one centered group: reserve the icon column
  -- whenever lcd is available, since either the PNG icon or the vector
  -- glyph fallback (drawBatteryGlyph) will draw into it.
  local icon = resolveTxBatteryIcon(txState)
  local hasIconArea = (icon ~= nil) or (lcd ~= nil)

  local parts
  if hasIconArea then
    parts = { { w = TX_BATTERY_ICON_W, h = TX_BATTERY_ICON_H }, { w = TX_ICON_TEXT_GAP }, { w = textW, h = TX_TEXT_H } }
  else
    parts = { { w = textW, h = TX_TEXT_H } }
  end
  local placed = centerGroup(rect, parts)

  if icon then
    lcd.drawBitmap(icon, placed[1].x, placed[1].y)
  elseif hasIconArea then
    local glyphH = 9
    local glyphY = placed[1].y + math.floor((TX_BATTERY_ICON_H - glyphH) / 2)
    drawBatteryGlyph(placed[1].x + 1, glyphY, txState)
  end

  local textPart = hasIconArea and placed[3] or placed[1]
  drawShadowText(textPart.x, textPart.y, txText, SMLSIZE, txColor)
end

-- One line ("<time> <date>"), vertically centered, right-aligned within
-- the cell -- flush toward the widget's right edge like the pre-Task-3
-- layout, but computed from the cell's own bounds instead of a fixed
-- rightPad hack.
local function drawDateTime(rect, timeText, dateText)
  local text = timeText .. " " .. dateText
  local textW = #text * DATE_TIME_TEXT_CHAR_W

  local textX = rect.x + rect.w - textW - DATE_TIME_RIGHT_PADDING
  if textX < rect.x then
    textX = rect.x
  end
  local textY = centerStart(rect.y, rect.h, DATE_TIME_TEXT_H)

  drawShadowText(textX, textY, text, SMLSIZE, _TEXT_COLOR)
end

function M.draw(bounds, telemetry, state, theme)
  if not bounds then
    return
  end

  local textColor = (theme and theme.textColor) or _WHITE
  _TEXT_COLOR = textColor
  _TEXT_SHADOW_COLOR = (theme and theme.isLight) and _LIGHT_TEXT_SHADOW or _BLACK
  local linkIcons = ensureIconsLoaded(theme)

  local cells = gridCells(bounds.x, bounds.y, bounds.w, bounds.h, GRID_WEIGHTS)
  local logoCell, modelCell, txBatCell, connCell, dateTimeCell = cells[1], cells[2], cells[3], cells[4], cells[5]

  if not logoCell or not modelCell or not txBatCell or not connCell or not dateTimeCell then
    return
  end

  -- logoCell is intentionally never drawn into: the EdgeTX telemetry-app
  -- layout supplies and positions that asset itself.

  -- Left-aligned within its cell (not centered) -- still vertically
  -- centered, and still truncates safely within the cell's width.
  local modelText = truncateText(readModelName(), modelCell.w - MODEL_TEXT_PADDING, MODEL_TEXT_CHAR_W)
  local modelX = modelCell.x + MODEL_TEXT_PADDING
  local modelY = centerStart(modelCell.y, modelCell.h, MODEL_TEXT_H)
  drawShadowText(modelX, modelY, modelText, MIDSIZE, _TEXT_COLOR, _BOLD)

  local txV, txState = readTxBatteryInfo()
  drawTxBattery(txBatCell, txV, txState)

  local connected = telemetry and telemetry.connected
  drawLinkIcon(connCell, connected, linkIcons)

  drawDateTime(dateTimeCell, readClockText(), readDateText())
end

function M.drawSkeleton(bounds)
  if not bounds then
    return
  end

  local x1 = bounds.x
  local y1 = bounds.y
  local x2 = bounds.x + bounds.w - 1
  local y2 = bounds.y + bounds.h - 1
  lcd.drawLine(x1, y1, x2, y1, SOLID, FORCE)
  lcd.drawLine(x1, y2, x2, y2, SOLID, FORCE)
  lcd.drawLine(x1, y1, x1, y2, SOLID, FORCE)
  lcd.drawLine(x2, y1, x2, y2, SOLID, FORCE)
  lcd.drawText(bounds.x + 2, bounds.y + 2, "Top Bar", SMLSIZE)
end

return M
