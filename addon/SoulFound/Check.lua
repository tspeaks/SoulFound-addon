-- /sf check: reports which game APIs exist on this client and whether SoulFound
-- can read talents, gear and quests. The report is copyable for bug reports.
local _, SF = ...

local Check = {}
SF.Check = Check

Check.APIS = {
    "GetBuildInfo", "UnitClass", "UnitRace", "UnitLevel", "UnitXP", "GetMoney",
    "C_Map.GetBestMapForUnit", "C_Map.GetPlayerMapPosition",
    "C_QuestLog.GetNumQuestLogEntries", "C_QuestLog.GetInfo", "C_QuestLog.IsComplete",
    "GetNumQuestLogEntries", "GetQuestLogTitle",
    "C_QuestLog.GetAllCompletedQuestIDs", "GetQuestsCompleted",
    "GetNumTalentTabs", "GetTalentTabInfo", "GetNumTalents", "GetTalentInfo", "GetTalentPrereqs",
    "UnitCharacterPoints", "C_ClassTalents", "C_Traits", "C_SpecializationInfo",
    "GetInventoryItemLink", "C_Item.GetItemInfoInstant", "GetItemInfoInstant",
    "C_Item.GetItemInfo", "GetItemInfo", "GetItemStats", "C_Item.GetItemStats",
    "C_TooltipInfo.GetHyperlink", "TooltipUtil.SurfaceArgs", "TooltipDataProcessor.AddTooltipPostCall",
    "GetNumSkillLines", "GetSkillLineInfo", "GetProfessions", "GetProfessionInfo",
    "GetNumTradeSkills", "GetTradeSkillInfo", "GetTradeSkillNumReagents", "GetTradeSkillReagentInfo", "C_TradeSkillUI",
    "GetNumQuestChoices", "GetNumQuestRewards", "GetQuestItemLink", "GetCoinTextureString",
    "BackdropTemplateMixin", "C_Timer.After", "issecretvalue", "InCombatLockdown",
}

local function try(lines, label, fn)
    local ok, result = pcall(fn)
    if ok then
        lines[#lines + 1] = label .. ": " .. tostring(result)
    else
        lines[#lines + 1] = label .. ": ERROR " .. tostring(result)
    end
end

function Check.run()
    local lines = {}
    local c = SF.clientInfo()
    lines[#lines + 1] = string.format("SoulFound %s | client %s build %s interface %s project %s",
        SF.VERSION, tostring(c.version), tostring(c.build), tostring(c.interface), tostring(c.project))
    lines[#lines + 1] = "Tooltip hook: " .. tostring(SF.Tooltip.mode)

    local missing = {}
    for _, name in ipairs(Check.APIS) do
        if SF.api(name) == nil then missing[#missing + 1] = name end
    end
    lines[#lines + 1] = "Missing APIs: " .. (#missing > 0 and table.concat(missing, ", ") or "none")

    try(lines, "Character", function()
        local _, classFile = UnitClass("player")
        local _, raceFile = UnitRace("player")
        return string.format("%s %s level %d", tostring(raceFile), tostring(classFile), UnitLevel("player"))
    end)
    try(lines, "Talents", function()
        local tree = SF.State.talents()
        if not tree.available then return "Classic talent API missing" end
        local parts = {}
        for _, tab in ipairs(tree.tabs) do
            local first = tab.talents[1]
            parts[#parts + 1] = string.format("%s (%d talents, %d spent, first: %s)",
                tostring(tab.name), #tab.talents, tab.spent, first and first.name or "-")
        end
        return string.format("%d tabs, unspent %s | %s", #tree.tabs, tostring(tree.unspent), table.concat(parts, "; "))
    end)
    try(lines, "Professions", function()
        local parts = {}
        for name, p in pairs(SF.Professions.read()) do parts[#parts + 1] = string.format("%s %d/%d", name, p.rank, p.max) end
        return #parts > 0 and table.concat(parts, ", ") or "none read"
    end)
    try(lines, "Quest log", function() return #SF.State.questLog() .. " quests" end)
    try(lines, "Completed quests", function() return #SF.State.completedQuests() end)
    try(lines, "Position", function()
        local p = SF.State.position()
        return p and string.format("map %s %.1f, %.1f", tostring(p.map), p.x or -1, p.y or -1) or "unavailable"
    end)

    -- Raw tooltip lines for two equipped items, so text patterns can be checked.
    for _, slot in ipairs({ 16, 5 }) do
        try(lines, "Slot " .. slot, function()
            local link = GetInventoryItemLink("player", slot)
            if not link then return "empty" end
            local raw, source = SF.Stats.tooltipLines(link)
            local texts = {}
            for _, l in ipairs(raw or {}) do texts[#texts + 1] = l.text end
            local read = SF.Stats.read(link)
            local parsed = {}
            for k, v in pairs(read and read.stats or {}) do parsed[#parsed + 1] = k .. "=" .. v end
            return string.format("%s via %s | lines: %s | parsed: %s", link:match("%[(.-)%]") or link,
                tostring(source), table.concat(texts, " / "), table.concat(parsed, ", "))
        end)
    end

    -- Every talent-related function this client has, so a fallback can be
    -- written if the Classic talent API is missing or changed.
    try(lines, "Talent functions", function()
        local found = {}
        for name, v in pairs(_G) do
            if type(name) == "string" and name:find("Talent") then
                if type(v) == "function" then
                    found[#found + 1] = name
                elseif type(v) == "table" and name:find("^C_") then
                    for k, f in pairs(v) do
                        if type(f) == "function" then found[#found + 1] = name .. "." .. tostring(k) end
                    end
                end
            end
        end
        for _, ns in ipairs({ "C_Traits", "C_SpecializationInfo" }) do
            local t = _G[ns]
            if type(t) == "table" then
                for k, f in pairs(t) do
                    if type(f) == "function" then found[#found + 1] = ns .. "." .. tostring(k) end
                end
            end
        end
        table.sort(found)
        if #found > 80 then
            local n = #found
            for i = n, 81, -1 do found[i] = nil end
            found[#found + 1] = "(+" .. (n - 80) .. " more)"
        end
        return table.concat(found, ", ")
    end)

    local errors = SoulFoundDB and SoulFoundDB.errors or {}
    lines[#lines + 1] = "Logged errors: " .. #errors
    for i = math.max(1, #errors - 4), #errors do
        if errors[i] then lines[#lines + 1] = "  " .. errors[i].msg:gsub("\n", " | ") end
    end

    local report = table.concat(lines, "\n")
    SoulFoundDB.lastCheck = { t = time(), report = report }
    return report
end
