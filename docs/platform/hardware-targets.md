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

## 5. Large Display Class
Large display class:
- Resolution: 800 x 480 pixels

Known radios in the 800 x 480 class:
- RadioMaster TX16S Mark III

**Status: supported and tested** (Multi-Resolution Layout project). This
class was originally listed here as a future/out-of-scope target (see
[grid-layout-verification-checklist.md](grid-layout-verification-checklist.md),
which predates this and still records 800x480 as explicitly out of scope
at the time it was written), but a later project confirmed and fixed it:
`topBarH` is pinned to EdgeTX's own real system-logo height per width
(45px at 480-wide, 62px at 800-wide -- see
[layout.lua](../../SCRIPTS/WIDGETS/FPVDASH/layout/layout.lua)'s
`menuHeaderHeight()`), and all five dashboard regions render correctly
at this resolution. Covered by
[tests/spec/layout_spec.lua](../../tests/spec/layout_spec.lua) and the
`screen_800x480` test fixture.

## 6. Layout Compatibility Strategy
The dashboard layout strategy is:
- Base layout compatible with 480 x 272
- Extended layout for 480 x 320
- Large-display layout for 800 x 480, using the same region set with
  `topBarH` scaled to that width's real system-logo height

This keeps the dashboard usable across the majority of EdgeTX color radios while allowing progressive enhancement.
