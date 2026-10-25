-- Windows: a copy/paste box for strings, the plan panel, and reward picks.
local _, SF = ...

local UI = {}
SF.UI = UI

local BACKDROP = {
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 },
}

local function makeFrame(name, width, height)
    local f = CreateFrame("Frame", name, UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    f:SetSize(width, height)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    if f.SetBackdrop then f:SetBackdrop(BACKDROP) end
    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    f.title:SetPoint("TOP", 0, -18)
    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -6, -6)
    if UISpecialFrames then tinsert(UISpecialFrames, name) end
    f:Hide()
    return f
end

local function makeButton(parent, label, width)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(width or 110, 22)
    b:SetText(label)
    return b
end

local stringWindow

local function getStringWindow()
    if stringWindow then return stringWindow end
    local f = makeFrame("SoulFoundStringWindow", 560, 380)

    f.hint = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.hint:SetPoint("TOPLEFT", 22, -44)
    f.hint:SetPoint("TOPRIGHT", -22, -44)
    f.hint:SetJustifyH("LEFT")

    local scroll = CreateFrame("ScrollFrame", "SoulFoundStringScroll", f, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 22, -66)
    scroll:SetPoint("BOTTOMRIGHT", -40, 48)

    local edit = CreateFrame("EditBox", nil, scroll)
    edit:SetMultiLine(true)
    edit:SetFontObject(ChatFontNormal)
    edit:SetWidth(490)
    edit:SetHeight(260)
    edit:SetAutoFocus(false)
    edit:SetMaxLetters(0)
    edit:SetScript("OnEscapePressed", function() f:Hide() end)
    edit:SetScript("OnTextChanged", function(self, userInput)
        if userInput and f.readOnly then
            self:SetText(f.readOnly)
            self:HighlightText()
        end
    end)
    scroll:SetScrollChild(edit)
    scroll:EnableMouse(true)
    scroll:SetScript("OnMouseDown", function() edit:SetFocus() end)
    f.edit = edit

    f.action = makeButton(f, "Import")
    f.action:SetPoint("BOTTOMRIGHT", -22, 18)
    f.select = makeButton(f, "Select all")
    f.select:SetPoint("BOTTOMLEFT", 22, 18)
    f.select:SetScript("OnClick", function()
        edit:SetFocus()
        edit:HighlightText()
    end)

    stringWindow = f
    return f
end

-- Shows text the player copies out (export, check report).
function UI.showCopy(title, hint, text)
    local f = getStringWindow()
    f.title:SetText(title)
    f.hint:SetText(hint)
    f.readOnly = text
    f.edit:SetText(text)
    f.action:Hide()
    f:Show()
    f.edit:SetFocus()
    f.edit:HighlightText()
end

-- Shows an empty box for pasting, and calls onSubmit(text).
function UI.showPaste(title, hint, onSubmit)
    local f = getStringWindow()
    f.title:SetText(title)
    f.hint:SetText(hint)
    f.readOnly = nil
    f.edit:SetText("")
    f.action:SetText("Import")
    f.action:SetScript("OnClick", function()
        if onSubmit(f.edit:GetText()) then f:Hide() end
    end)
    f.action:Show()
    f:Show()
    f.edit:SetFocus()
end

local function textPanel(name, width, maxLines)
    local f = makeFrame(name, width, 60 + maxLines * 16)
    f.lines = {}
    for i = 1, maxLines do
        local fs = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        fs:SetPoint("TOPLEFT", 22, -44 - (i - 1) * 16)
        fs:SetPoint("RIGHT", -22, 0)
        fs:SetJustifyH("LEFT")
        fs:SetWordWrap(false)
        f.lines[i] = fs
    end
    function f:SetLines(lines)
        for i, fs in ipairs(self.lines) do fs:SetText(lines[i] or "") end
    end
    return f
end

local planPanel

local STAT_LABELS = {
    agility = "Agility", strength = "Strength", stamina = "Stamina", intellect = "Intellect",
    spirit = "Spirit", armor = "Armor", weapon_dps = "Weapon DPS", attack_power = "Attack Power",
    ranged_attack_power = "Ranged AP", crit = "Crit %", hit = "Hit %", dodge = "Dodge %",
    parry = "Parry %", block = "Block %", defense = "Defense", spell_power = "Spell Power",
    healing = "Healing", mp5 = "Mana/5", spell_crit = "Spell Crit %", spell_hit = "Spell Hit %",
}

function UI.showPlan()
    local plan = SF.plan()
    if not plan then
        SF.print("no plan yet. Use /sf export, build a plan on the website, then /sf import.")
        return
    end
    planPanel = planPanel or textPanel("SoulFoundPlanPanel", 420, 14)
    planPanel.title:SetText(plan.title or "Your SoulFound plan")
    local lines = {}
    local nextTalent = SF.Talents.next()
    lines[#lines + 1] = nextTalent
        and string.format("Next talent: |cffffd100%s|r (%d/%d)", nextTalent.name, nextTalent.rank, nextTalent.max)
        or "Next talent: none left in the plan"
    local stats = {}
    for stat, v in pairs(plan.stat_values or {}) do stats[#stats + 1] = { stat = stat, v = v } end
    table.sort(stats, function(a, b) return a.v > b.v end)
    local top = {}
    for i = 1, math.min(5, #stats) do
        top[#top + 1] = (STAT_LABELS[stats[i].stat] or stats[i].stat) .. string.format(" %.2g", stats[i].v)
    end
    lines[#lines + 1] = "Stat values: " .. table.concat(top, ", ")
    lines[#lines + 1] = " "
    for _, tip in ipairs(plan.advice or {}) do
        if #lines >= 14 then break end
        lines[#lines + 1] = "- " .. tip
    end
    planPanel:SetLines(lines)
    planPanel:Show()
end

local rewardPanel

function UI.showRewards(lines)
    rewardPanel = rewardPanel or textPanel("SoulFoundRewardPanel", 380, 8)
    rewardPanel.title:SetText("SoulFound reward pick")
    rewardPanel:SetLines(lines)
    rewardPanel:ClearAllPoints()
    if QuestFrame and QuestFrame:IsShown() then
        rewardPanel:SetPoint("TOPLEFT", QuestFrame, "TOPRIGHT", 0, 0)
    else
        rewardPanel:SetPoint("CENTER", 300, 0)
    end
    rewardPanel:Show()
end

function UI.hideRewards()
    if rewardPanel then rewardPanel:Hide() end
end
