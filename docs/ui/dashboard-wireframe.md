# Dashboard Wireframe

## 1. Purpose
This document provides the first visual wireframe of the EdgeTX telemetry dashboard.

The wireframe combines the previously defined dashboard components into a single visual reference so implementation can proceed without ambiguity.

This document does not define new behavior. It visualizes the architecture already established in:
- [docs/dashboard-information-hierarchy.md](dashboard-information-hierarchy.md)
- [docs/top-bar.md](top-bar.md)
- [docs/stick-monitor.md](stick-monitor.md)
- [docs/telemetry-layout.md](telemetry-layout.md)
- [docs/telemetry-cards.md](telemetry-cards.md)

The goal is to establish a clear visual blueprint before widget implementation begins.

## 2. Wireframe Scope
The wireframe includes the following dashboard regions:
1. Top Bar
2. Stick Monitor
3. Primary Telemetry Grid
4. Context Telemetry Row
5. Optional Diagnostic Area

It illustrates the relative placement and hierarchy of these regions rather than final visual styling.

## 3. Primary Wireframe
The following wireframe shows the intended dashboard structure for the primary target display class.

```text
┌──────────────────────────────────────────────────────────────────────────────┐
│ Top Bar                                                                      │
│ Model Name                 Radio Battery     Link Status         Time / Date │
├──────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│                             Stick Monitor Area                               │
│                                                                              │
│                     Left Stick                     Right Stick               │
│                        (o)                        (o)                        │
│                                                                              │
├──────────────────────┬──────────────────────┬────────────────────────────────┤
│ Battery              │ Link Quality         │ Packet Rate                    │
│ 16.2 V               │ 100 %                │ 500 Hz                         │
├──────────────────────┼──────────────────────┼────────────────────────────────┤
│ RSSI                 │ Current              │ Satellites                     │
│ -65 dBm              │ 18.4 A               │ 12                             │
├──────────────────────┴──────────────────────┴────────────────────────────────┤
│ Context Telemetry: TX Power                                 Flight Mode      │
│                     250 mW                                   ACRO            │
├──────────────────────────────────────────────────────────────────────────────┤
│ Optional Diagnostics                                                         │
│ RSSI1        RSSI2        Capacity        Active Antenna                     │
│ -67 dBm      -69 dBm      540 mAh         ANT 1                              │
└──────────────────────────────────────────────────────────────────────────────┘
```

This is a structural wireframe only. Spacing and sizing are approximate and should be refined by implementation-facing layout definitions.

## 4. Region Summary

### 4.1 Top Bar
The top bar provides persistent radio-side information:
- model name
- radio battery
- telemetry status icon
- time and date

Reference behavior:
- [docs/top-bar.md](top-bar.md)

### 4.2 Stick Monitor
The stick monitor sits below the top bar and above aircraft telemetry.

It includes:
- left stick visualization
- right stick visualization
- center markers
- moving stick indicators

Reference behavior:
- [docs/stick-monitor.md](stick-monitor.md)

### 4.3 Primary Telemetry Grid
The primary telemetry grid contains the six highest-priority telemetry values:

```text
Battery      | Link Quality | Packet Rate
RSSI         | Current      | Satellites
```

Reference layout:
- [docs/telemetry-layout.md](telemetry-layout.md)

Reference card definitions:
- [docs/telemetry-cards.md](telemetry-cards.md)

### 4.4 Context Telemetry Row
The context telemetry row extends the primary grid without replacing it.

It contains:
- TX Power
- Flight Mode

These values provide useful operating context but should remain visually secondary to the primary grid.

### 4.5 Optional Diagnostic Area
The optional diagnostic area displays telemetry only when those sensors are present.

Possible cards include:
- RSSI1
- RSSI2
- Capacity
- Active Antenna

This region must not disrupt the placement of the primary grid or context telemetry.

These diagnostics correspond to the optional slot definitions described in [docs/telemetry-layout.md](telemetry-layout.md).

## 5. Hierarchy And Scan Order
The wireframe reflects the information hierarchy defined in [docs/dashboard-information-hierarchy.md](dashboard-information-hierarchy.md).

Expected scan order:
1. Top Bar
2. Stick Monitor
3. Primary Telemetry Grid
4. Context Telemetry Row
5. Optional Diagnostic Area

The stick monitor remains visually prominent enough for radio-input checks, but lighter than the primary telemetry cards.

## 6. Wireframe Style Guidance
This wireframe focuses on structure rather than visual styling.

Guidelines:
- simple boxes for cards and regions
- labeled areas rather than final artwork
- approximate spacing only
- no final color decisions implied
- no final font sizing implied beyond relative hierarchy

## 7. Relationship To Existing Architecture
This wireframe consolidates the current dashboard architecture into one reference.

Relationship summary:
- the top bar provides persistent radio-side context
- the stick monitor provides radio-input verification below the top bar
- the primary telemetry grid is the dominant aircraft-telemetry region
- the context row extends the primary telemetry model
- the optional diagnostics region appears only when supporting sensors exist

Together, these regions define the overall dashboard blueprint for implementation.

## 8. Acceptance Mapping
This document provides:
- a visual wireframe of the dashboard
- labeled dashboard regions
- primary, context, and optional telemetry areas
- clear placement of the top bar, stick monitor, and telemetry grid
- a short explanation of how the wireframe relates to the existing architecture documents