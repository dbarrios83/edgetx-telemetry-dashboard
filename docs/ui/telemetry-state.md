# Telemetry State System Design

## 1. Purpose
This document defines the centralized telemetry state system for the EdgeTX telemetry dashboard.

The goal is to standardize how raw telemetry values are evaluated and communicated to the rendering layer.

This design prevents duplicated threshold logic across telemetry cards and ensures consistent UI behavior.

## 2. Separation of Concerns

The widget separates telemetry handling into three distinct layers:

```
telemetry value acquisition
        |
        v
telemetry state evaluation   <-- this document defines this layer
        |
        v
UI rendering
```

The rendering layer must consume telemetry **states**, not raw values.

Threshold evaluation logic must live only in the state evaluation layer.

## 3. Telemetry States

The state system supports the following states:

| State        | Meaning                                             |
|--------------|-----------------------------------------------------|
| OK           | Value is within normal operating range              |
| WARNING      | Value is below preferred minimum but still flyable  |
| LOW          | Value is significantly below normal — land soon     |
| CRITICAL     | Value is unsafe — immediate action required         |
| DISCONNECTED | Telemetry source is unavailable or not connected    |
| UNKNOWN      | Value is present but cannot be evaluated            |

Connection state is handled separately as a boolean evaluation (see section 5.5) and does not produce one of the states above.

These states drive:
- UI color selection (see design-principles.md for color scheme)
- Icon variant selection
- Warning indicators

`UNKNOWN` must render the metric in gray and must not trigger any warning. It must never be treated as `CRITICAL`.

## 4. State Evaluation Model

The state for any telemetry metric is determined by calling the evaluation function with the current value and the metric's threshold table.

Conceptual interface:

```lua
-- Returns one of: "OK", "WARNING", "LOW", "CRITICAL", "UNKNOWN"
telemetryState(value, thresholds)
```

Usage examples:

```lua
batteryState = telemetryState(voltage,     batteryThresholds)
cellState    = telemetryState(cellVoltage, cellThresholds)
satState     = telemetryState(sats,        satelliteThresholds)
linkState    = telemetryState(rqly,        linkThresholds)
```

Connection state is binary and is evaluated separately:

```lua
-- Returns "OK" or "DISCONNECTED"
connectionState(tpwr)
```

Returning `OK` (rather than a separate `CONNECTED` constant) keeps connection state compatible with the same color and icon mapping used by all other metrics.

If the input value is nil or unavailable the evaluator must return `UNKNOWN`.

## 5. Threshold Data Structure

Threshold tables are defined as a map of named boundary values, ordered from highest to lowest:

```lua
batteryThresholds = {
    ok      = 7.9,
    warning = 7.5,
    low     = 7.1,
}
```

The evaluator walks the table top-to-bottom in this fixed order:

1. `CRITICAL` — value is below `low`
2. `LOW`      — value is below `warning`
3. `WARNING`  — value is below `ok`
4. `OK`       — value is at or above `ok`

This explicit evaluation order prevents ambiguous comparisons in the implementation.

## 6. Threshold Definitions

### 6.1 Battery Pack Voltage (2S example)

| Threshold    | State    |
|-------------|----------|
| >= 7.9 V    | OK       |
| >= 7.5 V    | WARNING  |
| >= 7.1 V    | LOW      |
| < 7.1 V     | CRITICAL |

> Note: Pack voltage thresholds depend on cell count. The threshold table must be selected based on the detected cell count.

### 6.2 Battery Voltage Per Cell

Per-cell voltage is derived as:

```
cellVoltage = totalVoltage / cellCount
```

| Threshold      | State    |
|---------------|----------|
| >= 3.9 V/cell  | OK       |
| >= 3.7 V/cell  | WARNING  |
| >= 3.55 V/cell | LOW      |
| < 3.55 V/cell  | CRITICAL |

Per-cell evaluation should be used when cell count is known, as it is cell-count independent and more reliable than pack voltage alone.

### 6.3 Link Quality (RQly / LQ)

| Threshold | State    |
|-----------|----------|
| >= 80 %   | OK       |
| >= 60 %   | WARNING  |
| < 60 %    | CRITICAL |

### 6.4 Satellite Count

| Threshold | State    |
|-----------|----------|
| >= 8      | OK       |
| 6-7       | WARNING  |
| <= 5      | CRITICAL |

### 6.5 Connection State

Connection is a binary state derived from TX power (`tpwr`).

| Condition  | State        |
|------------|--------------|
| tpwr > 0   | CONNECTED    |
| tpwr <= 0  | DISCONNECTED |

When `DISCONNECTED`, aircraft telemetry cards (voltage, LQ, sats) must not display stale values.

## 7. Interface Between Evaluation and Rendering

The rendering layer receives a state value and must not re-evaluate thresholds.

### 7.1 Color Mapping

| State        | Color   |
|--------------|---------|
| OK           | Green   |
| WARNING      | Yellow  |
| LOW          | Orange  |
| CRITICAL     | Red     |
| DISCONNECTED | Gray    |
| UNKNOWN      | Gray    |

### 7.2 Icon Variant Mapping

Some metric icons have multiple variants. The state selects which variant is rendered.

| State        | Example icon selection                 |
|--------------|----------------------------------------|
| OK           | `link.png`                             |
| DISCONNECTED | `link_off.png`                         |
| CRITICAL     | active icon + red color override       |

### 7.3 Expected Widget Data Flow

```
refresh() called
    |
    v
Acquire raw telemetry values
    |
    v
Evaluate each value against thresholds  --> returns states
    |
    v
Pass states to rendering functions
    |
    v
Rendering functions apply color + icon based on state
    |
    v
lcd draw calls
```

The `refresh()` loop must only acquire telemetry values.
Threshold evaluation must occur in the telemetry state layer before rendering.

## 8. Extensibility

Adding a new telemetry metric requires:
1. Defining a threshold table for the metric
2. Calling `telemetryState(value, thresholds)` for that metric
3. Passing the returned state to the relevant card renderer

No changes to the rendering layer are needed to extend threshold logic.

## 9. Acceptance Criteria Coverage

- Telemetry evaluation rules are defined for: battery voltage, per-cell voltage, link quality, satellite count, connection state.
- Thresholds are documented for each metric.
- The state model (`telemetryState`) is reusable across all telemetry cards.
- Rendering layer receives states, not raw values — separation is clearly defined.
