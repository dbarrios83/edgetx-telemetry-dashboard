# edgetx-telemetry-dashboard
A modern telemetry dashboard widget for EdgeTX colour screen radios.

# EdgeTX Widgets Installation Guide

This guide explains how to install and configure the `FPVDASH` widget from this repository on an EdgeTX-compatible transmitter.

![Dashboard Overview](docs/img/dashboard_overview.png)

## Prerequisites

1. EdgeTX firmware installed on your radio.
2. A valid EdgeTX SD card contents pack for your firmware version.
3. A model with telemetry sensors discovered (recommended before final widget setup).
4. Supported target radios include colour-screen EdgeTX radios (for example RadioMaster TX15).

## Installation Steps

### 1. Download the Widget Files
1. Clone or download this repository.
2. Use the `SCRIPTS/WIDGETS/FPVDASH` folder from this project.

### 2. Copy Files to the SD Card
1. Connect the radio to your computer with USB.
2. On the radio, select `USB Storage (SD)`.
3. Open the mounted SD card and go to `/WIDGETS/`.
4. Copy the `FPVDASH` folder (from `SCRIPTS/WIDGETS/FPVDASH` in this repo) into `/WIDGETS/`.
5. Confirm the final runtime path exists:
	 `/WIDGETS/FPVDASH/`

### 3. Bind and Discover Sensors
1. Power on radio and receiver.
2. Open **Model Settings** -> **Telemetry**.
3. Select **Discover new sensors** and wait for completion.
4. Optionally select **Stop discovery** and then **Delete all sensors / Rediscover** if sensor mapping looks stale.

### 4. Load the Widget on the Transmitter
1. Open the model display screen where you want the dashboard.
2. Enter widget layout setup (long press `PAGE` on most radios).
3. Select the telemetry screen and set it to `App Mode`.
4. Select a widget zone and choose `Telemetry Dashboard` (FPVDASH).

![App Mode Setup](docs/img/app_mode.png)

### 5. Configure Widget Options
The widget currently provides these options:
1. `darkTheme` (`BOOL`):
	 `On` = dark mode, `Off` = light mode.
2. `transpLevel` (`COMBO` where supported):
	 Controls section overlay transparency.

![Widget Settings](docs/img/widget_setting.png)

### 6. Test the Widget
1. Exit setup screens.
2. Verify top bar, sticks, context telemetry, timers, and footer render correctly.
3. Check live updates for LQ, RSSI, packet rate, battery, and satellite status.

## Telemetry Screen Setup (App Mode Required)

`FPVDASH` must be loaded on a telemetry screen configured in `App Mode`.
If the screen is not in `App Mode`, the widget may not load or may not render correctly.

## Widget Overview

`FPVDASH` is a full dashboard widget that includes:
- Model name and TX battery (top bar)
- Link status and key telemetry indicators
- Stick monitor
- Context telemetry grid (current, power, RF mode/packet rate, RSSI, satellites, antenna, flight mode)
- Timers row
- Footer with ELRS label and EdgeTX version

## Troubleshooting

- Widget not visible:
	Confirm files are under `/WIDGETS/FPVDASH/` and `main.lua` exists.
- Missing telemetry values:
	Re-run **Discover new sensors** in model telemetry settings.
- Stale values after switching drones:
	Use **Reset telemetry** from the model telemetry page.
- Version text or icons not updating:
	Power-cycle the radio after replacing widget files.

## Uninstallation

1. Open SD card contents.
2. Remove folder: `/WIDGETS/FPVDASH/`.

## Project Structure

```text
edgetx-telemetry-dashboard/
	.github/
		copilot-instructions.md
	LICENSE
	README.md
	SCRIPTS/
		WIDGETS/
			FPVDASH/
				main.lua
				layout/
					layout.lua
					slots.lua
				render/
					topbar.lua
					sticks.lua
					context.lua
					timers.lua
					footer.lua
					cards.lua
				telemetry/
					read.lua
					state.lua
				icons/
					antenna.png
					battery.png
					clock.png
					current.png
					drone.png
					link.png
					link_off.png
					radio.png
					rfmd.png
					rfmd-b.png
					sat.png
					signal.png
					battery/
						battery-dead.png
						battery-full.png
						battery-low.png
						battery-ok.png
						battery-warn.png
					link/
						connection-dead.png
						connection-low.png
						connection-ok.png
						connection-warn.png
					dark/
						*.png
					light/
						*.png
	docs/
		architecture/
			architecture.md
			lua-widget-architecture.md
			rendering-pipeline.md
			telemetry-module.md
			ui-components-module.md
		assets/
			icons.md
		implementation/
			implementation-notes.md
		platform/
			edgetx-api-cheatsheet.md
			hardware-targets.md
		product/
			design-principles.md
			telemetry-inventory.md
			telemetry-priority.md
			use-cases.md
			ux.md
		ui/
			dashboard-information-hierarchy.md
			dashboard-wireframe.md
			stick-monitor.md
			telemetry-cards.md
			telemetry-layout.md
			telemetry-state.md
			top-bar.md
	design/
		wireframes/
		mockups/
	tests/
		examples/
```

## Additional Resources

- EdgeTX Manual: https://manual.edgetx.org
- EdgeTX Website: https://www.edgetx.org/
- EdgeTX GitHub: https://github.com/EdgeTX