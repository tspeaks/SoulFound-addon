-- Events and slash commands.
local ADDON, SF = ...

local frame = CreateFrame("Frame")
local handlers = {}

local function on(event, fn)
    handlers[event] = SF.wrap(fn)
    -- Unknown events raise an error on newer clients, so register defensively.
    pcall(frame.RegisterEvent, frame, event)
end

frame:SetScript("OnEvent", function(_, event, ...)
    local fn = handlers[event]
    if fn then fn(...) end
end)

on("ADDON_LOADED", function(name)
    if name ~= ADDON then return end
    SoulFoundDB = SoulFoundDB or {}
    SoulFoundCharDB = SoulFoundCharDB or {}
end)

on("PLAYER_LOGIN", function()
    SF.Tooltip.install()
    SF.Professions.prime()
    SF.after(5, function() SF.Talents.remind(false) end)
    SF.after(6, function() SF.Professions.remindPlan() end)
end)

on("SKILL_LINES_CHANGED", function() SF.Professions.onSkillsChanged() end)
on("TRADE_SKILL_SHOW", function() SF.Professions.onTradeSkill() end)
on("TRADE_SKILL_UPDATE", function() SF.Professions.onTradeSkill() end)
on("TRADE_SKILL_CLOSE", function() SF.Professions.onTradeSkillClosed() end)

on("PLAYER_LEVEL_UP", function()
    SF.Trace.add("L")
    -- Talent points update a moment after the level-up event.
    SF.after(1.5, function() SF.Talents.remind(false) end)
end)

on("CHARACTER_POINTS_CHANGED", function()
    SF.after(0.5, function() SF.Talents.remind(false) end)
end)

on("QUEST_COMPLETE", function() SF.Rewards.onQuestComplete() end)
on("QUEST_DETAIL", function() SF.Rewards.onQuestDetail() end)
on("QUEST_FINISHED", function() SF.UI.hideRewards() end)

on("QUEST_ACCEPTED", function(a, b)
    -- Classic passes (logIndex, questID); newer clients pass (questID).
    SF.Trace.add("A", b or a)
end)
on("QUEST_TURNED_IN", function(questID) SF.Trace.add("T", questID) end)
on("PLAYER_DEAD", function() SF.Trace.add("D") end)

local function export()
    if SF.inCombat() then
        SF.print("leave combat first.")
        return
    end
    SF.Stats.clearCache()
    local str = SF.Codec.encode("export", SF.State.collect())
    SF.UI.showCopy("SoulFound export",
        "Press Ctrl+C to copy, then paste it into the SoulFound planner.", str)
end

local function importPlan(text)
    local kind, data = SF.Codec.decode(text)
    if not kind then
        SF.print(data)
        return false
    end
    if kind ~= "plan" or data.format ~= "soulfound-plan" then
        SF.print("that's a SoulFound string, but not a plan. Paste the plan from the planner.")
        return false
    end
    local _, classFile = UnitClass("player")
    if data.class and data.class ~= classFile then
        SF.print(string.format("this plan is for a %s, but you're a %s. Not imported.", data.class, tostring(classFile)))
        return false
    end
    SoulFoundCharDB.plan = data
    SF.print("plan imported: " .. tostring(data.title or "untitled"))
    SF.Talents.remind(true)
    SF.Professions.remindPlan()
    return true
end

local HELP = {
    "/sf export: copy your character's state for the planner",
    "/sf import: paste a plan from the planner",
    "/sf show: show your plan",
    "/sf talent: show your next talent point",
    "/sf prof: your professions, what to gather or craft, and when to train",
    "/sf check: test this client and copy a report",
    "/sf trace on|off|clear: opt-in play log, included in exports (off by default)",
    "/sf reset: remove the current plan",
}

SLASH_SOULFOUND1 = "/sf"
SLASH_SOULFOUND2 = "/soulfound"
SlashCmdList.SOULFOUND = SF.wrap(function(msg)
    local cmd, rest = (msg or ""):match("^%s*(%S*)%s*(.-)%s*$")
    cmd = cmd:lower()
    if cmd == "export" then
        export()
    elseif cmd == "import" then
        SF.UI.showPaste("SoulFound import", "Paste your plan with Ctrl+V, then click Import.", importPlan)
    elseif cmd == "show" then
        SF.UI.showPlan()
    elseif cmd == "talent" then
        SF.Talents.remind(true)
    elseif cmd == "prof" or cmd == "professions" then
        SF.Professions.report()
    elseif cmd == "check" then
        SF.UI.showCopy("SoulFound check", "Press Ctrl+C to copy this report.", SF.Check.run())
    elseif cmd == "trace" then
        if rest == "on" or rest == "off" then
            SF.Trace.set(rest == "on")
            SF.print("play log " .. rest .. ".")
        elseif rest == "clear" then
            SF.Trace.clear()
            SF.print("play log cleared.")
        else
            SF.print("play log is " .. (SF.Trace.enabled() and "on" or "off") .. ". Use /sf trace on or /sf trace off.")
        end
    elseif cmd == "reset" then
        SoulFoundCharDB.plan = nil
        SF.print("plan removed.")
    else
        SF.print("commands:")
        for _, line in ipairs(HELP) do SF.print(line) end
    end
end)
