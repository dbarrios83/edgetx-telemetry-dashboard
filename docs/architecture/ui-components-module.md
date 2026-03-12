# UI Components Module

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
Planned runtime renderer modules:

```text
SCRIPTS/WIDGETS/FPVDASH/render/topbar.lua
SCRIPTS/WIDGETS/FPVDASH/render/sticks.lua
SCRIPTS/WIDGETS/FPVDASH/render/cards.lua
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

### 4.3 Card Renderer (`render/cards.lua`)
Responsibilities:
- draw primary telemetry cards
- draw context telemetry row
- draw optional diagnostic cards when available
- apply telemetry state styling and icon behavior

Inputs:
- card region bounds and slot mappings from layout modules
- per-frame telemetry snapshot
- evaluated telemetry states

## 5. Renderer Contract
Renderers consume prepared data and layout bounds and should not read sensors directly.

Base renderer pattern:

```lua
draw(rect, data)
```

Renderers may also expose specialized functions when a component renders multiple regions.

Example:

```lua
cards.drawPrimary(rect, telemetry, state)
cards.drawContext(rect, telemetry, state)
cards.drawOptional(rect, telemetry, state)
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
3. primary telemetry cards
4. context telemetry cards
5. optional diagnostics

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