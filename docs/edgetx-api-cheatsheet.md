# EdgeTX Lua Widget API Cheat Sheet

This file provides practical guidance for implementing the EdgeTX telemetry dashboard widget.

It is intended for AI coding agents and contributors working on Lua widget code.

---

## Target Environment

- EdgeTX
- Lua widget environment
- Color screen radios
- Primary display class: `480x320`
- Compatible display class: `480x272`

Hardware assumptions are defined in `docs/hardware-targets.md`.

The implementation must remain lightweight and avoid unnecessary redraw and memory allocation.

---

## Widget Lifecycle

EdgeTX widgets typically implement these functions:

- `create(zone, options)`
- `update(widget, options)`
- `background(widget)`
- `refresh(widget, event, touchState)`

### `create(zone, options)`
Called when the widget is created.

Use it to:

- initialize widget state
- cache geometry derived from `zone`
- initialize references to options
- prepare reusable values

Typical responsibilities:

- store `zone`
- store `options`
- initialize cached layout data
- initialize telemetry defaults

### `update(widget, options)`
Called when widget options change.

Use it to:

- update widget configuration
- recompute cached layout if needed

Do not use it for heavy rendering.

### `background(widget)`
Called when the widget is not the active visible screen.

Use it only for lightweight background work if needed.

Keep this function minimal.

### `refresh(widget, event, touchState)`
Main rendering function.

Use it to:

- read current telemetry state
- render the widget
- draw only what is necessary

Keep this function fast and deterministic.

Avoid unnecessary allocations in `refresh`.

---

## Common Design Rules

- Prefer flat UI over decorative UI
- Prioritize readability over visual complexity
- Avoid expensive redraw patterns
- Keep coordinate calculations simple
- Cache layout values outside hot paths
- Reuse loaded assets
- Separate telemetry collection from rendering

---

## Suggested Module Responsibilities

### `dashboard.lua`
Main widget entry point.

Responsibilities:

- expose EdgeTX lifecycle functions
- wire together telemetry, layout, and rendering modules

### `telemetry.lua`
Responsibilities:

- fetch telemetry values
- normalize values
- expose safe defaults when telemetry is missing
- convert raw telemetry into UI-friendly state

### `ui_layout.lua`
Responsibilities:

- define panel coordinates
- compute layout regions
- centralize sizing and spacing rules

### `ui_components.lua`
Responsibilities:

- reusable draw functions for individual components
- battery card
- LQ indicator
- RSSI card
- packet rate card
- satellite indicator
- stick monitor

### `render.lua`
Responsibilities:

- orchestrate full-screen rendering
- compose the final frame from layout + components

### `icons.lua`
Responsibilities:

- load icon assets
- cache icon references
- expose icon lookup helpers

---

## Telemetry Model

The UI should work with a normalized telemetry state table.

Example structure:

```lua
local telemetry = {
  battery = {
    voltage = 7.52,
    cells = 2,
    percentage = 41
  },
  link = {
    lq = 100,
    rssi = -21,
    packetRate = 250,
    antenna = 1,
    txPower = "25mW"
  },
  gps = {
    sats = 12,
    fix = true
  },
  sticks = {
    thr = 0,
    yaw = -100,
    pit = 0,
    roll = 100
  },
  status = {
    armed = false,
    warning = nil
  }
}