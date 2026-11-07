-- Deterministic API doubles. These do not emulate protected execution or taint.
test = { frames = {}, items = {}, combat = false, popups = {}, messages = {}, timers = {}, bindings = {}, overrides = {} }
Enum = { BagIndex = { ReagentBag = 5 }, ItemQuality = { Poor = 0, Rare = 3, Heirloom = 7 },
    ForbiddenAspect = { ScriptedInput = 1 } }
function InCombatLockdown() return test.combat end
function GetUnitName() return "Test-Realm" end
function issecretvalue(value) return type(value) == "table" and value.secret == true end
function wipe(value) for key in pairs(value) do value[key] = nil end; return value end
function GetTime() return test.time or 0 end
function GetCurrentKeyBoardFocus() return test.focus end
function IsShiftKeyDown() return false end
function IsControlKeyDown() return false end
function IsAltKeyDown() return false end
function UnitExists() return false end
function SpellCanTargetItem() return test.spellTarget == true end
function SpellCanTargetItemID() return test.spellTargetID == true end
function SpellStopTargeting()
    test.stoppedSpell = (test.stoppedSpell or 0) + 1
    test.spellTarget, test.spellTargetID = false, false
end
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
    if test.focus == self then self:ClearFocus() end
    if shown and self.scripts.OnHide then self.scripts.OnHide(self) end
end
function Frame:SetShown(shown) if shown then self:Show() else self:Hide() end end
function Frame:IsShown() return self.shown end
function Frame:IsVisible() return self.shown and (not self.parent or self.parent:IsVisible()) end
function Frame:IsEnabled() return self.enabled ~= false end
function Frame:Enable() self.enabled = true end
function Frame:Disable() self.enabled = false end
function Frame:SetEnabled(enabled) self.enabled = enabled end
function Frame:GetParent() return self.parent end
function Frame:SetParent(parent) self.parent = parent end
function Frame:SetID(value) self.id = value end
function Frame:GetID() return self.id or 0 end
function Frame:GetEffectiveScale() return self.effectiveScale or (self.parent and self.parent:GetEffectiveScale()) or 1 end
function Frame:GetFrameStrata() return "MEDIUM" end
function Frame:GetFrameLevel() return 1 end
function Frame:HasAccessConstraints() return false end
function Frame:HasAnyForbiddenAspects() return false end
function Frame:SetText(text)
    self.text, self.cursor = text, type(text) == "string" and #text or 0
    if self.scripts.OnTextChanged then self.scripts.OnTextChanged(self, false) end
