# EdgeTX Telemetry Dashboard Design Principles

## 1. Purpose
This document defines the core design rules for the EdgeTX telemetry dashboard.
It establishes consistent UI and performance principles to guide design and implementation decisions.

## 2. Design Goals
- readability first
- minimal clutter
- fast interpretation during flight
- minimal rendering overhead

## 3. Readability First
Telemetry must be readable instantly so pilots can make quick decisions without scanning the screen.
Critical telemetry should be immediately visible and legible, including:
- battery voltage
- link quality
- RSSI
- packet rate

## 4. Minimal Clutter
Only telemetry that is relevant during flight should be displayed.
Avoid adding information that competes with critical flight data.

Avoid:
- redundant indicators
- duplicated telemetry
- decorative UI

## 5. Fast Interpretation
Pilots must interpret telemetry state within a fraction of a second.
Visual state cues should be simple, consistent, and easy to recognize.

Example color states:

Green -> healthy  
Yellow -> warning  
Red -> critical

## 6. Minimal Rendering Overhead
EdgeTX hardware is resource constrained, so rendering must stay lightweight and predictable.

Guidelines:
- avoid full screen redraws
- cache layout calculations
- load icons once and reuse them
- avoid gradients
- avoid animations

## 7. Target Hardware
Hardware targets are defined in [docs/platform/hardware-targets.md](../platform/hardware-targets.md).

Design should support:
- Base layout compatibility with 480 x 272
- Extended layout for 480 x 320
- Future expansion for larger displays
