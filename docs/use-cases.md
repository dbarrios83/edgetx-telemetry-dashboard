# Dashboard Use Cases

## 1. Primary Operational Use Case
The EdgeTX Telemetry Dashboard is a persistent aircraft and radio status panel.

It is not intended to replace in-goggle OSD during flight. Instead, it provides a stable, always-available status view before flight, during flight, and after flight.

At a glance, the pilot should understand:
- aircraft battery condition
- radio link health
- packet rate status
- GPS readiness (if GPS is installed)
- radio battery level
- current time
- active model identity
- stick positions
- firmware environment

The dashboard structure should remain consistent across the full session lifecycle, while post-flight telemetry focus is limited to timers and last known GPS location (when available).

## 2. Always-Visible Information

### 2.1 Aircraft Telemetry
- Drone voltage
- Link Quality (LQ)
- Packet rate
- Satellite count (if GPS telemetry is available)

### 2.2 Radio and Session Information
- Model name
- Radio battery
- Current time
- Stick layout and stick monitor

### 2.3 Firmware and Environment Information
- EdgeTX version
- ELRS version

## 3. Conditional Telemetry Behavior
Some information is conditional and should be shown only when the required source exists.

Conditional data:
- Satellite count (when GPS telemetry is available)
- Last known GPS location (when GPS telemetry has reported a valid position)

Missing optional telemetry must not break layout stability. The dashboard must keep a consistent structure even when GPS data is not present.

## 4. Receiver Detection Behavior
Telemetry-based values must only be shown when receiver telemetry is detected. This avoids stale or misleading values.

### 4.1 Receiver Not Detected
When receiver telemetry is not detected:
- Do not display drone voltage
- Do not display Link Quality
- Do not display packet rate
- Do not display satellite count
- Do not run telemetry-based timers

Show a clear status indicator:

`NO RX TELEMETRY`

This indicator remains visible until telemetry becomes active.

### 4.2 Receiver Detected
When receiver telemetry becomes active:
- Display telemetry values automatically
- Start updating link metrics
- Show satellite count if GPS telemetry is present
- Allow telemetry-based timers to run

Hide the `NO RX TELEMETRY` indicator once telemetry is active.

## 5. Session Phase Behavior

### 5.1 Before Flight
Before arming, the pilot uses the dashboard to confirm readiness:
- drone voltage
- link quality
- packet rate
- satellite count (if GPS is installed)
- radio battery
- model name
- stick positions
- firmware environment

### 5.2 During Flight
During flight, the pilot primarily monitors OSD in goggles. The radio dashboard should still present the same core telemetry when available.

Requirements during flight:
- stable layout
- no page switching required
- continued readability at a glance

### 5.3 After Flight
After landing or disarming, the dashboard should prioritize post-flight review data.

Relevant telemetry after flight:
- Timers
- Last known GPS location (if GPS telemetry was available)

## 6. Questions the Dashboard Must Answer
The pilot should be able to answer these questions immediately:
- Is the aircraft battery healthy?
- Is the radio link healthy?
- Is the packet rate correct?
- Do I have GPS lock or enough satellites?
- Which model is active?
- Is the radio battery OK?
- What time is it?
- Are the sticks centered and responding correctly?
- Which EdgeTX version is running?
- Which ELRS version is running?
- Where was the last known aircraft location?

## 7. Design Implications
The dashboard should prioritize persistent visibility over mode-based navigation.

Core implications:
- Essential values remain visible at all times
- Core information does not require page switching
- Layout remains stable throughout the session
- UI supports quick glance reading
- Optional telemetry enriches but does not control layout

## 8. Target Hardware and Screen
This use-case definition applies across supported EdgeTX color display classes.

For display classes, screen resolutions, known radio models, and layout strategy, see:
- `docs/hardware-targets.md`
