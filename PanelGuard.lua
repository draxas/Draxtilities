if EUI_CLIENT_BLOCKED then return end
local _, ns = ...
local L = ns.L

function ns.CreatePanelGuard(spec)
    local G = {}
    local button, permission, boundTarget, removalTicket, request
    local watcher = CreateFrame("Frame", nil, UIParent)
    watcher:Hide()
    local function Disarm()
        if button and not InCombatLockdown() then
            button:SetAttribute("type", nil)
            button:SetAttribute("clickbutton", nil)
        end
    end
    function G.Cancel()
        permission = nil
        local pending = request
        request = nil
        if pending and ns.pending == pending then ns.CancelRequest() end
        if removalTicket then ns.CancelRemovals(removalTicket); removalTicket = nil end
    end
    function G.Refresh()
        if InCombatLockdown() then return end
        watcher:SetShown(G.running == true)
        local target = spec.Target()
        if not target or not target:IsVisible() then
            G.Cancel()
            boundTarget = target
            if button then button:Hide(); UnregisterStateDriver(button, "visibility"); Disarm() end
            return
        end
        if not button then
            button = CreateFrame("Button", nil, UIParent, "SecureActionButtonTemplate")
            button:RegisterForClicks("LeftButtonUp")
            button:SetAttribute("useOnKeyDown", false)
            button:EnableMouseMotion(true)
            button:SetScript("OnEnter", function(self)
                local live = spec.Target()
                if not live or not live:IsVisible() then G.Refresh(); return end
                EllesmereUI.ShowWidgetTooltip(self, L["Draxtilities checks protected copies before this action."])
            end)
            button:SetScript("OnLeave", function() EllesmereUI.HideWidgetTooltip() end)
            button:SetScript("PreClick", function(_, mouseButton)
                if InCombatLockdown() then return end
                Disarm()
                if not G.running then return end
                if mouseButton ~= "LeftButton" or IsShiftKeyDown() or IsControlKeyDown() or IsAltKeyDown() then
                    permission = nil
                    return
                end
                local live = spec.Target()
                if live ~= boundTarget or not live:IsVisible() or not live:IsEnabled() then permission = nil; return end
                if live:HasAccessConstraints() or live:HasAnyForbiddenAspects(Enum.ForbiddenAspect.ScriptedInput) then
                    permission = nil
                    ns.Print(L["The native control does not permit delegated input."])
                    return
                end
                local items, signature, reason = spec.Collect()
                if reason then permission = nil; ns.Print(reason); return end
                local protected = false
                for _, item in ipairs(items) do if ns.IsLocked(item) then protected = true; break end end
                if protected and permission ~= signature then
                    permission = nil
                    local started = ns.Request(spec.title, items, function()
                        local _, now, invalid = spec.Collect()
                        return spec.Target() == live and live:IsVisible() and live:IsEnabled()
                            and not invalid and now == signature
                    end, function()
                        request = nil
                        permission = signature
                        ns.Print(L["Authorized once. Click the native action button again to finish."])
                    end, false, function() request = nil end,
                        L["After confirming, click the original action button again. Any changed item or action needs a new confirmation."])
                    if started then request = ns.pending end
                    return
                end
                permission = nil
                if spec.track then
                    if removalTicket then ns.CancelRemovals(removalTicket) end
                    removalTicket = ns.WatchRemoval(items)
                end
                button:SetAttribute("type", "click")
                button:SetAttribute("clickbutton", live)
            end)
            button:SetScript("PostClick", function()
                Disarm()
            end)
            G.button = button
        end
        if boundTarget ~= target then G.Cancel() end
        boundTarget = target
        button:ClearAllPoints()
        button:SetScale(target:GetEffectiveScale() / UIParent:GetEffectiveScale())
        button:SetAllPoints(target)
        button:SetFrameStrata(target:GetFrameStrata())
        button:SetFrameLevel(target:GetFrameLevel() + 20)
        Disarm()
        RegisterStateDriver(button, "visibility", "[combat] hide;")
        button:Show()
    end
    function G.Suspend() G.Cancel() end
    function G.Stop()
        G.Cancel()
        watcher:Hide()
        if button then
            button:Hide()
            UnregisterStateDriver(button, "visibility")
            Disarm()
            button:ClearAllPoints()
        end
    end
    -- Native tabs can hide or restore their action button without a bag or
    -- panel event. Observe visibility from our own frame, without hooks.
    watcher:SetScript("OnUpdate", function(self, elapsed)
        self.elapsed = (self.elapsed or 0) + elapsed
        if self.elapsed < 0.2 then return end
        self.elapsed = 0
        if not G.running or InCombatLockdown() then return end
        local target = spec.Target()
        local visible = target ~= nil and target:IsVisible()
        if target ~= boundTarget or visible ~= (button ~= nil and button:IsShown()) then G.Refresh() end
    end)
    return G
end
