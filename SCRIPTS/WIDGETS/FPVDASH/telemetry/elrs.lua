-- ELRS firmware version resolver via CRSF device-info frames.
-- Sends a device-info request (0x28) and listens for the response (0x29).
-- State is per-widget; call init() once in create() and update() every refresh.

local M = {}

-- Parse a null-terminated string out of a CRSF byte array starting at `off`.
-- Returns the string and the offset of the byte after the null terminator.
local function fieldGetString(data, off)
  local startOff = off
  while off <= #data and data[off] ~= 0 do
    data[off] = string.char(data[off])
    off = off + 1
  end
  return table.concat(data, nil, startOff, off - 1), off + 1
end

-- Parse a CRSF device-info frame into state.
-- Only accepts frames addressed to the TX module (address 0xEE).
local function parseDeviceInfo(state, data)
  if not data or data[2] ~= 0xEE then
    return false
  end

  local name, off = fieldGetString(data, 3)
  state.name = (name and #name > 0) and name or "ELRS"

  -- Version fields are at fixed offsets after the device name string.
  local vMaj = data[off + 9]
  local vMin = data[off + 10]
  local vRev = data[off + 11]

  if type(vMaj) ~= "number" or type(vMin) ~= "number" or type(vRev) ~= "number" then
    state.vStr = state.name
    return true
  end

  state.vStr = string.format("%s %d.%d.%d", state.name, vMaj, vMin, vRev)
  return true
end

-- Create and return a fresh per-widget ELRS state table.
function M.init()
  return {
    name    = nil,
    vStr    = nil,
    lastUpd = 0,
    done    = false,
  }
end

-- Poll the CRSF telemetry bus for a device-info response, and periodically
-- send a device-info request until a valid response is received.
-- Call once per refresh() frame.
function M.update(state)
  if not state or state.done then
    return
  end

  if type(crossfireTelemetryPop) ~= "function" or type(crossfireTelemetryPush) ~= "function" then
    return
  end

  local command, data = crossfireTelemetryPop()
  if command == 0x29 then
    if parseDeviceInfo(state, data) then
      state.done = true
    end
    return
  end

  -- Re-send the device-info request every ~1 second (100 × 10 ms ticks).
  local now = getTime()
  if (state.lastUpd or 0) + 100 < now then
    crossfireTelemetryPush(0x28, { 0x00, 0xEA })
    state.lastUpd = now
  end
end

-- Return the human-readable ELRS version string, e.g. "ELRS 3.4.0".
-- Returns "ELRS" when no device-info frame has been received yet.
function M.getString(state)
  return (state and type(state.vStr) == "string" and #state.vStr > 0)
    and state.vStr
    or  "ELRS"
end

return M
