-- Profession leveling help: which recipe to craft for a skill-up, what to
-- gather, and when to train the next rank. Tier data follows original Classic
-- and is shown as guidance; the live recipe colors from the game always win.
local _, SF = ...

local Prof = {}
SF.Professions = Prof

Prof.CRAFTING = { "Alchemy", "Blacksmithing", "Enchanting", "Engineering", "Leatherworking", "Tailoring", "Cooking", "First Aid" }
Prof.GATHERING = { "Herbalism", "Mining", "Skinning", "Fishing" }

-- Rank caps and the skill/level needed to train past each one.
Prof.RANKS = {
    { cap = 75, name = "Journeyman", skill = 50, level = 10 },
    { cap = 150, name = "Expert", skill = 125, level = 20 },
    { cap = 225, name = "Artisan", skill = 200, level = 35 },
}

-- Gathering nodes: { skill needed, name }.
Prof.NODES = {
    Mining = {
        { 1, "Copper Vein" }, { 65, "Tin Vein" }, { 75, "Silver Vein" }, { 125, "Iron Deposit" },
        { 155, "Gold Vein" }, { 175, "Mithril Deposit" }, { 230, "Truesilver Deposit" },
        { 245, "Small Thorium Vein" }, { 275, "Rich Thorium Vein" },
    },
    Herbalism = {
        { 1, "Peacebloom and Silverleaf" }, { 15, "Earthroot" }, { 50, "Mageroyal" }, { 70, "Briarthorn" },
        { 85, "Stranglekelp" }, { 100, "Bruiseweed" }, { 115, "Wild Steelbloom" }, { 120, "Grave Moss" },
        { 125, "Kingsblood" }, { 150, "Liferoot" }, { 160, "Fadeleaf" }, { 170, "Goldthorn" },
        { 185, "Khadgar's Whisker" }, { 195, "Wintersbite" }, { 205, "Firebloom" }, { 210, "Purple Lotus" },
        { 220, "Arthas' Tears" }, { 230, "Sungrass" }, { 235, "Blindweed" }, { 245, "Ghost Mushroom" },
        { 250, "Gromsblood" }, { 260, "Golden Sansam" }, { 270, "Dreamfoil" }, { 280, "Mountain Silversage" },
        { 285, "Plaguebloom" }, { 290, "Icecap" }, { 300, "Black Lotus" },
    },
}

local KNOWN = {}
for _, n in ipairs(Prof.CRAFTING) do KNOWN[n] = "craft" end
for _, n in ipairs(Prof.GATHERING) do KNOWN[n] = "gather" end

-- Returns { [name] = { rank, max } } for the character's professions.
function Prof.read()
    local out = {}
    if GetNumSkillLines and GetSkillLineInfo then
        for i = 1, GetNumSkillLines() or 0 do
            local name, isHeader, _, rank, _, _, max = GetSkillLineInfo(i)
            if name and not isHeader and KNOWN[name] then out[name] = { rank = rank or 0, max = max or 0 } end
        end
    elseif GetProfessions and GetProfessionInfo then
        for _, index in pairs({ GetProfessions() }) do
            if index then
                local name, _, rank, max = GetProfessionInfo(index)
                if name and KNOWN[name] then out[name] = { rank = rank or 0, max = max or 0 } end
            end
        end
    end
    return out
end

