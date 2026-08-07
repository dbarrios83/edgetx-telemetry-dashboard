# Grid-Aligned Top Bar and Sticks — Companion Verification Checklist

Grid-Aligned Top Bar and Sticks plan, Task 5 — "Verify grid layouts in
EdgeTX Companion." Tasks 1-4 established the grid contract, refactored
both renderers onto it, and covered cell geometry, containment, and
fallback behavior at the logic level
([tests/spec/primitives_geometry_spec.lua](../../tests/spec/primitives_geometry_spec.lua),
[tests/spec/layout_grid_spec.lua](../../tests/spec/layout_grid_spec.lua),
140/140 passing as of Task 4). What the automated harness cannot verify
is *perceived* visual balance — proportional font metrics, real icon
bitmaps, and actual EdgeTX rendering — because it mocks the EdgeTX Lua
API rather than rendering pixels. This checklist is that one remaining
visual pass, same role as
[simulator-regression-checklist.md](simulator-regression-checklist.md)
played for the Reliability & Compatibility plan.

Every row states an exact input and an exact expected result, sourced
from the confirmed grid spec (sticks 30/40/30 — LQ / Sticks / Receiver
Battery; top bar 10/36/20/16/18 — EdgeTX Logo / Model / TX Battery /
Receiver Connection / Date-Time) and from the tier thresholds already
established in `render/sticks.lua` and `render/topbar.lua`. Nothing here
should require judgment calls beyond "does this look centered" — if a
result doesn't match, it's a finding, not a matter of interpretation.

## How to use this checklist

1. Work through it top to bottom in one Companion session per display
   class (two full passes total: 480×272, then 480×320).
2. For each row, set the stated sensor/telemetry values in Companion's
   simulator panel, observe the top bar and sticks panel, and mark
   Pass/Fail.
