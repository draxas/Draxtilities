-- Deterministic API doubles. These do not emulate protected execution or taint.
test = { frames = {}, items = {}, combat = false, popups = {}, messages = {}, timers = {} }
Enum = { BagIndex = { ReagentBag = 5 }, ItemQuality = { Poor = 0, Rare = 3, Heirloom = 7 },
    ForbiddenAspect = { ScriptedInput = 1 } }
function InCombatLockdown() return test.combat end
function GetUnitName() return "Test-Realm" end
function issecretvalue(value) return type(value) == "table" and value.secret == true end
function wipe(value) for key in pairs(value) do value[key] = nil end; return value end
function GetTime() return test.time or 0 end
function IsShiftKeyDown() return false end
function IsControlKeyDown() return false end
function IsAltKeyDown() return false end
function UnitExists() return false end
function SpellCanTargetItem() return false end
function SpellCanTargetItemID() return false end
function IsModifiedClick() return false end
function HandleModifiedItemClick() end
DEFAULT_CHAT_FRAME = { AddMessage = function(_, value) table.insert(test.messages, value) end }
SlashCmdList, UISpecialFrames = {}, {}

local Frame = {}
Frame.__index = Frame
function Frame:SetScript(name, callback) self.scripts[name] = callback end
function Frame:GetScript(name) return self.scripts[name] end
function Frame:RegisterEvent(event) self.events[event] = true end
function Frame:UnregisterAllEvents() wipe(self.events) end
function Frame:SetAttribute(key, value) self.attributes[key] = value end
function Frame:GetAttribute(key) return self.attributes[key] end
function Frame:Show() self.shown = true end
function Frame:Hide()
    local shown = self.shown
    self.shown = false
    if shown and self.scripts.OnHide then self.scripts.OnHide(self) end
end
function Frame:SetShown(shown) if shown then self:Show() else self:Hide() end end
function Frame:IsShown() return self.shown end
function Frame:IsVisible() return self.shown and (not self.parent or self.parent:IsVisible()) end
function Frame:IsEnabled() return self.enabled ~= false end
function Frame:Enable() self.enabled = true end
function Frame:Disable() self.enabled = false end
function Frame:GetParent() return self.parent end
function Frame:SetParent(parent) self.parent = parent end
function Frame:SetID(value) self.id = value end
function Frame:GetID() return self.id or 0 end
function Frame:GetEffectiveScale() return 1 end
function Frame:GetFrameStrata() return "MEDIUM" end
function Frame:GetFrameLevel() return 1 end
function Frame:HasAccessConstraints() return false end
function Frame:HasAnyForbiddenAspects() return false end
function Frame:SetText(text) self.text = text end
function Frame:CreateTexture() return CreateFrame("Texture") end
function Frame:CreateFontString() return CreateFrame("FontString") end
for _, name in ipairs({ "SetAllPoints", "ClearAllPoints", "SetPoint", "SetSize", "SetWidth", "SetHeight",
    "SetColorTexture", "SetFrameStrata", "SetFrameLevel", "SetScale", "EnableMouse", "EnableMouseMotion",
    "RegisterForClicks", "RegisterForDrag", "SetPassThroughButtons", "SetMovable", "StartMoving", "StopMovingOrSizing" }) do
    Frame[name] = function() end
end
function CreateFrame(_, name, parent)
    local frame = setmetatable({ scripts = {}, events = {}, attributes = {}, parent = parent, shown = true }, Frame)
    table.insert(test.frames, frame)
    if name then _G[name] = frame end
    return frame
end
UIParent = CreateFrame("Frame")
GameTooltip = CreateFrame("Frame")
function RegisterStateDriver(frame, _, condition) frame.driver = condition end
function UnregisterStateDriver(frame) frame.driver = nil end
C_Timer = { After = function(_, callback) table.insert(test.timers, callback) end }
function test.flushTimers()
    local callbacks = test.timers
    test.timers = {}
    for _, callback in ipairs(callbacks) do callback() end
end
function test.event(event, ...)
    for _, frame in ipairs(test.frames) do
        if frame.events[event] and frame.scripts.OnEvent then frame.scripts.OnEvent(frame, event, ...) end
    end
