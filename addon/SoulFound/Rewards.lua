-- On the quest turn-in screen, ranks the reward choices for the player's build.
local _, SF = ...

local Rewards = {}
SF.Rewards = Rewards

local function getItemInfo(link)
    local f = SF.api("C_Item.GetItemInfo") or GetItemInfo
    if not f then return nil end
    local ok, name, _, _, _, _, _, _, _, _, _, sellPrice = pcall(f, link)
    if not ok then return nil end
    return name, sellPrice
end

-- Returns choices sorted best-first: { index, link, score, delta, unusable, sell }.
function Rewards.rank(links, evaluate)
    local ranked = {}
    for i, link in ipairs(links) do
        local e = evaluate(link)
        local _, sell = getItemInfo(link)
        ranked[#ranked + 1] = {
            index = i, link = link,
            score = e and e.score, delta = e and e.delta,
            unusable = e and e.unusable or false, sell = sell or 0,
        }
    end
    table.sort(ranked, function(a, b)
        if a.unusable ~= b.unusable then return not a.unusable end
        local da, db = a.delta or -math.huge, b.delta or -math.huge
        if da ~= db then return da > db end
        return a.sell > b.sell
    end)
    return ranked
end

local function money(copper)
    if GetCoinTextureString then return GetCoinTextureString(copper) end
    return string.format("%dc", copper)
end

local function itemLinks(kind, count)
    local links = {}
    for i = 1, count or 0 do
        local link = GetQuestItemLink(kind, i)
        if link then links[#links + 1] = link end
    end
    return links
end

-- When a quest is offered, says if its rewards hold an upgrade for the build.
function Rewards.onQuestDetail()
    if not (GetNumQuestChoices and GetQuestItemLink) then return end
    local plan = SF.plan()
    if not plan or not plan.stat_values then return end
    local links = itemLinks("choice", GetNumQuestChoices())
    for _, link in ipairs(itemLinks("reward", GetNumQuestRewards and GetNumQuestRewards() or 0)) do
        links[#links + 1] = link
    end
    if #links == 0 then return end
    local best = Rewards.rank(links, function(link) return SF.Gear.evaluate(link, plan.stat_values) end)[1]
    if best.delta and best.delta > 0 and not best.unusable then
        SF.print(string.format("this quest rewards an upgrade for your build: %s (|cff40ff40+%.1f|r)", best.link, best.delta))
    end
end

function Rewards.onQuestComplete()
    if not (GetNumQuestChoices and GetQuestItemLink) then return end
    local n = GetNumQuestChoices() or 0
    if n < 1 then return end
    local plan = SF.plan()
    if not plan or not plan.stat_values then
        SF.print("import a plan (/sf import) to get reward picks for your build.")
        return
    end
    local links = itemLinks("choice", n)
    if #links == 0 then return end

    local ranked = Rewards.rank(links, function(link) return SF.Gear.evaluate(link, plan.stat_values) end)
    local best = ranked[1]
    local lines = {}
    if best.delta and best.delta > 0 and not best.unusable then
        lines[#lines + 1] = string.format("Pick %s: |cff40ff40+%.1f|r for your build", best.link, best.delta)
    else
        local bySell = ranked[1]
        for _, r in ipairs(ranked) do
            if r.sell > bySell.sell then bySell = r end
        end
        lines[#lines + 1] = "No upgrade here for your build."
        if bySell.sell > 0 then
            lines[#lines + 1] = string.format("Best to sell: %s (%s)", bySell.link, money(bySell.sell))
        end
    end
    for _, r in ipairs(ranked) do
        local note
        if r.unusable then
            note = "|cffff6060can't use|r"
        elseif r.delta then
            note = string.format("%s%+.1f|r", r.delta > 0 and "|cff40ff40" or "|cffaaaaaa", r.delta)
        else
            note = "not scored"
        end
        lines[#lines + 1] = string.format("  %s  %s", r.link, note)
    end
    for _, line in ipairs(lines) do SF.print(line) end
    if SF.UI and SF.UI.showRewards then SF.UI.showRewards(lines) end
end
