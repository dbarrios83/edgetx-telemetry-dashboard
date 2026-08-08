# Implementation Notes

## Detecting Screen Resolution

The dashboard should adapt to different EdgeTX color screen resolutions at runtime.

EdgeTX Lua widget scripts can query the LCD size to determine the available drawing area. The widget should use this information to adjust layout spacing and telemetry placement.

Supported screen classes include:

- 480 × 272
- 480 × 320
- 800 × 480 (RadioMaster TX16S Mark III; confirmed and tested -- see
  [docs/platform/hardware-targets.md](../platform/hardware-targets.md)
  Section 5)

The layout should be designed so that:

- 480 × 272 acts as the base layout
- 480 × 320 extends the vertical layout
- 800 × 480 uses the same region set, with the top bar height scaled to
  that width's real system-logo height

## Design Strategy

Recommended approach:

1. Define a base layout using 480 × 272.
2. Detect screen height at runtime.
3. Expand vertical layout if additional space is available.

This ensures compatibility across most EdgeTX color radios.

## Notes on EdgeTX Lua Widgets

Widget scripts run continuously while visible on the radio screen and are used to display telemetry or custom UI elements on color LCD radios. :contentReference[oaicite:0]{index=0}

They draw UI elements using LCD drawing functions such as:

- `lcd.drawText`
- `lcd.drawNumber`
- `lcd.drawTimer`

These functions allow scripts to render custom dashboards directly on the transmitter display. :contentReference[oaicite:1]{index=1}