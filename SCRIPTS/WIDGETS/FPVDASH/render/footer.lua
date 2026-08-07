-- Footer renderer.
-- Renders ELRS version bottom-left and EdgeTX version bottom-right.
-- Shown only on 480×320 class radios; omitted on 480×272 class.

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
