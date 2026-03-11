# Architecture

## Goal
Build an EdgeTX widget-based telemetry dashboard optimized for quick in-flight readability.

## High-Level Components
- `lua/widgets/dashboard/dashboard.lua`: Widget entry point, render/update lifecycle, telemetry adapters.
- `icons/`: Bitmap/icon assets grouped by telemetry domain.
- `tests/`: Unit and simulation-style checks for parsing and layout logic.
- `examples/`: Example configs, screenshots, and sample telemetry payload references.

## Planned Data Flow
1. Read telemetry fields from EdgeTX runtime APIs.
2. Normalize into internal dashboard model.
3. Render primary status cards (battery, satellites, LQ, RSSI).
4. Update at widget refresh cadence with lightweight background processing.

## Notes
- Keep rendering allocation-light to avoid frame drops on radio hardware.
- Separate parsing/formatting logic from draw logic for testability.
