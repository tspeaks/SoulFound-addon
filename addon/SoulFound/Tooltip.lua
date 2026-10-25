-- Adds one SoulFound line to item tooltips. Skipped in combat, where Forever can
-- restrict tooltip data.
local _, SF = ...

local Tooltip = {}
SF.Tooltip = Tooltip

local function addLine(tooltip, link)
    if SF.inCombat() or not link or SF.isSecret(link) then return end
    if tooltip == SF.scanner then return end
    local plan = SF.plan()
    if not plan or not plan.stat_values then return end
    local e = SF.Gear.evaluate(link, plan.stat_values)
    if not e or (e.score == 0 and not e.delta) then return end
    local text = string.format("SoulFound: %.1f", e.score)
    if e.unusable then
        text = text .. " |cffff6060(can't use)|r"
    elseif e.delta then
        text = text .. string.format(" %s(%+.1f vs equipped)|r", e.delta > 0 and "|cff40ff40" or "|cffff8080", e.delta)
    end
    tooltip:AddLine(text, 0.56, 0.84, 1)
    if tooltip.Show then tooltip:Show() end
end

local function linkFrom(tooltip)
    if tooltip and tooltip.GetItem then
        local _, link = tooltip:GetItem()
        return link
    end
end

function Tooltip.install()
    local addPostCall = SF.api("TooltipDataProcessor.AddTooltipPostCall")
    local itemType = Enum and Enum.TooltipDataType and Enum.TooltipDataType.Item
    if addPostCall and itemType then
        addPostCall(itemType, SF.wrap(function(tooltip, data)
            addLine(tooltip, linkFrom(tooltip) or (data and data.hyperlink))
        end))
        Tooltip.mode = "TooltipDataProcessor"
        return
    end
    for _, tip in ipairs({ GameTooltip, ItemRefTooltip }) do
        if tip and tip.HookScript then
            tip:HookScript("OnTooltipSetItem", SF.wrap(function(self)
                addLine(self, linkFrom(self))
            end))
        end
    end
    Tooltip.mode = "OnTooltipSetItem"
end
