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

local M = {}

local _WHITE = (type(WHITE) == "number") and WHITE or 0xFFFF
local _BLACK = 0x0000

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
