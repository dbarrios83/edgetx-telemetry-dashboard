# Telemetry Module

## 1. Goal
Define the telemetry access module used by the EdgeTX telemetry dashboard widget.

The telemetry module is responsible for retrieving telemetry values from the EdgeTX sensor API, normalizing raw data, and exposing a consistent telemetry snapshot to the rest of the dashboard system.

This module isolates telemetry access from UI rendering and ensures renderers operate on prepared data rather than reading sensors directly.

## 2. Scope
The telemetry module defines:
- telemetry sensor access strategy
- telemetry snapshot structure
- normalization rules
- telemetry state evaluation interface
- handling of missing or unavailable sensors

This document defines architecture and module contracts but does not implement telemetry logic.

## 3. Runtime Module Paths
Planned runtime modules:

```text
SCRIPTS/WIDGETS/FPVDASH/telemetry/read.lua
SCRIPTS/WIDGETS/FPVDASH/telemetry/state.lua
```

These modules provide telemetry values and telemetry health states used by the dashboard.

## 4. Responsibilities

### 4.1 Telemetry Read Module (`telemetry/read.lua`)
Responsibilities:
- retrieve telemetry sensor values from EdgeTX APIs
- normalize raw sensor data into dashboard-friendly fields
- expose a per-frame telemetry snapshot
- gracefully handle missing telemetry sensors

Telemetry values should be read once per frame and cached in a snapshot structure.

Example snapshot:

```lua
telemetry = {
  battery = 16.2,
  rssi = -65,
  linkQuality = 100,
  packetRate = 500,
  current = 18.4,
  satellites = 12,
  txPower = 250,
  flightMode = "ACRO"
}
```

The snapshot is passed to renderers during the frame pipeline.

### 4.2 Telemetry State Module (`telemetry/state.lua`)
Responsibilities:
- evaluate health states for telemetry values
- categorize telemetry values into dashboard state levels
- provide consistent state outputs consumed by UI components

Telemetry states:

```text
OK
WARNING
LOW
CRITICAL
UNKNOWN
DISCONNECTED
```

Example usage:

```lua
local state = telemetryState.evaluate(value, thresholds)
```

These states drive UI behavior such as icon color and warning indicators.

## 5. Telemetry Snapshot Model
The telemetry module exposes a single snapshot per frame.

Example access pattern:

```lua
local telemetry = telemetryRead.snapshot()
```

Renderers consume the snapshot instead of querying sensors directly.

Advantages:
- avoids repeated sensor reads
- improves performance
- keeps rendering deterministic

## 6. Supported Telemetry Fields
The dashboard expects the following telemetry values:

```text
battery
rssi
linkQuality
packetRate
current
satellites
txPower
flightMode
```

Optional diagnostic telemetry may include:

```text
rssi1
rssi2
capacity
activeAntenna
```

Missing telemetry values should return a safe fallback value and be marked as `UNKNOWN`.

## 7. Data Flow Integration
Within the widget refresh pipeline:

```text
Telemetry Read -> State Evaluation -> Layout Computation -> Rendering
```

Sequence per frame:
1. read telemetry snapshot
2. evaluate telemetry state values
3. compute layout regions
4. render UI components

The telemetry module must not perform UI rendering.

## 8. Error Handling
The telemetry module must handle:
- missing telemetry sensors
- telemetry link loss
- uninitialized telemetry values
- sensor name differences between receivers

When telemetry is unavailable, snapshot fields should return safe placeholder values and the state should be set to `DISCONNECTED` or `UNKNOWN`.

## 9. Performance Considerations
The telemetry module runs inside the EdgeTX Lua runtime and must remain lightweight.

Implementation guidelines:
- avoid repeated sensor lookups within a frame
- reuse snapshot tables where possible
- avoid expensive computations during refresh
- perform simple normalization only

## 10. Acceptance Mapping
This module definition provides:
- telemetry access architecture
- telemetry snapshot structure
- telemetry state evaluation interface
- integration with dashboard rendering pipeline
- isolation of telemetry access from UI components

Implementation of this module will occur in EPIC 6 - Implement MVP Dashboard.

## 11. Related Specifications
- [Lua Widget Architecture](lua-widget-architecture.md)
- [Telemetry State](../ui/telemetry-state.md)
- [Telemetry Cards](../ui/telemetry-cards.md)
- [Telemetry Layout](../ui/telemetry-layout.md)
- [UI Components Module](ui-components-module.md)
