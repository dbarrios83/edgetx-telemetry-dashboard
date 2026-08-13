# Stick Monitor

## 1. Purpose
This document defines the behavior of the stick monitor displayed on the EdgeTX telemetry dashboard.

The stick monitor visualizes the live position of the transmitter gimbals and provides immediate feedback about stick movement, channel mapping, and control centering.

This document defines behavior and UI expectations only. Rendering implementation belongs in the widget code.

## 2. Functional Role
The stick monitor serves three primary purposes:
- verify that both gimbals respond correctly before flight
- confirm that stick-to-channel mapping is correct
- reveal abnormal stick behavior, trim issues, or calibration problems

The stick monitor is radio-side information, not aircraft telemetry.

It must remain visible even when aircraft telemetry is unavailable.

## 3. Data Source
Stick position values come from radio input channels rather than telemetry sensors.

Typical normalized value range:

    -100 -> minimum stick position
       0 -> center
    +100 -> maximum stick position

The monitor should consume normalized stick values so rendering code does not need to understand raw input ranges.

The stick monitor should display pre-mix, pilot-control stick positions so it reflects direct gimbal movement rather than flight-mode or mixer output.

Example conceptual structure:

```lua
sticks = {
  thr = 0,
  yaw = -100,
  pitch = 0,
  roll = 100
}
```

## 4. Display Model
The stick monitor displays two gimbal visualizations.

Typical Mode 2 arrangement:

    Left Stick      Right Stick
      [ □ ]           [ □ ]

Mode 2 axis mapping:
- left horizontal: yaw
- left vertical: throttle
- right horizontal: roll
- right vertical: pitch

The dashboard should use Mode 2 as the documented baseline while keeping the mapping logic separate enough to support other modes later.

## 5. Stick Visualization Rules
Each stick is represented by a calibrated square pad:
- a square movement boundary that defines the gimbal's honest,
  independent X/Y range — not a circle, which would either clamp
  diagonal movement or misrepresent it
- a solid dark pad fill, giving the pad visual depth against the
  dashboard's wallpaper/theme background
- a light 4×4 calibration grid inside the pad: quarter lines at 25%/75%
  on both axes, and a brighter pair of axes at the exact 50% center
- a persistent, round center-reference indicator
- a round, two-layer moving marker (a light outline around a dark
  center) that shows the current stick position

Conceptual visualization (schematic only — see
[stick-grid-verification-checklist.md](../platform/stick-grid-verification-checklist.md)
for what the actual rendering looks like):

    +-----------+
    |  :  |  :  |
    |..-..+..-..|
    |  :  o  :  |
    |  :  |  :  |
    +-----------+

Visualization rules:
- both stick pads use the same size, derived from the available layout
  space (never a fixed pixel size or a check against display
  resolution/name)
- the grid stays visually subordinate to the moving marker and to the
  telemetry cards elsewhere on the dashboard — it reads as calibration
  detail, not a focal point
- the moving marker must remain clearly visible against the pad fill and
  the grid
- the center-reference indicator must remain visible whenever the
  marker is away from center (it may be covered when the marker is
  exactly centered)
- graphics should stay solid and lightweight — no gradients, alpha
  blending, blur, or other soft effects
- the moving marker should never render outside the pad's bordered
  movement area, at any stick position including the four corners

## 6. Movement Mapping
Stick inputs must be mapped from normalized channel values into the visible gimbal range.

Baseline normalization:

    normalized = input / 100

Mapped position (independently per axis, across the pad's usable
bordered range — not a shared radius):

    x = mapAxis(normalizedHorizontal, minX, maxX)
    y = mapAxis(normalizedVertical, minY, maxY)

Mapping rules:
- horizontal minimum maps to the left edge of the pad's usable range
- horizontal maximum maps to the right edge of the pad's usable range
- vertical minimum maps to the bottom edge of the pad's usable range
- vertical maximum maps to the top edge of the pad's usable range
- `0` maps to the visual center for self-centering axes
- X and Y are mapped independently, so diagonal deflection is not
  clamped or distorted the way a circular boundary would require

Throttle note:
- on a standard Mode 2 radio, throttle usually does not self-center
- the throttle indicator must remain at the actual stick position when released rather than snapping back to center

## 7. Display Behavior
The stick monitor must:
- update continuously while the widget refresh loop runs
- reflect live stick movement without noticeable lag
- remain stable and readable when the rest of the dashboard changes state
- show the real current position of each axis at all times

Behavior expectations:
- spring-centered axes should return to the center marker when released
- non-spring-centered axes should remain where the physical stick rests
- motion should appear smooth, but not at the cost of adding visible latency
- the monitor should not depend on telemetry refresh state

## 8. Center Indicator
The stick display should clearly indicate the neutral position.

Implemented as two layers:
- a small, round, neutral-gray center-reference dot, exactly at the
  pad's center
- a pair of brighter grid axes crossing at the same center point, more
  prominent than the quarter-grid lines but still secondary to the
  moving marker

Requirements:
- the center reference must remain visible whenever the moving marker
  is away from center
- it must be visually lighter/smaller than the moving marker
- it should help pilots confirm centering during pre-flight checks

## 9. Visual Priority
The stick monitor is secondary to telemetry cards.

Rules:
- telemetry values remain the most visually dominant elements on the screen
- the stick monitor must still be readable at a glance
- stick graphics should avoid decorative detail
- line weight and marker size should be consistent between the two gimbals

## 10. Telemetry Independence
The stick monitor must function independently of receiver telemetry availability.

Rules:
- the stick monitor remains visible even when telemetry is inactive
- the stick monitor must not depend on aircraft telemetry values
- the stick monitor continues updating while the dashboard shows:

    NO RX TELEMETRY

This prevents the radio-side control check from disappearing when the aircraft is powered off or not yet connected.

## 11. Layout Placement
The stick monitor belongs above the telemetry card grid.

Reference arrangement:

    Top Bar

    Stick Monitor Area

    Telemetry Card Grid

Placement rules:
- the monitor should occupy a reserved area above the primary card grid
- left and right gimbals should remain horizontally aligned
- the monitor should not push critical telemetry cards into different positions
- layout definitions should place the stick monitor using reserved bounds rather than ad hoc draw coordinates

For grid and slot behavior below the stick monitor area, see [docs/telemetry-layout.md](telemetry-layout.md).

## 12. Performance Considerations
Stick rendering must remain lightweight so the widget refresh loop stays responsive.

Guidelines:
- use simple, solid shapes instead of complex graphics (no gradients,
  alpha blending, blur, or bitmap scaling)
- avoid unnecessary redraw work outside the monitor area when possible
- reuse precomputed layout values for stick pad bounds and center
- avoid allocations inside the refresh loop
- select marker/grid sizing from the pad's own computed size, never
  from display resolution or a named resolution class

## 13. Acceptance Mapping
This definition establishes:
- the stick visualization model
- stick input normalization and mapping rules
- display behavior expectations
- layout placement rules
- telemetry independence requirements
