# EdgeTX Telemetry Dashboard – Copilot Instructions

## Project Purpose

This repository implements a modern telemetry dashboard for EdgeTX FPV transmitters.

The goal is to provide FPV pilots with a **clear, modern, and performant telemetry interface** optimized for radio hardware constraints.

The dashboard displays values such as:

- Battery voltage
- Link Quality (LQ)
- RSSI
- Packet rate
- Satellite count
- Stick positions
- TX power / antenna state

The implementation must prioritize:

- readability
- low clutter
- fast interpretation during flight
- minimal rendering overhead

---

## Target Hardware

The dashboard must run smoothly on:

- RadioMaster TX15
- EdgeTX color screen radios

Target resolution: 480x272

---

# Architecture

The dashboard is implemented as a **Lua widget for EdgeTX**.

Primary entry point:

`SCRIPTS/WIDGETS/TELEMETRY/dashboard.lua`

The widget should follow EdgeTX lifecycle callbacks:

- `create(zone, options)`
- `update(widget, options)`
- `background(widget)`
- `refresh(widget, event, touchState)`

---

## Design principles

1. Rendering logic must be lightweight.
2. Avoid unnecessary allocations inside refresh loops.
3. Separate **telemetry parsing** from **UI rendering**.

Suggested internal modules:

- `telemetry.lua`
- `ui_layout.lua`
- `ui_components.lua`
- `render.lua`
- `icons.lua`

---

# Performance Rules

EdgeTX radios have limited CPU and no GPU acceleration.

Follow these rules:

- Avoid full screen redraws when possible
- Cache layout calculations
- Reuse icon handles instead of loading images repeatedly
- Avoid gradients and complex graphics
- Prefer flat shapes and small PNG icons
- Avoid dynamic memory allocation inside the `refresh` loop

---

# UI Structure

The dashboard layout contains:

### Top bar
- model name
- LQ
- packet rate
- satellites

### Main area
- stick monitor (left and right)

### Bottom cards
- battery
- RSSI
- TX power
- antenna

All UI components should be implemented as reusable render functions.

---

# Icons

Icons are stored in:

`SCRIPTS/WIDGETS/TELEMETRY/icons/`

Runtime icon files are flat in this directory (no subfolders).

Guidelines:

- PNG format
- small size (24px or 32px)
- transparent background
- monochrome if possible

Icons must be loaded once and reused.

---

# Design Artifacts

UX and visual design references live in:

- `docs/architecture.md`
- `docs/ux.md`
- `design/wireframes/`
- `design/mockups/`

If implementing UI components, consult these documents first.

---

# Repository Conventions

Code lives in:

`SCRIPTS/WIDGETS/TELEMETRY/`

Icons:

`SCRIPTS/WIDGETS/TELEMETRY/icons/`

Design files:

`design/`

Documentation:

`docs/`

Examples:

`tests/examples/`

Keep commits focused and avoid unrelated refactors.

---

# AI Agent Guidelines

When generating code:

- Prefer simple Lua constructs
- Avoid introducing external dependencies
- Follow EdgeTX widget lifecycle strictly
- Do not assume a full Lua standard library
- Ensure rendering code is deterministic and allocation-light
- Always keep telemetry parsing separate from rendering logic