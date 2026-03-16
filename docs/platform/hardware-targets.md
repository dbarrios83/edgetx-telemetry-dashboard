# Hardware Targets

## 1. Purpose
This document defines the display classes and screen resolutions supported by the EdgeTX telemetry dashboard.

It is the source of truth for hardware assumptions used by layout design, UI scaling, telemetry grouping, and Lua rendering strategy.

## 2. Primary Target Display Class
First release target:
- Resolution: 480 x 320 pixels
- Display type: color touchscreen

This class provides enough vertical space for a structured telemetry dashboard while remaining compatible with common EdgeTX color radios.

## 3. Radios Using the Primary Display Class
Known radios in the 480 x 320 class:
- RadioMaster TX15
- RadioMaster TX15 Max
- Jumper T15
- Jumper T15 Pro

These radios use a 3.5-inch IPS touchscreen with 480 x 320 resolution.

## 4. Compatible Display Class
Compatible class:
- Resolution: 480 x 272 pixels

Known radios in the 480 x 272 class:
- RadioMaster TX16S
- RadioMaster TX16S Mark II
- Jumper T16
- Jumper T18

Layouts designed for 480 x 320 should remain compatible with this class by compressing vertical spacing.

## 5. Future Large Displays
Some future radios may provide larger display classes.

Example:
- RadioMaster TX16S Mark III (larger display class)

Large screens should be supported later through an expanded layout mode with additional telemetry panels.

## 6. Layout Compatibility Strategy
The dashboard layout strategy is:
- Base layout compatible with 480 x 272
- Extended layout for 480 x 320
- Future expanded layouts for larger screens

This keeps the dashboard usable across the majority of EdgeTX color radios while allowing progressive enhancement.