function Prof.exportList()
    local list = SF.Json.array({})
    for name, p in pairs(Prof.read()) do list[#list + 1] = { name = name, rank = p.rank, max = p.max } end
    table.sort(list, function(a, b) return a.name < b.name end)
    return list
end

-- The highest skinnable mob level for a skinning rank (Classic formula).
function Prof.skinnableLevel(rank)
    if rank < 100 then return 10 + math.floor(rank / 10) end
    return math.floor(rank / 5)
end

-- Up to three nodes that still give skill-ups, best first (a node can until
-- about 100 past its requirement, most reliably in the first 50), and the
-- next unlock.
function Prof.gatherAdvice(name, rank)
    local nodes = Prof.NODES[name]
    if not nodes then return nil end
    local useful, nextNode = {}, nil
    for i = #nodes, 1, -1 do
        local node = nodes[i]
        if rank >= node[1] and rank < node[1] + 100 and #useful < 3 then useful[#useful + 1] = node[2] end
    end
    for _, node in ipairs(nodes) do
        if rank < node[1] then nextNode = node break end
    end
    return useful, nextNode
end

-- Training reminder text when the rank cap is holding the player back, else nil.
function Prof.trainNeeded(name, rank, max, level)
    if KNOWN[name] ~= "craft" and KNOWN[name] ~= "gather" then return nil end
    if name == "Fishing" then return nil end
    for _, r in ipairs(Prof.RANKS) do
        if max == r.cap and rank >= r.skill then
            if level < r.level then
                return string.format("%s %d/%d: you can train %s at level %d.", name, rank, max, r.name, r.level)
            end
            return string.format("%s %d/%d: visit a trainer for %s, or your skill-ups stop at %d.", name, rank, max, r.name, max)
        end
    end
    return nil
end

-- Picks the recipe to craft from { name, type, available } entries:
-- orange you can make now, then yellow you can make now, then orange you need materials for.
function Prof.pickRecipe(recipes)
    local function first(kind, needMats)
        for _, r in ipairs(recipes) do
            if r.type == kind and ((r.available or 0) > 0) == needMats then return r end
        end
    end
    return first("optimal", true) or first("medium", true) or first("optimal", false) or first("medium", false)
end

local function tradeRecipes()
    local recipes = {}
    if not (GetNumTradeSkills and GetTradeSkillInfo) then return recipes end
    for i = 1, GetNumTradeSkills() or 0 do
        local name, kind, available = GetTradeSkillInfo(i)
        if name and kind ~= "header" then
            recipes[#recipes + 1] = { index = i, name = name, type = kind, available = available }
        end
    end
    return recipes
end

local function reagents(index)
    if not (GetTradeSkillNumReagents and GetTradeSkillReagentInfo) then return nil end
    local parts = {}
    for r = 1, GetTradeSkillNumReagents(index) or 0 do
        local name, _, count, have = GetTradeSkillReagentInfo(index, r)
        if name then parts[#parts + 1] = string.format("%s %d/%d", name, have or 0, count or 0) end
    end
    return table.concat(parts, ", ")
end

local COLOR = { optimal = "|cffff8040", medium = "|cffffff00" }
local lastPick

function Prof.onTradeSkill()
    local recipes = tradeRecipes()
    if #recipes == 0 then return end
    local pick = Prof.pickRecipe(recipes)
    if not pick then
        if lastPick ~= "none" then
            SF.print("no recipe here gives a skill-up any more. Train new recipes or the next rank.")
        end
        lastPick = "none"
        return
    end
    if pick.name == lastPick then return end
    lastPick = pick.name
    local color = COLOR[pick.type] or ""
    if (pick.available or 0) > 0 then
        SF.print(string.format("craft %s%s|r next (you can make %d).", color, pick.name, pick.available))
    else
        SF.print(string.format("craft %s%s|r next once you have the materials: %s.", color, pick.name, reagents(pick.index) or "?"))
    end
end

function Prof.onTradeSkillClosed()
    lastPick = nil
end

local seen = {}

-- Called when skills change: unlock and training notices, once each.
function Prof.onSkillsChanged()
    local level = UnitLevel("player")
    for name, p in pairs(Prof.read()) do
        local before = seen[name]
        seen[name] = p.rank
        if before and p.rank > before then
            local _, nextBefore = Prof.gatherAdvice(name, before)
            if nextBefore and p.rank >= nextBefore[1] then
                SF.print(string.format("%s %d: you can now gather %s.", name, p.rank, nextBefore[2]))
            end
            if name == "Skinning" and Prof.skinnableLevel(p.rank) > Prof.skinnableLevel(before) then
                SF.print(string.format("Skinning %d: you can skin mobs up to level %d.", p.rank, Prof.skinnableLevel(p.rank)))
            end
            local train = Prof.trainNeeded(name, p.rank, p.max, level)
            local trainBefore = Prof.trainNeeded(name, before, p.max, level)
            if train and not trainBefore then SF.print(train) end
        end
    end
end

-- /sf prof: a summary line per profession, plus the plan's picks.
function Prof.report()
    local level = UnitLevel("player")
    local mine = Prof.read()
    local any = false
    for _, name in ipairs({ "Alchemy", "Blacksmithing", "Enchanting", "Engineering", "Leatherworking", "Tailoring",
        "Herbalism", "Mining", "Skinning", "Cooking", "First Aid", "Fishing" }) do
        local p = mine[name]
        if p then
            any = true
            local line = string.format("%s %d/%d", name, p.rank, p.max)
            local useful, nextNode = Prof.gatherAdvice(name, p.rank)
            if useful then
                if #useful > 0 then line = line .. ": skill-ups from " .. table.concat(useful, ", ") end
                if nextNode then line = line .. string.format(". Next: %s at %d", nextNode[2], nextNode[1]) end
            elseif name == "Skinning" then
                line = line .. string.format(": skin mobs up to level %d", Prof.skinnableLevel(p.rank))
            end
            local train = Prof.trainNeeded(name, p.rank, p.max, level)
            if train then line = line .. ". |cffffd100Train next rank.|r" end
            SF.print(line)
        end
    end
    if not any then SF.print("no professions yet.") end
    local plan = SF.plan()
    local picks = plan and plan.professions and plan.professions.primary
    if picks and #picks > 0 then
        local missing = {}
        for _, name in ipairs(picks) do if not mine[name] then missing[#missing + 1] = name end end
        SF.print("your plan's professions: " .. table.concat(picks, " + ")
            .. (#missing > 0 and (". Not learned yet: " .. table.concat(missing, ", ")) or ""))
    end
end

function Prof.remindPlan()
    local plan = SF.plan()
    local picks = plan and plan.professions and plan.professions.primary
    if not picks or #picks == 0 or UnitLevel("player") < 5 then return end
    local mine = Prof.read()
    local missing = {}
    for _, name in ipairs(picks) do if not mine[name] then missing[#missing + 1] = name end end
    if #missing > 0 then
        SF.print("your plan includes " .. table.concat(missing, " and ") .. ". Learn it from a trainer; every capital city has one for each profession.")
    end
end

function Prof.prime()
    for name, p in pairs(Prof.read()) do seen[name] = p.rank end
end
