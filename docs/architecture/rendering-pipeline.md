# Rendering Pipeline

## 1. Goal
Define the rendering pipeline used by the EdgeTX telemetry dashboard widget.

The rendering pipeline describes the sequence of operations executed during each widget refresh cycle. It establishes how telemetry data flows from the telemetry module through layout computation into UI renderers.

The goal is to ensure a deterministic and predictable frame update process while keeping rendering lightweight and consistent with EdgeTX runtime constraints.

## 2. Scope
The rendering pipeline defines:
- frame update sequence
- interaction between telemetry, layout, and rendering modules
- renderer invocation order
- responsibilities of the widget orchestrator during refresh

This document defines rendering flow but does not implement drawing logic.

## 3. Frame Lifecycle Integration
The rendering pipeline is executed inside the widget `refresh()` function.

Relevant EdgeTX lifecycle callbacks:

```text
create(zone, options)
update(widget, options)
refresh(widget, event, touchState)
background(widget)
```

The dashboard rendering pipeline runs entirely within `refresh()`.

## 4. Rendering Pipeline Overview
Each frame follows a deterministic pipeline:

```text
Telemetry Read -> State Evaluation -> Layout Computation -> Rendering
```

This flow ensures all UI components render from a consistent telemetry snapshot and precomputed layout geometry.

## 5. Frame Execution Sequence
During `refresh()`, the following sequence occurs:

1. retrieve telemetry snapshot
2. evaluate telemetry health states
3. compute dashboard layout regions
4. render UI components

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

The telemetry snapshot must be read only once per frame and reused by all renderers to prevent repeated sensor access.

The widget orchestrator coordinates this pipeline but does not perform drawing itself.

## 6. Renderer Invocation Order
Dashboard components are rendered in the following order:

1. Top Bar
2. Stick Monitor
3. Primary Telemetry Cards
4. Context Telemetry Row
5. Optional Diagnostic Cards

This order preserves visual hierarchy and avoids overlapping artifacts between regions.

## 7. Renderer Inputs
Renderers consume prepared data and layout bounds provided by the widget orchestrator.

Typical renderer inputs:

```text
rect      -> layout bounds for the component
telemetry -> telemetry snapshot
state     -> evaluated telemetry states
```

Renderers must not:
- read telemetry sensors directly
- compute layout geometry
- modify widget orchestration state

## 8. Layout Dependency
The rendering pipeline depends on layout outputs produced by the layout module.

Layout outputs include bounding rectangles for:
- top bar
- stick monitor
- primary telemetry grid
- context telemetry row
- optional diagnostics region

Renderers must operate strictly within their assigned bounds.

## 9. Performance Considerations
The rendering pipeline runs inside the EdgeTX Lua runtime and must remain lightweight.

Guidelines:
- read telemetry sensors once per frame
- avoid dynamic memory allocation during rendering
- reuse layout structures where possible
- keep rendering deterministic and predictable
- avoid expensive computations in the refresh loop

The pipeline should prioritize stable frame timing and UI responsiveness.

## 10. Architectural Boundaries
The rendering pipeline enforces strict module boundaries:
- telemetry module -> provides telemetry snapshot
- telemetry state module -> evaluates telemetry health
- layout module -> computes geometry
- render modules -> draw UI components
- widget orchestrator -> coordinates the pipeline

This separation prevents tight coupling and simplifies maintenance.

## 11. Acceptance Mapping
This definition provides:
- rendering pipeline sequence
- refresh integration with EdgeTX lifecycle
- renderer invocation order
- renderer input contracts
- clear separation between telemetry, layout, and rendering

Implementation of this pipeline will occur in EPIC 6 - Implement MVP Dashboard.

## 12. Related Specifications
- [Lua Widget Architecture](lua-widget-architecture.md)
- [Telemetry Module](telemetry-module.md)
- [UI Components Module](ui-components-module.md)
- [Telemetry Layout](../ui/telemetry-layout.md)
- [Dashboard Wireframe](../ui/dashboard-wireframe.md)
