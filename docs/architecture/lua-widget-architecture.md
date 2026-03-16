# Lua Widget Architecture

## 1. Goal
Define the overall Lua architecture for the EdgeTX telemetry dashboard widget.

This architecture establishes module structure, responsibilities, and interaction boundaries between layout, telemetry access, and rendering.

The goal is to keep the implementation modular, maintainable, and extensible while avoiding tight coupling between telemetry logic and UI drawing logic.

This document guides EPIC 6 implementation tasks.

## 2. Scope
This architecture definition covers:
- widget entrypoint
- module organization
- EdgeTX widget lifecycle usage
- data flow between modules
- separation of responsibilities

This document does not define final UI visuals and does not require implementation in this task.

## 3. Widget Entry Point
The dashboard is implemented as an EdgeTX Lua widget.

Runtime entrypoint:

    /SCRIPTS/WIDGETS/FPVDASH/main.lua

Repository path:

    SCRIPTS/WIDGETS/FPVDASH/main.lua

The entrypoint coordinates telemetry reads, state evaluation, layout computation, and renderer calls.

## 4. Widget Lifecycle
The architecture uses the standard EdgeTX widget lifecycle callbacks:

- `create(zone, options)`
- `update(widget, options)`
- `refresh(widget, event, touchState)`
- `background(widget)`

Lifecycle responsibilities:

### 4.1 `create(zone, options)`
- initialize widget-local state
- load reusable resources (for example icon handles)
- initialize long-lived module context

### 4.2 `update(widget, options)`
- apply options changes
- refresh cached configuration values
- avoid heavy rendering work

### 4.3 `refresh(widget, event, touchState)`
- run frame-level dashboard pipeline
- compute current layout regions
- invoke renderer modules

All user-visible dashboard rendering occurs in `refresh()`.

### 4.4 `background(widget)`
- run low-frequency maintenance tasks
- perform non-visual housekeeping
- avoid frequent allocations and heavy drawing

## 5. Module Organization
Proposed module structure under the runtime widget directory:

```text
SCRIPTS/WIDGETS/FPVDASH/
    main.lua

  layout/
    layout.lua
    slots.lua

  render/
    topbar.lua
    sticks.lua
    cards.lua

  telemetry/
    read.lua
    state.lua
```

This structure isolates responsibilities and allows focused testing by module.

## 6. Module Responsibilities

### 6.1 Widget Orchestrator
File:

    SCRIPTS/WIDGETS/FPVDASH/main.lua

Responsibilities:
- lifecycle management
- module orchestration
- frame pipeline coordination
- passing bounded data into renderers

The widget orchestrator should not embed detailed telemetry parsing rules or draw individual card internals.

### 6.2 Layout Module
Files:

    SCRIPTS/WIDGETS/FPVDASH/layout/layout.lua

Responsibilities:
- compute dashboard region bounds from widget zone and display class
- define top bar, stick monitor, primary grid, context row, and diagnostics bounds
- output deterministic rectangles for renderers

The layout module outputs geometry only and does not draw.

### 6.3 Slot Definition Module
Files:

    SCRIPTS/WIDGETS/FPVDASH/layout/slots.lua

Responsibilities:
- map telemetry metrics to fixed slot identifiers
- enforce stable placement when optional sensors are missing

Primary slot mapping:

```text
P1 -> Battery
P2 -> Link Quality
P3 -> Packet Rate
P4 -> RSSI
P5 -> Current
P6 -> Satellites
```

Context slots:

```text
C1 -> TX Power
C2 -> Flight Mode
```

Optional diagnostic slots:

```text
O1 -> RSSI1
O2 -> RSSI2
O3 -> Capacity
O4 -> Active Antenna
```

### 6.4 Rendering Modules
Files:

    SCRIPTS/WIDGETS/FPVDASH/render/topbar.lua
    SCRIPTS/WIDGETS/FPVDASH/render/sticks.lua
    SCRIPTS/WIDGETS/FPVDASH/render/cards.lua

Responsibilities:
- draw UI elements inside provided bounds
- render only, without layout computation
- consume normalized data and evaluated telemetry state

Renderer contract:

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

Renderers should avoid direct sensor reads and avoid mutating global widget state.

### 6.5 Telemetry Modules
Files:

    SCRIPTS/WIDGETS/FPVDASH/telemetry/read.lua
    SCRIPTS/WIDGETS/FPVDASH/telemetry/state.lua

