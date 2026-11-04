if EUI_CLIENT_BLOCKED then return end
local _, ns = ...

function ns.CreateTypedDelete()
    local D, definitions = {}, {}
    local current
    local function SameCursor(request)
        local item = ns.CaptureLocation(C_Cursor.GetCursorItem())
        return item and item.guid == request.item.guid and ns.IsLocked(item)
    end
    local function Valid(request)
        return current == request and ns.active.cursor and not InCombatLockdown() and SameCursor(request)
    end
    function D.Cancel()
        local request = current
        current = nil
        if not request then return end
        StaticPopup_Hide(request.key)
        local item = ns.CaptureLocation(C_Cursor.GetCursorItem())
        if item and item.guid == request.item.guid then ClearCursor() end
    end
    local function Accept(dialog, request)
        if not Valid(request) or not dialog:GetButton1():IsEnabled() then D.Cancel(); ns.Stale(); return end
        request.dialog, request.typed = dialog, true
        request.phase = "accepted"
    end
    local function Definition(quest)
        local baseKey = quest and "DELETE_GOOD_QUEST_ITEM" or "DELETE_GOOD_ITEM"
        local key = "DRAXTILITIES_" .. baseKey
        if definitions[key] then return key end
        local base = StaticPopupDialogs and StaticPopupDialogs[baseKey]
        if not base or type(base.OnAccept) ~= "function" then return end
        local info = {}
        for field, value in pairs(base) do info[field] = value end
        info.OnAccept = Accept
        info.OnCancel = D.Cancel
        info.OnHide = function(dialog, request)
            if base.OnHide then base.OnHide(dialog, request) end
            if current ~= request then return end
            if request.phase ~= "accepted" or not Valid(request) then D.Cancel(); return end
            request.phase = "review"
            if not ns.Request("Delete a protected item", { request.item }, function()
                return Valid(request) and request.typed == true
            end, function()
                current = nil
                request.nativeAccept(request.dialog, request)
            end, true, D.Cancel) then D.Cancel() end
        end
        info.EditBoxOnEnterPressed = function(editBox, request)
            local dialog = editBox:GetParent()
            if not dialog:GetButton1():IsEnabled() then return end
            Accept(dialog, request)
            StaticPopup_Hide(key)
        end
        info.EditBoxOnEscapePressed = D.Cancel
        StaticPopupDialogs[key], definitions[key] = info, info
        return key
    end
    function D.Start(item)
        if InCombatLockdown() or not ns.active.cursor then return true end
        local quality = C_Item.GetItemQuality(item.location)
        if not quality then
            C_Item.RequestLoadItemDataByID(item.id)
            ns.Print("Item data is loading. Try again.")
            return true
        end
        if quality < Enum.ItemQuality.Rare or quality == Enum.ItemQuality.Heirloom then return false end
        if current then return true end
        ns.CancelRequest()
        local quest = C_Container.GetContainerItemQuestInfo(item.bag, item.slot)
        local isQuest = quest and (quest.isQuestItem or quest.questID)
        local key, name = Definition(isQuest), C_Item.GetItemName(item.location)
        if not key or not name then ns.Print("The native deletion dialog is unavailable."); return true end
        local base = StaticPopupDialogs[isQuest and "DELETE_GOOD_QUEST_ITEM" or "DELETE_GOOD_ITEM"]
        current = { item = item, key = key, phase = "typing", nativeAccept = base.OnAccept }
        if not StaticPopup_Show(key, name, nil, current) then D.Cancel() end
        return true
    end
    function D.CursorChanged()
        if current and not SameCursor(current) then D.Cancel(); ns.CancelRequest() end
    end
    function D.IsTyping() return current ~= nil and current.phase ~= "review" end
    function D.Stop()
        D.Cancel()
        for key, definition in pairs(definitions) do
            if StaticPopupDialogs[key] == definition then StaticPopupDialogs[key] = nil end
        end
        wipe(definitions)
    end
    return D
end
