if EUI_CLIENT_BLOCKED then return end
local addon, ns = ...
Draxtilities = ns
ns.id, ns.modules, ns.order, ns.active = addon, {}, {}, {}
local loader = CreateFrame("Frame")
local events = CreateFrame("Frame")
local skin
local skinCallbacks = {}

function ns.AddSkin(callback)
    skinCallbacks[#skinCallbacks + 1] = callback
    if skin then callback(skin) end
end

function ns.ToggleBagSelection()
    if InCombatLockdown() then return end
    local bags = ns.active.bags
    if bags then bags.SetMode(not bags.mode)
    else ns.Print("Enable Item Protection and EUI bag controls in Settings first.") end
end

function ns.Print(message)
    DEFAULT_CHAT_FRAME:AddMessage("|cff0cd29fDraxtilities:|r " .. message)
end

function ns.Register(key, spec)
    ns.modules[key] = spec
    ns.order[#ns.order + 1] = key
end

function ns.RefreshOptions(preserveInput)
    local EUI = EllesmereUI
    if InCombatLockdown() or not EUI.GetActiveModule or not EUI.IsShown or not EUI:IsShown() then return end
    local key = EUI.GetPluginModuleKey(ns.id, "Protection")
    if key and EUI:GetActiveModule() == key then
        -- Inventory events must not rebuild a text field while the user types.
        -- The live search field consumes any delayed refresh on focus loss.
        if preserveInput and GetCurrentKeyBoardFocus() then ns.optionsDirty = true; return end
        ns.optionsDirty = nil
        EUI:RefreshPage(true)
    end
end

function ns.Refresh()
    if InCombatLockdown() then return end
    for _, key in ipairs(ns.order) do
        local controller = ns.active[key]
        if controller and controller.Refresh then controller.Refresh() end
    end
end

function ns.CancelRequest()
    local request = ns.pending
    ns.pending = nil
    if request then
        EllesmereUI:CloseConfirmPopup(request.handle)
        if request.dismiss then request.dismiss() end
    end
end

function ns.Cancel()
    ns.CancelRequest()
    ns.CancelRemovals()
    if ns.CancelBagBinding then ns.CancelBagBinding() end
    for _, controller in pairs(ns.active) do
        if controller.Cancel then controller.Cancel() end
    end
end

local function SyncEvents()
    events:UnregisterAllEvents()
    if not next(ns.active) then return end
    events:RegisterEvent("PLAYER_REGEN_DISABLED")
    events:RegisterEvent("PLAYER_REGEN_ENABLED")
    events:RegisterEvent("BAG_UPDATE_DELAYED")
    events:RegisterEvent("ITEM_DATA_LOAD_RESULT")
    for key in pairs(ns.active) do
        for _, event in ipairs(ns.modules[key].events or {}) do events:RegisterEvent(event) end
    end
end

function ns.SetEnabled(key, enabled, preservePreference)
    if InCombatLockdown() then ns.Print("Change protection settings out of combat."); return false end
    local spec = ns.modules[key]
    if not spec then return false end
    if enabled and EllesmereUI.ItemProtection then
        ns.Print("Disable the old integrated Item Protection and install the original EllesmereUI first.")
        return false
    end
    ns.Cancel()
    if enabled and not ns.active[key] then
        local controller, reason = spec.Start()
        if not controller then ns.Print(reason or "This module is unavailable."); return false end
        controller.running = true
        ns.active[key] = controller
    elseif not enabled and ns.active[key] then
        ns.active[key].running = false
        ns.active[key].Stop()
        ns.active[key] = nil
    end
    if not preservePreference then ns.db.modules[key] = enabled and true or false end
    if ns.UpdateBagBinding then ns.UpdateBagBinding() end
    SyncEvents()
    ns.Refresh()
    return true
end

function ns.SetProtectionEnabled(enabled)
    if InCombatLockdown() then return false end
    if enabled and EllesmereUI.ItemProtection then
        ns.Print("Disable the old integrated Item Protection and install the original EllesmereUI first.")
        return false
    end
    ns.Cancel()
    ns.db.itemProtectionEnabled = enabled and true or false
    for _, key in ipairs(ns.order) do
        ns.SetEnabled(key, enabled and ns.db.modules[key] == true, true)
    end
    ns.RefreshOptions()
    return true
end

function ns.SetProtectionOption(key, enabled)
    if InCombatLockdown() or not ns.modules[key] then return false end
    if ns.db.itemProtectionEnabled then return ns.SetEnabled(key, enabled) end
    ns.db.modules[key] = enabled and true or false
    return true
end

local refreshQueued
local deferredRefreshEvents = {
    MERCHANT_SHOW = true, MERCHANT_CLOSED = true,
    AUCTION_HOUSE_SHOW = true, AUCTION_HOUSE_CLOSED = true,
    PLAYER_INTERACTION_MANAGER_FRAME_SHOW = true, PLAYER_INTERACTION_MANAGER_FRAME_HIDE = true,
    ADDON_LOADED = true,
}

events:SetScript("OnEvent", function(_, event, ...)
    local arg, success = ...
    if event == "PLAYER_REGEN_DISABLED" then
        ns.Cancel()
        for _, controller in pairs(ns.active) do
            if controller.Suspend then controller.Suspend() end
        end
        return
    end
    if event == "ITEM_DATA_LOAD_RESULT" then
        if not ns.loading[arg] then return end
        ns.loading[arg] = nil
        if not success then return end
    elseif event == "BAG_UPDATE_DELAYED" then
        ns.ReconcileRemovals()
    end
    if InCombatLockdown() then return end
    if event == "PLAYER_REGEN_ENABLED" and ns.UpdateBagBinding then ns.UpdateBagBinding() end
    for _, key in ipairs(ns.order) do
        local controller = ns.active[key]
        if controller then
            if controller.Event then controller.Event(event, ...) end
            if controller.Refresh then controller.Refresh() end
        end
    end
    -- Native panels may finish showing after our event handler has run.
    if deferredRefreshEvents[event] and not refreshQueued then
        refreshQueued = true
        C_Timer.After(0, function()
            refreshQueued = nil
            ns.Refresh()
        end)
    end
    if event == "BAG_UPDATE_DELAYED" or event == "ITEM_DATA_LOAD_RESULT" or event == "PLAYER_REGEN_ENABLED" then
        ns.RefreshOptions(true)
    end
end)

loader:SetScript("OnEvent", function(_, _, name)
    if name ~= addon then return end
    loader:UnregisterAllEvents()
    loader:SetScript("OnEvent", nil)
    ns.InitStore()
    if ns.RegisterOptions() == false then return end
    if EllesmereUI.RegisterSkin then
        EllesmereUI.RegisterSkin(ns.id, function(S)
            skin = S
            for _, callback in ipairs(skinCallbacks) do callback(S) end
        end)
    end
    if ns.db.itemProtectionEnabled then ns.SetProtectionEnabled(true) end
end)
loader:RegisterEvent("ADDON_LOADED")

SLASH_DRAXTILITIES1 = "/draxtilities"
SLASH_DRAXTILITIES2 = "/dt"
SlashCmdList.DRAXTILITIES = function(text)
    if not ns.db or InCombatLockdown() then return end
    if text == "lock" then
        ns.ToggleBagSelection()
    elseif text == "cursor" then
        local item = ns.CaptureLocation(C_Cursor.GetCursorItem())
        if item and item.bag and ns.Toggle(item.bag, item.slot) then ClearCursor() end
    else
        if EllesmereUI.OpenPlugin then
            EllesmereUI.OpenPlugin(ns.id, "Protection", text == "items" and "Items" or "Settings")
        else ns.Print("Update EllesmereUI to a version with the public Plugin API.") end
    end
end
