if EUI_CLIENT_BLOCKED then return end
local _, ns = ...
local controller
ns.Register("cursor", {
    title = "Cursor Safeguards",
    description = "Confirms dragging a protected copy into the world to delete it, or onto a merchant to sell it. Typed DELETE comes before the final EUI review.",
    events = { "CURSOR_CHANGED", "MERCHANT_SHOW", "MERCHANT_CLOSED" },
    Start = function()
        if controller then return controller end
        local C = {}
        controller = C
        local typed = ns.CreateTypedDelete()
        local nativeDeleteGUID
        C.IsTyping = typed.IsTyping
        function C.Cancel()
            typed.Cancel()
            local guid = nativeDeleteGUID
            nativeDeleteGUID = nil
            local item = guid and ns.CaptureLocation(C_Cursor.GetCursorItem())
            if item and item.guid == guid then ClearCursor() end
        end
        local function Cursor()
            if GetCursorInfo() ~= "item" then return end
            local item = ns.CaptureLocation(C_Cursor.GetCursorItem())
            if ns.IsLocked(item) then return item end
        end
        local function Action(sell)
            if not C.running or InCombatLockdown() then return end
            local item = Cursor()
            if not item then return end
            if not sell and UnitExists("mouseover") then
                ns.Print("Giving items to units or players is outside this protection.")
                return
            end
            if not sell and typed.Start(item) then return end
            ns.Request(sell and "Sell a protected item" or "Delete a protected item", { item }, function()
                local now = Cursor()
                return now and now.guid == item.guid and (not sell
                    or (MerchantFrame and MerchantFrame:IsVisible() and MerchantFrame.selectedTab == 1))
            end, function()
                if sell then PickupMerchantItem(0); return end
                local name, quality = C_Item.GetItemName(item.location), C_Item.GetItemQuality(item.location)
                if not name or not quality or not GameEvent or not GameEvent.HandleDeleteItemConfirm then
                    ns.Print("The native deletion confirmation is unavailable.")
                    return
                end
                local quest = C_Container.GetContainerItemQuestInfo(item.bag, item.slot)
                nativeDeleteGUID = item.guid
                ns.WatchRemoval({ item })
                GameEvent.HandleDeleteItemConfirm(nil, "DELETE_ITEM_CONFIRM", name, quality, nil,
                    quest and (quest.isQuestItem or quest.questID) and 1 or 0)
            end)
        end
        local function MakeLayer(sell)
            local f = CreateFrame("Button", nil, UIParent)
            f:RegisterForClicks("LeftButtonUp", "RightButtonUp")
            f:EnableMouseMotion(false)
            f:SetScript("OnClick", function(_, button)
                if button == "RightButton" then ClearCursor() else Action(sell) end
            end)
            f:SetScript("OnReceiveDrag", function() Action(sell) end)
            f:Hide()
            return f
        end
        C.world, C.merchant = MakeLayer(false), MakeLayer(true)
        C.world:SetAllPoints(UIParent)
        C.world:SetFrameStrata("BACKGROUND")
        C.world:SetFrameLevel(UIParent:GetFrameLevel() + 1)
        function C.Refresh()
            if InCombatLockdown() then return end
            typed.CursorChanged()
            local item = Cursor()
            if nativeDeleteGUID and (not item or item.guid ~= nativeDeleteGUID) then
                local location = C_Item.GetItemLocation(nativeDeleteGUID)
                if location and location:HasAnyLocation() and C_Item.DoesItemExist(location) then
                    -- A cancelled native dialog returns the copy to its bag.
                    -- Retain the lock whenever removal has not been observed.
                    ns.CancelRemoval(nativeDeleteGUID)
                end
                nativeDeleteGUID = nil
            end
            C.world:SetShown(item ~= nil)
            local merchant = item and MerchantFrame and MerchantFrame:IsVisible() and MerchantFrame.selectedTab == 1
            C.merchant:SetShown(merchant and true or false)
            if merchant then
                C.merchant:SetScale(MerchantFrame:GetEffectiveScale() / UIParent:GetEffectiveScale())
                C.merchant:ClearAllPoints()
                C.merchant:SetAllPoints(MerchantFrame)
                C.merchant:SetFrameStrata(MerchantFrame:GetFrameStrata())
                C.merchant:SetFrameLevel(MerchantFrame:GetFrameLevel() + 50)
            end
        end
        function C.Suspend() C.world:Hide(); C.merchant:Hide() end
        function C.Stop() typed.Stop(); C.Suspend() end
        return C
    end,
})
