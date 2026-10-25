-- Compares an item against what's equipped, using the plan's stat values.
local _, SF = ...

local Gear = {}
SF.Gear = Gear

Gear.SLOTS_BY_LOC = {
    INVTYPE_HEAD = { 1 }, INVTYPE_NECK = { 2 }, INVTYPE_SHOULDER = { 3 },
    INVTYPE_CHEST = { 5 }, INVTYPE_ROBE = { 5 }, INVTYPE_WAIST = { 6 },
    INVTYPE_LEGS = { 7 }, INVTYPE_FEET = { 8 }, INVTYPE_WRIST = { 9 },
    INVTYPE_HAND = { 10 }, INVTYPE_FINGER = { 11, 12 }, INVTYPE_TRINKET = { 13, 14 },
    INVTYPE_CLOAK = { 15 }, INVTYPE_WEAPON = { 16, 17 }, INVTYPE_2HWEAPON = { 16 },
    INVTYPE_WEAPONMAINHAND = { 16 }, INVTYPE_WEAPONOFFHAND = { 17 }, INVTYPE_SHIELD = { 17 },
    INVTYPE_HOLDABLE = { 17 }, INVTYPE_RANGED = { 18 }, INVTYPE_RANGEDRIGHT = { 18 },
    INVTYPE_THROWN = { 18 }, INVTYPE_RELIC = { 18 },
}

local function slotScore(slot, values)
    local link = GetInventoryItemLink("player", slot)
    if not link then return 0, nil end
    local read = SF.Stats.read(link)
    return read and SF.Stats.score(read.stats, values) or 0, link
end

local function offhandIsWeapon()
    local link = GetInventoryItemLink("player", 17)
    if not link then return false end
    local _, _, _, loc = SF.State.itemInfoInstant(link)
    return loc == "INVTYPE_WEAPON" or loc == "INVTYPE_WEAPONOFFHAND"
end

-- Returns { score, delta, unusable } or nil if the item can't be scored.
-- delta compares against the weakest item it could replace.
function Gear.evaluate(link, values)
    values = values or (SF.plan() and SF.plan().stat_values)
    if not values then return nil end
    local read = SF.Stats.read(link)
    if not read then return nil end
    local _, _, _, loc = SF.State.itemInfoInstant(link)
    local slots = loc and Gear.SLOTS_BY_LOC[loc]
    local score = SF.Stats.score(read.stats, values)
    if not slots then
        return { score = score, unusable = read.unusable }
    end

    local current
    if loc == "INVTYPE_2HWEAPON" then
        -- A two-hander replaces both hands.
        current = slotScore(16, values) + slotScore(17, values)
    elseif loc == "INVTYPE_WEAPON" and not offhandIsWeapon() then
        current = slotScore(16, values)
    else
        for _, slot in ipairs(slots) do
            local s = slotScore(slot, values)
            if current == nil or s < current then current = s end
        end
    end
    return { score = score, delta = score - (current or 0), unusable = read.unusable }
end
