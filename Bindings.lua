if EUI_CLIENT_BLOCKED then return end
local _, ns = ...
local target = CreateFrame("Button", "DraxtilitiesLockBinding", UIParent)
target:RegisterForClicks("AnyUp")
target:SetScript("OnClick", function()
    if ns.active.bags then ns.ToggleBagSelection() end
end)
target:Hide()
local appliedKey, capture

-- Temporary bindings leave the player's normal binding intact. Stopping Bag
-- Locks releases the key; the configured chord remains in our SavedVariables.
function ns.UpdateBagBinding()
    if InCombatLockdown() then return end
    local key = ns.active.bags and ns.db.bagLockKey or nil
    if type(key) ~= "string" or key == "" or (capture and capture:IsShown()) then key = nil end
    if appliedKey == key then return end
    ClearOverrideBindings(target)
    if key then SetOverrideBindingClick(target, false, key, "DraxtilitiesLockBinding", "LeftButton") end
    appliedKey = key
end

function ns.SetBagBinding(key)
    if InCombatLockdown() or not ns.active.bags then return false end
    if key ~= nil and (type(key) ~= "string" or key == "") then return false end
    ns.db.bagLockKey = key
    ns.UpdateBagBinding()
    ns.RefreshOptions()
    return true
end

function ns.CancelBagBinding()
    if capture then capture:Hide() end
end

function ns.BeginBagBinding()
    if InCombatLockdown() or not ns.active.bags then return end
    if not capture then
        local frame = CreateFrame("Frame", "DraxtilitiesBindingCapture", UIParent)
        frame:SetSize(420, 155)
        frame:SetPoint("CENTER")
        frame:SetFrameStrata("FULLSCREEN_DIALOG")
        frame:EnableMouse(true)
        local background = frame:CreateTexture(nil, "BACKGROUND")
        background:SetAllPoints()
        background:SetColorTexture(0.06, 0.06, 0.06, 1)
        local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        title:SetPoint("TOP", 0, -14)
        title:SetText("Bag item selection shortcut")
        local hint = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        hint:SetPoint("TOPLEFT", 16, -42)
        hint:SetPoint("TOPRIGHT", -16, -42)
        hint:SetWordWrap(true)
        local apply = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        apply:SetSize(115, 24)
        apply:SetPoint("BOTTOMLEFT", 20, 16)
        apply:SetText("Save shortcut")
        apply:SetScript("OnClick", function()
            local key = frame.pendingKey
            if key and ns.SetBagBinding(key) then frame:Hide() end
        end)
        local cancel = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        cancel:SetSize(115, 24)
        cancel:SetPoint("BOTTOMRIGHT", -20, 16)
        cancel:SetText("Cancel")
        cancel:SetScript("OnClick", function() frame:Hide() end)
        local clear = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        clear:SetSize(115, 24)
        clear:SetPoint("BOTTOM", 0, 16)
        clear:SetText("Clear shortcut")
        clear:SetScript("OnClick", function()
            if ns.SetBagBinding(nil) then frame:Hide() end
        end)
        frame:SetScript("OnKeyDown", function(self, key)
            if InCombatLockdown() then return end
            self:SetPropagateKeyboardInput(false)
            if key == "ESCAPE" then self:Hide(); return end
            if IsKeyPressIgnoredForBinding(key) then return end
            local chord = CreateKeyChordStringUsingMetaKeyState(key)
            self.pendingKey = chord
            local action = GetBindingAction(chord, true)
            local assignment = action and action ~= "" and ("Currently assigned to: " .. GetBindingName(action))
                or "Not currently assigned."
            hint:SetText(GetBindingText(chord) .. "\n" .. assignment
                .. "\nActive while EUI bag controls are enabled.")
            apply:Enable()
        end)
        frame:SetScript("OnHide", function(self)
            self.pendingKey = nil
            self:EnableKeyboard(false)
            ns.UpdateBagBinding()
        end)
        UISpecialFrames[#UISpecialFrames + 1] = "DraxtilitiesBindingCapture"
        ns.AddSkin(function(S)
            S.Shell(frame); S.Button(apply); S.Button(cancel); S.Button(clear); S.Font(title); S.Font(hint)
        end)
        frame.hint, frame.apply, frame.clear = hint, apply, clear
        capture = frame
    end
    capture.pendingKey = nil
    capture.hint:SetText("Press a key combination, then save it.\nEsc cancels without changing your shortcut.")
    capture.apply:Disable()
    capture.clear:SetShown(ns.db.bagLockKey ~= nil)
    capture:Show()
    capture:EnableKeyboard(true)
    ns.UpdateBagBinding()
end