end
function test.click(frame)
    if frame.scripts.PreClick then frame.scripts.PreClick(frame, "LeftButton") end
    if frame.attributes.type == "click" then
        local target = frame.attributes.clickbutton
        target.clicks = (target.clicks or 0) + 1
    end
    if frame.scripts.PostClick then frame.scripts.PostClick(frame, "LeftButton") end
end

function test.location(bag, slot)
    return { bag = bag, slot = slot,
        HasAnyLocation = function(self) return self.bag ~= nil end,
        GetBagAndSlot = function(self) return self.bag, self.slot end }
end
ItemLocation = { CreateFromBagAndSlot = function(_, bag, slot) return test.location(bag, slot) end }
function test.put(bag, slot, guid, id, stack, quality)
    local item = { guid = guid, id = id or 100, stack = stack or 1, quality = quality or 3,
        bag = bag, slot = slot, link = "[Test item]" }
    test.items[bag .. ":" .. slot] = item
    return item
end
local function itemAt(location) return location and test.items[location.bag .. ":" .. location.slot] end
C_Item = {
    DoesItemExist = function(location) return itemAt(location) ~= nil end,
    GetItemGUID = function(location) return itemAt(location).guid end,
    GetItemID = function(location) return itemAt(location).id end,
    GetItemLink = function(location) return itemAt(location).link end,
    GetItemMaxStackSize = function(location) return itemAt(location).stack end,
    GetItemQuality = function(location) return itemAt(location).quality end,
    GetItemName = function() return "Test item" end,
    GetItemLocation = function(guid)
        for _, item in pairs(test.items) do
            if item.guid == guid then return test.location(item.bag, item.slot) end
        end
    end,
    RequestLoadItemDataByID = function(id) test.requested = id end,
}
C_Container = {
    GetContainerNumSlots = function() return 8 end,
    GetContainerItemInfo = function(bag, slot)
        local item = itemAt(test.location(bag, slot))
        return item and { itemID = item.id, quality = item.quality }
    end,
    GetContainerItemQuestInfo = function() return {} end,
    PickupContainerItem = function(bag, slot) test.cursor = test.location(bag, slot) end,
    UseContainerItem = function(bag, slot) test.items[bag .. ":" .. slot] = nil end,
}
C_Cursor = { GetCursorItem = function() return test.cursor end }
function GetCursorInfo() return test.cursor and "item" end
function CursorHasItem() return test.cursor ~= nil end
function ClearCursor() test.cursor = nil end
function DeleteCursorItem()
    local location = test.cursor
    if location then test.items[location.bag .. ":" .. location.slot] = nil end
    test.cursor = nil
end
function PickupMerchantItem() DeleteCursorItem() end

EllesmereUI = {
    RegisterPlugin = function(_, spec) test.plugin = spec; return true end,
    OpenPlugin = function() return true end,
    IsSearchPrebuild = function() return false end,
    ShowWidgetTooltip = function() end, HideWidgetTooltip = function() end,
    ShowConfirmPopup = function(_, options)
        test.confirm = options
        test.confirmHandle = {}
        return test.confirmHandle
    end,
    CloseConfirmPopup = function() test.closed = true end,
}
EUI_Bags = {
    RegisterItemOverlayIcon = function(_, callback) test.paint = callback end,
    UnregisterItemOverlayIcon = function() test.paint = nil end,
}
StaticPopupDialogs = {}
for _, key in ipairs({ "DELETE_GOOD_ITEM", "DELETE_GOOD_QUEST_ITEM", "DELETE_ITEM", "DELETE_QUEST_ITEM" }) do
    StaticPopupDialogs[key] = { OnAccept = DeleteCursorItem, OnCancel = ClearCursor }
end
function StaticPopup_Show(key, _, _, data)
    local dialog = CreateFrame("Frame")
    dialog.data = data
    dialog.button1 = CreateFrame("Button")
    function dialog:GetButton1() return self.button1 end
    test.popups[key] = dialog
    return dialog
end
function StaticPopup_Hide(key)
    local dialog = test.popups[key]
    if dialog then
        test.popups[key] = nil
        local definition = StaticPopupDialogs[key]
        if definition.OnHide then definition.OnHide(dialog, dialog.data) end
    end
end
GameEvent = { HandleDeleteItemConfirm = function()
    StaticPopup_Show("DELETE_ITEM", nil, nil, {})
end }
C_ScrappingMachineUI = { GetScrapSpellID = function() return 123 end }
