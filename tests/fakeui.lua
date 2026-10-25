-- A small fake of WoW's frame API: enough state to drive the addon's windows,
-- events and slash commands in tests. Unknown methods are no-ops.
local fake = { frames = {} }

local Object = {}
Object.__index = function(t, k)
    local m = rawget(Object, k)
    if m then return m end
    return function() return nil end
end

local function new(kind, name, parent)
    local o = setmetatable({ kind = kind, name = name, parent = parent, scripts = {}, shown = true,
        text = "", events = {}, lines = {} }, Object)
    if name then _G[name] = o end
    table.insert(fake.frames, o)
    return o
end

function Object:SetScript(event, fn) self.scripts[event] = fn end
function Object:GetScript(event) return self.scripts[event] end
function Object:HookScript(event, fn)
    local old = self.scripts[event]
    self.scripts[event] = function(...)
        if old then old(...) end
        fn(...)
    end
end
function Object:Fire(event, ...)
    local fn = self.scripts[event]
    if fn then return fn(self, ...) end
end
function Object:Show() self.shown = true end
function Object:Hide() self.shown = false end
function Object:IsShown() return self.shown end
function Object:SetText(t) self.text = t or "" end
function Object:GetText() return self.text end
function Object:RegisterEvent(e)
    if fake.unknownEvents and fake.unknownEvents[e] then error("Attempt to register unknown event \"" .. e .. "\"") end
    self.events[e] = true
end
function Object:CreateFontString() return new("FontString") end
function Object:GetTextColor() return 1, 1, 1 end
function Object:AddLine(text) table.insert(self.lines, text) end
function Object:NumLines() return 0 end
function Object:GetItem() return self.itemName, self.itemLink end

function fake.install()
    _G.CreateFrame = function(kind, name, parent) return new(kind, name, parent) end
    _G.UIParent = new("Frame", "UIParent")
    _G.WorldFrame = new("Frame", "WorldFrame")
    _G.GameTooltip = new("GameTooltip", "GameTooltip")
    _G.ItemRefTooltip = new("GameTooltip", "ItemRefTooltip")
    _G.UISpecialFrames = {}
    _G.ChatFontNormal = {}
end

-- Sends a game event to every frame registered for it.
function fake.event(event, ...)
    for _, f in ipairs(fake.frames) do
        if f.events[event] then f:Fire("OnEvent", event, ...) end
    end
end

function fake.find(name) return _G[name] end

return fake
