-- Opt-in play log (off by default). Nothing leaves the game unless the player
-- copies an export string; with tracing on, the export includes this log.
local _, SF = ...

local Trace = {}
SF.Trace = Trace

-- Keeps exports small enough to paste comfortably (~60 bytes per entry).
local MAX = 1000

local function store()
    SoulFoundCharDB.trace = SoulFoundCharDB.trace or { enabled = false, entries = {} }
    return SoulFoundCharDB.trace
end

function Trace.enabled()
    return SoulFoundCharDB and store().enabled or false
end

function Trace.entries()
    local out = SF.Json.array({})
    for i, e in ipairs(store().entries) do out[i] = e end
    return out
end

function Trace.set(on)
    store().enabled = on and true or false
end

function Trace.clear()
    store().entries = {}
end

-- kind: "A" accepted, "T" turned in, "D" died, "L" level up.
function Trace.add(kind, questID)
    if not Trace.enabled() then return end
    local entries = store().entries
    local pos = SF.State.position()
    entries[#entries + 1] = {
        t = time(), e = kind, q = questID, l = UnitLevel("player"),
        m = pos and pos.map, x = pos and pos.x, y = pos and pos.y,
    }
    while #entries > MAX do table.remove(entries, 1) end
end
