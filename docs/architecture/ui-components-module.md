# UI Components Module

> **Note (Step 10, 2026-08-06):** this is the original pre-implementation
> design document. `render/cards.lua` (the "Telemetry Cards" component
> described below) was deleted in Step 9 as dead code — it was loaded
> but never called. `render/context.lua` is the actual, live telemetry
> grid renderer; `render/timers.lua` and `render/footer.lua` were also
> added and aren't reflected below. See the Reliability & Compatibility
> plan's Step 9 for why, and the actual source under
> `SCRIPTS/WIDGETS/FPVDASH/` for current ground truth.

## 1. Goal
Define the reusable UI components module used by the telemetry dashboard widget.

These components are the visual building blocks rendered by the widget and provide a consistent structure for telemetry visualization.

This document defines component responsibilities and module boundaries. It does not define implementation details beyond module contracts.

## 2. Component Set
The UI components module is composed of three primary renderer groups:
- Top Bar
- Stick Monitor
- Telemetry Cards

These components map directly to the behavior and structure defined in:
- [docs/ui/top-bar.md](../ui/top-bar.md)
- [docs/ui/stick-monitor.md](../ui/stick-monitor.md)
- [docs/ui/telemetry-cards.md](../ui/telemetry-cards.md)

## 3. Runtime Module Paths
Actual runtime renderer modules:

```text
SCRIPTS/WIDGETS/FPVDASH/render/topbar.lua
SCRIPTS/WIDGETS/FPVDASH/render/sticks.lua
SCRIPTS/WIDGETS/FPVDASH/render/context.lua
SCRIPTS/WIDGETS/FPVDASH/render/timers.lua
SCRIPTS/WIDGETS/FPVDASH/render/footer.lua
```

Each renderer is responsible for drawing only its own component area.

## 4. Responsibilities By Renderer

### 4.1 Top Bar Renderer (`render/topbar.lua`)
Responsibilities:
- draw model name, radio battery, telemetry status icon, and time/date
- keep top-bar layout compact and stable
- remain functional when aircraft telemetry is unavailable

Inputs:
- top-bar bounds from layout module
- telemetry snapshot fields needed for status/icon selection
- radio-side values (model, radio battery, time)

### 4.2 Stick Renderer (`render/sticks.lua`)
Responsibilities:
- draw left and right stick monitors
- render center markers and stick indicators
- map normalized stick input values into monitor coordinates

Inputs:
- stick-monitor bounds from layout module
- per-frame stick input snapshot

### 4.3 Context Grid Renderer (`render/context.lua`)
Responsibilities:
- draw the 2x4 context telemetry grid (current, packet rate, TX power,
  RSSI, satellites, flight mode, RSNR, consumed capacity) directly
  within its given region — no separate slot-mapping layer
- apply telemetry state styling and icon behavior
- distinguish an undiscovered sensor from a genuine zero reading via the
  normalized snapshot's `available` map (never reads sensors directly)

Inputs:
- primary-grid region bounds from the layout module
- per-frame telemetry snapshot
- evaluated telemetry states

### 4.4 Timers and Footer Renderers (`render/timers.lua`, `render/footer.lua`)
Responsibilities:
- draw the three-timer row and the ELRS/EdgeTX version footer
  (footer only on the taller 480x320 display class)

## 5. Renderer Contract
Renderers consume prepared data and layout bounds and should not read sensors directly.

Base renderer pattern:

```lua
draw(rect, telemetry, state, theme)
```

Example (actual signature, `render/context.lua`):

```lua
context.draw(layout.primaryGrid, telemetry, state, theme)
```

All renderer functions must receive precomputed layout bounds and prepared data from the widget orchestrator.

## 6. Data Dependencies
The UI components module depends on:
- layout module outputs (regions and slot geometry)
- telemetry snapshot values (read once per frame)
- telemetry state evaluation outputs (`OK`, `WARNING`, `LOW`, `CRITICAL`, `UNKNOWN`)

The UI components module must not:
- access telemetry sensors directly
- compute layout geometry internally
- mutate global widget orchestration state

## 7. Refresh Integration
Within `refresh()`, component rendering order is:
1. top bar
2. stick monitor
3. context telemetry grid
4. timers row
5. footer (480x320 display class only)

This order preserves hierarchy and prevents overlap artifacts.

## 8. Design And Performance Constraints
Renderer constraints:
- prioritize numeric readability over decorative rendering
- keep icon usage consistent with UI specifications
- avoid frequent allocations inside frame rendering paths
- keep drawing deterministic for predictable frame behavior

Icon usage must follow the icon specifications defined in:
- [docs/assets/icons.md](../assets/icons.md)

The UI components module should remain lightweight to fit EdgeTX runtime constraints.

## 9. Value Formatting
Telemetry values should be formatted before rendering to ensure consistent units and readability.

Examples:
- Battery voltage -> `16.2 V`
- RSSI -> `-65 dBm`
- Current -> `18.4 A`
- Packet rate -> `500 Hz`

Formatting may be handled either in the telemetry module or in small utility helpers used by the card renderer.

## 10. Acceptance Mapping
This document defines:
- the reusable UI component set
- renderer module boundaries
- component responsibilities
- renderer input contracts
- integration of components into widget refresh flow