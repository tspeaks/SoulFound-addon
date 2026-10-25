-- Run from the repo root: lua5.1 tests/addon_test.lua [write-fixture|read-plan]
package.path = "tests/?.lua;" .. package.path
local stub = require("wowstub")
stub.install()
local SF = stub.loadAddon("addon/SoulFound")
SoulFoundDB, SoulFoundCharDB = {}, {}

local passed, failed = 0, 0
local function test(name, fn)
    local ok, err = pcall(fn)
    if ok then
        passed = passed + 1
    else
        failed = failed + 1
        print("FAIL " .. name .. ": " .. tostring(err))
    end
end
local function eq(a, b, msg)
    if a ~= b then error((msg or "") .. " expected " .. tostring(b) .. ", got " .. tostring(a), 2) end
end

test("base64 vectors", function()
    eq(SF.Base64.encode("Man"), "TWFu")
    eq(SF.Base64.encode("Ma"), "TWE=")
    eq(SF.Base64.encode("M"), "TQ==")
    eq(SF.Base64.decode("TWFu"), "Man")
    eq(SF.Base64.decode("TWE="), "Ma")
    eq(SF.Base64.decode("TQ=="), "M")
    local all = {}
    for i = 0, 255 do all[#all + 1] = string.char(i) end
    local s = table.concat(all)
    eq(SF.Base64.decode(SF.Base64.encode(s)), s, "all bytes")
end)

test("json round trip", function()
    local data = {
        name = 'Sir "Quote" \\ \n tab\t', level = 14, ratio = 0.25, neg = -3,
        ok = true, no = false, list = { 1, 2, 3 }, empty = SF.Json.array({}),
        obj = {}, nested = { { a = 1 }, { b = "x" } }, unicode = "Café ☃",
    }
    local text = SF.Json.encode(data)
    local back = SF.Json.decode(text)
    eq(back.name, data.name)
    eq(back.level, 14)
    eq(back.ratio, 0.25)
    eq(back.neg, -3)
    eq(back.ok, true)
    eq(back.no, false)
    eq(#back.list, 3)
    eq(#back.empty, 0)
    eq(back.nested[2].b, "x")
    eq(back.unicode, "Café ☃")
    assert(text:find('"empty":%[%]'), "empty array encodes as []")
    assert(text:find('"obj":{}'), "empty object encodes as {}")
    eq(SF.Json.decode('"\\u00e9\\ud83d\\ude00"'), "é😀", "unicode escapes")
end)

test("json rejects garbage", function()
    assert(not pcall(SF.Json.decode, "{bad"))
    assert(not pcall(SF.Json.decode, '{"a":1} extra'))
end)

test("codec", function()
    local str = SF.Codec.encode("plan", { format = "soulfound-plan", title = "T" })
    eq(str:sub(1, 5), "SF1P:")
    local kind, data = SF.Codec.decode("  " .. str:sub(1, 20) .. "\n" .. str:sub(21) .. " ")
    eq(kind, "plan")
    eq(data.title, "T")
    local k2, msg = SF.Codec.decode("hello")
    eq(k2, nil)
    assert(msg:find("SF1"))
end)

local function lines(texts)
    local out = {}
    for i, t in ipairs(texts) do out[i] = { text = t, r = 1, g = 1, b = 1 } end
    return out
end

test("stat parsing", function()
    local stats, unusable = SF.Stats.parseLines(lines({
        "Thug Boots", "Binds when equipped", "Feet Leather", "45 Armor", "+3 Agility", "+2 Stamina",
        "Equip: Increases your chance to dodge an attack by 1%.",
        "Equip: Increases your chance to parry an attack by 1%.",
        "Equip: Improves your chance to get a critical strike by 1%.",
        "Equip: Improves your chance to hit by 1%.",
        "Equip: +20 Attack Power.",
        "(3) Set: +10 Agility.",
        "Use: Increases agility by +50.",
    }))
    eq(stats.armor, 45)
    eq(stats.agility, 3)
    eq(stats.stamina, 2)
    eq(stats.dodge, 1)
    eq(stats.parry, 1)
    eq(stats.crit, 1)
    eq(stats.hit, 1)
    eq(stats.attack_power, 20)
    eq(unusable, false)

    local weapon = SF.Stats.parseLines(lines({
        "Cruel Barb", "One-Hand Sword", "30 - 57 Damage Speed 2.80", "(15.5 damage per second)", "+12 Strength",
        "Equip: Improves your chance to get a critical strike with spells by 1%.",
        "Equip: +24 ranged Attack Power.",
        "Equip: Restores 3 mana per 5 sec.",
        "Equip: Increases healing done by spells and effects by up to 22.",
        "Equip: Increases damage and healing done by magical spells and effects by up to 12.",
    }))
    eq(weapon.weapon_dps, 15.5)
    eq(weapon.strength, 12)
    eq(weapon.spell_crit, 1)
    eq(weapon.crit, nil)
    eq(weapon.ranged_attack_power, 24)
    eq(weapon.attack_power, nil)
    eq(weapon.mp5, 3)
    eq(weapon.healing, 22)
    eq(weapon.spell_power, 12)

    local red = lines({ "Chain Vest", "Mail" })
    red[2].r, red[2].g, red[2].b = 1, 0.13, 0.13
    local _, isUnusable = SF.Stats.parseLines(red)
    eq(isUnusable, true)
end)

test("score", function()
    eq(SF.Stats.score({ agility = 3, dodge = 1 }, { agility = 1, dodge = 20 }), 23)
    eq(SF.Stats.score({ agility = 3 }, nil), 0)
end)

test("next talent from order", function()
    local index = {
        ["Lightning Reflexes"] = { rank = 2, max = 5, tab = "Combat" },
        ["Deflection"] = { rank = 0, max = 5, tab = "Combat" },
    }
    local order = { "Lightning Reflexes", "Lightning Reflexes", "Lightning Reflexes", "Deflection", "Made Up" }
    local nextTalent, missing = SF.Talents.nextFromOrder(order, index)
    eq(nextTalent.name, "Lightning Reflexes")
    eq(nextTalent.rank, 3)
    index["Lightning Reflexes"].rank = 3
    nextTalent, missing = SF.Talents.nextFromOrder(order, index)
    eq(nextTalent.name, "Deflection")
    eq(nextTalent.rank, 1)
    index["Deflection"].rank = 1
    nextTalent, missing = SF.Talents.nextFromOrder(order, index)
    eq(nextTalent, nil)
    eq(missing[1], "Made Up")
end)

test("reward ranking", function()
    GetItemInfo = function(link)
        local sells = { A = 100, B = 900, C = 50 }
        return link, nil, nil, nil, nil, nil, nil, nil, nil, nil, sells[link]
    end
    local evals = {
        A = { score = 10, delta = 4 },
        B = { score = 20, delta = 9, unusable = true },
        C = { score = 8, delta = 6 },
    }
    local ranked = SF.Rewards.rank({ "A", "B", "C" }, function(l) return evals[l] end)
    eq(ranked[1].link, "C", "best usable upgrade first")
    eq(ranked[2].link, "A")
    eq(ranked[3].link, "B", "unusable last")
end)

test("profession tiers, skinning, training", function()
    local useful, nextNode = SF.Professions.gatherAdvice("Mining", 130)
    eq(table.concat(useful, ","), "Iron Deposit,Silver Vein,Tin Vein")
    eq(nextNode[2], "Gold Vein")
    useful, nextNode = SF.Professions.gatherAdvice("Mining", 120)
    eq(table.concat(useful, ","), "Silver Vein,Tin Vein")
    eq(nextNode[2], "Iron Deposit")
    useful = SF.Professions.gatherAdvice("Mining", 64)
    eq(table.concat(useful, ","), "Copper Vein")
    eq(#SF.Professions.gatherAdvice("Herbalism", 280), 3, "capped at three")
    eq(SF.Professions.gatherAdvice("Tailoring", 50), nil)
    eq(SF.Professions.skinnableLevel(1), 10)
    eq(SF.Professions.skinnableLevel(95), 19)
    eq(SF.Professions.skinnableLevel(150), 30)
    assert(SF.Professions.trainNeeded("Tailoring", 50, 75, 9):find("level 10"))
    assert(SF.Professions.trainNeeded("Tailoring", 52, 75, 12):find("Journeyman"))
    eq(SF.Professions.trainNeeded("Tailoring", 40, 75, 12), nil)
    eq(SF.Professions.trainNeeded("Fishing", 75, 75, 30), nil)
    eq(SF.Professions.trainNeeded("Tailoring", 300, 300, 60), nil)
end)

test("recipe pick", function()
    local pick = SF.Professions.pickRecipe({
        { name = "Grey", type = "trivial", available = 9 },
        { name = "Yellow ready", type = "medium", available = 2 },
        { name = "Orange needs mats", type = "optimal", available = 0 },
        { name = "Orange ready", type = "optimal", available = 1 },
    })
    eq(pick.name, "Orange ready")
    pick = SF.Professions.pickRecipe({ { name = "O", type = "optimal", available = 0 }, { name = "Y", type = "medium", available = 3 } })
    eq(pick.name, "Y", "a yellow you can make beats an orange you can't")
    eq(SF.Professions.pickRecipe({ { name = "G", type = "easy", available = 5 } }), nil)
end)

-- Classic-style talent tree used by the export fixture.
local TREE = {
    { name = "Assassination", talents = { { "Improved Eviscerate", 1, 1, 0, 3 }, { "Malice", 2, 3, 0, 5 } } },
    { name = "Combat", talents = {
        { "Improved Gouge", 1, 1, 0, 3 }, { "Improved Sinister Strike", 1, 2, 0, 2 },
        { "Lightning Reflexes", 1, 3, 4, 5 }, { "Deflection", 2, 2, 0, 5 },
        { "Precision", 2, 3, 0, 5 }, { "Endurance", 3, 1, 0, 2 }, { "Riposte", 3, 2, 0, 1, { 2, 2 } },
    } },
    { name = "Subtlety", talents = { { "Master of Deception", 1, 2, 0, 5 } } },
}

local function installTree()
    GetNumTalentTabs = function() return #TREE end
    GetTalentTabInfo = function(tab)
        local spent = 0
        for _, t in ipairs(TREE[tab].talents) do spent = spent + t[4] end
        return TREE[tab].name, "icon", spent, "bg"
    end
    GetNumTalents = function(tab) return #TREE[tab].talents end
    GetTalentInfo = function(tab, i)
        local t = TREE[tab].talents[i]
        return t[1], "icon", t[2], t[3], t[4], t[5]
    end
    GetTalentPrereqs = function(tab, i)
        local p = TREE[tab].talents[i][6]
        if p then return p[1], p[2], true end
    end
    UnitCharacterPoints = function() return 1 end
end

test("state collect", function()
    installTree()
    local data = SF.State.collect()
    eq(data.format, "soulfound-export")
    eq(data.char.class, "ROGUE")
    eq(data.client.forever, true)
    eq(data.talents.available, true)
    eq(data.talents.unspent, 1)
    eq(#data.talents.tabs, 3)
    eq(data.talents.tabs[2].talents[3].rank, 4)
    eq(data.talents.tabs[2].talents[7].prereq[1], 2)
    local text = SF.Json.encode(data)
    assert(text:find('"gear":%[%]'), "empty gear encodes as []")
end)

test("talent tab info with numeric id first", function()
    installTree()
    local original = GetTalentTabInfo
    GetTalentTabInfo = function(tab)
        local name, _, spent = original(tab)
        return 100 + tab, name, "desc", "icon", spent, "bg"
    end
    local tree = SF.State.talents()
    eq(tree.tabs[2].name, "Combat")
    eq(tree.tabs[2].spent, 4)
    GetTalentTabInfo = original
end)

test("missing talent API is reported, not an error", function()
    local saved = GetNumTalentTabs
    GetNumTalentTabs = nil
    eq(SF.State.talents().available, false)
    GetNumTalentTabs = saved
end)

local mode = arg[1]
if mode == "write-fixture" then
    installTree()
    local f = assert(io.open("tests/out/export_rogue.txt", "w"))
    f:write(SF.Codec.encode("export", SF.State.collect()))
    f:close()
elseif mode == "read-plan" then
    test("import plan built by the web planner", function()
        local f = assert(io.open("tests/out/plan_rogue.txt"))
        local kind, plan = SF.Codec.decode(f:read("*a"))
        f:close()
        eq(kind, "plan")
        eq(plan.format, "soulfound-plan")
        eq(plan.class, "ROGUE")
        assert(plan.stat_values.agility > 0, "has stat values")
        installTree()
        SoulFoundCharDB.plan = plan
        local nextTalent = SF.Talents.next()
        eq(nextTalent.name, "Lightning Reflexes", "next point continues Lightning Reflexes")
        eq(nextTalent.rank, 5)
    end)
end

if mode == "read-plan" then
    local f = io.open("tests/out/plan_from_page.txt")
    if f then
        test("import plan made by the planner page", function()
            local kind, plan = SF.Codec.decode(f:read("*a"))
            f:close()
            eq(kind, "plan")
            eq(plan.class, "ROGUE")
            assert(#plan.talent_order > 0 and plan.stat_values.dodge > 0)
        end)
    end
end

print(string.format("lua: %d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
