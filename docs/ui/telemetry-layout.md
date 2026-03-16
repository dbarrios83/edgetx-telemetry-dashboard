# Telemetry Card Layout System

## 1. Purpose
This document defines the layout system used to position telemetry cards on the EdgeTX telemetry dashboard.

It describes how card slots are arranged, how each card is structured internally, and how optional telemetry is handled without destabilizing the dashboard.

This document defines layout only. Rendering implementation belongs in widget code that consumes these layout definitions.

## 2. Screen Context
Primary target display class:
- 480 x 320 pixels

Compatible display class:
- 480 x 272 pixels

The layout system must keep the same card order and visual hierarchy across both classes.

For supported radios and display classes, see [docs/platform/hardware-targets.md](../platform/hardware-targets.md).

## 3. Layout Goals
The telemetry card layout system must ensure:
- consistent card spacing
- predictable telemetry placement
- stable layout when optional sensors are missing
- strong value readability at glance distance
- layout definitions that can be consumed by rendering code

The layout must favor fixed slots over dynamic reflow.

## 4. Layout Model
The dashboard uses a slot-based card grid.

Each slot has a fixed role, fixed order, and fixed position within the chosen layout mode. Cards are assigned to slots by telemetry type rather than by first-available space.

### 4.1 Primary Grid
The fixed primary grid contains two rows and three columns.

It holds the six highest-priority glanceable telemetry cards:

    Row 1: Battery | Link Quality | Packet Rate
    Row 2: RSSI    | Current      | Satellites

Reference arrangement:

    ┌───────────────┬───────────────┬───────────────┐
    │ Battery       │ Link Quality  │ Packet Rate   │
    │ 16.2 V        │ 100 %         │ 500 Hz        │
    └───────────────┴───────────────┴───────────────┘

    ┌───────────────┬───────────────┬───────────────┐
    │ RSSI          │ Current       │ Satellites    │
    │ -65 dBm       │ 18.4 A        │ 12            │
    └───────────────┴───────────────┴───────────────┘

These six slots must remain fixed even when optional telemetry appears or disappears.

### 4.2 Context Extension Slots
Two additional reserved slots support primary context telemetry that is useful but not required in the fixed two-row grid:
- TX Power
- Flight Mode

These slots should render in a reserved extension area for the active display class.

Recommended ordering:

    Context Row: TX Power | Flight Mode

On taller layouts this may appear as a third row. On tighter layouts it may appear as a compact footer strip. In both cases, the slot order must remain fixed.

### 4.3 Optional Diagnostic Slots
Optional diagnostic cards render only when their sensors are available:
- RSSI1
- RSSI2
- Capacity
- Active Antenna

These cards must use reserved optional slots located after the primary grid and after the context extension slots.


The layout system must remain deterministic: a telemetry metric always appears in the same slot when present.

## 5. Card Dimensions And Spacing
Suggested baseline for the primary 480 x 320 layout:
- card width: 140 px
- card height: 100 px
- horizontal gap: 8-10 px
- vertical gap: 8-10 px
- outer margin: 12 px
- inner padding: 10-12 px

Layout rules:
- all cards in the same row use the same width
- all cards in the same row use the same height
- spacing remains uniform across the grid
- the value area must not be reduced to make room for icons or labels

For 480 x 272 compatibility:
- keep the same column order and slot assignments
- reduce vertical padding and row spacing before reducing width
- compress context or optional rows before altering the primary grid

## 6. Card Internal Structure
Each card contains the following elements:
- icon
- label
- value
- units when applicable
- status color

Reference structure:

    [icon] label
    value
    units

Internal placement rules:
- the icon sits to the left of the label
- the label remains secondary to the value
- the value is the dominant visual element in the card
- units render smaller than the value
- status color should accent the card without reducing readability

## 7. Placement Rules
The layout system must follow these placement rules:
- cards remain aligned in a grid
- values in a row should occupy a consistent visual band
- labels and icons should sit in the upper portion of the card
- the value block should receive the largest clear area inside the card
- card content must not shift when a neighboring optional slot is inactive
- required cards may render an unavailable placeholder when their telemetry source is missing

Primary slot mapping:
- slot P1: Battery
- slot P2: Link Quality
- slot P3: Packet Rate
- slot P4: RSSI
- slot P5: Current
- slot P6: Satellites

Context slot mapping:
- slot C1: TX Power
- slot C2: Flight Mode

Optional slot mapping:
- slot O1: RSSI1
- slot O2: RSSI2
- slot O3: Capacity
- slot O4: Active Antenna

## 8. Optional Card Handling
Optional telemetry must not cause the primary layout to collapse or shift.

Rules:
- primary slots remain visible and fixed whenever telemetry is active
- context slots keep their assigned order even if only one context card is available
- optional cards render only in reserved optional slots
- inactive optional slots should remain empty or hidden in place rather than triggering card reflow
- an entire optional row may be omitted only when every slot in that row is inactive

This preserves predictable card locations and prevents pilots from rescanning the layout when sensors are absent.

## 9. Layout Definition Responsibilities
The layout system must define:
- card positions
- card dimensions
- slot identifiers
- icon placement region
- label placement region
- value placement region
- unit placement region

Rendering code should consume these definitions rather than hardcoding pixel positions inside the widget refresh path.

Example conceptual structure:

```lua
layout = {
  mode = "480x320",
  slots = {
    battery = { id = "P1", x = 12, y = 12, w = 140, h = 100 },
    lq = { id = "P2", x = 160, y = 12, w = 140, h = 100 },
    rate = { id = "P3", x = 308, y = 12, w = 140, h = 100 }
  }
}
```

The exact numbers may differ by layout mode, but slot meaning and ordering must remain stable.

## 10. Design Implications
The layout system should support future growth without forcing a redesign of the primary grid.

Guidance:
- keep the two-row primary grid stable
- add new telemetry through reserved extension or optional slots
- preserve the visual hierarchy defined in [docs/product/telemetry-priority.md](../product/telemetry-priority.md)
- keep card definitions aligned with [docs/telemetry-cards.md](telemetry-cards.md)
- keep layout scaling consistent with [docs/platform/hardware-targets.md](../platform/hardware-targets.md)