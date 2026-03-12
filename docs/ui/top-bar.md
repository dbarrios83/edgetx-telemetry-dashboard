# Top Bar

## 1. Purpose
This document defines the information displayed in the dashboard top bar.

The top bar provides quick-access radio system status information that remains visible regardless of aircraft telemetry state.

It represents radio-side information, not aircraft telemetry.

This document defines content and behavior only. Rendering implementation belongs in the widget code.

## 2. Functional Role
The top bar provides immediate awareness of:
- active model configuration
- radio battery state
- telemetry connection status
- current time and date

These elements allow the pilot to confirm that the radio system and aircraft link are ready before flight.

The top bar must remain visible at all times.

## 3. Top Bar Layout
The top bar occupies a fixed horizontal strip at the top of the dashboard.

Conceptual layout:

    [Model Name]   [Radio Battery]   [Telemetry Status]   [Time / Date]

Example when telemetry is active:

    Nazgul5        8.1 V             link.png             21:34

Example when telemetry is inactive:

    Nazgul5        8.1 V             link_off.png         21:34

The exact pixel placement belongs to the dashboard wireframe and layout definitions.

## 4. Model Name
The top bar displays the currently active radio model name.

Example values:
- `Nazgul5`
- `Atlas LR`
- `Cinewhoop`

Purpose:
- confirm the correct model profile is loaded
- reduce the risk of launching with the wrong radio configuration

Behavior:
- always visible
- truncated when the name exceeds the available width
- stable during operation and must not shift when other top-bar values change

## 5. Radio Battery
The top bar displays the transmitter battery voltage.

Data source:
- radio system battery sensor

Example:

    8.1 V

Purpose:
- ensure the radio battery has sufficient charge
- reduce the risk of transmitter shutdown during operation

Behavior:
- updates when the radio system battery value changes
- always visible
- formatted as a voltage value with units
- must remain readable at glance distance

## 6. Telemetry Status Indicator
The telemetry connection state is represented using icons rather than text.

Icon assets:

    link.png
    link_off.png

Runtime icon path:

    /SCRIPTS/WIDGETS/TELEMETRY/icons/

### 6.1 Telemetry Active
When receiver telemetry is active, the top bar shows:

    link.png

Meaning:
- telemetry connection is established
- aircraft telemetry data is being received

### 6.2 Telemetry Inactive
When receiver telemetry is not detected, the top bar shows:

    link_off.png

Meaning:
- receiver telemetry is unavailable
- the aircraft may be powered off, disconnected, or out of telemetry range

Behavior rules:
- the indicator updates immediately when telemetry state changes
- the icon remains in a fixed position
- the top bar uses the icon instead of textual indicators such as `RX` or `NO RX`
- telemetry status changes must not shift the time, date, or model-name regions

## 7. Time And Date
The top bar displays the current radio system time.

Baseline example:

    21:34

If space allows, the current date may also be displayed.

Example with date:

    21:34
    2026-03-12

Purpose:
- provide a session time reference without leaving the dashboard
- support quick awareness of system time before and after flight

Behavior:
- time updates once per minute
- date updates automatically at midnight
- time remains visible regardless of telemetry availability
- date remains visible when enabled by the selected layout mode

Placement rules:
- positioned at the far right of the top bar
- visually separated from the telemetry indicator
- fixed in place and must not shift when telemetry state changes

## 8. Layout Rules
The top bar layout must follow these rules:
- elements remain horizontally aligned
- spacing remains stable when displayed values change
- the top bar height remains constant across supported display classes
- the model region should receive the most flexible width
- battery, telemetry status, and time/date regions should use fixed or tightly bounded widths
- the time/date region should be right-aligned within the top bar
- top-bar content must not overlap the stick monitor area below it

## 9. Telemetry Independence
The top bar must remain functional even when aircraft telemetry is unavailable.

When telemetry is inactive:
- model name remains visible
- radio battery remains visible
- telemetry indicator shows `link_off.png`
- time continues updating
- date continues updating when enabled

This keeps radio-side state visible even when the dashboard is also showing receiver-telemetry warnings elsewhere.

## 10. Design Implications
The top bar should stay compact, stable, and easy to scan.

Guidance:
- preserve a single consistent order for all top-bar elements
- prioritize readability over decorative styling
- keep the telemetry indicator lightweight and unambiguous
- align top-bar behavior with the always-visible radio-side information defined in [docs/product/use-cases.md](../product/use-cases.md)
- keep placement compatible with the stick monitor and card layout defined in [docs/stick-monitor.md](stick-monitor.md) and [docs/telemetry-layout.md](telemetry-layout.md)

## 11. Acceptance Mapping
This definition establishes:
- top-bar purpose
- displayed elements
- model-name display rules
- radio-battery display behavior
- telemetry status icon behavior
- time and date behavior
- layout and telemetry-independence rules