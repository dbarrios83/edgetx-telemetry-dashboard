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
        ○               ○

Mode 2 axis mapping:
- left horizontal: yaw
- left vertical: throttle
- right horizontal: roll
- right vertical: pitch

The dashboard should use Mode 2 as the documented baseline while keeping the mapping logic separate enough to support other modes later.

## 5. Stick Visualization Rules
Each stick should be represented by:
- a circular boundary that defines the gimbal movement range
- a persistent center indicator
- a moving dot that shows the current stick position

Conceptual visualization (schematic only—actual rendering uses a circle):

    +-----------+
    |     +     |
    |     o     |
    |           |
    +-----------+

Visualization rules:
- both stick circles use the same size
- the moving dot must remain clearly visible against the background
- the center marker must remain visible even when the dot moves away
- graphics should stay minimal and lightweight
- the moving dot should never render outside the stick boundary

## 6. Movement Mapping
Stick inputs must be mapped from normalized channel values into the visible gimbal range.

Baseline normalization:

    normalized = input / 100

Mapped position:

    x = centerX + normalizedHorizontal * radius
    y = centerY - normalizedVertical * radius

Mapping rules:
- horizontal minimum maps to the left edge of the stick range
- horizontal maximum maps to the right edge of the stick range
- vertical minimum maps to the bottom edge of the stick range
- vertical maximum maps to the top edge of the stick range
- `0` maps to the visual center for self-centering axes

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

Recommended options:
- small center dot
- subtle crosshair
- faint horizontal and vertical guide lines

Requirements:
- the center indicator must always remain visible
- it must be visually lighter than the moving stick dot
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

For grid and slot behavior below the stick monitor area, see `docs/telemetry-layout.md`.

## 12. Performance Considerations
Stick rendering must remain lightweight so the widget refresh loop stays responsive.

Guidelines:
- use simple shapes instead of complex graphics
- avoid unnecessary redraw work outside the monitor area when possible
- reuse precomputed layout values for stick centers and radius
- avoid allocations inside the refresh loop

## 13. Acceptance Mapping
This definition establishes:
- the stick visualization model
- stick input normalization and mapping rules
- display behavior expectations
- layout placement rules
- telemetry independence requirements
