# Implementation Notes

## Detecting Screen Resolution

The dashboard should adapt to different EdgeTX color screen resolutions at runtime.

EdgeTX Lua widget scripts can query the LCD size to determine the available drawing area. The widget should use this information to adjust layout spacing and telemetry placement.

Supported screen classes include:

- 480 × 272
- 480 × 320

Future radios may include larger displays such as:

- 800 × 480

The layout should be designed so that:

- 480 × 272 acts as the base layout
- 480 × 320 extends the vertical layout
- larger screens may enable additional panels

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