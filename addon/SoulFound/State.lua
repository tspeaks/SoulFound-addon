-- Gathers the character's state for the export string.
local _, SF = ...

local State = {}
SF.State = State
local Json = SF.Json

-- Inventory slots worth exporting (shirt and tabard skipped).
State.GEAR_SLOTS = { 1, 2, 3, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18 }

function State.itemInfoInstant(link)
    local f = SF.api("C_Item.GetItemInfoInstant") or GetItemInfoInstant
    if not f then return nil end
    local ok, id, itemType, subType, equipLoc = pcall(f, link)
    if not ok then return nil end
    return id, itemType, subType, equipLoc
end

-- Classic returns name first; some clients return a numeric tab ID first.
local function tabInfo(tab)
    local a, b, c, d, e = GetTalentTabInfo(tab)
    if type(a) == "number" and type(b) == "string" then
        return b, e
    end
    return a, c
end

-- Returns the live talent tree, or { available = false } where the Classic API is missing.
function State.talents()
    if not (GetNumTalentTabs and GetTalentTabInfo and GetNumTalents and GetTalentInfo) then
        return { available = false }
    end
    local tabs = Json.array({})
    for tab = 1, GetNumTalentTabs() or 0 do
        local tabName, spent = tabInfo(tab)
        local talents = Json.array({})
        for i = 1, GetNumTalents(tab) or 0 do
            local name, _, tier, column, rank, maxRank = GetTalentInfo(tab, i)
            if name then
                local entry = { name = name, tier = tier, col = column, rank = rank or 0, max = maxRank or 0, index = i }
                if GetTalentPrereqs then
                    local pTier, pCol = GetTalentPrereqs(tab, i)
                    if pTier then entry.prereq = Json.array({ pTier, pCol }) end
                end
                talents[#talents + 1] = entry
            end
        end
        tabs[#tabs + 1] = { name = tabName, spent = spent or 0, talents = talents }
    end
    return { available = true, unspent = State.unspentPoints(), tabs = tabs }
end

function State.unspentPoints()
    if UnitCharacterPoints then
        local points = UnitCharacterPoints("player")
        if type(points) == "number" then return points end
    end
    return nil
end

function State.questLog()
    local out = Json.array({})
    local numEntries = SF.api("C_QuestLog.GetNumQuestLogEntries")
    local getInfo = SF.api("C_QuestLog.GetInfo")
    if numEntries and getInfo then
        local isComplete = SF.api("C_QuestLog.IsComplete")
        for i = 1, numEntries() or 0 do
            local info = getInfo(i)
            if info and not info.isHeader and info.questID then
                out[#out + 1] = {
                    id = info.questID, title = info.title, level = info.level,
                    complete = isComplete and isComplete(info.questID) or false,
                }
            end
        end
    elseif GetNumQuestLogEntries and GetQuestLogTitle then
        for i = 1, GetNumQuestLogEntries() or 0 do
            local title, level, _, isHeader, _, isComplete, _, questID = GetQuestLogTitle(i)
            if title and not isHeader then
                out[#out + 1] = { id = questID, title = title, level = level, complete = isComplete == 1 or isComplete == true }
            end
        end
    end
    return out
end

function State.completedQuests()
    local out = Json.array({})
    local all = SF.api("C_QuestLog.GetAllCompletedQuestIDs")
    if all then
        for _, id in ipairs(all() or {}) do out[#out + 1] = id end
    elseif GetQuestsCompleted then
        for id in pairs(GetQuestsCompleted() or {}) do out[#out + 1] = id end
        table.sort(out)
    end
    return out
end

function State.gear()
    local out = Json.array({})
    for _, slot in ipairs(State.GEAR_SLOTS) do
        local link = GetInventoryItemLink("player", slot)
        if link then
            local id, _, subType, equipLoc = State.itemInfoInstant(link)
            local read = SF.Stats.read(link)
            out[#out + 1] = {
                slot = slot, id = id, name = link:match("%[(.-)%]"),
                sub = subType, loc = equipLoc, stats = read and read.stats or nil,
            }
        end
    end
    return out
end

function State.position()
    local best = SF.api("C_Map.GetBestMapForUnit")
    local getPos = SF.api("C_Map.GetPlayerMapPosition")
    if not (best and getPos) then return nil end
    local map = best("player")
    if not map then return nil end
    local pos = getPos(map, "player")
    if not pos then return { map = map } end
    local x, y = pos:GetXY()
    return { map = map, x = math.floor(x * 1000 + 0.5) / 10, y = math.floor(y * 1000 + 0.5) / 10 }
end

function State.collect()
    local _, classFile = UnitClass("player")
    local _, raceFile = UnitRace("player")
    local data = {
        format = "soulfound-export",
        version = 1,
        addon = SF.VERSION,
        client = SF.clientInfo(),
        char = {
            class = classFile,
            race = raceFile,
            faction = UnitFactionGroup("player"),
            level = UnitLevel("player"),
            xp = UnitXP and UnitXP("player") or nil,
            xp_max = UnitXPMax and UnitXPMax("player") or nil,
            money = GetMoney and GetMoney() or nil,
            zone = GetRealZoneText and GetRealZoneText() or nil,
            pos = State.position(),
        },
        talents = State.talents(),
        gear = State.gear(),
        professions = SF.Professions.exportList(),
        quests = { log = State.questLog(), completed = State.completedQuests() },
    }
    if SF.Trace and SF.Trace.enabled() then
        data.trace = SF.Trace.entries()
    end
    return data
end
