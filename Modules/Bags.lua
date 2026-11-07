if EUI_CLIENT_BLOCKED then return end
local _, ns = ...
local controller

local function CreateLockIcon(parent)
    local icon = CreateFrame("Frame", nil, parent)
    icon:SetSize(14, 14)
    local function Part(x, y, width, height, r, g, b)
        local texture = icon:CreateTexture(nil, "OVERLAY")
        texture:SetPoint("BOTTOMLEFT", x, y)
        texture:SetSize(width, height)
        texture:SetColorTexture(r, g, b, 1)
    end
    Part(2, 1, 10, 7, 0.95, 0.76, 0.27)
    Part(3, 8, 2, 4, 0.95, 0.76, 0.27)
    Part(9, 8, 2, 4, 0.95, 0.76, 0.27)
    Part(4, 11, 6, 2, 0.95, 0.76, 0.27)
    Part(6, 3, 2, 3, 0.1, 0.1, 0.1)
    return icon
end

-- Compatibility with the named windows in EUI Bags 9.7.8. Only geometry is
-- read; all parenting, anchors, scripts and skin changes belong to our button.
local function FooterButtonOffset(bagFrame)
    local money = EUI_BagMoneyFrame
    local footer = money and money:GetParent()
    if not footer or footer:GetParent() ~= bagFrame then return end
    local left, bottom, width = bagFrame:GetRect()
    if not left or not bottom or not width or width <= 0 then return end
    local scale, occupied = bagFrame:GetEffectiveScale(), {}
    -- Keep the rightmost area free for EUI's window lock and resize grip.
    local edge, limit, size = 6, width - 44, 22
    for _, child in ipairs({ footer:GetChildren() }) do
        if child:IsVisible() then
            local x, y, w, h = child:GetRect()
            if not x or not y or not w or not h then return end
            if x and y and w and h then
                local ratio = child:GetEffectiveScale() / scale
                x, y, w, h = x * ratio - left, y * ratio - bottom, w * ratio, h * ratio
                if y < 26 and y + h > 2 then
                    local first, last = math.max(edge, x - 4), math.min(limit, x + w + 4)
                    if first < last then occupied[#occupied + 1] = { first, last } end
                end
            end
        end
    end
    table.sort(occupied, function(a, b) return a[1] < b[1] end)
    local cursor, offset = edge, nil
    for _, interval in ipairs(occupied) do
        if interval[1] - cursor >= size then offset = interval[1] - size end
        cursor = math.max(cursor, interval[2])
    end
    if limit - cursor >= size then offset = limit - size end
    return offset
end

ns.Register("bags", {
    title = "EUI bag controls",
    description = "Lock icons, item selection, right-click sale confirmation and blocking of item spells targeted by clicking a locked item in EUI bags, including Disenchant. Requires EllesmereUIBags. EUI Quick Actions and macros are excluded.",
    events = { "MERCHANT_SHOW", "MERCHANT_CLOSED", "BAG_CLOSED" },
    Start = function()
        if not EUI_Bags or type(EUI_Bags.RegisterItemOverlayIcon) ~= "function"
            or type(EUI_Bags.UnregisterItemOverlayIcon) ~= "function" then
            return nil, "The public EUI Bags overlay API is unavailable. Enable the original EllesmereUIBags addon."
        end
        if controller then
            EUI_Bags.RegisterItemOverlayIcon("Draxtilities", controller.Paint)
            return controller
        end
        local B = { layers = {}, mode = false }
        controller = B
        function B.LayoutLauncher()
            local button = B.launcher
            if not button or not B.running or InCombatLockdown() then return end
            local bagFrame = button:GetParent()
            local offset = bagFrame:IsVisible() and FooterButtonOffset(bagFrame)
            button.fits = type(offset) == "number"
            if button.fits then
                button:ClearAllPoints()
                button:SetPoint("BOTTOMLEFT", bagFrame, "BOTTOMLEFT", offset, 4)
                button:SetFrameLevel(bagFrame:GetFrameLevel() + 20)
            end
            button:SetAlpha(button.fits and 1 or 0)
            button:EnableMouse(button.fits)
        end
        function B.SyncLauncher()
            local bagFrame = EUI_MainBagFrame
            local enabled = B.running and not InCombatLockdown()
            if not bagFrame or type(bagFrame.GetRect) ~= "function" then
                if B.launcher then B.launcher:Hide() end
                return
            end
            if enabled and not B.launcher then
                local button = CreateFrame("Button", nil, bagFrame, "UIPanelButtonTemplate")
                button:SetSize(22, 20)
                button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
                button.badge = CreateLockIcon(button)
                button.badge:SetPoint("CENTER")
                button.selection = button.badge:CreateTexture(nil, "BACKGROUND")
                button.selection:SetPoint("TOPLEFT", -4, 3)
                button.selection:SetPoint("BOTTOMRIGHT", 4, -3)
                button.selection:SetColorTexture(0.05, 0.82, 0.62, 0.3)
                button:SetScript("OnClick", function(self, mouseButton)
                    if not self.fits or not self:IsVisible() or not B.running or InCombatLockdown() then return end
                    if mouseButton == "RightButton" then
                        B.SetMode(false)
                        EllesmereUI.OpenPlugin(ns.id, "Protection", "Items")
                    else B.SetMode(not B.mode) end
                end)
                button:SetScript("OnEnter", function(self)
                    local action = B.mode and "Finish selecting item locks." or "Click to lock or unlock bag items."
                    EllesmereUI.ShowWidgetTooltip(self, "Draxtilities\n" .. action .. "\nRight-click for locked items.")
                end)
                button:SetScript("OnLeave", EllesmereUI.HideWidgetTooltip)
                button:SetScript("OnShow", B.LayoutLauncher)
                button:SetScript("OnHide", function()
                    EllesmereUI.HideWidgetTooltip()
                    if B.mode then B.SetMode(false) end
                end)
                button:SetScript("OnUpdate", function(self, elapsed)
                    self.elapsed = (self.elapsed or 0) + elapsed
                    if self.elapsed < 0.2 then return end
                    self.elapsed = 0
                    if not B.running or InCombatLockdown() then self:Hide(); return end
                    B.LayoutLauncher()
                end)
                ns.AddSkin(function(S) S.Button(button) end)
                B.launcher = button
            end
            if B.launcher then
                if enabled then
                    if B.launcher:GetParent() ~= bagFrame then B.launcher:SetParent(bagFrame) end
                    B.LayoutLauncher()
                end
                B.launcher.selection:SetShown(B.mode)
                B.launcher:SetShown(enabled)
            end
        end
        local function HideHover(layer)
            layer.fill:Hide()
            for _, edge in ipairs(layer.edges) do edge:Hide() end
        end
        local function Hover(layer)
            if not B.mode then return end
            local item = ns.Capture(layer.bag, layer.slot)
            if not item or (not ns.Eligible(item) and not ns.IsLocked(item)) then return end
            EllesmereUI.HideWidgetTooltip()
            GameTooltip:Hide()
            layer.fill:Show()
            for _, edge in ipairs(layer.edges) do edge:Show() end
        end
        local function Click(layer, button)
            if not B.running or InCombatLockdown() then return end
            if not layer.target:IsVisible() or layer.target:GetParent():GetID() ~= layer.bag
                or layer.target:GetID() ~= layer.slot then ns.Stale(); return end
            local item = ns.Capture(layer.bag, layer.slot)
            if not item or item.guid ~= layer.guid then ns.Stale(); return end
            if B.mode then
                if button == "RightButton" then B.SetMode(false) else ns.Toggle(item.bag, item.slot) end
                return
            end
            if not ns.IsLocked(item) then return end
            if SpellCanTargetItem() or SpellCanTargetItemID() then
                SpellStopTargeting()
                ns.Print("This item is locked. Unlock it before disenchanting or casting an item spell on it.")
            elseif IsModifiedClick() then
                HandleModifiedItemClick(item.link, item.location)
            elseif button == "RightButton" then
                if not MerchantFrame or not MerchantFrame:IsVisible() or MerchantFrame.selectedTab ~= 1 then return end
                ns.Request("Sell a protected item", { item }, function()
                    return B.running and MerchantFrame:IsVisible() and MerchantFrame.selectedTab == 1
                        and not GetCursorInfo() and not SpellCanTargetItem() and not SpellCanTargetItemID()
                end, function() C_Container.UseContainerItem(item.bag, item.slot) end)
            elseif not GetCursorInfo() or GetCursorInfo() == "item" then
                C_Container.PickupContainerItem(item.bag, item.slot)
            end
        end
        local function CreateLayer(target)
            local f = CreateFrame("Button", nil, target:GetParent())
            f:EnableMouse(true)
            f:RegisterForClicks("LeftButtonUp", "RightButtonUp")
            f:RegisterForDrag("LeftButton")
            f:SetScript("OnClick", Click)
            f:SetScript("OnDragStart", function(self) if not B.mode then Click(self, "LeftButton") end end)
            f:SetScript("OnReceiveDrag", function(self) Click(self, "LeftButton") end)
            f:SetScript("OnEnter", Hover)
            f:SetScript("OnLeave", HideHover)
            f:SetScript("OnUpdate", function(self)
                -- This control is a sibling of the secure slot, so it must
                -- follow slot hiding caused by EUI filtering or pooling.
                if self.target and not self.target:IsVisible() then self:Hide() end
            end)
            f.fill = f:CreateTexture(nil, "OVERLAY", nil, 5)
            f.fill:SetAllPoints()
            f.fill:SetColorTexture(1, 1, 1, 0.4)
            f.edges = {}
            for _, edge in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
                local t = f:CreateTexture(nil, "OVERLAY", nil, 6)
                t:SetColorTexture(0.05, 0.82, 0.62, 1)
                if edge == "TOP" or edge == "BOTTOM" then
                    t:SetPoint(edge .. "LEFT"); t:SetPoint(edge .. "RIGHT"); t:SetHeight(2)
                else
                    t:SetPoint("TOP" .. edge); t:SetPoint("BOTTOM" .. edge); t:SetWidth(2)
                end
                f.edges[#f.edges + 1] = t
            end
            f.shade = f:CreateTexture(nil, "BACKGROUND")
            f.shade:SetAllPoints()
            f.shade:SetColorTexture(0, 0, 0, 0.55)
            f.badge = CreateLockIcon(f)
            f.badge:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 1, 1)
            HideHover(f)
            f:Hide()
            return f
        end
        function B.Paint(target, data)
            if not B.running or InCombatLockdown() then return end
            local layer = B.layers[target]
            if data.bag < 0 or data.bag > Enum.BagIndex.ReagentBag then
                if layer then layer:Hide() end
                return
            end
            if not data.info or not data.info.itemID or data.slot < 1 then
                if layer then layer:Hide() end
                return
            end
            if not layer then layer = CreateLayer(target); B.layers[target] = layer end
            local item = ns.Capture(data.bag, data.slot)
            layer.target, layer.bag, layer.slot = target, data.bag, data.slot
            layer.guid = item and item.guid
            if not item or not target:IsVisible() then layer:Hide(); return end
            local locked = ns.IsLocked(item)
            if layer:GetParent() ~= target:GetParent() then layer:SetParent(target:GetParent()) end
            layer:ClearAllPoints()
            layer:SetAllPoints(target)
            layer:SetFrameStrata(target:GetFrameStrata())
            layer:SetFrameLevel(target:GetFrameLevel() + 20)
            layer:EnableMouseMotion(B.mode)
            layer.badge:SetShown(locked)
            layer.shade:SetShown(B.mode and not locked and not ns.Eligible(item))
            if not B.mode then HideHover(layer) end
            local merchant = MerchantFrame and MerchantFrame:IsVisible() and MerchantFrame.selectedTab == 1
            if B.mode or merchant then layer:SetPassThroughButtons("MiddleButton")
            else layer:SetPassThroughButtons("RightButton", "MiddleButton") end
            layer:SetShown(B.mode or locked)
            B.SyncLauncher()
        end
        function B.Refresh()
            if not B.running or InCombatLockdown() then return end
            for target, layer in pairs(B.layers) do
                if target:IsVisible() then
                    local bag, slot = target:GetParent():GetID(), target:GetID()
                    B.Paint(target, { bag = bag, slot = slot, info = C_Container.GetContainerItemInfo(bag, slot) })
                else layer:Hide() end
            end
            B.SyncLauncher()
        end
        function B.SetMode(on)
            if not B.running or InCombatLockdown() then return end
            ns.Cancel()
            B.mode = on and true or false
            if B.mode and not B.bar then
                local bar = CreateFrame("Frame", "DraxtilitiesSelection", UIParent)
                bar:SetSize(350, 70)
                bar:SetPoint("CENTER", UIParent, "CENTER", 0, 180)
                bar:SetFrameStrata("DIALOG")
                bar:EnableMouse(true)
                bar:SetMovable(true)
                bar:RegisterForDrag("LeftButton")
                bar:SetScript("OnDragStart", bar.StartMoving)
                bar:SetScript("OnDragStop", bar.StopMovingOrSizing)
                local label = bar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                label:SetPoint("TOP", 0, -12)
                label:SetText("Click items to lock or unlock. Esc to finish.")
                local stop = CreateFrame("Button", nil, bar, "UIPanelButtonTemplate")
                stop:SetSize(100, 22); stop:SetPoint("BOTTOMLEFT", 15, 10); stop:SetText("Done")
                stop:SetScript("OnClick", function() B.SetMode(false) end)
                local manage = CreateFrame("Button", nil, bar, "UIPanelButtonTemplate")
                manage:SetSize(160, 22); manage:SetPoint("BOTTOMRIGHT", -15, 10); manage:SetText("Locked items")
                manage:SetScript("OnClick", function()
                    B.SetMode(false); EllesmereUI.OpenPlugin(ns.id, "Protection", "Items")
                end)
                bar:SetScript("OnHide", function() B.mode = false; B.Refresh() end)
                UISpecialFrames[#UISpecialFrames + 1] = "DraxtilitiesSelection"
                ns.AddSkin(function(S)
                    S.Shell(bar); S.Button(stop); S.Button(manage); S.Font(label)
                end)
                B.bar = bar
            end
            if B.bar then B.bar:SetShown(B.mode) end
            B.Refresh()
            if B.mode and not next(B.layers) then ns.Print("Open or reopen your EUI bags once to attach the item controls.") end
        end
        function B.Event(event)
            if event == "MERCHANT_SHOW" or event == "BAG_CLOSED" then B.SetMode(false) end
        end
        function B.Suspend()
            B.mode = false
            for _, layer in pairs(B.layers) do layer:Hide() end
            if B.bar then B.bar:Hide() end
            if B.launcher then B.launcher:Hide() end
        end
        function B.Stop() B.Suspend(); EUI_Bags.UnregisterItemOverlayIcon("Draxtilities") end
        EUI_Bags.RegisterItemOverlayIcon("Draxtilities", B.Paint)
        return B
    end,
})
