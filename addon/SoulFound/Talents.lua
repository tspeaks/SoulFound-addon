-- Works out the next talent point from the plan and reminds the player.
-- It only tells the player; it never spends points for them.
local _, SF = ...

local Talents = {}
SF.Talents = Talents

-- Live ranks by talent name, read fresh each time.
function Talents.liveIndex()
    local tree = SF.State.talents()
    if not tree.available then return nil end
    local index = {}
    for _, tab in ipairs(tree.tabs) do
        for _, t in ipairs(tab.talents) do
            index[t.name] = { rank = t.rank, max = t.max, tab = tab.name }
        end
    end
    return index
end

-- Plan talent_order lists one name per point, in order. Returns the first entry
-- the character hasn't reached yet: name, wanted rank, max rank, tab.
-- The second return lists plan names missing from the live tree.
function Talents.nextFromOrder(order, index)
    local wanted, missing, reported = {}, {}, {}
    for _, name in ipairs(order or {}) do
        local live = index[name]
        if not live then
            if not reported[name] then
                reported[name] = true
                missing[#missing + 1] = name
            end
        else
            wanted[name] = (wanted[name] or 0) + 1
            if live.rank < wanted[name] then
                return { name = name, rank = wanted[name], max = live.max, tab = live.tab }, missing
            end
        end
    end
    return nil, missing
end

function Talents.next()
    local plan = SF.plan()
    if not plan or not plan.talent_order then return nil end
    local index = Talents.liveIndex()
    if not index then return nil end
    return Talents.nextFromOrder(plan.talent_order, index)
end

local warnedMissing = false

function Talents.remind(force)
    local plan = SF.plan()
    if not plan then return end
    local unspent = SF.State.unspentPoints()
    if not force and unspent ~= nil and unspent <= 0 then return end
    local nextTalent, missing = Talents.next()
    if missing and #missing > 0 and not warnedMissing then
        warnedMissing = true
        SF.print("your plan names talents that aren't in your tree: " .. table.concat(missing, ", ")
            .. ". Rebuild the plan from a fresh /sf export.")
    end
    if nextTalent then
        SF.print(string.format("spend your talent point: |cffffd100%s|r (%d/%d, %s)",
            nextTalent.name, nextTalent.rank, nextTalent.max, nextTalent.tab or "?"))
    elseif force then
        SF.print("your plan's talents are all spent.")
    end
end
