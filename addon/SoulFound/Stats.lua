-- Reads item stats from tooltip text and scores them with the plan's stat values.
-- Text patterns are English-only for the MVP.
local _, SF = ...

local Stats = {}
SF.Stats = Stats

-- One pattern per line; the first match wins. Order matters where texts overlap.
Stats.PATTERNS = {
    { "^%+(%d+) Agility", "agility" },
    { "^%+(%d+) Strength", "strength" },
    { "^%+(%d+) Stamina", "stamina" },
    { "^%+(%d+) Intellect", "intellect" },
    { "^%+(%d+) Spirit", "spirit" },
    { "^(%d+) Armor", "armor" },
    { "%(([%d%.]+) damage per second%)", "weapon_dps" },
    { "chance to dodge an attack by ([%d%.]+)%%", "dodge" },
    { "chance to parry an attack by ([%d%.]+)%%", "parry" },
    { "chance to block attacks with a shield by ([%d%.]+)%%", "block" },
    { "critical strike with spells by ([%d%.]+)%%", "spell_crit" },
    { "chance to get a critical strike by ([%d%.]+)%%", "crit" },
    { "chance to hit with spells by ([%d%.]+)%%", "spell_hit" },
    { "chance to hit by ([%d%.]+)%%", "hit" },
    { "%+(%d+) ranged Attack Power", "ranged_attack_power" },
    { "%+(%d+) Attack Power", "attack_power" },
    { "damage and healing done by magical spells and effects by up to (%d+)", "spell_power" },
    { "healing done by spells and effects by up to (%d+)", "healing" },
    { "[Rr]estores (%d+) mana per 5 sec", "mp5" },
    { "Increased Defense %+(%d+)", "defense" },
}

local function isRed(r, g, b)
    return r and g and b and r > 0.95 and g < 0.2 and b < 0.2
end

-- Lines that never describe the item's own equipped stats.
local function skipLine(text)
    return text:find("Set:", 1, true) or text:find("^Use:") or text:find("^Chance on hit:")
end

-- Parses a list of { text, r, g, b } lines.
function Stats.parseLines(lines)
    local stats, unusable = {}, false
    for i, line in ipairs(lines) do
        local text = line.text
        if i > 1 and isRed(line.r, line.g, line.b) then unusable = true end
        if type(text) == "string" and not skipLine(text) then
            for _, p in ipairs(Stats.PATTERNS) do
                local value = text:match(p[1])
                if value then
                    stats[p[2]] = (stats[p[2]] or 0) + (tonumber(value) or 0)
                    break
                end
            end
        end
    end
    return stats, unusable
end

local scanner
local function scanTooltip(link)
    if not CreateFrame then return nil end
    if not scanner then
        scanner = CreateFrame("GameTooltip", "SoulFoundScanTip", nil, "GameTooltipTemplate")
        SF.scanner = scanner
    end
    scanner:SetOwner(WorldFrame, "ANCHOR_NONE")
    scanner:ClearLines()
    scanner:SetHyperlink(link)
    local lines = {}
    for i = 1, scanner:NumLines() do
        local fs = _G["SoulFoundScanTipTextLeft" .. i]
        local text = fs and fs:GetText()
        if text and not SF.isSecret(text) then
            local r, g, b = fs:GetTextColor()
            lines[#lines + 1] = { text = text, r = r, g = g, b = b }
        end
    end
    scanner:Hide()
    return lines
end

-- Returns tooltip lines for an item link, preferring structured tooltip data.
function Stats.tooltipLines(link)
    local getHyperlink = SF.api("C_TooltipInfo.GetHyperlink")
    if getHyperlink then
        local ok, data = pcall(getHyperlink, link)
        if ok and type(data) == "table" and type(data.lines) == "table" then
            local surface = SF.api("TooltipUtil.SurfaceArgs")
            local lines = {}
            for _, l in ipairs(data.lines) do
                if l.leftText == nil and surface then pcall(surface, l) end
                local text = l.leftText
                if type(text) == "string" and not SF.isSecret(text) then
                    local c = l.leftColor
                    lines[#lines + 1] = { text = text, r = c and c.r, g = c and c.g, b = c and c.b }
                end
            end
            if #lines > 0 then return lines, "C_TooltipInfo" end
        end
    end
    return scanTooltip(link), "scan"
end

local cache = {}

-- Returns { stats, unusable } for an item link, or nil if the item isn't loaded yet.
function Stats.read(link)
    if type(link) ~= "string" then return nil end
    local hit = cache[link]
    if hit then return hit end
    local lines = Stats.tooltipLines(link)
    if not lines or #lines < 2 then return nil end
    for _, l in ipairs(lines) do
        if l.text:find("Retrieving item information", 1, true) then return nil end
    end
    local stats, unusable = Stats.parseLines(lines)
    local result = { stats = stats, unusable = unusable }
    cache[link] = result
    return result
end

function Stats.clearCache()
    cache = {}
end

function Stats.score(stats, values)
    local total = 0
    if not stats or not values then return 0 end
    for stat, amount in pairs(stats) do
        total = total + amount * (tonumber(values[stat]) or 0)
    end
    return total
end
