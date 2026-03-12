# Dashboard Information Hierarchy

## 1. Purpose
This document defines the visual information hierarchy of the EdgeTX telemetry dashboard.

The hierarchy establishes which information should receive the most visual attention and how a pilot is expected to visually scan the dashboard during pre-flight checks and during operation.

The goal is to ensure that critical flight information is always easier to see than secondary or diagnostic information.

This document defines priority and scanning order only. Layout positioning is defined in [docs/telemetry-layout.md](telemetry-layout.md).

## 2. Dashboard Usage Context
The telemetry dashboard is primarily used for:
- pre-flight system verification
- link diagnostics
- confirming aircraft readiness
- quick status checks during operation

During flight, pilots typically rely on the FPV OSD inside the goggles rather than the radio screen.

Therefore the dashboard must prioritize fast pre-flight readability.

## 3. Information Priority Levels
Dashboard information is organized into three visual priority levels.

| Level | Meaning |
|------|---------|
| Primary | Critical information required before flight |
| Secondary | Operational information useful during flight |
| Diagnostic | Information mainly used for debugging or tuning |

The visual design should reflect these priorities through placement, text emphasis, and restraint.

## 4. Primary Information
Primary information must be immediately visible and readable at glance distance.

Primary elements include:
- Aircraft Battery
- Link Quality
- Packet Rate
- RSSI
- Current
- Satellite Count

These values appear in the primary telemetry grid defined in [docs/telemetry-layout.md](telemetry-layout.md).

Purpose:
- confirm aircraft readiness
- verify radio link stability
- detect abnormal power conditions

## 5. Secondary Information
Secondary information provides context about the aircraft and radio state but is not required to determine immediate flight readiness.

Secondary elements include:
- TX Power
- Flight Mode

These values appear in context extension slots outside the primary grid.

They should remain readable, but should not visually compete with the primary telemetry values.

## 6. Diagnostic Information
Diagnostic information is useful for troubleshooting or advanced analysis but should not distract from critical telemetry.

Diagnostic elements include:
- RSSI1
- RSSI2
- Capacity
- Active Antenna

These values appear only when their sensors are available.

They should be placed in reserved optional diagnostic slots.

## 7. Radio System Information
Radio-side system information appears in the top bar and remains visible regardless of telemetry availability.

Elements include:
- Model Name
- Radio Battery
- Telemetry Status
- Time / Date

Top-bar behavior is defined in [docs/top-bar.md](top-bar.md).

This information is always visible, but it should remain visually lighter and more compact than the primary telemetry grid.

## 8. Stick Monitor Priority
The stick monitor provides radio input feedback and sits above the telemetry card grid.

Its priority is below the primary telemetry values but above optional diagnostics.

Purpose:
- confirm stick movement
- verify control mapping
- detect calibration issues

Stick monitor behavior is defined in [docs/stick-monitor.md](stick-monitor.md).

## 9. Expected Pilot Scan Order
The dashboard should support the following natural scan sequence:

1. Top Bar
2. Primary Telemetry Grid
3. Context Telemetry
4. Diagnostic Telemetry when present

The scan intent within each region is:

1. Top Bar: model confirmation, radio battery, telemetry connection, time/date
2. Primary Telemetry Grid: aircraft battery, link quality, packet rate, RSSI, current, satellites
3. Context Telemetry: TX power, flight mode
4. Diagnostic Telemetry: sensor-specific troubleshooting values

This order ensures the pilot checks the most critical information first.

## 10. Relationship Between Dashboard Regions
The dashboard hierarchy depends on a stable relationship between its regions.

Rules:
- the top bar remains visible at all times as persistent radio-side context
- the stick monitor remains visible below the top bar as a secondary radio-input region
- the primary telemetry grid remains the dominant visual area of the dashboard
- context telemetry extends the primary grid without replacing it
- diagnostic telemetry appears only when available and must not shift primary information

This relationship allows the pilot to build a fast, repeatable scan habit.
This hierarchy should remain stable across dashboard revisions so pilots can rely on a consistent scanning pattern.

## 11. Visual Design Implications
The hierarchy implies the following design rules:
- primary telemetry values should use the largest text size in the dashboard
- numeric telemetry values must remain the dominant visual element within each telemetry card
- icons must not reduce the readability of numeric values
- primary telemetry should receive the strongest visual emphasis
- top-bar content should remain compact and stable
- the stick monitor must remain readable but visually lighter than telemetry cards
- secondary and diagnostic data should not visually compete with the primary grid
- optional diagnostic content should use restrained emphasis so it does not interrupt the main scan path

## 12. Acceptance Mapping
This definition establishes:
- telemetry priority levels
- pilot scan order expectations
- the relationship between top bar, stick monitor, and telemetry regions
- visual priority implications for future UI implementation