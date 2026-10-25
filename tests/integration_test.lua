-- Drives the whole addon through fake events, windows and slash commands.
-- Run from the repo root: lua5.1 tests/integration_test.lua
package.path = "tests/?.lua;" .. package.path
local stub = require("wowstub")
local fake = require("fakeui")
stub.install()
fake.install()

-- Talent tree: Combat rogue with 4/5 Lightning Reflexes and one unspent point.
local ranks = { ["Lightning Reflexes"] = 4, ["Deflection"] = 0 }
local TREE = { { name = "Combat", talents = { { "Lightning Reflexes", 1, 3, 5 }, { "Deflection", 2, 2, 5 } } } }
GetNumTalentTabs = function() return #TREE end
GetTalentTabInfo = function(tab) return TREE[tab].name, "icon", ranks["Lightning Reflexes"] + ranks["Deflection"], "bg" end
GetNumTalents = function(tab) return #TREE[tab].talents end
GetTalentInfo = function(tab, i)
    local t = TREE[tab].talents[i]
    return t[1], "icon", t[2], t[3], ranks[t[1]], t[4]
end
GetTalentPrereqs = function() return nil end
UnitCharacterPoints = function() return 1 end

-- Items: equipped chest, plus three quest reward choices.
local ITEMS = {
    ["|Hitem:1|h[Old Vest]|h"] = { loc = "INVTYPE_CHEST", lines = { "Old Vest", "50 Armor", "+1 Agility" } },
    ["|Hitem:2|h[Agile Jerkin]|h"] = { loc = "INVTYPE_CHEST", sell = 300, lines = { "Agile Jerkin", "60 Armor", "+4 Agility", "Equip: Increases your chance to dodge an attack by 1%." } },
    ["|Hitem:3|h[Brute Mail]|h"] = { loc = "INVTYPE_CHEST", sell = 900, red = true, lines = { "Brute Mail", "Mail", "200 Armor", "+6 Strength" } },
    ["|Hitem:4|h[Plain Ring]|h"] = { loc = "INVTYPE_FINGER", sell = 100, lines = { "Plain Ring", "+1 Stamina" } },
}
local CHOICES = { "|Hitem:2|h[Agile Jerkin]|h", "|Hitem:3|h[Brute Mail]|h", "|Hitem:4|h[Plain Ring]|h" }
GetInventoryItemLink = function(_, slot) if slot == 5 then return "|Hitem:1|h[Old Vest]|h" end end
GetItemInfoInstant = function(link) local i = ITEMS[link]; return 1, "Armor", "Leather", i and i.loc end
GetItemInfo = function(link)
    local i = ITEMS[link]
    return link, link, 2, 10, 10, "Armor", "Leather", 1, i.loc, 0, i.sell or 0
end
C_TooltipInfo = {
    GetHyperlink = function(link)
        local i = ITEMS[link]
        local lines = {}
        for n, text in ipairs(i.lines) do
            local red = i.red and n == 2
            lines[n] = { leftText = text, leftColor = { r = 1, g = red and 0.13 or 1, b = red and 0.13 or 1 } }
        end
        return { lines = lines }
    end,
}
GetNumQuestChoices = function() return #CHOICES end
GetQuestItemLink = function(_, i) return CHOICES[i] end

-- Timers run immediately.
C_Timer = { After = function(_, fn) fn() end }

-- Tooltip processor hook, as on Forever.
local postCall
Enum = { TooltipDataType = { Item = 0 } }
TooltipDataProcessor = { AddTooltipPostCall = function(_, fn) postCall = fn end }

-- CHARACTER_POINTS_CHANGED is "unknown" here, to prove defensive registration.
fake.unknownEvents = { CHARACTER_POINTS_CHANGED = true }

local SF = stub.loadAddon("addon/SoulFound")

local passed, failed = 0, 0
local function test(name, fn)
    printed = {}
    local ok, err = pcall(fn)
    if ok then passed = passed + 1 else failed = failed + 1; print("FAIL " .. name .. ": " .. tostring(err)) end