Responsibilities of `read.lua`:
- retrieve sensor values from EdgeTX APIs
- normalize raw values into dashboard-friendly fields
- return unavailable markers when sensors are missing

Responsibilities of `state.lua`:
- evaluate health/state categories (`OK`, `WARNING`, `LOW`, `CRITICAL`, `UNKNOWN`)
- provide consistent state outputs consumed by renderers

Telemetry snapshot:

Telemetry values should be read once per frame and stored in a telemetry snapshot structure.

Example snapshot:

```lua
telemetry = {
    battery = 16.2,
    rssi = -65,
    lq = 100,
    packetRate = 500,
    current = 18.4,
    satellites = 12,
    txPower = 250,
    flightMode = "ACRO"
}
```

Renderers consume the snapshot rather than accessing sensors directly.

Example usage:

```lua
local value = telemetry.getRSSI()
local state = telemetryState(value, thresholds)
```

## 7. Rendering Order
Dashboard rendering occurs in the following order:

1. top bar
2. stick monitor
3. primary telemetry grid
4. context telemetry row
5. optional diagnostics

This order preserves visual hierarchy and helps prevent overlap artifacts.

## 8. Data Flow
Expected module flow per refresh cycle:

```text
Telemetry Read -> State Evaluation -> Layout Computation -> Rendering
```

Refresh sequence:
1. read telemetry values
2. normalize and evaluate telemetry state
3. compute layout regions
4. draw top bar, stick monitor, and cards using renderer modules

The flow is one-directional during a frame, minimizing side effects.

## 8.1 Refresh Pipeline
The `refresh()` function executes the dashboard rendering pipeline once per frame.

Expected pipeline:

1. retrieve telemetry snapshot
2. evaluate telemetry state
3. compute layout regions
4. render dashboard sections

Pseudo-flow:

```lua
function refresh(widget, event, touchState)
    local telemetry = telemetryRead.snapshot()
    local state = telemetryState.evaluate(telemetry)

    local regions = layout.compute(widget.zone)

    topbar.draw(regions.topbar, telemetry)
    sticks.draw(regions.sticks, telemetry)
    cards.drawPrimary(regions.primary, telemetry, state)
    cards.drawContext(regions.context, telemetry, state)
    cards.drawOptional(regions.optional, telemetry, state)
end
```

This pipeline keeps rendering logic deterministic and predictable.

## 9. Dependency Boundaries
Dependency rules:
- render modules depend on layout outputs and prepared data, not raw telemetry APIs
- layout modules depend on geometry inputs, not telemetry values
- telemetry modules depend on sensor APIs, not renderer modules
- the widget orchestrator is the only module that coordinates all subsystems

This keeps module coupling low and simplifies maintenance.

## 10. Key Design Principles
The architecture follows these principles:
- strict separation of layout and rendering
- telemetry access isolated in dedicated telemetry modules
- renderers only draw UI elements
- slot-based deterministic telemetry placement
- allocation-light refresh pipeline
- stable scan order and region hierarchy across display classes

## 11. Performance Considerations
The dashboard runs inside the EdgeTX Lua runtime, which has limited CPU and memory resources.

Implementation should follow these guidelines:
- avoid frequent table allocations inside `refresh()`
- avoid dynamic memory creation inside rendering loops
- reuse layout objects when possible
- avoid repeated sensor lookups during a frame
- cache icon resources during `create()`

Rendering should remain lightweight to maintain consistent radio UI responsiveness.

## 12. Related Specifications
This architecture aligns with:
- [docs/architecture/ui-components-module.md](ui-components-module.md)
- [docs/architecture/telemetry-module.md](telemetry-module.md)
- [docs/architecture/rendering-pipeline.md](rendering-pipeline.md)
- [docs/ui/telemetry-layout.md](../ui/telemetry-layout.md)
- [docs/ui/telemetry-cards.md](../ui/telemetry-cards.md)
- [docs/ui/telemetry-state.md](../ui/telemetry-state.md)
- [docs/ui/top-bar.md](../ui/top-bar.md)
- [docs/ui/stick-monitor.md](../ui/stick-monitor.md)
- [docs/ui/dashboard-information-hierarchy.md](../ui/dashboard-information-hierarchy.md)
- [docs/ui/dashboard-wireframe.md](../ui/dashboard-wireframe.md)

## 13. Acceptance Mapping
This definition provides:
- widget entrypoint architecture
- lifecycle responsibilities
- module organization
- explicit module responsibility boundaries
- frame data flow from telemetry to rendering
- key architectural principles for implementation
