# edgetx-telemetry-dashboard

EdgeTX telemetry dashboard project scaffold for FPV radio widgets.

## Repository Structure

```text
edgetx-telemetry-dashboard
|
+- lua/
|  +- widgets/
|     +- dashboard/
|        +- dashboard.lua
|
+- icons/
|  +- battery/
|  +- satellites/
|  +- lq/
|  +- rssi/
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
+- examples/
+- README.md
+- LICENSE
```

## Next Milestones

- Implement telemetry field readers and normalization.
- Build status card renderer for battery, satellites, LQ, and RSSI.
- Add test coverage for formatter and mapping logic.