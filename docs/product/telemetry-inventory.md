# Inventory Available Telemetry Values

## Purpose
This document inventories telemetry values available in EdgeTX and ExpressLRS for use by the telemetry dashboard.

## Telemetry Sources
Telemetry values available to the dashboard originate from the radio telemetry system.

Common sources include:

- ExpressLRS telemetry (CRSF protocol)
- Flight controller telemetry forwarded through the receiver
- GPS modules connected to the flight controller

The dashboard reads these values from EdgeTX telemetry sensors.

This helps later when writing Lua telemetry code.

## Telemetry Categories
- Power telemetry
- Radio link telemetry
- GPS telemetry
- Control input data
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

### Cell Voltage
- Description: Average or individual battery cell voltage reported by the flight controller.
- Unit: Volts (V)
- Typical range: 4.2 -> 3.3 V per cell
- Example values: 4.1 V, 3.8 V
- Usefulness for the dashboard: Provides more precise battery health information than pack voltage alone.

### Cell Count
- Description: Number of cells detected in the battery pack.
- Unit: cell count
- Typical range: 1 -> 6
- Example values: 4, 6
- Usefulness for the dashboard: Allows correct interpretation of pack voltage and battery warnings.

### Battery Percentage (Optional)
- Description: Estimated remaining battery capacity.
- Unit: percent (%)
- Typical range: 0 -> 100%
- Example values: 75%, 42%
- Usefulness for the dashboard: Provides a simple high-level battery status indicator.

## Radio Link Telemetry

### Link Quality (LQ)
- Description: Quality metric for packet reception on the control link.
- Unit: Percent (%)
- Typical range: 0 -> 100%
- Example values: 100%, 92%, 68%
- Usefulness for the dashboard: Immediate link reliability indicator for risk awareness.

### RSSI
- Description: Received Signal Strength Indicator representing raw signal strength.
- Note: In modern ExpressLRS systems Link Quality (LQ) is the primary link reliability metric while RSSI is mostly useful for diagnostics.
- Unit: dBm
- Typical range: -120 -> -30 dBm
- Example values: -58 dBm, -74 dBm, -95 dBm
- Usefulness for the dashboard: Signal strength trend monitoring and troubleshooting.

### RSSI dB (Optional for MVP)
- Description: Alternate RSSI representation exposed by some telemetry systems.
- Unit: dB
- Typical range: implementation dependent
- Example values: -58 dB, -74 dB
- Usefulness for the dashboard: Additional signal diagnostics where available.

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

## Control Input Data

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

## Telemetry Data Model (Draft)
The dashboard will eventually consume telemetry values through a normalized data structure.

Example conceptual structure:

```lua
telemetry = {
  power = {
    voltage = 7.52,
    cell_voltage = 3.76,
    current = 12.4
  },

  link = {
    lq = 100,
    rssi = -58,
    packet_rate = 250,
    tx_power = 100,
    antenna = 1
  },

  gps = {
    sats = 14
  },

  control = {
    throttle = 35,
    yaw = -12,
    pitch = 8,
    roll = -4
  },

  flight = {
    armed = false,
    mode = "Acro",
    failsafe = false
  }
}
```

This structure helps future code stay clear and scalable with paths such as `telemetry.link.lq` and `telemetry.power.voltage`.

This structure is not final and may evolve as the dashboard implementation progresses.
