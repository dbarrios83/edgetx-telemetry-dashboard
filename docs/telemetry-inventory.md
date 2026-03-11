# Inventory Available Telemetry Values

## Purpose
This document inventories telemetry values available in EdgeTX and ExpressLRS for use by the telemetry dashboard.

## Telemetry Categories
- Power telemetry
- Radio link telemetry
- GPS telemetry
- Control input telemetry
- System telemetry
- Flight telemetry

## Power Telemetry

### Battery Voltage
- Description: Main pack voltage reported by the radio telemetry system.
- Unit: Volts (V)
- Typical ranges for battery packs:
  - 1S: 4.2 -> 3.3 V
  - 2S: 8.4 -> 6.6 V
  - 3S: 12.6 -> 9.9 V
  - 4S: 16.8 -> 13.2 V
  - 5S: 21.0 -> 16.5 V
  - 6S: 25.2 -> 19.8 V
- Example value: 7.52 V
- Usefulness for the dashboard: Primary power health indicator used for warnings and landing decisions.
- Importance: Critical telemetry.

## Radio Link Telemetry

### Link Quality (LQ)
- Description: Quality metric for packet reception on the control link.
- Unit: Percent (%)
- Typical range: 0 -> 100%
- Example values: 100%, 92%, 68%
- Usefulness for the dashboard: Immediate link reliability indicator for risk awareness.

### RSSI
- Description: Received Signal Strength Indicator for the control link.
- Unit: dBm
- Typical range: -120 -> -30 dBm
- Example values: -58 dBm, -74 dBm, -95 dBm
- Usefulness for the dashboard: Signal strength trend monitoring and troubleshooting.

### Packet Rate
- Description: Current ExpressLRS packet update frequency.
- Unit: Hz
- Typical range: 25 / 50 / 100 / 250 / 500 Hz
- Example values: 250 Hz, 500 Hz
- Usefulness for the dashboard: Confirms active link profile and responsiveness.

### TX Power
- Description: Active transmitter output power level.
- Unit: mW
- Typical range: 25 / 100 / 250 / 500 / 1000 mW
- Example values: 100 mW, 250 mW
- Usefulness for the dashboard: Helps monitor link strategy and power consumption trade-offs.

### Active Antenna
- Description: Currently active antenna index for diversity systems.
- Unit: Antenna index
- Typical range: 1 or 2
- Example values: 1, 2
- Usefulness for the dashboard: Useful for diagnostics and link troubleshooting.

## GPS Telemetry

### Number of Satellites
- Description: Count of satellites currently used or tracked for position solution.
- Unit: satellites
- Typical range: 0 -> 20 satellites
- Example values: 0, 7, 14
- Usefulness for the dashboard: Indicates GPS availability and navigation confidence.

## Control Input Telemetry

### Stick Positions
- Description: Normalized control input positions from the radio sticks.
- Values: Throttle, Yaw, Pitch, Roll
- Unit: normalized stick value
- Typical range: -100 -> 100
- Example values: Throttle 35, Yaw -12, Pitch 8, Roll -4
- Usefulness for the dashboard: Supports pilot orientation, training, and input diagnostics.

## System Telemetry

### Current Draw
- Description: Real-time electrical current consumption.
- Unit: Amps (A)
- Typical range: 0 -> 100 A
- Example values: 4.8 A, 32.4 A
- Usefulness for the dashboard: Helps estimate power usage and battery stress.

## Flight Telemetry

### Flight State Indicators
- Armed state: Indicates whether the vehicle is armed and motors can spin.
- Flight mode: Indicates active control mode (for example: Angle, Horizon, Acro).
- Failsafe status: Indicates if failsafe is active or has been triggered.
- Flight timer: Indicates elapsed time since arming or takeoff.

These values are useful for status indicators in the dashboard because they give instant context for pilot intent, safety status, and mission progress.

## Telemetry Importance Summary

### Critical telemetry
- Battery voltage
- Link Quality
- RSSI
- Packet rate

### Secondary telemetry
- satellites
- TX power
- antenna
- current draw
- flight state indicators
