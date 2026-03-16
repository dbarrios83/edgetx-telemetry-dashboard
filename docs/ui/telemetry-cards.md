# Telemetry Cards

## 1. Purpose
This document defines the telemetry cards used by the EdgeTX telemetry dashboard.

Each card represents one telemetry metric and defines:
- telemetry sensor name
- value format
- units
- update behavior
- visibility rules

The card system should remain modular so new telemetry metrics can be added without redesigning the dashboard layout.

## 2. Card Display Rules
All telemetry cards should follow these common rules:
- consistent label placement
- clear value rendering at glance distance
- consistent unit formatting
- immediate updates when telemetry values change
- stable layout when optional sensors are missing

Common card content:
- icon
- label
- value
- units when applicable
- status color

## 3. Telemetry Availability Rules
Telemetry cards must only display live values when receiver telemetry is detected.

When telemetry is not available:
- telemetry cards must not show stale values
- telemetry-driven timers must not update
- the dashboard should show a clear indicator

Required indicator:

`NO RX TELEMETRY`

When telemetry becomes active:
- cards should begin updating automatically
- values should reflect the current telemetry state
- optional cards may appear when their sensors are present

When receiver telemetry is active but an individual sensor is missing:
- the layout should remain stable
- required cards may show an unavailable placeholder
- optional cards may remain hidden if their sensor is not present

## 4. Primary Telemetry Cards

### 4.1 Battery
- Telemetry sensor: `VFAS` or equivalent aircraft pack-voltage sensor
- Label: `Battery`
- Value format: pack voltage with one decimal place; detected cell count displayed below
- Units: `V`
- Example: `16.2 V` / `4S`
- Cell count detection: `cellCount = floor((totalVoltage / 4.2) + 1)` where `4.2 V` is the maximum LiPo cell voltage. This is approximate and assumes LiPo chemistry. Using nominal voltage (3.7 V) can misdetect packs at low state of charge.
- Cell count usage: displayed as battery configuration (e.g. `4S`), used to calculate per-cell voltage, used to select the correct pack voltage threshold table
- Update behavior: update whenever active telemetry changes
- Visibility rules: visible when receiver telemetry is active and a pack-voltage sensor is available
- UI behavior: primary status card for pre-flight battery verification and battery configuration confirmation
- Icon usage: include battery icon

### 4.2 Link Quality
- Telemetry sensor: `LQ`
- Label: `LQ`
- Value format: integer percentage
- Units: `%`
- Example: `100 %`
- Update behavior: update continuously while telemetry is active
- Visibility rules: visible when receiver telemetry is active and LQ is available
- UI behavior: primary indicator of radio link reliability
- Icon usage: include LQ icon

### 4.3 Packet Rate
- Telemetry sensor: `RFMD`
- Label: `Rate`
- Value format: mapped packet-rate text
- Units: `Hz`
- Example: `50 Hz`, `150 Hz`, `250 Hz`, `500 Hz`
- Update behavior: update when RF mode changes
- Visibility rules: visible when receiver telemetry is active and RFMD is available
- UI behavior: confirms active link configuration and should remain easy to read at a glance
- Notes: RFMD is the RF mode index and should be mapped to the active packet rate shown to the pilot

### 4.4 RSSI
- Telemetry sensor: `RSSI`
- Label: `RSSI`
- Value format: signed integer or percentage depending on telemetry source
- Units: `dBm` or `%` depending on receiver and protocol
- Example: `-65 dBm` or `72 %`
- Update behavior: update continuously while telemetry is active
- Visibility rules: visible when receiver telemetry is active and RSSI is available
- UI behavior: supports link diagnostics but should remain secondary to LQ for link health interpretation
- Icon usage: include RSSI icon

### 4.5 Current
- Telemetry sensor: `CUR`
- Label: `Current`
- Value format: one decimal place when needed
- Units: `A`
- Example: `18.4 A`
- Update behavior: update whenever current telemetry changes
- Visibility rules: visible when receiver telemetry is active and current telemetry is available
- UI behavior: helps detect abnormal power draw and monitor aircraft load
- Icon usage: include current icon

### 4.6 Satellite Count
- Telemetry sensor: `SATS`
- Label: `Sats`
- Value format: integer count
- Units: none
- Example: `12`
- Update behavior: update whenever GPS telemetry changes
- Visibility rules: visible only when receiver telemetry is active and GPS satellite telemetry is available
- UI behavior: confirms GPS readiness before flight
- Icon usage: include satellite icon

