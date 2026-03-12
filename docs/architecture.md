# Architecture

## Goal
Build an EdgeTX widget-based telemetry dashboard optimized for quick in-flight readability.

## High-Level Components
- `SCRIPTS/WIDGETS/TELEMETRY/dashboard.lua`: Widget entry point, render/update lifecycle, telemetry adapters.
- `SCRIPTS/WIDGETS/TELEMETRY/icons/`: Runtime icon assets loaded by absolute EdgeTX paths.
- `tests/`: Unit and simulation-style checks for parsing and layout logic.
- `tests/examples/`: Example configs and sample telemetry payload references.

## Runtime File Layout
The repository mirrors the EdgeTX SD card structure.

This allows developers to copy the `SCRIPTS` directory directly to the radio without a build step.

Runtime widget path:
- `/SCRIPTS/WIDGETS/TELEMETRY/dashboard.lua`

Runtime icon path:
- `/SCRIPTS/WIDGETS/TELEMETRY/icons/*.png`

## Planned Data Flow
1. Read telemetry fields from EdgeTX runtime APIs.
2. Normalize into internal dashboard model.
3. Render primary status cards (battery, satellites, LQ, RSSI).
4. Update at widget refresh cadence with lightweight background processing.

## Notes
- Keep rendering allocation-light to avoid frame drops on radio hardware.
- Separate parsing/formatting logic from draw logic for testability.
