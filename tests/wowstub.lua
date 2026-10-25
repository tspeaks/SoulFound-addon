-- Minimal stand-ins for the WoW API so addon files load under plain Lua 5.1.
-- Tests override individual functions as needed.
local stub = {}

local function dummy()
    local obj = {}
    return setmetatable(obj, {
        __index = function(t, k)
            local f = function() return nil end
            rawset(t, k, f)
            return f
        end,
    })
end

function stub.install()
    _G.time = os.time
    _G.unpack = unpack
    _G.tinsert = table.insert
    _G.printed = {}
    _G.DEFAULT_CHAT_FRAME = { AddMessage = function(_, msg) table.insert(printed, msg) end }
    _G.CreateFrame = function() return dummy() end
    _G.UIParent = dummy()
    _G.WorldFrame = dummy()
    _G.SlashCmdList = {}
    _G.InCombatLockdown = function() return false end
    _G.GetBuildInfo = function() return "1.60.1", "69913", "Oct 1 2026", 16001 end
    _G.WOW_PROJECT_ID = 1
    _G.UnitClass = function() return "Rogue", "ROGUE" end
    _G.UnitRace = function() return "Human", "Human" end
    _G.UnitFactionGroup = function() return "Alliance" end
    _G.UnitLevel = function() return 14 end
    _G.UnitXP = function() return 1800 end
    _G.UnitXPMax = function() return 7600 end
    _G.GetMoney = function() return 1930 end
    _G.GetRealZoneText = function() return "Westfall" end
    _G.GetInventoryItemLink = function() return nil end
end

-- Loads addon files in TOC order into one shared namespace.
function stub.loadAddon(dir)
    local ns = {}
    local toc = assert(io.open(dir .. "/SoulFound.toc"))
    for line in toc:lines() do
        local file = line:match("^([%w_]+%.lua)%s*$")
        if file then
            local chunk = assert(loadfile(dir .. "/" .. file))
            chunk("SoulFound", ns)
        end
    end
    toc:close()
    return ns
end

return stub
