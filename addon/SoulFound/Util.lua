-- Shared helpers. Forever (interface 16xxx) reports Retail's project ID but runs
-- Classic content, and some legacy globals are missing or broken there, so every
-- API is looked up at call time rather than assumed.
local _, SF = ...

SF.VERSION = "0.1.0"

function SF.print(msg)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cff8fd6ffSoulFound|r: " .. tostring(msg))
    end
end

-- SF.api("C_TooltipInfo.GetHyperlink") returns the function or nil.
function SF.api(path)
    local t = _G
    for part in path:gmatch("[^%.]+") do
        if type(t) ~= "table" then return nil end
        t = t[part]
    end
    return t
end

function SF.isSecret(v)
    local f = issecretvalue
    if f then
        local ok, secret = pcall(f, v)
        return ok and secret or false
    end
    return false
end

function SF.inCombat()
    return InCombatLockdown and InCombatLockdown() or false
end

function SF.clientInfo()
    local version, build, _, interface = GetBuildInfo()
    return {
        version = version,
        build = build,
        interface = interface,
        project = WOW_PROJECT_ID,
        forever = interface and interface >= 16000 and interface < 17000 or false,
    }
end

-- Errors are kept in SavedVariables so a tester can send them after /reload.
local seen = {}
function SF.logError(err)
    local msg = tostring(err)
    if SoulFoundDB then
        SoulFoundDB.errors = SoulFoundDB.errors or {}
        local list = SoulFoundDB.errors
        list[#list + 1] = { t = time and time() or 0, msg = msg }
        while #list > 30 do table.remove(list, 1) end
    end
    local key = msg:match("^[^\n]*"):sub(1, 120)
    if not seen[key] then
        seen[key] = true
        SF.print("|cffff6060error:|r " .. key .. " (see /sf check)")
    end
end

local function handler(err)
    local stack = debugstack and debugstack(2, 6, 0) or ""
    return tostring(err) .. "\n" .. stack
end

-- Wraps a function so an error is logged instead of breaking the caller.
function SF.wrap(fn)
    return function(...)
        local args, n = { ... }, select("#", ...)
        local ok, a, b, c = xpcall(function() return fn(unpack(args, 1, n)) end, handler)
        if not ok then
            SF.logError(a)
            return nil
        end
        return a, b, c
    end
end

function SF.after(seconds, fn)
    if C_Timer and C_Timer.After then
        C_Timer.After(seconds, SF.wrap(fn))
    else
        SF.wrap(fn)()
    end
end

function SF.plan()
    return SoulFoundCharDB and SoulFoundCharDB.plan or nil
end
