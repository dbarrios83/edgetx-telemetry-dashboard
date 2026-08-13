# Improved Stick Grid — Companion & Hardware Verification Checklist

Improved Stick Grid project, Tasks 7-8 ("Verify calibrated stick pads in
EdgeTX Companion" and "Benchmark stick-grid rendering on available
physical radios"). Phases 1-3 (geometry/constants, background+grid,
round marker, and their automated coverage) are done —
`lua tests/run.lua` is 188/188 passing as of this writing — but the
desktop mock cannot verify what things actually look like or how they
perform on a real renderer, the same limitation
[simulator-regression-checklist.md](simulator-regression-checklist.md)
documents for the rest of the widget. This checklist is that same kind
of gate, scoped to just the stick pads.

Task 9 (docs + project closeout) is blocked on this checklist: its own
acceptance criteria forbid marking anything complete without evidence,
so every row below needs an actual Pass/Fail (and a screenshot where
asked), not an assumption.

**Status: complete as of 2026-08-13** — see the Findings log and each
section's sign-off below for what was actually verified and by what
evidence.

## How to use this checklist

1. Work through Section 1 top to bottom in Companion, one full pass per
   display class (three passes total: 480×272, 480×320, 800×480).
2. For each row, set the stated stick/telemetry inputs, observe both
   pads, and mark Pass/Fail.
