-- EdgeTX Lua API mock layer for host-side testing.
--
-- The production widget (SCRIPTS/WIDGETS/FPVDASH) reads EdgeTX API
-- functions as globals (getFieldInfo, getValue, getFlightMode, getTime,
-- lcd.*, Bitmap.open, crossfireTelemetryPush/Pop, loadScript) because
-- that is how the real EdgeTX Lua runtime exposes them. This module
-- installs stand-ins for those globals on the desktop Lua interpreter
-- so widget modules can be loaded and exercised unmodified.
--
-- install(fixture) replaces the relevant globals; uninstall() removes
-- them again so state does not leak between spec files.

local M = {}

-- table.unpack was introduced in Lua 5.2; Lua 5.1 only has the global
-- `unpack`. This mock must run on any of 5.1-5.4 (see README.md's
-- "Running Tests" section), so resolve whichever one actually exists.
local unpack = table.unpack or unpack

local installedKeys = {}

-- fixture.sensors: { [sensorName] = { id = <number, optional>, value = <any> } }
-- fixture.flightMode: nil | value | { value1, value2, ... } (for multi-return getFlightMode)
-- fixture.time: starting tick count for getTime()
-- fixture.crsfIncoming: { { command = <num>, data = {...} }, ... } queue for crossfireTelemetryPop()
-- fixture.bitmaps: { [path] = false } to simulate a missing icon file at that path
-- fixture.rssiStream: value getRSSI()'s first return should report (0 or
--   nil = EdgeTX's TELEMETRY_STREAMING() is false, i.e. no telemetry of
--   any protocol is currently arriving; see radio/src/lua/api_general.cpp)
function M.install(fixture)
  fixture = fixture or {}
  -- Intentionally the same table the caller passed in (not a copy): tests
  -- can mutate fixture.sensors after install() (e.g. to simulate a sensor
  -- being discovered later) and getFieldInfo/getValue will see the change
  -- on their next call.
  local sensors = fixture.sensors or {}

  local nextId = 1
  for _, def in pairs(sensors) do
    if def.id == nil then
      def.id = nextId
      nextId = nextId + 1
    end
  end

  local function setGlobal(key, value)
    installedKeys[key] = true
    _G[key] = value
  end

  -- getFieldInfo only returns an entry for sensors the fixture declares as
  -- discovered. Anything else must behave as "not present in this model".
  setGlobal("getFieldInfo", function(name)
    local def = sensors[name]
    if not def then
      return nil
    end
    if def.id == nil then
      def.id = nextId
      nextId = nextId + 1
    end
    return { id = def.id, name = name, desc = def.desc or "" }
  end)

  -- Real EdgeTX getValue() accepts either a resolved numeric source ID or a
  -- raw sensor name string, and returns 0 for a name it does not recognize
  -- (it never returns nil for an unknown *name*). Reproducing that 0-for-
  -- unknown-name behavior here is what lets tests catch code paths that
  -- call getValue(name) directly instead of resolving through getFieldInfo.
  setGlobal("getValue", function(idOrName)
    if type(idOrName) == "number" then
      for _, def in pairs(sensors) do
        if def.id == idOrName then
          return def.value
        end
      end
      return nil
    end

    local def = sensors[idOrName]
    if def then
      return def.value
    end

    return 0
  end)

  -- Real getRSSI() returns 3 values: rssi (0 if no link), alarm_low,
  -- alarm_crit. Only the first is meaningful to production code here.
  setGlobal("getRSSI", function()
    return fixture.rssiStream or 0, 45, 42
  end)

  -- getStickMode() (1-4) is present from this project's 2.12 floor
  -- onward (confirmed against the tagged v2.12.0/v2.12.1 source, despite
  -- its own doc comment saying "Introduced in 3.0"), but only install it
  -- when the fixture opts in, so a fixture that omits `stickMode` can
  -- still exercise production code's `type(getStickMode) == "function"`
  -- guard -- e.g. for firmware that doesn't define the global at all,
  -- rather than "defines it but it errors".
  if fixture.stickMode ~= nil then
    setGlobal("getStickMode", function()
      return fixture.stickMode
    end)
  end

  -- fixture.dateTime: table like { hour=14, min=5, day=3, mon=8 }, or nil
  -- to simulate getDateTime() being unavailable.
  setGlobal("getDateTime", function()
    return fixture.dateTime
  end)

  -- fixture.modelName: string returned by model.getInfo().name.
  setGlobal("model", {
    getInfo = function()
      return { name = fixture.modelName or "" }
    end,
  })

  setGlobal("getFlightMode", function()
    local fm = fixture.flightMode
    if fm == nil then
      return nil
    end
    if type(fm) == "table" then
      return unpack(fm)
    end
    return fm
  end)

  local time = fixture.time or 0
  setGlobal("getTime", function()
    return time
  end)
  M.advanceTime = function(delta)
    time = time + (delta or 1)
  end

  local crsfQueue = {}
  for i = 1, #(fixture.crsfIncoming or {}) do
    crsfQueue[#crsfQueue + 1] = fixture.crsfIncoming[i]
  end
  M.crsfPushed = {}
  setGlobal("crossfireTelemetryPop", function()
    local frame = table.remove(crsfQueue, 1)
    if not frame then
      return nil, nil
    end
    return frame.command, frame.data
  end)
  setGlobal("crossfireTelemetryPush", function(command, data)
    M.crsfPushed[#M.crsfPushed + 1] = { command = command, data = data }
    return true
  end)

  -- lcd/Bitmap are no-ops that record calls so tests can assert on draw
  -- behavior (e.g. "an icon was drawn") without a real screen buffer.
  M.lcdCalls = {}
  local function recordCall(name)
    return function(...)
      M.lcdCalls[#M.lcdCalls + 1] = { name = name, ... }
      return true
    end
  end
  setGlobal("lcd", {
    drawText = recordCall("drawText"),
    drawFilledRectangle = recordCall("drawFilledRectangle"),
    drawRectangle = recordCall("drawRectangle"),
    drawBitmap = recordCall("drawBitmap"),
    drawLine = recordCall("drawLine"),
    -- Real EdgeTX signature: lcd.drawCircle(x, y, radius[, flags]) /
    -- lcd.drawFilledCircle(x, y, radius[, flags]) -- center + radius, not
    -- a bounding box, unlike drawRectangle/drawFilledRectangle above.
    -- Recorded with the same {name, ...} shape as every other call here
    -- (Improved Stick Grid, Task 2) so tests can filter marker/center-
    -- reference circles by center coordinates, radius, and color flags
    -- the same way stick_mode_spec.lua already filters
    -- drawFilledRectangle calls by size.
    drawCircle = recordCall("drawCircle"),
    drawFilledCircle = recordCall("drawFilledCircle"),
    setColor = recordCall("setColor"),
    -- Real EdgeTX signature: lcd.RGB(r, g, b) (8-bit components) or
    -- lcd.RGB(packedRGB) (single 0xRRGGBB int) -> a 32-bit flags value
    -- with the 16-bit RGB565 color packed into the UPPER half (bits
    -- 17-32), per luadoc.edgetx.org's drawing-flags-and-colors page --
    -- NOT a raw RGB565 value (see docs/platform/compatibility-matrix.md
    -- Section 12, a real-hardware finding: raw RGB565 hex literals
    -- passed directly to lcd draw functions are malformed EdgeTX color
    -- flags, not merely off-color). Modeled here with multiplication
    -- (packed = rgb565 * 65536) rather than bitwise shifts, matching
    -- this repo's existing Lua 5.1-compatibility constraint (5.1 has no
    -- native bitwise operators). A production color's `% 65536 == 0`
    -- tells a test it went through this function rather than being a
    -- hard-coded raw RGB565 literal.
    RGB = function(r, g, b)
      if g == nil and b == nil then
        local packed = r or 0
        r = math.floor(packed / 65536) % 256
        g = math.floor(packed / 256) % 256
        b = packed % 256
      end
      local r5 = math.floor((r or 0) / 8) % 32
      local g6 = math.floor((g or 0) / 4) % 64
      local b5 = math.floor((b or 0) / 8) % 32
      local rgb565 = (r5 * 2048) + (g6 * 32) + b5
      return rgb565 * 65536
    end,
    -- Mock approximation only, not real EdgeTX font metrics -- this
    -- desktop harness has no real renderer, so there is no ground truth
    -- to match. Keyed on this mock's own SMLSIZE=0/MIDSIZE=4/DBLSIZE=8
    -- tokens below, just distinct enough per size for tests to verify a
    -- caller actually uses sizeText's return value for positioning, not
    -- to assert pixel-perfect real-world sizes (that's EdgeTX Companion's
    -- job -- see render/primitives.lua's sizeText comment).
    sizeText = function(text, flags)
      text = tostring(text or "")
      flags = flags or 0
      local perChar, height
      if flags >= 8 then
        perChar, height = 12, 20
      elseif flags >= 4 then
        perChar, height = 9, 16
      else
        perChar, height = 5, 8
      end
      return #text * perChar, height
    end,
  })

  setGlobal("Bitmap", {
    open = function(path)
      if fixture.bitmaps and fixture.bitmaps[path] == false then
        return nil
      end
      return { __mockBitmap = path }
    end,
  })

  -- Mirrors main.lua's own WIDGET_ROOTS probing: resolve relative to the
  -- real repo files on disk so module-loading code exercises its actual
  -- fallback-path logic instead of a fake.
  setGlobal("loadScript", fixture.loadScript or function(path)
    local chunk = loadfile(path)
    if chunk then
      return chunk
    end
    return nil
  end)

  -- EdgeTX color / widget-option constants used by main.lua and renderers.
  setGlobal("WHITE", 0xFFFF)
  setGlobal("BLACK", 0x0000)
  setGlobal("RED", 0xF800)
  setGlobal("YELLOW", 0xFFE0)
  setGlobal("GREEN", 0x07E0)
  setGlobal("CUSTOM_COLOR", 1)
  setGlobal("SMLSIZE", 0)
  setGlobal("MIDSIZE", 4)
  setGlobal("DBLSIZE", 8)
  setGlobal("BOOL", 1)
  setGlobal("VALUE", 2)
  -- fixture.disableCombo: simulates an EdgeTX build exposing neither
  -- COMBO nor CHOICE, so a widget's own `type(COMBO) == "number" or
  -- type(CHOICE) == "number"` detection falls back to a plain VALUE
  -- option -- see tests/spec/main_spec.lua.
  if not fixture.disableCombo then
    setGlobal("COMBO", 3)
  end

  return M
end

function M.uninstall()
  for key in pairs(installedKeys) do
    _G[key] = nil
  end
  installedKeys = {}
  M.lcdCalls = nil
  M.crsfPushed = nil
  M.advanceTime = nil

  -- Widget code (main.lua's loadModule, and every render/*.lua's
  -- loadSiblingModule) caches loaded sibling modules in this
  -- well-namespaced global, scoped to one continuous runtime session
  -- (one radio power-on, in production; one install()/uninstall() cycle,
  -- here). Not clearing it here would leak module instances -- and the
  -- loadScript call *counts* tests assert on -- across what are meant to
  -- be independent test cases (see tests/paths.lua's loadWidgetModule
  -- comment on the same principle for module-level state).
  _G.__FPVDASH_MODULE_CACHE__ = nil
end

-- Installs the fixture, runs fn(), and always uninstalls afterward, even if
-- fn() raises (e.g. a failed assertion). Without this, a failing test would
-- leave mocked globals installed and cascade into unrelated failures in
-- whichever test runs next.
function M.withInstall(fixture, fn)
  M.install(fixture)
  local ok, err = pcall(fn)
  M.uninstall()
  if not ok then
    error(err, 0)
  end
end

return M
