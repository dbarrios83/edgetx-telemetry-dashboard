-- Shared drawing/formatting primitives for the render/*.lua renderers.
--
-- Extracted from near-identical copies that had begun to drift (see
-- Architecture & Packaging Hardening, Task 5) -- toNumber and
-- openBitmapFromCandidates were byte-identical in every renderer;
-- drawShadowText's actual lcd.setColor/drawText mechanics were identical
-- too, but each renderer computes its own shadow color differently:
-- render/sticks.lua and render/topbar.lua derive it from the current
-- theme's light/dark state (a module-level _TEXT_SHADOW_COLOR, set from
-- theme.isLight), while render/context.lua, render/footer.lua, and
-- render/timers.lua use a simpler heuristic based only on the text color
-- itself. That is a real, pre-existing behavioral difference between
-- renderers, not an oversight this module should paper over -- so
-- drawShadowText() takes the resolved shadow color as an explicit
-- argument rather than guessing one true way to compute it. Each
-- renderer keeps its own thin wrapper that computes shadowColor exactly
-- as it did before this extraction, then delegates here.
--
-- Deliberately excludes icon-loading (ensureIconsLoaded): its shape also
-- differs meaningfully between renderers (theme-keyed icon folders vs.
-- render/sticks.lua's theme-agnostic battery/link icons) in ways that
-- don't collapse into one shared function without losing that
-- distinction.
--
-- gridCells/centerStart/centerGroup/centerGroupVertical (Grid-aligned top
-- bar and sticks, Task 1) are the geometry contract both renderers refactor
-- onto: weighted columns with deterministic remainder-pixel handling, plus
-- centering helpers that treat an icon+gap+text (or a stacked date/time
-- pair) as one group rather than positioning each element independently.

local M = {}

local _WHITE = (type(WHITE) == "number") and WHITE or 0xFFFF
local _BLACK = 0x0000

local function roundedInt(v)
  if v >= 0 then
    return math.floor(v + 0.5)
  end
  return math.ceil(v - 0.5)
end

-- Divides the rectangle (x, y, w, h) into #weights columns, in order,
-- proportional to each weight (weights need not sum to 100 -- they are
-- normalized against their own total). Column boundaries are computed from
-- the *cumulative* weight up to each column, then rounded, so every column
-- edge is a single deterministic pixel value shared by its two neighbors:
-- there is no separate per-column rounding step that could leave a gap or
-- overlap. The final column's right edge is pinned to exactly x + w
-- (rather than a rounded cumulative value) so the columns always cover the
-- full input width even when float rounding would otherwise miss it by a
-- pixel. y and h are passed through unchanged on every cell.
function M.gridCells(x, y, w, h, weights)
  local n = weights and #weights or 0
  if n == 0 then
    return {}
  end

  local totalWeight = 0
  for i = 1, n do
    totalWeight = totalWeight + weights[i]
  end

  local cells = {}
  local prevEdge = x
  local cumulative = 0
  for i = 1, n do
    cumulative = cumulative + weights[i]
    local edge
    if i == n or totalWeight <= 0 then
      edge = x + w
    else
      edge = x + roundedInt(w * cumulative / totalWeight)
    end
    cells[i] = { x = prevEdge, y = y, w = edge - prevEdge, h = h }
    prevEdge = edge
  end

  return cells
end

-- Returns the start coordinate that centers a span of length `innerLen`
-- within [outerStart, outerStart + outerLen). Clamped to outerStart so an
-- oversized item (e.g. a long model name) never starts before its cell --
-- it stays left/top-aligned inside the cell rather than drawing outside it.
function M.centerStart(outerStart, outerLen, innerLen)
  local start = outerStart + math.floor(((outerLen or 0) - (innerLen or 0)) / 2)
  if start < outerStart then
    start = outerStart
  end
  return start
end

-- Centers an ordered horizontal sequence of parts (e.g. {icon, gap, text})
-- as a single group within `rect`, so the group's combined width -- not
-- each part separately -- determines the horizontal offset. Each part is
-- `{w = <width>, h = <height>}` (h defaults to 0); a zero-width/height
-- entry works as a plain gap. Every part's y is centered independently
-- within rect.h using its own height, which is what keeps differently
-- sized icons and text visually aligned on the same middle line. Returns
-- an array parallel to `parts`, each entry `{x = ..., y = ...}` giving
-- that part's top-left corner. A single-part list centers that one part
-- alone, covering the icon-only/text-only fallback case.
function M.centerGroup(rect, parts)
  local n = parts and #parts or 0
  local results = {}
  if n == 0 then
    return results
  end

  local totalW = 0
  for i = 1, n do
    totalW = totalW + (parts[i].w or 0)
  end

  local cursorX = M.centerStart(rect.x, rect.w, totalW)
  for i = 1, n do
    local part = parts[i]
    local py = M.centerStart(rect.y, rect.h, part.h or 0)
    results[i] = { x = cursorX, y = py }
    cursorX = cursorX + (part.w or 0)
  end

  return results
end

-- Centers an ordered vertical sequence of parts (e.g. stacked time/date
-- text) as a single group within `rect`, mirroring centerGroup on the
-- other axis: the stack's combined height determines the vertical offset,
-- while each row's x is centered independently within rect.w using its
-- own width (rows commonly differ in width, e.g. "14:05" vs "3 Aug").
-- Returns an array parallel to `parts`, each entry `{x = ..., y = ...}`.
function M.centerGroupVertical(rect, parts)
  local n = parts and #parts or 0
  local results = {}
  if n == 0 then
    return results
  end

  local totalH = 0
  for i = 1, n do
    totalH = totalH + (parts[i].h or 0)
  end

  local cursorY = M.centerStart(rect.y, rect.h, totalH)
  for i = 1, n do
    local part = parts[i]
    local px = M.centerStart(rect.x, rect.w, part.w or 0)
    results[i] = { x = px, y = cursorY }
    cursorY = cursorY + (part.h or 0)
  end

  return results
end

-- Coerce a raw EdgeTX sensor value (a plain number, a {value=...}/
-- {val=...} table, or a numeric string) to a plain number, or nil if it
-- isn't one of those shapes.
function M.toNumber(v)
  if type(v) == "number" then
    return v
  end

  if type(v) == "table" then
    if type(v.value) == "number" then
      return v.value
    end
    if type(v.val) == "number" then
      return v.val
    end
  end

  if type(v) == "string" then
    local n = tonumber(v:match("%-?%d+%.?%d*"))
    if n then
      return n
    end
  end

  return nil
end

-- Tries Bitmap.open() for every name under every root, in the order
-- given, and returns the first bitmap that actually opens (or nil if
-- none do, or Bitmap isn't available at all).
function M.openBitmapFromCandidates(roots, names)
  if not Bitmap or type(Bitmap.open) ~= "function" then
    return nil
  end

  for i = 1, #names do
    for j = 1, #roots do
      local bm = Bitmap.open(roots[j] .. names[i])
      if bm then
        return bm
      end
    end
  end

  return nil
end

-- Draws `text` twice -- a 1px-offset shadow using `shadowColor`, then the
-- real text using `color` on top -- using whichever color-setting
-- mechanism the running EdgeTX build supports (the TEXT_COLOR draw-flag,
-- the CUSTOM_COLOR draw-flag, or a plain lcd.drawText(..., color)
-- fallback with pcall in case that signature isn't supported either).
-- `extraFlags` (optional) is added to the size argument, e.g. for BOLD;
-- omit it, or pass a non-number, to add nothing.
function M.drawShadowText(x, y, text, size, color, shadowColor, extraFlags)
  if not lcd or type(lcd.drawText) ~= "function" then
    return
  end

  local txtColor = (type(color) == "number") and color or _WHITE
  local shadow = (type(shadowColor) == "number") and shadowColor or _BLACK
  local flags = (type(extraFlags) == "number") and extraFlags or 0

  if type(TEXT_COLOR) == "number" and type(lcd.setColor) == "function" then
    lcd.setColor(TEXT_COLOR, shadow)
    lcd.drawText(x + 1, y + 1, text, size + flags)

    lcd.setColor(TEXT_COLOR, txtColor)
    lcd.drawText(x, y, text, size + flags)
    return
  end

  if type(CUSTOM_COLOR) == "number" and type(lcd.setColor) == "function" then
    lcd.setColor(CUSTOM_COLOR, shadow)
    lcd.drawText(x + 1, y + 1, text, size + CUSTOM_COLOR + flags)

    lcd.setColor(CUSTOM_COLOR, txtColor)
    lcd.drawText(x, y, text, size + CUSTOM_COLOR + flags)
    return
  end

  local okShadow = pcall(lcd.drawText, x + 1, y + 1, text, size + flags, shadow)
  if not okShadow then
    lcd.drawText(x + 1, y + 1, text, size + flags)
  end

  local okText = pcall(lcd.drawText, x, y, text, size + flags, txtColor)
  if not okText then
    lcd.drawText(x, y, text, size + flags)
  end
end

return M
