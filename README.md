# EdgeTX Telemetry Dashboard

A modern telemetry dashboard for EdgeTX radios designed for FPV pilots.

Goals:
- Improve telemetry readability
- Provide a clean dashboard UI
- Maintain high performance on EdgeTX hardware

Features (planned):
- Battery telemetry panel
- Link quality indicators
- Satellite count display
- Stick monitor
- Modern icon pack
- Dark theme UI

Status:
- Design documentation completed
- Next stage: implementation (EPIC 6)

## Repository Structure

```text
edgetx-telemetry-dashboard
|
+- SCRIPTS/
|  +- WIDGETS/
|     +- FPVDASH/
|        +- main.lua
|        +- layout/
|        |  +- layout.lua
|        |  +- slots.lua
|        +- render/
|        |  +- topbar.lua
|        |  +- sticks.lua
|        |  +- cards.lua
|        +- telemetry/
|        |  +- read.lua
|        |  +- state.lua
|        +- icons/
|           +- battery.png
|           +- signal.png
|           +- sat.png
|           +- antenna.png
|           +- current.png
|           +- radio.png
|           +- link.png
|           +- link_off.png
|           +- clock.png
|           +- drone.png
|           +- rfmd.png
|
+- design/
|  +- wireframes/
|  +- mockups/
|
+- docs/
|  +- architecture.md
|  +- ux.md
|
+- tests/
|  +- examples/
+- README.md
+- LICENSE
```

## Deployment

This repository mirrors the EdgeTX SD card runtime layout.

Copy the `SCRIPTS` folder directly to the EdgeTX SD card.

Resulting SD card structure:

```text
/SCRIPTS/WIDGETS/FPVDASH/
	main.lua
	layout/
		layout.lua
		slots.lua
	render/
		topbar.lua
		sticks.lua
		cards.lua
	telemetry/
		read.lua
		state.lua
	icons/
		battery.png
		signal.png
		sat.png
		antenna.png
		current.png
		radio.png
		link.png
		link_off.png
		clock.png
		drone.png
		rfmd.png
```

## Next Milestones

- Implement telemetry field readers and normalization.
- Build status card renderer for battery, satellites, LQ, and RSSI.
- Add test coverage for formatter and mapping logic.