end
local function saw(pattern)
    for _, m in ipairs(printed) do if m:find(pattern) then return true end end
    return false
end
local slash = function(msg) SlashCmdList.SOULFOUND(msg) end

fake.event("ADDON_LOADED", "SoulFound")
fake.event("PLAYER_LOGIN")

test("saved variables initialised", function()
    assert(type(SoulFoundDB) == "table" and type(SoulFoundCharDB) == "table")
end)

test("tooltip installed via TooltipDataProcessor", function()
    assert(SF.Tooltip.mode == "TooltipDataProcessor", tostring(SF.Tooltip.mode))
    assert(postCall, "post-call registered")
end)

test("help", function()
    slash("")
    assert(saw("/sf export"), "help lists export")
end)

local exportText
test("export window shows an export string", function()
    slash("export")
    local w = fake.find("SoulFoundStringWindow")
    assert(w and w.shown, "window shown")
    exportText = w.edit:GetText()
    assert(exportText:sub(1, 5) == "SF1E:", exportText:sub(1, 20))
    local kind, data = SF.Codec.decode(exportText)
    assert(kind == "export" and data.char.class == "ROGUE")
    assert(data.gear[1].name == "Old Vest" and data.gear[1].stats.agility == 1, "gear stats exported")
end)

test("export is read-only", function()
    local w = fake.find("SoulFoundStringWindow")
    w.edit:SetText("tampered")
    w.edit:Fire("OnTextChanged", true)
    assert(w.edit:GetText() == exportText)
end)

test("export refused in combat", function()
    InCombatLockdown = function() return true end
    slash("export")
    InCombatLockdown = function() return false end
    assert(saw("leave combat"))
end)

test("rewards without a plan ask for one", function()
    fake.event("QUEST_COMPLETE")
    assert(saw("import a plan"))
end)

local function importString(text)
    slash("import")
    local w = fake.find("SoulFoundStringWindow")
    w.edit:SetText(text)
    w.action:Fire("OnClick")
    return w
end

test("import rejects junk and other classes", function()
    importString("not a plan")
    assert(saw("SF1"), "junk message")
    importString(SF.Codec.encode("plan", { format = "soulfound-plan", class = "MAGE" }))
    assert(saw("for a MAGE"), "class mismatch")
    importString(exportText)
    assert(saw("not a plan"), "export pasted as plan")
    assert(SoulFoundCharDB.plan == nil)
end)

local PLAN = {
    format = "soulfound-plan", version = 1, class = "ROGUE", title = "Tanky dodge/parry rogue",
    stat_values = { agility = 1, dodge = 20, armor = 0.04, strength = 0.5, stamina = 0.7 },
    talent_order = { "Lightning Reflexes", "Lightning Reflexes", "Lightning Reflexes", "Lightning Reflexes",
        "Lightning Reflexes", "Deflection", "Deflection" },
    advice = { "Keep Evasion for pulls where a second mob joins." },
}

test("import a plan and get a talent reminder", function()
    local w = importString(SF.Codec.encode("plan", PLAN))
    assert(not w.shown, "window closes after import")
    assert(SoulFoundCharDB.plan.title == PLAN.title)
    assert(saw("Lightning Reflexes.*5/5"), table.concat(printed, " || "))
end)

test("reminder moves on after the point is spent", function()
    ranks["Lightning Reflexes"] = 5
    fake.event("PLAYER_LEVEL_UP", 15)
    assert(saw("Deflection.*1/5"), table.concat(printed, " || "))
end)

test("plan panel", function()
    slash("show")
    local p = fake.find("SoulFoundPlanPanel")
    assert(p and p.shown)
    assert(p.lines[1]:GetText():find("Deflection"), p.lines[1]:GetText())
    assert(p.lines[2]:GetText():find("Dodge"), p.lines[2]:GetText())
end)

