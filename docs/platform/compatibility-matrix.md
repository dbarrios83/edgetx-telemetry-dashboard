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
two classes this matrix's RFMD/alias rules apply to:

- **480x320** (primary): RadioMaster TX15, TX15 Max, Jumper T15, T15 Pro
- **480x272** (compatible): RadioMaster TX16S, TX16S Mark II, Jumper T16, T18

[layout/layout.lua](../../SCRIPTS/WIDGETS/FPVDASH/layout/layout.lua)
distinguishes the two by zone height (`FOOTER_THRESHOLD = 290`), not by
querying the radio model.

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
`telemetryRead.snapshot(elrsMajorVersion)`.

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
