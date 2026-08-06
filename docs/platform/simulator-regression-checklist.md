# Companion Simulator Regression Checklist

Reliability & Compatibility plan, Step 11 — "Execute full Companion
simulator regression." This is the release gate: everything Steps 1-10
fixed and unit-tested at the logic level (`lua tests/run.lua`, 92/92
passing as of Step 10) needs one visual pass in the actual EdgeTX
Companion simulator before it ships, because the automated harness
mocks the EdgeTX Lua API — it cannot verify layout, rendering, icon
loading, or that the simulator's real `getRSSI()`/`getValue()`/
`getFieldInfo()` behave the way the mock assumes.

Every test case below states an exact input and an exact expected
result, sourced from the fixtures and thresholds already established in
[compatibility-matrix.md](compatibility-matrix.md) and `tests/spec/`.
Nothing here should require judgment calls — if a result doesn't match,
it's a finding, not a matter of interpretation.

## How to use this checklist

1. Work through it top to bottom in one Companion session per display
   class (two full passes total: 480x272, then 480x320).
2. For each row, set the stated sensor/telemetry values in Companion's
   simulator panel, observe the widget, and mark Pass/Fail.
3. Attach a screenshot (or a one-line written observation, if a
   screenshot isn't practical) for every row marked in the "Screenshot
   required" column.
4. Log any Fail as a P1 (safety/crash/wrong data) or P2 (visual/
   cosmetic) finding in a new row under [Findings log](#findings-log).
5. This checklist is not release-complete until every row passes AND
   the [real-radio smoke test](#real-radio-smoke-test-final-gate) is
   done. A green simulator pass alone is not sufficient — see the
   plan's risk register ("Simulator differs from hardware").

## Prerequisites

- [ ] EdgeTX Companion built against **EdgeTX 2.12 or later** (the
      compatibility matrix's Section 1 floor — TX15 support specifically
      requires 2.12; an older Companion build may not offer that radio
      profile at all).
- [ ] Widget files copied into the simulator's model SD card path at
      `/WIDGETS/FPVDASH/` (or configure Companion to load directly from
      `SCRIPTS/WIDGETS/FPVDASH/` in this repo).
- [ ] A model configured with a telemetry screen in **App Mode**, with
      the FPVDASH widget assigned to a zone.
- [ ] Record the exact Companion version and simulated radio firmware
      version used, here: `______________________`

## 1. Display class × theme × transparency matrix

Compatibility matrix Section 8 profiles:

| Display class | Companion radio profile | Zone height driving `layout.lua`'s footer threshold |
|---|---|---|
| 480×272 | `RadioMaster TX16S` | `< 290` → no footer row |
| 480×320 | `RadioMaster TX15` | `>= 290` → footer row shown |

For **each** display class, run all 8 combinations (2 themes × 4
transparency levels). `darkTheme` is the widget's `BOOL` option;
`transpLvl` is `1`-`4` (Choice) or `0`-`3` (plain numeric), depending on
what the simulated build exposes — see compatibility-matrix.md Section 9
for which convention applies.

| # | Theme | transpLvl (Choice / numeric) | Expected overlay transparency | Pass/Fail | Screenshot required |
|---|---|---|---|---|---|
| 1 | Dark | 1 / 0 | Level 1 (lightest overlay, value 6) | | Yes |
| 2 | Dark | 2 / 1 | Level 2 (value 8) | | Yes |
| 3 | Dark | 3 / 2 | Level 3 (value 10) | | Yes |
| 4 | Dark | 4 / 3 | Level 4 (heaviest overlay, value 12) | | Yes |
| 5 | Light | 1 / 0 | Level 1 | | Yes |
| 6 | Light | 2 / 1 | Level 2 | | Yes |
| 7 | Light | 3 / 2 | Level 3 | | Yes |
| 8 | Light | 4 / 3 | Level 4 | | Yes |

**Check on every row:** text stays legible against the background at
every transparency level in both themes (this is the one thing the unit
tests structurally cannot verify — `tests/spec/main_spec.lua` confirms
the four levels resolve to four distinct numeric values, not that they
look right).

**480×272 only:** confirm no footer row is drawn (zone height < 290).
**480×320 only:** confirm the footer row is drawn and bottom-anchored
(ELRS version bottom-left, EdgeTX version bottom-right — see
`render/footer.lua`).

## 2. Connection detection (Step 7)

Per compatibility-matrix.md Section 7, `connected = getRSSI() > 0 OR
linkQuality > 0 OR txPower > 0 OR packetRate > 0`.

| # | Scenario | Sensors set | Expected | Pass/Fail | Screenshot |
|---|---|---|---|---|---|
| 1 | Healthy ELRS link | RQly=98, RFMD, TPWR all live | Connected, all cards show live values | | |
| 2 | No telemetry at all | Simulator telemetry off / no sensors | Disconnected: link icon shows "off" state, cards show placeholders (`--`, `N/A`), not stale or fabricated values | | Yes |
| 3 | Generic-only telemetry, no ELRS fields | VFAS, Curr, GPS, RSSI live; RQly/TPWR/RFMD never discovered | **Connected** (via `getRSSI()`, not the ELRS-specific fields) — this is the exact Step 7 fix; confirm it visually, not just in the unit test | | Yes |
| 4 | Valid LQ=0 while otherwise connected | RQly=0 (a real, critical reading), other generic sensors live, telemetry still streaming | Connected stays true; LQ card shows critical/red at 0%, not "disconnected" | | Yes |
| 5 | Loss → reconnect | Start connected, kill telemetry, wait, restore telemetry | Widget transitions to disconnected within a couple of frames, then fully restores on reconnect with **no stale intermediate frame** showing old values | | Yes (before/during/after) |

## 3. Battery cell-count boundaries (Step 3 — safety-critical)

Per `tests/spec/battery_spec.lua`. These are the exact cases the
original safety bug (a draining pack misread as a smaller "full" pack)
would have failed.

| # | Scenario | VFAS sequence | Expected | Pass/Fail | Screenshot |
|---|---|---|---|---|---|
| 1 | 6S pack draining | Connect at 25.0V (6S, near-full) → drop to 21.0V over several frames | Stays **6S** throughout; at 21.0V shows ~3.50V/cell, colored critical/warning — never reports "full" | | Yes (at connect and at 21.0V) |
| 2 | 4S pack draining below 13.05V | Connect at 16.8V (4S full) → drop to 13.05V | Stays **4S**; at 13.05V shows ~3.26V/cell, critical — not misread as 3S "full" | | Yes |
| 3 | Exact full-charge LiHV, no round-up | Connect at exactly 8.70V | Reads as **2S**, not 3S | | |
| 4 | Exact full-charge LiHV, no round-up | Connect at exactly 17.40V | Reads as **4S**, not 5S | | |
| 5 | Disconnect/reconnect resets the latch | Connect at 25.0V (6S) → disconnect → reconnect at 8.4V (a different, smaller pack) | New connection reads as **2S**, not pinned to the previous 6S | | |

## 4. RFMD packet-rate decoding (Step 5)

Per compatibility-matrix.md Section 4 and `tests/spec/read_spec.lua`.
Requires the simulator to actually send a CRSF device-info response so
`telemetry/elrs.lua` resolves an ELRS major version — confirm the
footer/RFMD card only starts decoding *after* that exchange completes,
not immediately on connect.

| # | ELRS version | RFMD value | Expected packet rate | Pass/Fail |
|---|---|---|---|---|
| 1 | 3.x | 9 | 500 Hz | |
| 2 | 4.x | 4 | 150 Hz (900MHz range) | |
| 3 | 4.x | 29 | 500 Hz (2.4GHz range) | |
| 4 | 4.x | 101 | 150 Hz (dual-band range) | |
| 5 | 3.x **and** 4.x | 4 | **Different rates** (100Hz on 3.x, 150Hz on 4.x) — confirm the same raw index really does decode differently by version, the exact ambiguity Step 5 fixed | |
| 6 | Either | 0 | Unavailable (`--`/`N/A`), never a rate | |
| 7 | Unknown/undetected | any | Unavailable, never a guess | |

## 5. Sensor alias, valid-zero, and missing-sensor cases (Step 4)

| # | Scenario | Setup | Expected | Pass/Fail |
|---|---|---|---|---|
| 1 | Primary alias missing, secondary present | Discover `RxBt` but not `VFAS` | Battery still reads correctly via the fallback alias | |
| 2 | Sensor genuinely undiscovered | Don't discover `Curr` at all | Current card shows placeholder (`--.-A`), **not** `0.0A` | |
| 3 | Sensor present, genuinely reads zero | `Curr` discovered, reads exactly 0A (idle) | Current card shows `0.0A` as a real value, distinct from case 2 | |
| 4 | RSNR falls back to SNR | Discover `SNR` but not `RSNR` | RSNR card still populates | |
| 5 | No GPS fix | `GPS` sensor not discovered or reports no fix | Satellites card shows `N/A`, regardless of any `Sats` reading present | |

## 6. Timers and footer fallback

| # | Scenario | Expected | Pass/Fail |
|---|---|---|---|
| 1 | All three radio timers running | MM:SS format for each, updating live | |
| 2 | A timer at 0 / not running | Shows `00:00`, not a placeholder | |
| 3 | Footer before ELRS device-info resolves | Shows `ELRS` (bare fallback text), not blank or an error | |
| 4 | Footer after ELRS device-info resolves | Shows the full version string, e.g. `ELRS 4.1.0` | |
| 5 | Footer EdgeTX version | Shows the simulator's actual EdgeTX version string | |

## Real-radio smoke test (final gate)

Per the plan's risk register: **the simulator does not guarantee real
hardware behavior.** This is the release gate that runs *after* every
row above passes, not a substitute for it.

- [ ] Load the widget on one physical 480×272-class radio.
- [ ] Load the widget on one physical 480×320-class radio (if available;
      note in findings if not — this is a coverage gap, not a pass).
- [ ] Bind to a real ELRS receiver, confirm connect/disconnect/reconnect
      matches Section 2 above on real hardware.
- [ ] Confirm no crash, freeze, or corrupted rendering after several
      minutes of live flight-adjacent use (arming, throttle, GPS
      acquisition if applicable).
- [ ] Record radio model, EdgeTX version, and ELRS version actually
      tested: `______________________`

## Findings log

Record every Fail from the tables above. Use the same P1 (safety/
correctness) vs P2 (cosmetic/consistency) severity split the original
review used.

| Finding | Section / row | Severity | Status |
|---|---|---|---|
| _(none logged yet)_ | | | |

## Sign-off

- [ ] Every table above is fully filled in with Pass/Fail and required
      screenshots.
- [ ] No unresolved P1 or P2 finding remains in the findings log.
- [ ] Real-radio smoke test complete.
- [ ] Notion Step 11 task and Implementation Plan updated to Done.