### 4.7 TX Power
- Telemetry sensor: `TPWR`
- Label: `TX Power`
- Value format: integer power level
- Units: `mW`
- Example: `25 mW`, `100 mW`, `250 mW`
- Update behavior: update when transmitter power changes
- Visibility rules: show when telemetry is active and TX power telemetry is exposed
- UI behavior: confirms active output power and dynamic power adjustments; a value of `0` or absent indicates no connection

### 4.8 Flight Mode
- Telemetry sensor: `FMODE`
- Label: `Mode`
- Value format: text value
- Units: none
- Example: `ACRO`, `ANGLE`, `HORIZON`, `GPS RESCUE`
- Update behavior: update whenever the flight controller reports a new mode
- Visibility rules: show when telemetry is active and a flight-mode sensor is available
- UI behavior: confirms aircraft control mode; useful during pre-flight verification

## 5. Additional Supported Telemetry Cards

### 5.1 RSSI1
- Telemetry sensor: `RSSI1`
- Label: `RSSI1`
- Value format: signed integer or percentage depending on telemetry source
- Units: `dBm` or `%` depending on receiver and protocol
- Example: `-65 dBm` or `72 %`
- Update behavior: update while telemetry is active
- Visibility rules: show only when antenna-specific RSSI telemetry is available
- UI behavior: diagnostic card for diversity receiver analysis

### 5.2 RSSI2
- Telemetry sensor: `RSSI2`
- Label: `RSSI2`
- Value format: signed integer
- Units: `dBm`
- Example: `-68 dBm`
- Update behavior: update while telemetry is active
- Visibility rules: show only when antenna-specific RSSI telemetry is available
- UI behavior: diagnostic card for diversity receiver analysis

### 5.3 Capacity
- Telemetry sensor: `CAP`
- Label: `Capacity`
- Value format: integer
- Units: `mAh`
- Example: `540 mAh`
- Update behavior: update whenever consumed capacity changes
- Visibility rules: show when telemetry is active and capacity telemetry is available
- UI behavior: supports battery usage review during and after flight

### 5.4 Active Antenna
- Telemetry sensor: `ANT`
- Label: `Antenna`
- Value format: integer antenna index
- Units: none
- Example: `1`, `2`
- Update behavior: update when the active antenna changes
- Visibility rules: show only for receivers that expose active antenna telemetry
- UI behavior: diagnostic card used to confirm diversity switching behavior

## 6. Icon Usage
Icons should be used to improve fast recognition without reducing readability.

Cards that should include icons:
- Battery
- Link Quality
- RSSI
- Satellite Count
- Current

Icon rules:
- simple minimal design
- consistent size across all cards
- positioned next to the value or label
- optimized for small screens
- must not reduce legibility of the numeric value

Icon path:

    /SCRIPTS/WIDGETS/FPVDASH/icons/

Cards mainly used for diagnostics may omit icons and use text-only rendering.

## 7. Icon Color States

Cards that use status icons should reflect the telemetry state through color.

| State    | Color  | Meaning                          |
|----------|--------|----------------------------------|
| OK       | Green  | Normal / healthy                          |
| WARNING  | Yellow | Below preferred minimum but still flyable |
| LOW      | Orange | Significantly below normal — land soon    |
| CRITICAL | Red    | Unsafe — immediate action required        |
| UNKNOWN  | Gray   | Telemetry unavailable or missing          |

Icons must update dynamically as telemetry values change.

## 8. Threshold Examples

Threshold evaluation determines the icon color state for each card.

### Battery (2S example)

    >= 7.9 V → OK (green)
    >= 7.5 V → WARNING (yellow)
    >= 7.1 V → LOW (yellow/orange)
    <  7.1 V → CRITICAL (red)

### Satellite Count

    >= 8 → OK (green)
    6-7  → WARNING (yellow)
    <= 5 → CRITICAL (red)

### Connection / Link Quality

    TPWR <= 0 or missing LQ telemetry → no active connection (gray)
    RQly < 60 %                       → CRITICAL (red)
    RQly < 80 %                       → WARNING (yellow)
    otherwise                         → OK (green)

Threshold evaluation is centralized in the telemetry state module.
See [docs/telemetry-state.md](telemetry-state.md) for the full state system design.

## 9. Design Implications
The telemetry card system should support future growth without forcing layout redesign.

Architecture guidance:
- card definitions should be modular
- rendering rules should stay consistent across cards
- missing optional sensors must not break the dashboard structure
- critical cards should remain visually prominent