3. Attach a screenshot for every row marked "Screenshot required".
4. Log any Fail as a finding under [Findings log](#findings-log) —
   P1 (wrong stick mapping, marker escapes the pad, crash) or P2
   (visual/cosmetic only).
5. Then work through Section 2 on whatever physical hardware is
   actually available. If none is available, say so explicitly in the
   hardware log — do not leave it blank, and do not mark it Pass.
6. This checklist is not complete until every Section 1 row passes and
   Section 2 has either real results or an explicit documented
   residual-risk acceptance for any resolution class that couldn't be
   tested.

## Prerequisites

- [x] EdgeTX Companion built against **EdgeTX 2.12 or later** (the
      compatibility matrix's Section 1 floor).
- [x] Widget files loaded from `SCRIPTS/WIDGETS/FPVDASH/` in this repo
      (or copied to the simulator's `/WIDGETS/FPVDASH/` model path),
      on the `feature/improved-stick-grid` branch.
- [x] A model configured with a telemetry screen in **App Mode**, with
      the FPVDASH widget assigned to a zone, and radio channels mapped
      so `ail`/`ele`/`thr`/`rud` respond to the physical gimbals.
- [x] Simulated/real radio firmware confirmed as **EdgeTX 2.12.2** (visible
      in every screenshot's footer). Exact Companion desktop-app version
      not separately recorded.

## What you're checking against

The confirmed visual spec (full detail in the Notion project page) and
what the code actually implements
([render/sticks.lua](../../SCRIPTS/WIDGETS/FPVDASH/render/sticks.lua)):

| Element | Spec |
|---|---|
| Pad background | Solid very-dark navy fill, full pad |
| Quarter grid | 1px lines at 25%/75% on both axes, dark desaturated blue |
| Center axes | 1px lines at 50% on both axes, muted cyan (brighter than quarter grid) |
| Border | 2px solid white, drawn last of the static layers so it stays crisp |
| Center reference | Small round gray dot, exact pad center, may be covered by a centered marker |
| Live marker | Round, white outer ring over near-black inner fill |
| Marker size | boxSize < 120px → 7px inner / 9px outer; boxSize ≥ 120px → 11px inner / 13px outer — selected from the pad's own size, never from `LCD_W` |

Expected pad size and marker tier per display class (from
`layout/layout.lua`'s real `stickH` output, verified by
`tests/spec/stick_mode_spec.lua`'s multi-resolution tests):

| Display class | Companion radio profile | Expected pad size | Expected marker tier |
|---|---|---|---|
| 480×272 | `RadioMaster TX16S` | 74×74 px | small (7/9 px) |
| 480×320 | `RadioMaster TX15` | 77×77 px | small (7/9 px) |
| 800×480 | `RadioMaster TX16S Mark III` (if available in your Companion build) | ~140×140 px | large (11/13 px) |

If a measured pad size or marker tier doesn't match this table, that's
a finding — either the layout math regressed, or this table is stale
and needs correcting before sign-off.

## 1. Visual verification matrix

For **each** display class above, run every row below (theme × scenario).
`darkTheme` is the widget's `BOOL` option.

**Results as of 2026-08-13 (dbarrios83), Companion, all three display
classes (480×272 / 480×320 / 800×480):**

| # | Scenario | Pass/Fail | Evidence |
|---|---|---|---|
| 1 | Sticks centered, dark theme | **Pass** | Multiple screenshots across the 2026-08-13 session, all three resolutions |
| 2 | Sticks centered, light theme | **Pass** | Confirmed by user; not filed as a separate screenshot per resolution |
| 3-6 | Individual axis extremes (roll/pitch, ±100) | **Pass** (general coverage) | Exercised via normal stick movement during testing, not isolated per value; exact ±100/±100 containment at all 4 corners is additionally proven by 8 automated tests (`sticks_grid_spec.lua`'s marker-containment suite) |
| 7-10 | Diagonal corners | **Pass** (general coverage) | Same as above — not individually screenshotted per corner |
| 11 | Throttle at the bottom | **Pass** | Visible in the 2026-08-13 08:26/08:33/09:19 screenshots (left pad, marker near bottom) |
| 12 | Representative mid-range position | **Pass** | Visible across the session's screenshots (marker at various off-center positions) |
| 13 | Receiver telemetry connected | **Pass** | Every screenshot from this session shows connected telemetry (LQ%, battery, etc.) |
| 14 | Receiver telemetry disconnected | **Not visually re-verified this pass** | Not shown in any 2026-08-13 screenshot; disconnected-state rendering is covered by automated tests (`stick_mode_spec.lua`, `sticks_spec.lua`, `layout_grid_spec.lua` all exercise `connected = false`) |
| 15-18 | Stick Modes 1-4 | **Not individually re-verified visually this pass** | Testing used the radio's configured mode (not swept through all four); correctness across all 4 modes is covered by 12 automated tests (`stick_mode_spec.lua`'s mode-assignment suite) |

Rows 3-10, 12, and 15-18 were not each isolated into their own
screenshot — general stick movement during the session exercised them,
backed by the automated containment/mode-assignment test suite for the
exact numeric guarantees. If a fully isolated manual pass through every
row is wanted later, this table shows exactly which ones still need it.

## 2. Review points (check across every row above, not a separate pass)

- [x] The grid stays visually secondary to the primary telemetry cards
      below it — it should read as calibration detail, not the focal
      point of the screen.
- [x] Quarter lines are visible on inspection but don't look busy or
      dominant at a glance.
- [x] The dark pad fill visibly separates the pad from the theme
      wallpaper/background behind it.
- [x] Center axes and the center reference dot are both readable
      against the fill, in both themes.
- [x] The marker is not so small it's hard to see at 800×480, and not
      so large it looks oversized/heavy at 480-wide.
- [x] The 2px border reads as crisp and intentional, not muddy — check
      it isn't visibly interrupted by the grid lines underneath it.
- [x] No overlap, clipping, or pixel-level asymmetry between the two
      pads (mirror them visually — they should look identical except
      for mirrored stick position).
- [x] All five dashboard regions (top bar, sticks, telemetry grid,
      context row, footer) remain intact and correctly positioned on
      480×272 — confirms the new pad rendering didn't push anything
      else out of place.

Confirmed across the 2026-08-13 session's screenshots (multiple
resolutions and wallpapers, both themes per user confirmation).

## 3. Sign-off (Task 7 acceptance criteria)

- [x] Every Section 1 matrix row is checked and documented — see the
      per-row evidence notes above; rows 3-10/12/15-18 rely on general
      stick-movement coverage plus the automated test suite rather than
      one isolated screenshot per row (documented explicitly, not
      silently assumed).
- [~] Screenshots exist for the core scenarios (centered, throttle-low,
      mid-range, connected) across all three display classes, but not
      one per individual matrix row (e.g. each corner separately) — see
      row-by-row evidence notes above.
- [x] All visual/geometry changes made during this project are
      constants-only or narrowly-scoped fixes in `render/sticks.lua`
      (`STICK_GRID_COLORS` → `lcd.RGB()`, `stickGridCoords`' x50/y50
      centering, gray border-color fallbacks) — see
      `docs/platform/compatibility-matrix.md` Section 12 and the
      findings log below.
- [x] No untracked divergence from the spec table above remains
      unresolved — the color-format and center-alignment bugs found
      during this pass are fixed and confirmed (see Findings log).
- [x] Companion shows no obvious refresh lag while dragging sticks
      through their full range (per user confirmation).

**Task 7 status: accepted as sufficient by the project owner
(dbarrios83, 2026-08-13)**, with the explicitly-documented gap above
(rows 3-10/12/14/15-18 not individually isolated) treated as covered by
the automated test suite (188 tests passing) rather than blocking
further manual passes.

## 4. Physical hardware benchmark (Task 8)

Install the candidate build (this branch) on whatever EdgeTX hardware is
actually available. Prioritize at least one 480×320 device; also test
480×272 and 800×480 hardware if you have it. For each device: move both
sticks rapidly through their full range while telemetry updates, and
compare against the previously released stick renderer if you still
have a build of it handy.

Watch for: input-to-display latency, tearing or incomplete pad redraw,
marker jitter, color inconsistency, or background-fill artifacts.

| Device | EdgeTX version | Theme | Test duration | Outcome | Notes |
|---|---|---|---|---|---|
| RadioMaster TX15 (480×320 class) | 2.12.2 | Dark + light | Ad hoc, during the 2026-08-13 fix/verify session | **Pass** | Rendering (fill, grid, border, marker), stick responsiveness, and telemetry all confirmed working as expected by the device owner; no lag/tearing/artifacts reported |

**Residual risk accepted (2026-08-13, dbarrios83) for 480×272
(RadioMaster TX16S class) and 800×480 (RadioMaster TX16S Mark III
class):** no physical hardware in these two classes is owned by the
project maintainer, so only Companion testing was possible for them
(see Section 1's matrix — both passed there). Companion showed no
refresh-rate regression on any resolution, and the rendering changes are
limited to one fill, six 1px grid rects, four border rects, and two
circles per pad per frame (see `docs/platform/compatibility-matrix.md`
Section 12) — proportionally the same added draw work already confirmed
fine on the TX15. This is accepted as sufficient; a future owner of
either radio class re-testing this is a nice-to-have, not a blocker.

### Task 8 acceptance criteria

- [x] No noticeable input-to-display latency compared with the previous renderer (confirmed on TX15).
- [x] No persistent tearing or incomplete pad redraw (confirmed on TX15).
- [x] Marker motion stays smooth enough for pre-flight control verification (confirmed on TX15).
- [x] Solid background/grid colors render consistently across the tested devices (confirmed on TX15 and in Companion across all three classes).
- [x] Test evidence is recorded above, or an explicit hardware-unavailable risk acceptance is recorded per display class that couldn't be tested (TX15 evidence + explicit risk acceptance for the other two classes, above).

**Task 8 status: accepted as sufficient by the project owner
(dbarrios83, 2026-08-13).**

## Findings log

| # | Severity | Display class | Description | Resolution |
|---|---|---|---|---|
| 1 | P1 | All | Pad background fill and calibrated grid were invisible on real hardware; only the marker rendered. Root cause: `STICK_GRID_COLORS` held raw RGB565 hex literals instead of `lcd.RGB()`-packed values (EdgeTX packs RGB565 into the upper half of a 32-bit flags value — see `docs/platform/compatibility-matrix.md` Section 12). | Fixed: all custom colors now go through `lcd.RGB()`; confirmed rendering correctly on TX15 and in Companion across all three resolutions/themes, 2026-08-13. |
| 2 | P2 | 480×320 (odd pad size) | Cyan center axis was computed with independent percentage rounding (`pctPixel(..., 0.5)`), landing 1px off from the marker/center-reference's `math.floor(w/2)` on odd pad dimensions (e.g. 77px). | Fixed: `stickGridCoords`'s x50/y50 now use `math.floor(length/2)` directly, matching the other center-based geometry exactly. |
| 3 | P2 | N/A (code, not visual) | `resolveStickBorderColor()`'s `gray`/`darkgray`/`lightgray` fallbacks had the same raw-RGB565 defect as Finding 1, undetected because they aren't the default border color. | Fixed alongside Finding 1; regression test added (`tests/spec/sticks_grid_spec.lua`). |

## Next step

**Complete.** Both Task 7 and Task 8 are accepted as sufficient by the
project owner (dbarrios83, 2026-08-13) with the gaps above explicitly
documented rather than silently assumed passed. Task 9 (docs + project
closeout) can now proceed: updating `docs/ui/stick-monitor.md` and the
Notion project's progress tracking/Stage from the results captured here.
