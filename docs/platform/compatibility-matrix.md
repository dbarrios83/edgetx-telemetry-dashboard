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

### Current widget table vs. the authoritative tables

[`PACKET_RATE_FROM_RFMD`](../../SCRIPTS/WIDGETS/FPVDASH/telemetry/read.lua#L33-L65)
only matches the real firmware at indexes 1-3 (25/50/100 Hz, which
happen to be identical across the old flat numbering and both tables
above). From index 4 onward it diverges from both the 3.x and 4.x
tables — e.g. widget index 4 says 150 Hz, but 3.x says 100 Hz (8ch) and
4.x 2.4 GHz says 150 Hz only at index 24, not 4. **This table is stale
and is the concrete defect Step 5 needs to replace** with version/band
-aware lookup, using the tables above as source of truth.

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

## 7. Companion simulator verification profiles

Manual/Step 11 regression should use, at minimum:

- **480x272 class:** EdgeTX Companion's `RadioMaster TX16S` profile
- **480x320 class:** EdgeTX Companion's `RadioMaster TX15` profile (verify
  this radio profile is present in the Companion version being used to
  test — TX15 support landing at EdgeTX 2.12, per Section 1, means older
  Companion builds may not include it)

Both should be tested in EdgeTX 2.12 and the current 2.12/3.0 line, per
Section 1.
