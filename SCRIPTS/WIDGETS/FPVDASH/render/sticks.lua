-- Stick monitor renderer.
-- Renders stick monitor layout skeleton only.

local M = {}

local function drawCenteredLabel(rect, label)
  local textW = #label * 4
  local textH = 8
  local tx = rect.x + math.floor((rect.w - textW) / 2)
  local ty = rect.y + math.floor((rect.h - textH) / 2)
  lcd.drawText(tx, ty, label, SMLSIZE)
end

function M.drawSkeleton(bounds)
  if not bounds then
    return
  end

  lcd.drawRectangle(bounds.x, bounds.y, bounds.w, bounds.h)
  drawCenteredLabel(bounds, "Stick Monitor")
end

return M