test("reward pick prefers the usable upgrade", function()
    fake.event("QUEST_COMPLETE")
    assert(saw("Pick .*Agile Jerkin"), table.concat(printed, " || "))
    assert(saw("Brute Mail.*can't use"), "red item flagged")
    local r = fake.find("SoulFoundRewardPanel")
    assert(r and r.shown)
    fake.event("QUEST_FINISHED")
    assert(not r.shown)
end)

test("quest offer mentions an upgrade reward", function()
    GetNumQuestRewards = function() return 0 end
    fake.event("QUEST_DETAIL")
    assert(saw("rewards an upgrade.*Agile Jerkin"), table.concat(printed, " || "))
end)

test("quest offer stays quiet without an upgrade", function()
    local saved = CHOICES
    CHOICES = { "|Hitem:3|h[Brute Mail]|h" }
    fake.event("QUEST_DETAIL")
    CHOICES = saved
    assert(#printed == 0, table.concat(printed, " || "))
end)

test("no upgrade suggests the best sell", function()
    CHOICES = { "|Hitem:4|h[Plain Ring]|h", "|Hitem:3|h[Brute Mail]|h" }
    GetInventoryItemLink = function(_, slot)
        if slot == 5 then return "|Hitem:2|h[Agile Jerkin]|h" end
        if slot == 11 or slot == 12 then return "|Hitem:4|h[Plain Ring]|h" end
    end
    fake.event("QUEST_COMPLETE")
    assert(saw("No upgrade"), table.concat(printed, " || "))
    assert(saw("Best to sell: .*Brute Mail"), table.concat(printed, " || "))
end)

test("tooltip line", function()
    local tip = GameTooltip
    tip.lines = {}
    tip.itemLink = "|Hitem:1|h[Old Vest]|h"
    postCall(tip, {})
    assert(tip.lines[1] and tip.lines[1]:find("SoulFound"), tostring(tip.lines[1]))
    assert(tip.lines[1]:find("vs equipped"))
end)

test("tooltip skipped in combat and for the scanner", function()
    GameTooltip.lines = {}
    InCombatLockdown = function() return true end
    postCall(GameTooltip, {})
    InCombatLockdown = function() return false end
    assert(#GameTooltip.lines == 0)
end)

test("check report", function()
    slash("check")
    local w = fake.find("SoulFoundStringWindow")
    local report = w.edit:GetText()
    assert(report:find("Missing APIs"), report)
    assert(report:find("Talents: 1 tabs"), report)
    assert(SoulFoundDB.lastCheck.report == report)
end)

test("trace on, events, export includes trace", function()
    slash("trace on")
    fake.event("QUEST_ACCEPTED", 3, 747)
    fake.event("QUEST_ACCEPTED", 748)
    fake.event("QUEST_TURNED_IN", 747, 100, 50)
    fake.event("PLAYER_DEAD")
    slash("export")
    local _, data = SF.Codec.decode(fake.find("SoulFoundStringWindow").edit:GetText())
    assert(#data.trace == 4, "4 entries, got " .. #data.trace)
    assert(data.trace[1].q == 747 and data.trace[2].q == 748 and data.trace[3].e == "T")
    slash("trace off")
    fake.event("PLAYER_DEAD")
    assert(#SoulFoundCharDB.trace.entries == 4, "off stops logging")
    slash("trace clear")
    assert(#SoulFoundCharDB.trace.entries == 0)
end)

test("a full export stays pasteable", function()
    local ids = {}
    for i = 1, 1500 do ids[i] = 100 + i * 7 end
    C_QuestLog = C_QuestLog or {}
    C_QuestLog.GetAllCompletedQuestIDs = function() return ids end
    slash("trace on")
    for i = 1, 1200 do fake.event("QUEST_ACCEPTED", 1000 + i) end
    slash("export")
    local text = fake.find("SoulFoundStringWindow").edit:GetText()
    local _, data = SF.Codec.decode(text)
    assert(#data.trace == 1000, "trace capped at 1000, got " .. #data.trace)
    assert(#text < 150000, "export is " .. #text .. " bytes")
    slash("trace clear")
    slash("trace off")
    C_QuestLog.GetAllCompletedQuestIDs = nil
end)

local SKILLS = {
    { "Professions", true }, { "Mining", false, 120, 150 }, { "Skinning", false, 95, 150 },
    { "Secondary Skills", true }, { "Tailoring", false, 130, 150 }, { "Defense", false, 70, 70 },
}
GetNumSkillLines = function() return #SKILLS end
GetSkillLineInfo = function(i)
    local s = SKILLS[i]
    return s[1], s[2], true, s[3], 0, 0, s[4]
end

test("profession report", function()
    slash("prof")
    assert(saw("Mining 120/150: skill%-ups from Silver Vein, Tin Vein%. Next: Iron Deposit at 125"), table.concat(printed, " || "))
    assert(saw("Skinning 95/150: skin mobs up to level 19"))
    assert(saw("Tailoring 130/150"))
    assert(not saw("Defense"), "weapon skills aren't professions")
end)

test("skill-up notices: unlocks and training", function()
    SF.Professions.prime()
    SKILLS[2][3] = 125
    SKILLS[3][3] = 100
    fake.event("SKILL_LINES_CHANGED")
    assert(saw("Mining 125: you can now gather Iron Deposit"), table.concat(printed, " || "))
    assert(saw("Skinning 100: you can skin mobs up to level 20"))
    printed = {}
    SKILLS[2][3] = 126
    fake.event("SKILL_LINES_CHANGED")
    assert(#printed == 0, "no repeat notices: " .. table.concat(printed, " || "))
end)

test("plan professions: reminder for ones not learned", function()
    SoulFoundCharDB.plan = { format = "soulfound-plan", professions = { primary = { "Leatherworking", "Skinning" } } }
    SF.Professions.remindPlan()
    assert(saw("Leatherworking"), table.concat(printed, " || "))
    assert(not saw("Skinning and"), "Skinning is already learned")
    SoulFoundCharDB.plan = nil
end)

test("crafting window recommends a recipe", function()
    local RECIPES = {
        { "Tailoring", "header" }, { "Linen Bag", "trivial", 4 }, { "Brown Linen Pants", "medium", 1 },
        { "Gray Woolen Shirt", "optimal", 0 },
    }
    GetNumTradeSkills = function() return #RECIPES end
    GetTradeSkillInfo = function(i) local r = RECIPES[i]; return r[1], r[2], r[3] or 0 end
    GetTradeSkillNumReagents = function() return 2 end
    GetTradeSkillReagentInfo = function(_, r) if r == 1 then return "Wool Cloth", nil, 2, 1 end return "Gray Dye", nil, 1, 0 end
    fake.event("TRADE_SKILL_SHOW")
    assert(saw("craft .*Brown Linen Pants.* next %(you can make 1%)"), table.concat(printed, " || "))
    printed = {}
    fake.event("TRADE_SKILL_UPDATE")
    assert(#printed == 0, "same pick isn't repeated")
    RECIPES[3][3] = 0
    fake.event("TRADE_SKILL_UPDATE")
    assert(saw("Gray Woolen Shirt.*materials: Wool Cloth 1/2, Gray Dye 0/1"), table.concat(printed, " || "))
    fake.event("TRADE_SKILL_CLOSE")
end)

test("export includes professions", function()
    slash("export")
    local _, data = SF.Codec.decode(fake.find("SoulFoundStringWindow").edit:GetText())
    assert(#data.professions == 3 and data.professions[1].name == "Mining", "got " .. #data.professions)
end)

test("reset removes the plan", function()
    slash("reset")
    assert(SoulFoundCharDB.plan == nil)
end)

test("no errors were logged", function()
    local errs = SoulFoundDB.errors or {}
    assert(#errs == 0, errs[1] and errs[1].msg)
end)

test("errors in handlers are caught and logged", function()
    GetNumQuestChoices = function() error("boom") end
    fake.event("QUEST_COMPLETE")
    assert(#SoulFoundDB.errors == 1 and SoulFoundDB.errors[1].msg:find("boom"))
end)

print(string.format("integration: %d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
