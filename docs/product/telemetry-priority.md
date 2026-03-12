# Telemetry Priority Matrix

## Purpose
This document ranks telemetry values by pilot importance for the EdgeTX telemetry dashboard.

The primary use case is pre-flight verification, not continuous in-flight monitoring. During flight, pilots primarily rely on FPV OSD inside goggles.

## Usage Context
The dashboard is mainly used for:
- pre-flight system verification
- link diagnostics
- receiver and telemetry validation
- post-flight inspection

The design objective is to quickly confirm that the aircraft is safe and ready to fly.

## Priority Levels
| Level | Description |
|------|-------------|
| Critical | Must always be visible for pre-flight safety checks |
| Important | Useful system information but not required at all times |
| Secondary | Mainly used for diagnostics and debugging |

## Critical Telemetry
- Battery voltage
- Link Quality (LQ)
- Packet rate

### Why Critical
These values directly affect:
- battery safety
- control link reliability
- radio responsiveness

Abnormal values should block arming until investigated.

## Important Telemetry
- RSSI
- Cell voltage
- Satellite count
- Current draw
- Flight mode
- Armed state

### Why Important
These values provide operational context and system state confirmation, but they are not always urgent.
Cell voltage is especially useful for checking per-cell voltage consistency before flying.

## Secondary Telemetry
- TX power
- Active antenna
- Failsafe state
- Stick position visualization

### Why Secondary
These values are useful for diagnostics, troubleshooting, and tuning, but are not required for normal pre-flight checks.

## Always-Visible Status Indicators
The following values must always be visible in the dashboard layout:
- Battery voltage
- Link Quality (LQ)
- Packet rate

These values should live in the primary status row or primary dashboard area.

## Dashboard Layout Guidance
### Primary Elements
- Battery indicator
- LQ indicator
- Packet rate indicator

### Secondary Elements
- RSSI indicator
- Cell voltage
- Satellite count
- Current draw
- Flight state indicators

### Diagnostic Elements
- TX power
- Antenna
- Stick monitors

## Acceptance Mapping
- Telemetry values are classified into priority levels.
- Critical telemetry is clearly defined.
- Always-visible status indicators are identified.
- Prioritization reflects FPV pilot workflow (pre-flight first).
- Results are ready to guide dashboard UI design.
