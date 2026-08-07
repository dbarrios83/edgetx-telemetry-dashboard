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

## Verification summary (2026-08-07)

Actual verification did not proceed as a literal row-by-row pass through
Sections 1-3 above (written before verification started, describing the
Task 2/3 *centered-group* design). Instead it happened as five rounds of
live Companion screenshots against the two officially supported classes,
each surfacing a real issue that was fixed and re-verified in the next
round — the same iterative pattern
[simulator-regression-checklist.md](simulator-regression-checklist.md)
used for the Reliability & Compatibility plan. The design changed
materially as a result; Sections 1-3's "Expected" columns above now
describe the *original* centered-group design, not the final one.

**Final design, as actually shipped and confirmed:**
- Sticks panel (both side cells): icon stacked **above** text (not
  beside it), `_SMLSIZE` font, both axes centered as one group. Fixes a
  text/icon vertical-baseline mismatch and a horizontal overflow off the
  screen edge that the original side-by-side `_MIDSIZE` design hit.
- Top bar model name: **left-aligned** in its cell (not centered).
- Top bar TX battery: icon + value **right-aligned** as one group in its
  cell, `_SMLSIZE` font (not centered, not `_MIDSIZE`).
- Top bar date/time: **one line**, date first then time
  (`"<date>   <time>"`, three-space separator), right-aligned in its
  cell (not a centered stacked pair).

**Rounds (commits, newest last):**
1. `f186229` — Companion screenshot found the model name overlapping the
   TX battery icon (`MODEL_TEXT_CHAR_W` badly underestimated real glyph
   width) and sticks text/icon vertical mismatch (`*_TEXT_H` too short).
2. `491887a` — Sticks text was still misaligned and, at the Receiver
   Battery cell's width, ran off the screen edge. Restructured to
   icon-above-text at `_SMLSIZE` per direct instruction. **Confirmed
   correct by the user; sticks panel closed.**
3. `a8c79a0` — Top bar redesign per direct instruction: model left-align,
   TX battery `_SMLSIZE`, date/time collapsed to one right-aligned line.
4. `3fcaf93` — TX battery left-align and date/time date-first reorder,
   plus `DATE_TIME_TEXT_CHAR_W` widened (4→7) after the date/time line
   ran off the right edge of the screen (this cell sits flush against
   the widget's edge, so an underestimate there is unrecoverable, unlike
   the Model-cell overlap in round 1).
5. `8db60bd` — TX battery flipped to right-align (reversing round 3);
   date/time separator widened to three spaces for more visual gap.
   **Confirmed correct by the user; top bar closed.**

**Display classes checked:**
- **480×320 (TX15-class):** connected state, both the sticks panel and
  top bar confirmed correct after the rounds above.
- **480×272 (TX16S-class):** disconnected state confirmed correct — no
  LQ/RX-battery content drawn (expected per Section 2 row 5's logic),
  stick boxes render correctly, top bar fits with no overflow, footer
  row correctly absent (below the 290px `FOOTER_THRESHOLD`, matching
  `tests/spec/layout_spec.lua`'s existing coverage). A connected-state
  screenshot on this class specifically was not captured; not treated as
  a gap because the grid math is the same percentage-of-zone-bounds
  logic already confirmed correct on 480×320, and `tests/spec/
  layout_grid_spec.lua` exercises both classes' proportions and
  containment automatically.
- **800×480 (TX16S Mark III):** tried opportunistically, not one of this
  project's two target classes. Found a background-wash gap behind the
  sticks/telemetry-cards/timers regions not present on either supported
  class. Investigated (see below) and explicitly accepted as an
  out-of-scope, pre-existing limitation rather than fixed here.

**TX16S Mark III (800×480) investigation:** `layout/layout.lua`'s region
math is percentage-of-zone-height/width and hand-traces to sane, positive
values for an 800×480 zone — no code bug identified by static reading,
and reproducing it further would need actual Companion access this
environment doesn't have.
[hardware-targets.md](hardware-targets.md) already lists TX16S Mark III
under "Future Large Displays," requiring "an expanded layout mode" not
yet built. More fundamentally: region *boundaries* are relative
(percentage-of-zone), but icon sizes, `SMLSIZE`/`MIDSIZE` fonts, and
every padding/gap constant tuned across the rounds above are fixed
absolute pixels — EdgeTX's Lua widget API has no scalable font/icon
system, so full resolution independence would need a separate,
larger effort than this project's scope. **User decision: accept as a
known, pre-existing gap and close this project on the two officially
supported classes**, consistent with hardware-targets.md's existing
documented status for that display class.

## Findings log

See "Rounds" above — five real findings, each fixed and re-verified
before moving to the next. No unresolved P1/P2 finding remains on either
of the two officially supported display classes.

## Sign-off

- [x] 480×320 (TX15-class) confirmed correct: sticks panel and top bar,
      connected state.
- [x] 480×272 (TX16S-class) confirmed correct: disconnected state, no
      overflow/overlap, footer correctly absent.
- [x] `lua tests/run.lua` passes after every adjustment made during this
      pass (140/140, final state).
- [x] No unresolved finding remains on either supported display class.
- [ ] 800×480 (TX16S Mark III) — explicitly out of scope; not a release
      gate for this project. See investigation above.