end
function Frame:GetText() return self.text or "" end
function Frame:GetWidth() return 800 end
function Frame:GetRect() if self.rect then return unpack(self.rect) end end
function Frame:GetChildren()
    local children = {}
    for _, frame in ipairs(test.frames) do
        if frame.parent == self and frame.kind ~= "Texture" and frame.kind ~= "FontString" then
            children[#children + 1] = frame
        end
    end
    return unpack(children)
end
function Frame:SetAlpha(alpha) self.alpha = alpha end
function Frame:EnableMouse(enabled) self.mouseEnabled = enabled end
function Frame:HasFocus() return test.focus == self end
function Frame:SetFocus()
    if test.focus == self then return end
    test.focus = self
    if self.scripts.OnEditFocusGained then self.scripts.OnEditFocusGained(self) end
end
function Frame:HighlightText(first, last)
    self.selectionStart, self.selectionEnd = first or 0, last or #self:GetText()
end
function Frame:ClearFocus()
    if test.focus ~= self then return end
    test.focus = nil
    if self.scripts.OnEditFocusLost then self.scripts.OnEditFocusLost(self) end
end
function Frame:GetCursorPosition() return self.cursor or 0 end
function Frame:SetCursorPosition(position) self.cursor = position end
function Frame:SetPoint(...) self.point = { ... } end
function Frame:GetPoint() return unpack(self.point or { "CENTER", UIParent, "CENTER", 0, 0 }) end
function Frame:SetTexture(texture) self.texture = texture end
function Frame:EnableKeyboard(enabled) self.keyboard = enabled end
function Frame:SetPropagateKeyboardInput(enabled) self.propagate = enabled end
function Frame:CreateTexture() return CreateFrame("Texture") end
function Frame:CreateFontString() return CreateFrame("FontString") end
for _, name in ipairs({ "SetAllPoints", "ClearAllPoints", "SetSize", "SetWidth", "SetHeight",
    "SetColorTexture", "SetFrameStrata", "SetFrameLevel", "SetScale", "EnableMouseMotion",
    "RegisterForClicks", "RegisterForDrag", "SetPassThroughButtons", "SetMovable", "StartMoving", "StopMovingOrSizing",
    "SetWordWrap", "SetTexCoord", "SetJustifyH", "SetAutoFocus", "SetFontObject", "SetTextInsets" }) do
    Frame[name] = function() end
end
function CreateFrame(kind, name, parent, template)
    local frame = setmetatable({ kind = kind, scripts = {}, events = {}, attributes = {}, parent = parent, shown = true }, Frame)
    if template == "InputBoxTemplate" then
        frame.scripts.OnEditFocusGained = function(self) self:HighlightText() end
    end
    table.insert(test.frames, frame)
    if name then _G[name] = frame end
    return frame
end
UIParent = CreateFrame("Frame")
GameTooltip = CreateFrame("Frame")
function GameTooltip:SetOwner(owner, anchor) self.owner, self.anchor = owner, anchor end
function GameTooltip:IsOwned(owner) return self.owner == owner end
function GameTooltip:SetBagItem(bag, slot) test.tooltip = { bag = bag, slot = slot } end
function GameTooltip:SetHyperlink(link) test.tooltip = { link = link } end
function GameTooltip:SetItemByID(id) test.tooltip = { id = id } end
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

function ClearOverrideBindings(owner)
    assert(not InCombatLockdown(), "binding changed in combat")
    test.overrides[owner] = nil
end
function SetOverrideBindingClick(owner, _, key, name, button)
    assert(not InCombatLockdown(), "binding changed in combat")
    test.overrides[owner] = test.overrides[owner] or {}
    test.overrides[owner][key] = "CLICK " .. name .. ":" .. (button or "LeftButton")
end
function GetBindingAction(key, checkOverride)
    if checkOverride then
        for _, bindings in pairs(test.overrides) do
            if bindings[key] then return bindings[key] end
        end
    end
    return test.bindings[key] or ""
end
function GetBindingText(key) return key end
function GetBindingName(action) return action end
function IsKeyPressIgnoredForBinding(key)
    return key == "LSHIFT" or key == "RSHIFT" or key == "LCTRL" or key == "RCTRL"
        or key == "LALT" or key == "RALT" or key == "UNKNOWN"
end
function CreateKeyChordStringUsingMetaKeyState(key)
    return (IsAltKeyDown() and "ALT-" or "") .. (IsControlKeyDown() and "CTRL-" or "")
        .. (IsShiftKeyDown() and "SHIFT-" or "") .. key
end
function test.pressKey(key)
    local name, button = GetBindingAction(key, true):match("^CLICK ([^:]+):(.+)$")
    local target = name and _G[name]
    if target and target.scripts.OnClick then target.scripts.OnClick(target, button) end
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
    GetItemIconByID = function(id) return id end,
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
    IsSearchPrebuild = function() return test.prebuild == true end,
    RegisterSkin = function(_, callback)
        test.skinRegistrations = (test.skinRegistrations or 0) + 1
        test.skinCallback = callback
    end,
    ShowWidgetTooltip = function() end, HideWidgetTooltip = function() end,
    ShowConfirmPopup = function(_, options)
        test.confirm = options
        test.confirmHandle = {}
        return test.confirmHandle
    end,
    CloseConfirmPopup = function() test.closed = true end,
}
EllesmereUI.Widgets = {
    SectionHeader = function(_, _, text)
        test.sections[#test.sections + 1] = text
        return {}, 24
    end,
    DualRow = function(_, _, _, left, right)
        test.rows[#test.rows + 1] = { left = left, right = right }
        test.controls[#test.controls + 1] = left
        if right then test.controls[#test.controls + 1] = right end
        return {}, 50
    end,
}
function test.buildPage(name, prebuild)
    test.controls, test.sections, test.rows, test.prebuild = {}, {}, {}, prebuild == true
    test.pageParent = test.pageParent or CreateFrame("Frame")
    return test.plugin.modules[1].buildPage(name, test.pageParent, 0)
end
function test.searchBox()
    for _, frame in ipairs(test.frames) do
        if frame.kind == "EditBox" and frame.parent == test.pageParent and frame:IsShown() then return frame end
    end
end
function test.typeSearch(text, cursor)
    local box = assert(test.searchBox())
    box:SetFocus()
    box.text, box.cursor = text, cursor or #text
    box.selectionStart, box.selectionEnd = 0, 0
    box.scripts.OnTextChanged(box, true)
end
function test.insertSearch(text)
    local box = assert(test.searchBox())
    assert(box:HasFocus(), "search lost keyboard focus")
    local first, last = box.selectionStart or 0, box.selectionEnd or 0
    if first == last then first, last = box:GetCursorPosition(), box:GetCursorPosition() end
    box.text = box:GetText():sub(1, first) .. text .. box:GetText():sub(last + 1)
    box.cursor = first + #text
    box.selectionStart, box.selectionEnd = 0, 0
    box.scripts.OnTextChanged(box, true)
end
function test.itemRows()
    local rows = {}
    for _, frame in ipairs(test.frames) do
        if frame.entry and frame.parent == test.pageParent and frame:IsShown() then rows[#rows + 1] = frame end
    end
    return rows
end
function test.findControl(text)
    for _, control in ipairs(test.controls) do
        if control.text == text then return control end
    end
end
function test.hasText(text)
    for _, control in ipairs(test.controls) do
        if control.text and control.text:find(text, 1, true) then return true end
    end
    return false
end
EUI_MainBagFrame = CreateFrame("Frame", "EUI_MainBagFrame", UIParent)
EUI_MainBagFrame.rect = { 100, 100, 600, 400 }
EUI_MainBagFrame:Hide()
test.bagFooter = CreateFrame("Frame", nil, EUI_MainBagFrame)
EUI_BagMoneyFrame = CreateFrame("Frame", "EUI_BagMoneyFrame", test.bagFooter)
EUI_BagMoneyFrame.rect = { 550, 107, 110, 14 }
EUI_Bags = EUI_MainBagFrame
function EUI_Bags.RegisterItemOverlayIcon(_, callback) test.paint = callback end
function EUI_Bags.UnregisterItemOverlayIcon() test.paint = nil end
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
