# Lua Widget Architecture

> **Note (Step 10, 2026-08-06):** this is the original pre-implementation
> design document. The implementation evolved during development: the
> planned `layout/slots.lua` + `render/cards.lua` slot/card rendering
> path was superseded by `render/context.lua`, which draws the telemetry
> grid directly from `layout.lua`'s regions without a separate slot
> layer, and both files were deleted as dead code once confirmed unused
> (see the project's Reliability & Compatibility plan, Step 9).
> `render/timers.lua` and `render/footer.lua` were also added and are
> not reflected below. Sections 5, 6.3, 6.4, and 8.1 have been updated
> to match; for anything else, the actual source under
> `SCRIPTS/WIDGETS/FPVDASH/` is the ground truth, not this document.

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
Actual module structure under the runtime widget directory:

```text
SCRIPTS/WIDGETS/FPVDASH/
    main.lua

  layout/
    layout.lua

  render/
    topbar.lua
    sticks.lua
    context.lua
    timers.lua
    footer.lua

  telemetry/
    read.lua
    state.lua
    battery.lua
    elrs.lua
```

This structure isolates responsibilities and allows focused testing by module.
There is no separate slot-definition module: `layout.lua` outputs the
regions renderers draw into directly, and `context.lua` lays out its own
2x4 metric grid within the `primaryGrid` region it's given.

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

### 6.3 Slot Definition Module (removed — see note at top)
The originally planned slot-mapping module (`layout/slots.lua`, with
`P1`-`P6`/`C1`-`C2`/`O1`-`O4` slot identifiers) was deleted in Step 9 as
dead code: its only consumer was `render/cards.lua`, which was itself
loaded but never called from `refresh()`. `render/context.lua` draws
its 8-metric grid (current, packet rate, TX power, RSSI, satellites,
flight mode, RSNR, consumed capacity) directly within the `primaryGrid`
region `layout.lua` provides, with no intermediate slot layer.

### 6.4 Rendering Modules
Files:

    SCRIPTS/WIDGETS/FPVDASH/render/topbar.lua
    SCRIPTS/WIDGETS/FPVDASH/render/sticks.lua
    SCRIPTS/WIDGETS/FPVDASH/render/context.lua
    SCRIPTS/WIDGETS/FPVDASH/render/timers.lua
    SCRIPTS/WIDGETS/FPVDASH/render/footer.lua

Responsibilities:
- draw UI elements inside provided bounds
- render only, without layout computation
- consume normalized data and evaluated telemetry state

Renderer contract:

Base renderer pattern:

```lua
draw(rect, telemetry, state, theme)
```

Example (actual signatures, `SCRIPTS/WIDGETS/FPVDASH/render/context.lua`):

```lua
context.draw(layout.primaryGrid, telemetry, state, theme)
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
    -- widget.telemetrySession is created once per widget instance in
    -- create() (telemetryRead.init()) and must never be shared between
    -- instances -- see Section 8.2.
    local telemetry = telemetryRead.snapshot(widget.telemetrySession, elrsMajorVersion)
    local state = telemetryState.evaluate(telemetry)

    local layout = layoutModule.compute(widget.zone)

    topbarRenderer.draw(layout.topBar, telemetry, state, theme)
    sticksRenderer.draw(layout.stickMonitor, telemetry, state, theme)
    contextRenderer.draw(layout.primaryGrid, telemetry, state, theme)
    timersRenderer.draw(layout.contextRow, telemetry, state, theme)
    footerRenderer.draw(layout.footerRow, telemetry, state, theme)
end
```

This pipeline keeps rendering logic deterministic and predictable.

## 8.2 Per-Instance State Ownership

**Status: implemented (Architecture & Packaging Hardening project, Task 3,
2026-08-06).**

EdgeTX shares a widget script's file-scope (module-level) Lua locals
across every instance of that widget -- if `main.lua` is placed in two
zones, both instances execute the same loaded chunk and see the same
module-level variables. A module that keeps mutable per-session state in
a file-scope local (rather than on the `widget` table `create()`
returns) will have that state corrupted the moment a second instance
exists.

Two categories of module state exist in this codebase, and they are
treated differently:

- **Shared code, safe to keep at module scope:** `layout/layout.lua` is
  pure/stateless -- it takes its inputs as arguments and holds no mutable
  state between calls. The `render/*.lua` modules are not fully
  stateless, and exactly how each one caches its icons differs:
  - `render/context.lua` and `render/timers.lua` each keep a single
    icon-set cache keyed by theme folder (`dark`/`light`) -- every icon
    they load lives under a theme-specific folder.
  - `render/topbar.lua` keeps *two* caches: a theme-keyed cache (like
    context.lua/timers.lua) for its link icons, plus a separate
    one-time, theme-independent load for its battery icons, which live
    under `icons/battery/` rather than a theme folder.
  - `render/sticks.lua`'s icons (battery and connection status) are
    entirely theme-independent, so it has no theme-keyed cache at all --
    just a single one-time load, the same shape as topbar.lua's battery
    icons.

  `render/sticks.lua` and `render/topbar.lua` also recompute a
  theme-dependent shadow-color local inside `M.draw()`. This is safe to
  share across every instance of the widget precisely because it's
  *derived, bounded, and theme-keyed* -- for a given theme there is only
  ever one correct icon set or shadow color, so two instances on the same
  theme option converge on the same cached value instead of fighting over
  it, and a bounded two-entry cache (one per theme, where a cache is
  theme-keyed at all) can't grow unbounded. See
  `tests/spec/icon_cache_spec.lua` for the regression this cache keying
  fixes (module-level state that remembered only the *most-recently-
  drawn* theme used to thrash on every alternating-theme redraw), and its
  "still loads the theme-independent battery icons exactly once" test for
  the theme-independent half of this split. Loading one shared copy of
  each render module per widget
  script (not per instance) is both correct and desirable for this
  reason; see Section 8's deferred-loading discussion in `main.lua`.
- **Mutable per-instance state, must live on the widget table:**
  `telemetry/read.lua`'s sensor-ID cache and rescan counter, and
  `telemetry/battery.lua`'s latched cell count, previously lived as
  module-level locals. They now follow the same explicit-state-object
  shape `telemetry/elrs.lua` already used for its CRSF device-info
  polling state:
  - `telemetryRead.init()` / `batteryModule.init()` return a fresh state
    table, called once per widget instance in `create()` and stored on
    the returned `widget` table (`widget.telemetrySession`, alongside
    the existing `widget.elrsState`).
  - `telemetryRead.snapshot(session, elrsMajorVersion)` and
    `batteryModule.resolve(state, voltage, explicitCells)` /
    `batteryModule.reset(state)` take that state as an explicit
    argument rather than reading/writing a module-level local.

A new widget instance created mid-session (e.g. a second zone added
after telemetry is already connected and partially into a flight) starts
with a fresh, empty session -- it does not inherit another instance's
already-discovered sensors or already-latched pack size. See
`tests/spec/main_spec.lua`'s "per-instance telemetry state isolation"
tests for the exact regression scenario this fixes.

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