3. Attach a screenshot (or a one-line written observation, if a
   screenshot isn't practical) for every row marked in the "Screenshot
   required" column.
4. Log any Fail as a finding in a new row under [Findings log](#findings-log).
   Only bounded, documented optical-spacing adjustments within a
   centered group are in scope for a fix here (per the project's
   Implementation approach, step 5) — a real geometry bug (wrong
   proportions, overlap, content outside its cell) is a regression and
   should be traced back to Tasks 2-3 instead.
5. After any visual adjustment, re-run `lua tests/run.lua` and confirm
   it still passes before marking this checklist done.

## Prerequisites

- [ ] EdgeTX Companion simulator available, with `FPVDASH` widget files
      loaded (either copied to the simulator's SD card path at
      `/WIDGETS/FPVDASH/`, or Companion configured to load directly from
      `SCRIPTS/WIDGETS/FPVDASH/` in this repo).
- [ ] A model configured with a telemetry screen in **App Mode**, with
      the FPVDASH widget assigned full-screen (per README.md's
      Installation Steps — this widget is not designed for a partial
      zone).
- [ ] Record the exact Companion version and simulated radio firmware
      version used, here: `______________________`

## 1. Cell geometry sanity (both display classes, both themes)

Per `layout/layout.lua`'s region computation, both display classes use
the full 480px zone width; only the top bar and sticks-panel heights
differ:

| Display class | Companion radio profile | Top bar bounds (`render/topbar.lua`) | Sticks bounds (`render/sticks.lua`) |
|---|---|---|---|
| 480×320 (TX15-class) | `RadioMaster TX15` | 480×44 | 480×102 |
| 480×272 (TX16S-class) | `RadioMaster TX16S` | 480×38 | 480×87 |

For **each** display class × theme combination (4 total: 320/Dark,
320/Light, 272/Dark, 272/Light), with a healthy connected link (RQly=95,
TPWR live, VFAS=15.2 for a 4S "ok" reading):

| # | Display class | Theme | Expected | Pass/Fail | Screenshot required |
|---|---|---|---|---|---|
| 1 | 480×320 | Dark | Top bar shows 5 implied columns in order: blank logo space (~10%), model name, TX battery, connection, date/time. Sticks panel shows LQ / two stick boxes / RX battery in that order (30/40/30). No column's content overlaps its neighbor, none is clipped at the widget edge. | | Yes |
| 2 | 480×320 | Light | Same as above, light theme. | | Yes |
| 3 | 480×272 | Dark | Same as row 1, compressed height — confirm nothing overlaps vertically at the smaller sticks/top-bar height. | | Yes |
| 4 | 480×272 | Light | Same as row 3, light theme. | | Yes |

**Check on every row:** no visible gap or overlap between adjacent
cells' content groups (the cells themselves are always exactly adjacent
per Task 1's `gridCells` contract — this row is checking that each
cell's *content* stays inside its own cell, not that the cells
themselves tile correctly, which is already unit-tested).

## 2. Sticks panel centering and content variations

All rows connected unless stated otherwise.

| # | Scenario | Sensors set | Expected | Pass/Fail | Screenshot |
|---|---|---|---|---|---|
| 1 | LQ two-digit value | RQly=45 (low tier), TPWR live | LQ icon + "45%" centered together as one group in the left (30%) cell; icon and text vertically aligned on the same middle line | | Yes |
| 2 | LQ three-digit value | RQly=100 (ok tier), TPWR live | LQ icon + "100%" centered together; group shifts slightly vs. row 1 (wider text) but stays fully inside the left cell, not clipped at the cell's right edge | | Yes |
| 3 | RX battery "ok" tier | VFAS=15.2 (4S @ 3.80V/cell) | Battery icon + "3.80V (4S)" centered together in the right (30%) cell | | Yes |
| 4 | RX battery "dead" tier | VFAS=0 after a latch, or a fresh RxBt=0 reading | Dead-battery icon + "0.00V" (with "(NS)" only if cells were already latched) centered together, same as row 3's layout | | Yes |
| 5 | Disconnected | Telemetry off / no sensors | No LQ or RX battery icon/text drawn (both side cells empty); stick boxes still render in the center cell | | Yes |
| 6 | Reconnect | Row 5's state, then restore row 1's sensors | LQ and RX battery groups reappear correctly centered, no stale or misplaced content from the disconnected frame | | |

**Check on rows 1-4:** the stick boxes (center 40% cell) do not shift
position when the side cells' text width changes — the three cells are
independent regardless of content.

## 3. Top bar centering and content variations

| # | Scenario | Sensors / config | Expected | Pass/Fail | Screenshot |
|---|---|---|---|---|---|
| 1 | Short model name | Model name "Apex5", TxBt=8.4V, RQly connected | Model name centered in its (36%) cell; TX battery icon + "8.4V" centered together in its (20%) cell; connection icon centered in its (16%) cell | | Yes |
| 2 | Long model name | Model name "Apex5-LongRangeFreestyleBuild" (or any name clearly wider than the cell) | Name truncates with a trailing "..." and stays fully inside the Model cell — never overlaps the TX Battery cell to its right | | Yes |
| 3 | TX battery low/warning tier | TxBt=6.8V | Warning-colored icon + "6.8V" still centered as one group, same alignment as row 1's healthy reading | | |
| 4 | Receiver disconnected | Telemetry off | Connection cell shows the disconnected icon (or "NO" text fallback), still centered in its own cell; unaffected cells (Model, TX Battery) render normally | | Yes |
| 5 | Date/time over ~1 minute | Let the simulator clock advance past a minute boundary | Time updates each refresh; date and time stay stacked (time above date) and centered as one group in the Date-Time cell — no horizontal jump when the digit count changes (e.g. "9:59" → "10:00") | | |

**Check on every row:** the reserved logo cell (leftmost 10%) never
shows dashboard content — only whatever the EdgeTX telemetry-app layout
itself draws there.

## 4. Regression

- [ ] After any visual adjustment made while working through this
      checklist, re-run `lua tests/run.lua` from the repo root and
      confirm it still reports all tests passing.
- [ ] Confirm no adjustment required changing a cell's percentage weight
      (30/40/30 or 10/36/20/16/18) — those are fixed by the confirmed
      spec; only intra-group spacing constants documented in
      `render/sticks.lua` / `render/topbar.lua` are in scope here.

## Findings log

_None yet._

## Sign-off

- [ ] All rows in Sections 1-3 marked Pass.
- [ ] `lua tests/run.lua` passes after any adjustments made during this
      pass.
- [ ] No unresolved finding remains.
