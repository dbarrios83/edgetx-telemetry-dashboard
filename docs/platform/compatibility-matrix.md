# Compatibility Matrix

Reliability & Compatibility plan, Step 2. Records the versions, targets,
protocols, sensor aliases, and fallback behavior FPVDASH promises to
support, so implementation decisions in Steps 3-11 have a documented
baseline instead of an assumed one.

## 1. EdgeTX version support

**Supported: EdgeTX 2.12 and current 2.12/3.0 simulator behavior.**

The Reliability & Compatibility plan's original working assumption was
"2.11+". While drafting this matrix, checking the actual per-radio EdgeTX
support dates ([edgetx.org/supportedradios](https://edgetx.org/supportedradios/))
showed that two of the four radios in the widget's own primary display
class only gained EdgeTX support at 2.12:

| Radio | Display class | EdgeTX support since |
|---|---|---|
| RadioMaster TX15 | 480x320 | **2.12** |
| Jumper T15 | 480x320 | 2.10.1 |
| Jumper T15 Pro | 480x320 | **2.12** |
| RadioMaster TX15 Max | 480x320 | not separately listed; treat as TX15 (2.12) until confirmed |
| RadioMaster TX16S / Mark II | 480x272 | 2.4 |
| Jumper T16 (T16 / T16 Plus / T16 Pro Hall) | 480x272 | 2.4 |
| Jumper T18 (T18 / T18 Lite / T18 Pro) | 480x272 | 2.4 |

A "2.11+" claim would be false for TX15 and T15 Pro users, so the floor
for the primary display class is **2.12**, not 2.11. This is a
correction to the plan's original assumption, not a new decision — it
follows directly from the sourced release data above.

No EdgeTX-version detection exists in the widget today, and none is
planned. Version support here is a documentation and Companion
simulator commitment, not a runtime check.

## 2. Target radios and screen sizes

Full radio list and layout strategy live in
[hardware-targets.md](hardware-targets.md); repeated here only as the
classes this matrix's RFMD/alias rules apply to (RFMD/alias resolution
itself is resolution-independent, so this section doesn't change with
the addition of the third class below):

- **480x320** (primary): RadioMaster TX15, TX15 Max, Jumper T15, T15 Pro
- **480x272** (compatible): RadioMaster TX16S, TX16S Mark II, Jumper T16, T18
- **800x480** (compatible): RadioMaster TX16S Mark III

[layout/layout.lua](../../SCRIPTS/WIDGETS/FPVDASH/layout/layout.lua)
distinguishes zone height by the actual widget zone dimensions passed
in at runtime, not by querying the radio model. (An earlier
`FOOTER_THRESHOLD = 290` height check used to gate footer visibility;
the Multi-Resolution Layout project removed it -- all five regions now
render on every resolution, including 800x480, via `topBarH` pinned to
EdgeTX's real per-width system-logo height. See
[hardware-targets.md](hardware-targets.md) Section 5.)

## 3. Protocol scope: ExpressLRS vs. generic telemetry

**Decision (2026-08-06):** ELRS-only for link-specific diagnostics;
generic sensors are best-effort for any protocol, not a dedicated
first-class use case.

- Link-specific fields (`packetRate`/RFMD, `txPower`/TPWR, ELRS firmware
  version footer) are ExpressLRS-specific. On a non-ELRS setup (or ELRS
  with those sensors not discovered) they render as unavailable — this
  is expected, not a bug, and does not get dedicated non-ELRS test
  fixtures.
- Generic sensors (`VFAS`/battery, `Curr`/current, GPS satellite count,
  RSSI) are protocol-agnostic and are expected to work on any telemetry
  source that exposes them, ELRS or not.

## 4. ExpressLRS RFMD packet-rate semantics, by version and band

This is the part earlier attempts got wrong (see the "Fix RFMD packet
rate resolution" / "Revert RFMD mapping changes" commits) — the RFMD
CRSF telemetry value is the raw
[`expresslrs_RFrates_e`](https://github.com/ExpressLRS/ExpressLRS/blob/master/src/include/common.h)
firmware enum value, and that enum has been reshaped across releases.
Tables below are pulled directly from tagged firmware source, not
inferred, so they can be cited if questioned:

- 3.x (last stable): [`common.h` at tag `3.6.4`](https://github.com/ExpressLRS/ExpressLRS/blob/3.6.4/src/include/common.h)
- 4.x (latest at time of writing): [`common.h` at tag `4.1.0`](https://github.com/ExpressLRS/ExpressLRS/blob/4.1.0/src/include/common.h)

### ELRS 3.x (a single flat table, same indexes regardless of band)

| RFMD | Rate | Mode |
|---|---|---|
| 0 | 4 Hz | LoRa (failsafe/low-rate beacon) |
| 1 | 25 Hz | LoRa |
| 2 | 50 Hz | LoRa |
| 3 | 100 Hz | LoRa |
| 4 | 100 Hz (8ch) | LoRa |
| 5 | 150 Hz | LoRa |
| 6 | 200 Hz | LoRa |
| 7 | 250 Hz | LoRa |
| 8 | 333 Hz (8ch) | LoRa |
| 9 | 500 Hz | LoRa |
| 10 | 250 Hz | FLRC (DVDA) |
| 11 | 500 Hz | FLRC (DVDA) |
| 12 | 500 Hz | FLRC |
| 13 | 1000 Hz | FLRC |
| 14 | 50 Hz | LoRa (DVDA) |
| 15 | 200 Hz (8ch) | LoRa |
| 16 | 500 Hz | FSK 2.4GHz (DVDA) |
| 17 | 1000 Hz | FSK 2.4GHz |
| 18 | 1000 Hz | FSK 900MHz |
| 19 | 1000 Hz (8ch) | FSK 900MHz |

### ELRS 4.x (disjoint index ranges per band; NOT the same table as 3.x)

**900 MHz (0-11):**

| RFMD | Rate | Mode |
|---|---|---|
| 0 | 25 Hz | LoRa |
| 1 | 50 Hz | LoRa |
| 2 | 100 Hz | LoRa |
| 3 | 100 Hz (8ch) | LoRa |
| 4 | 150 Hz | LoRa |
| 5 | 200 Hz | LoRa |
| 6 | 200 Hz (8ch) | LoRa |
| 7 | 250 Hz | LoRa |
| 8 | 333 Hz (8ch) | LoRa |
| 9 | 500 Hz | LoRa |
| 10 | 50 Hz | LoRa (DVDA) |
| 11 | 1000 Hz (8ch) | FSK |

**2.4 GHz (20-36):**

| RFMD | Rate | Mode |
|---|---|---|
| 20 | 25 Hz | LoRa |
| 21 | 50 Hz | LoRa |
| 22 | 100 Hz | LoRa |
| 23 | 100 Hz (8ch) | LoRa |
| 24 | 150 Hz | LoRa |
| 25 | 200 Hz | LoRa |
| 26 | 200 Hz (8ch) | LoRa |
| 27 | 250 Hz | LoRa |
| 28 | 333 Hz (8ch) | LoRa |
| 29 | 500 Hz | LoRa |
| 30 | 250 Hz | FLRC (DVDA) |
| 31 | 500 Hz | FLRC (DVDA) |
| 32 | 500 Hz | FLRC |
| 33 | 1000 Hz | FLRC |
| 34 | 250 Hz | FSK (DVDA) |
| 35 | 500 Hz | FSK (DVDA) |
| 36 | 1000 Hz | FSK |

**Dual-band (100-101):**

| RFMD | Rate | Mode |
|---|---|---|
| 100 | 100 Hz (8ch) | LoRa Dual |
| 101 | 150 Hz | LoRa Dual |

### Why RFMD 0 must never be trusted as "4 Hz"

RFMD `0` means **4 Hz** on ELRS 3.x, but **900 MHz 25 Hz** on ELRS 4.x —
the same raw value means two different things depending on firmware
version, and `0` is also the value commonly seen while telemetry is
lost. The widget's existing decision to always treat RFMD `0` as
unavailable rather than displaying a rate ([read.lua:190-199](../../SCRIPTS/WIDGETS/FPVDASH/telemetry/read.lua#L190-L199))
is correct and should stay.

### Implementation status (Step 5, done 2026-08-06)

`telemetry/read.lua` now carries two separate tables,
[`PACKET_RATE_FROM_RFMD_3X`](../../SCRIPTS/WIDGETS/FPVDASH/telemetry/read.lua)
and
[`PACKET_RATE_FROM_RFMD_4X`](../../SCRIPTS/WIDGETS/FPVDASH/telemetry/read.lua),
transcribed directly from the tables above, and
`resolvePacketRateFromRfmd(rfmd, elrsMajorVersion)` selects between them.
Since the 4.x table's band ranges are disjoint (900/2.4/dual never
overlap), the RFMD value's own range identifies the band — no separate
band signal is needed, only the ELRS major version.

The major version comes from `telemetry/elrs.lua`'s existing CRSF
device-info parsing, now also exposed as structured data
(`state.versionMajor` / `M.getMajorVersion(state)`) rather than only a
display string, and threaded through by `main.lua` into
`telemetryRead.snapshot(session, elrsMajorVersion)`. (The leading
`session` argument was added in the Architecture & Packaging Hardening
project's Task 3, which moved the sensor-ID cache and battery latch off
module scope into a per-widget-instance session from `telemetryRead.init()`
-- see `docs/architecture/lua-widget-architecture.md` Section 8.1.)

An index that falls in neither table (unknown version, or a value in a
band gap like `12`-`19` for 4.x) resolves to unavailable, never a
guess. RFMD `0` stays unavailable regardless of version — a deliberately
conservative policy, since it's also the value commonly seen while
telemetry is lost or not yet established.

The old flat, non-version-aware `PACKET_RATE_FROM_RFMD` table this
section used to describe as stale has been removed entirely.

## 5. Canonical sensor aliases and precedence

From [`FIELD_SENSORS`](../../SCRIPTS/WIDGETS/FPVDASH/telemetry/read.lua#L18-L31).
Aliases are tried in the listed order; the first one `getFieldInfo()`
confirms is discovered on the model wins — no fallback to a later alias
once an earlier one resolves, even if its value is momentarily zero
(zero is a valid reading, not an absence signal; see next section).

| Field | Alias precedence (first discovered wins) | Notes |
|---|---|---|
| battery | `VFAS` > `RxBt` > `Bat` > `BATT` > `A4` | `VFAS`/`RxBt` are CRSF-standard; `A4` is a legacy analog fallback |
| rssi | `1RSS` > `2RSS` > `TRSS` | Deliberately excludes `RSSI` (EdgeTX's internal radio RSSI, not link telemetry) |
| linkQuality | `RQly` > `LQ` > `TQly` | |
| packetRate | `RFMD` | ELRS-only; see Section 4 |
| current | `Curr` > `CUR` | |
| satellites | `Sats` > `SATS` > `SAT` | |
| txPower | `TPWR` > `TxPw` | ELRS-only |
| flightMode | `FM` > `FMODE` | Falls back to `getFlightMode()`, currently broken — see Step 6 |
| rssi1 / rssi2 | `1RSS` / `2RSS` | Per-antenna values, diversity diagnostics |
| capacity | `Capa` > `CAP` | |
| activeAntenna | `ANT` | |

## 6. Fallback policy for unknown protocol/version data

**Unknown or ambiguous inputs render as unavailable/neutral, never as a
guessed value.** This already governs RFMD decoding
(`resolvePacketRateFromRfmd` returns `nil` for unmapped indexes) and
should extend to any future version/band-aware logic in Step 5: an ELRS
firmware version or RF band this widget doesn't recognize must resolve
to "unavailable," not to the nearest table it happens to match.

## 7. Connection detection

**Status: implemented (Step 7, 2026-08-06).**

The widget must not depend solely on ELRS-specific fields to decide
whether telemetry is live — a model exposing only generic sensors
(pack voltage, current, GPS, antenna RSSI) and no LQ/TX power/RFMD
should still be detected as connected.

The primary signal is EdgeTX's own `getRSSI()`. Its first return value
is `0` unless the firmware's internal `TELEMETRY_STREAMING()` flag is
true, for whichever telemetry protocol is actually in use — not just
ELRS/CRSF. Sourced directly from EdgeTX firmware, not inferred:

```c
// radio/src/lua/api_general.cpp, luaGetRSSI (EdgeTX/edgetx)
static int luaGetRSSI(lua_State * L)
{
  if (TELEMETRY_STREAMING())
    lua_pushinteger(L, min((uint8_t)99, TELEMETRY_RSSI()));
  else
    lua_pushinteger(L, 0);
  lua_pushinteger(L, g_model.rfAlarms.warning);
  lua_pushinteger(L, g_model.rfAlarms.critical);
  return 3;
}
```

Note this returns three values (`rssi, alarm_low, alarm_crit`); only the
first is used here, and it is a normalized value capped at 99 — not raw
dBm, and not the same thing as the widget's own `rssi`/`rssi1`/`rssi2`
display fields, which come from the `1RSS`/`2RSS`/`TRSS` sensors and
must not be conflated with this connection-detection signal.

**Rule:** `connected = getRSSI() > 0 OR linkQuality > 0 OR txPower > 0 OR
packetRate > 0`. The ELRS-specific checks are kept as a fallback
alongside `getRSSI()`, not replaced by it, in case `getRSSI()` is ever
unavailable or behaves unexpectedly on a given firmware build —
`getRSSI()` has been documented since EdgeTX 2.2.0, well within the 2.12+
floor from Section 1, so this should rarely matter in practice.

**Correction found during Step 11 simulator testing (2026-08-06):** an
earlier version of this section claimed `getRSSI()` and the LQ sensor
are independent signals, so a real LQ=0 reading would not be confused
with "no telemetry at all." That is **not true for CRSF/ExpressLRS.**
Checking where EdgeTX firmware actually sets `telemetryStreaming` (the
flag `getRSSI()` reads) shows it is driven by the *same* value as the
LQ sensor for CRSF specifically:

```c
// radio/src/telemetry/crossfire.cpp, LINK_ID frame handling
if (i == RX_QUALITY_INDEX) {
  if (value) {
    telemetryData.rssi.set(value);
    telemetryStreaming = TELEMETRY_TIMEOUT10ms;
    telemetryData.telemetryValid |= 1 << module;
  } else {
    if (telemetryData.telemetryValid & (1 << module)) {
      telemetryData.rssi.reset();
      telemetryStreaming = 0;
    }
  }
}
```

So on a real ELRS radio, when LQ genuinely hits 0, `getRSSI()` goes to 0
in the same instant, for the same reason — they are not independent for
this protocol, and the widget correctly shows disconnected in that
state (confirmed via simulator testing, matching a real-radio LQ=0
reading in principle, since this is protocol logic, not simulator-only
behavior). `getRSSI()` still earns its place in the OR-condition for two
things that remain real and confirmed:
- **Non-CRSF protocols.** FrSky S.Port tracks a dedicated `RSSI_ID`
  sensor independently of LQ (`radio/src/telemetry/frsky_sport.cpp`), so
  `getRSSI()` genuinely can stay nonzero there even if a model's LQ-style
  field isn't discovered.
- **The primary Step 7 scenario:** a model exposing generic sensors
  (VFAS/current/GPS) with **no** LQ/TX power/RFMD ever discovered at
  all — confirmed working via simulator testing.

When disconnected, `packetRate`/`available.packetRate` are explicitly
reset so a stale rate never renders; every renderer additionally gates
on `telemetry.connected == true` before drawing any live value, so a
reconnect never has an intermediate frame showing stale data from before
the disconnect.

## 8. Widget and option metadata

**Status: implemented (Step 8, 2026-08-06).**

The original review flagged widget/option names as exceeding a documented
EdgeTX limit. Checking the actual color-LCD firmware source before
acting on that (`radio/src/lua/lua_widget_factory.cpp`'s
`parseOptionDefinitions`, `radio/src/gui/colorlcd/mainview/widget.h`'s
`WidgetOption::name`, and the persistence layer in `topbar.cpp`/
`layout.cpp`) found no hard length limit: option names are read via
`luaL_checkstring` with no truncation, `WidgetOption::name` is a
`const char *`, and persisted widget names use `std::string`. This
appears to not hold for the current EdgeTX 2.12+ color-LCD firmware this
project targets — it may reflect older/monochrome-radio behavior, or
simply wasn't verified against source when the finding was written.

`transpLevel` (11 characters) was still renamed to `transpLvl` (9
characters) as cheap, harmless defensive hygiene matching the original
finding's intent, even without a confirmed hard requirement. Renaming an
*option* name is safe because EdgeTX persists option values positionally
(`WidgetPersistentData.options[i]`, a plain array), not by name.

The widget's own registered `name` ("Telemetry Dashboard", 20
characters) was deliberately left unchanged. Unlike option names, the
widget name **is** used as a persistent lookup key — `topbar.cpp`/
`layout.cpp` store `factory->getName()` into each configured zone, and
matching it back to a factory on load is presumably name-based. Renaming
it would risk breaking every existing user's already-configured
screen (the zone would no longer resolve to this widget) for a length
constraint that could not be confirmed to exist.

**Cross-checked again (2026-08-06, Architecture & Packaging Hardening
project, Task 1):** the current
[luadoc.edgetx.org "Widget Scripts"](https://luadoc.edgetx.org/overview/script-types/widget-scripts)
reference page still states in prose that "The name length must be 10
characters or less." That wording is unchanged despite the firmware-source
finding above. Since `parseOptionDefinitions`/`WidgetOption::name`/the
persistence layer cited above show no enforced truncation or rejection in
EdgeTX 2.12+ color-LCD firmware, this is treated as a documentation/
firmware discrepancy, not a functional constraint — the decision to leave
the widget's registered name unchanged stands. If a future EdgeTX firmware
release starts enforcing this documented limit, `main.lua`'s `name` field
would need revisiting at that time, weighed again against the zone-lookup
breakage risk described above.

The real, confirmed bug in this area was the transparency-value mapping
(Section 9 below), not name length.

## 9. Transparency-value mapping

**Status: implemented (Step 8, 2026-08-06).**

EdgeTX exposes `transpLvl` as one of two option types depending on the
firmware build:

- **Choice/Combo** (`COMBO`/`CHOICE` defined): the settings screen's
  `Choice` control is 0-based internally, but reads/writes the stored
  value via `getUnsignedValue(optIdx) - 1`
  (`radio/src/gui/colorlcd/mainview/widget_settings.cpp`) — so the value
  Lua actually receives is **1-based** (1..4), matching this widget's
  choice labels `"1".."4"`.
- **Plain `VALUE`** (older/other builds without `COMBO`/`CHOICE`):
  declared here with `min=0, max=3`, so it is genuinely **0-based**.

The old code tried to infer which convention applied from the raw
number's range alone (checking `1..4` before `0..3`), which silently
misread the 0-based `VALUE` option through the 1-based interpretation —
level 12 (index 3 in `VALUE` mode) was unreachable, and level 6 was
reachable from two different raw inputs. The fix branches on
`OPTION_COMBO` (already known at load time, no guessing) to select the
correct convention. All four levels are now individually reachable in
each mode; see `tests/spec/main_spec.lua`.

## 10. Companion simulator verification profiles

Manual/Step 11 regression should use, at minimum:

- **480x272 class:** EdgeTX Companion's `RadioMaster TX16S` profile
- **480x320 class:** EdgeTX Companion's `RadioMaster TX15` profile (verify
  this radio profile is present in the Companion version being used to
  test — TX15 support landing at EdgeTX 2.12, per Section 1, means older
  Companion builds may not include it)

Both should be tested in EdgeTX 2.12 and the current 2.12/3.0 line, per
Section 1.

The full, checkable Step 11 test plan — exact inputs and expected
results for every scenario referenced throughout this document — is
[simulator-regression-checklist.md](simulator-regression-checklist.md).

## 11. Circle drawing primitives (`lcd.drawCircle` / `lcd.drawFilledCircle`)

**Status: documented (Improved Stick Grid project, Task 2).**

The calibrated stick-grid design (round center reference, round live
marker) needs `lcd.drawFilledCircle` and, for the center reference's
outline case, `lcd.drawCircle`. Both are part of EdgeTX's color-LCD Lua
drawing API and are available on the **2.12+ floor** this matrix already
establishes in Section 1 — no separate version gate is needed for them
specifically.

**Decision:** `render/sticks.lua` still wraps its circle-drawing calls in
a guarded helper (checks `type(lcd.drawFilledCircle) == "function"`
before calling it, mirroring the existing `drawFilledSquare` fallback to
manual `lcd.drawLine` rows when `lcd.drawFilledRectangle` is
unavailable) rather than calling the primitive unconditionally. This is
defensive consistency with that existing pattern, not evidence the
primitive is actually missing anywhere in the supported 2.12+ range — if
the guard ever activates, the fallback degrades to the previous
square-marker/point rendering rather than erroring.

`tests/mock_edgetx.lua` always provides both primitives (see
`mock_edgetx_circles_spec.lua`), so the desktop test harness alone cannot
exercise the fallback path; that path is reviewed by reading
`render/sticks.lua`'s guard directly, the same way other defensively
guarded EdgeTX API calls in this codebase are.

## 12. Calibrated stick-grid colors were malformed EdgeTX color flags

**Status: root cause confirmed (code review + luadoc.edgetx.org,
2026-08-13) and fix confirmed working on real hardware (2026-08-13,
Improved Stick Grid project).**

**Corrected conclusion — read this first.** The invisible grid/border
seen across every round of real-hardware testing below was caused by
`STICK_GRID_COLORS` in `render/sticks.lua` holding raw RGB565 hex
literals (e.g. `bg = 0x0845`) passed directly as `lcd` draw-function
color arguments. Per
[luadoc.edgetx.org's drawing-flags-and-colors page](https://luadoc.edgetx.org/lua-api-programming/drawing-flags-and-colors),
EdgeTX draw functions expect a 32-bit flags value with the 16-bit RGB565
color packed into the **upper half** (bits 17-32) — "colors in EdgeTX
are not binary compatible with colors in OpenTX," and the docs
explicitly warn that scripts using "hard coded constants instead of
calling `lcd.RGB`... [is] not going to work with EdgeTX." A raw 16-bit
literal lands entirely in the wrong half of that 32-bit value — garbage,
not merely a slightly-wrong shade. `WHITE`/`BLACK`/etc. worked throughout
every round because they're EdgeTX-provided constants already in the
correct packed format; every custom color (bg/quarterGrid/centerAxis/
centerRef/markerInner) was not.

**Fix:** `render/sticks.lua` now produces every custom color via
`lcd.RGB(r, g, b)` (a `rgbColor()` helper, guarded with a named-constant
fallback for a hypothetical build without `lcd.RGB`), never a raw hex
literal. `tests/mock_edgetx.lua` now implements `lcd.RGB()` matching
EdgeTX's real packed format (`rgb565 * 65536`, using multiplication
rather than bitwise ops for Lua 5.1 compatibility), and
`tests/spec/sticks_grid_spec.lua` asserts every `STICK_GRID_COLORS` value
is actually a multiple of 65536 — i.e. that it came from `lcd.RGB()` and
not a hard-coded literal — as a regression guard. Both
`DRAW_PAD_BACKGROUND` and `DRAW_PAD_GRID` are re-enabled; the toggles
themselves are kept in the code (not removed) in case a future
regression needs the same bisection approach.

**Retraction:** the "N `lcd.drawFilledRectangle` calls per pad per
refresh" theory below, developed across rounds 1-4 of hardware testing,
is **disproven**. The border-only round (round 4) happened to be the
first round where a correctly-formatted color (`WHITE`, for the border)
was drawn *without* any malformed-color draw call preceding it in the
same refresh — which reads exactly like "fewer rectangle calls fixes
it," but was actually "no malformed color corrupted anything before this
one drew." The investigation history is kept below for context (this
codebase's convention — see Section 1's own "correction to the plan's
original assumption" — is to correct, not delete, prior reasoning), but
should not be read as current guidance.

---

### Investigation history (superseded by the correction above)

`render/sticks.lua`'s stick-pad border has long used the
`lcd.setColor(CUSTOM_COLOR, color)` + `lcd.drawLine(..., CUSTOM_COLOR)`
indirection (see Section 11's own mention of this pattern) to render
arbitrary RGB565 values via `lcd.drawLine`, which — per the border
code's own long-standing comment — doesn't reliably accept a raw color
value directly on some radios. Before this project, that border draw was
the very first draw call for its pad, and it rendered correctly (see the
pre-project `docs/img/dashboard_overview.png`).

Once the calibrated pad background fill (`lcd.drawFilledRectangle`,
Task 3) was added as the first draw call for each pad, two rounds of
real-hardware testing showed:

1. **First finding:** with the fill added, and the grid's quarter/
   center-axis lines *also* using the `CUSTOM_COLOR` indirection (three
   `lcd.setColor` calls per pad per frame instead of the border's
   original one), both the grid and the border were invisible. The
   initial hypothesis was repeated `lcd.setColor` calls per refresh.
2. **Second finding:** switching the grid lines to pass colors directly
   to `lcd.drawLine` (no `lcd.setColor` at all) did **not** fix it —
   the grid was still invisible, and so was the border, whose own
   `lcd.setColor`/`lcd.drawLine` code was completely unchanged from the
   working pre-project version.

Across both rounds, the one constant that changed was the new
`lcd.drawFilledRectangle` background fill now running *before* every
`lcd.drawLine` call in the pad. The live marker (`lcd.drawFilledCircle`,
direct color, no `lcd.setColor`) rendered correctly throughout both
rounds, as did the fill itself.

**Current best-evidence conclusion:** `lcd.drawLine` does not reliably
render, at least on the hardware that reported this, once it follows an
`lcd.drawFilledRectangle` call earlier in the same widget refresh —
independent of the `CUSTOM_COLOR` indirection, which was a red herring
in the first fix attempt.

**Fix:** `render/sticks.lua` no longer calls `lcd.drawLine` anywhere in
the stick-pad draw path. The border and the calibrated grid's
quarter/center-axis lines are now drawn as `lcd.drawFilledRectangle`
calls (1px-thick for grid lines, `STICK_BORDER_THICKNESS`-thick for the
border) with colors passed directly — the same primitive/argument
combination already proven to work for the pad fill and the marker.
`lcd.setColor`/`CUSTOM_COLOR` are no longer used anywhere in this
renderer's default (non-debug) path.

**Third finding:** the `lcd.drawFilledRectangle`-only version above was
also re-tested on the same hardware and was **still invisible** — same
result as both `lcd.drawLine` attempts. The marker
(`lcd.drawFilledCircle`) kept rendering correctly throughout. So the
constraint is not specific to `lcd.drawLine` after all: on this
hardware, once several `lcd.drawFilledRectangle` calls run in one pad's
refresh, none of them appear to render (including the border, whose
call count didn't change across any of these rounds) — while
`lcd.drawFilledCircle` calls in the same refresh, at any position in the
sequence, keep working.

**Current diagnostic step (2026-08-13, unresolved):** `render/sticks.lua`
now gates the pad background fill and the calibrated grid off entirely
via two local toggles, `DRAW_PAD_BACKGROUND` and `DRAW_PAD_GRID` (both
`false`), leaving only the border (still `lcd.drawFilledRectangle`,
4 calls per pad), the center reference, and the marker (both
`lcd.drawFilledCircle`) in the default render path. This isolates
whether the border — the one thing that reliably rendered before this
project — still renders on its own once the fill/grid calls that used to
precede it are removed. `drawStickPadBackground`/`drawStickGrid` remain
implemented and exposed on `M` (`M.drawStickPadBackground`,
`M.drawStickGrid`) so their logic stays covered by
`tests/spec/sticks_grid_spec.lua` independent of the toggles, ready to
re-enable once a working approach is confirmed.

**Fourth finding (border-only, confirmed working):** with both toggles
off, the border rendered correctly on real hardware — a complete,
crisp white outline around both pads, alongside the center reference and
marker. This confirms the border's 4 `lcd.drawFilledRectangle` calls are
not inherently broken; something about combining many more such calls in
one pad's refresh is what fails.

**Fifth round (grid re-enabled, background still off, 10 rect calls/pad)
was in flight — never got a hardware screenshot back — when code review
identified the actual root cause (malformed color flags, not call
count), documented at the top of this section. That correction is what's
implemented now, not a continuation of this bisection.**

### Current status

**Confirmed working on real hardware (2026-08-13).** With both
`DRAW_PAD_BACKGROUND` and `DRAW_PAD_GRID` re-enabled and colors produced
via `lcd.RGB()`, a fresh screenshot showed the navy pad fill, the full
4×4 grid (quarter lines plus a clearly brighter cyan center axis), the
white border, the gray center reference, and the round marker all
rendering together correctly on both pads — matching the confirmed
visual spec. This closes out the investigation in this section.

Remaining work is routine QA, not further debugging: the full matrix in
`docs/platform/stick-grid-verification-checklist.md` (all three display
classes, both themes, connected/disconnected, corners/extremes, all four
stick modes) still needs to be run before Task 7 is complete, and exact
RGB tuning (the `rgbColor()` 8-bit inputs in `render/sticks.lua`) can
still be adjusted during that pass if any shade looks off — that's
cosmetic tuning now, not a rendering bug.

**Follow-up code review (2026-08-13) caught the same defect in two more
places** that hadn't been exercised by the screenshots above because
they aren't the default: `resolveStickBorderColor()`'s `gray`/
`darkgray`/`lightgray` fallbacks (used only if `GREY`/`DARKGREY`/
`LIGHTGREY` aren't defined by the running build) held the same kind of
raw RGB565 literals (`0x8410`, `0x4208`, `0xC618`) and have been switched
to `rgbColor()` the same way. The debug-only numeric override path
(`STICK_BORDER_COLOR` set to a raw number, e.g. the constant's own
`0xF800` example) still accepts a plain number as-is by design — its
comment now documents that the number must already be an EdgeTX-packed
value (produced via `lcd.RGB()`), not a raw RGB565 literal, rather than
attempting to auto-detect/convert one from the other.
