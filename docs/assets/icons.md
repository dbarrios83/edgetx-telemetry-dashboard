# Icons

## Purpose
This document defines icon asset conventions and runtime usage for the EdgeTX telemetry dashboard.

## Runtime Path
Icon assets are loaded from:

    /SCRIPTS/WIDGETS/FPVDASH/icons/

Repository location:

    SCRIPTS/WIDGETS/FPVDASH/icons/

## Core Icon Assets
Current runtime icon files:
- `battery.png`
- `signal.png`
- `sat.png`
- `antenna.png`
- `current.png`
- `radio.png`
- `link.png`
- `link_off.png`
- `clock.png`
- `drone.png`
- `rfmd.png`

## Usage Notes
- Icons should be loaded once during `create()` and reused.
- Use `link.png` when telemetry is active.
- Use `link_off.png` when telemetry is inactive.
- Keep icon rendering lightweight and consistent in size across cards.

## Related Specs
- [docs/ui/top-bar.md](../ui/top-bar.md)
- [docs/ui/telemetry-cards.md](../ui/telemetry-cards.md)
- [docs/architecture/lua-widget-architecture.md](../architecture/lua-widget-architecture.md)
