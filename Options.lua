if EUI_CLIENT_BLOCKED then return end
local _, ns = ...
local query, page = "", 1
local PAGE_SIZE = 12
local itemRows = {}
local searchBox, refreshingSearch
local actions = {
    { "bags", "EUI bag controls" },
    { "cursor", "Dragged item sales and deletion" },
    { "merchant", "Sell All Junk button" },
    { "auctions", "Auction Post button" },
    { "scrapping", "Scrap button" },
}

local function CopyName(record)
    local link = record.link or ""
    return (link:match("%[(.-)%]") or link):lower()
end

local function HideTooltip(row)
    if GameTooltip:IsOwned(row) then GameTooltip:Hide() end
end

local function ShowTooltip(iconTarget)
    local row = iconTarget:GetParent()
    local entry = row.entry
    if not entry then return end
    EllesmereUI.HideWidgetTooltip()
    GameTooltip:SetOwner(iconTarget, "ANCHOR_CURSOR")
    local item = entry.item
    local current = item and ns.Capture(item.bag, item.slot)
    if current and current.guid == entry.guid then
        GameTooltip:SetBagItem(current.bag, current.slot)
    elseif entry.record.link then
        GameTooltip:SetHyperlink(entry.record.link)
    else
        GameTooltip:SetItemByID(entry.record.id)
    end
    GameTooltip:Show()
end

local function CreateItemRow(parent)
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(52)
    row:EnableMouse(false)
    row.iconTarget = CreateFrame("Frame", nil, row)
    row.iconTarget:SetSize(30, 30)
    row.iconTarget:SetPoint("LEFT", 20, 0)
    row.iconTarget:EnableMouse(true)
    row.iconTarget:SetScript("OnEnter", ShowTooltip)
    row.iconTarget:SetScript("OnLeave", HideTooltip)
    row:SetScript("OnHide", function(self) HideTooltip(self.iconTarget) end)
    row.icon = row.iconTarget:CreateTexture(nil, "ARTWORK")
    row.icon:SetAllPoints()
    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    row.action = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    row.action:SetSize(90, 26)
    row.action:SetPoint("RIGHT", -20, 0)
    row.action:SetText("Unlock")
    row.action:SetScript("OnClick", function()
        ns.Remove(row.entry.guid)
        ns.RefreshOptions()
    end)
    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    row.name:SetPoint("LEFT", row.icon, "RIGHT", 10, 8)
    row.name:SetPoint("RIGHT", row.action, "LEFT", -16, 8)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)
    row.detail = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    row.detail:SetPoint("LEFT", row.icon, "RIGHT", 10, -10)
    row.detail:SetPoint("RIGHT", row.action, "LEFT", -16, -10)
    row.detail:SetJustifyH("LEFT")
    row.detail:SetWordWrap(false)
    ns.AddSkin(function(S)
        S.Button(row.action); S.Font(row.name); S.Font(row.detail)
    end)
    return row
end

local function CreateSearchBox(parent)
    local box = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    box:SetAutoFocus(false)
    box:SetFontObject(GameFontHighlight)
    box:SetTextInsets(10, 10, 0, 0)
    box:SetScript("OnTextChanged", function(self, userInput)
        if not userInput or query == self:GetText() then return end
        query, page = self:GetText(), 1
        local focused, cursor = self:HasFocus(), self:GetCursorPosition()
        -- A public page refresh may replace the EUI wrapper. Our controls are
        -- reparented to that wrapper, rather than recreated on every keystroke.
        refreshingSearch = true
        ns.RefreshOptions()
        refreshingSearch = false
        if focused and self:IsVisible() then
            self:SetFocus()
            -- InputBoxTemplate selects all text on focus gain. Restoring only
            -- the caret leaves that selection active for the next keystroke.
            self:HighlightText(0, 0)
            self:SetCursorPosition(cursor)
        end
    end)
    box:SetScript("OnEnterPressed", box.ClearFocus)
    box:SetScript("OnEscapePressed", box.ClearFocus)
    box:SetScript("OnEditFocusLost", function(self)
        if not refreshingSearch and self:IsVisible() and ns.optionsDirty then ns.RefreshOptions() end
    end)
    ns.AddSkin(function(S) S.EditBox(box) end)
    return box
end

local function BuildPage(pageName, parent, yOffset)
    local EUI, W = EllesmereUI, EllesmereUI.Widgets
    local y = yOffset
    local prebuild = EUI.IsSearchPrebuild()
    if not prebuild then
        for _, row in ipairs(itemRows) do row:Hide() end
        if pageName ~= "Items" and searchBox then searchBox:Hide() end
    end
    local function Row(left, right)
        local _, height = W:DualRow(parent, y, left, right)
        y = y - height
    end
    local function Refresh() ns.RefreshOptions() end
    local function Disabled()
        return InCombatLockdown() or not ns.db.itemProtectionEnabled
    end
    if pageName == "Settings" then
        Row({ type = "toggle", text = "Enable Item Protection", noCapture = true,
              tooltip = "Turn all selected protection actions on or off. Saved item locks and your action preferences are kept when disabled.",
              disabled = InCombatLockdown,
              getValue = function() return ns.db.itemProtectionEnabled end,
              setValue = ns.SetProtectionEnabled })
        Row({ type = "button", text = "Lock or unlock bag items", width = 240,
              disabled = function() return Disabled() or not ns.active.bags end,
              tooltip = "Open your EUI bags, then click this button. Click items to add or remove their locks. Done or Esc finishes selection. Requires EUI bag controls.",
              onClick = ns.ToggleBagSelection },
            { type = "labeledButton", text = "Selection shortcut", width = 140,
              buttonText = ns.db.bagLockKey and GetBindingText(ns.db.bagLockKey) or "Set shortcut",
              disabled = function() return Disabled() or not ns.active.bags end,
              onClick = ns.BeginBagBinding,
              tooltip = "Choose a key for the same bag selection mode. It only works while EUI bag controls are enabled and out of combat." })
        local _, height = W:SectionHeader(parent, "Actions", y)
        y = y - height
        local controls = {}
        for _, action in ipairs(actions) do
            local key = action[1]
            controls[#controls + 1] = {
                type = "toggle", text = action[2], noCapture = true,
                tooltip = ns.modules[key] and ns.modules[key].description or "",
                disabled = Disabled,
                getValue = function() return ns.db.modules[key] == true end,
                setValue = function(value)
                    if ns.SetProtectionOption(key, value) then Refresh() end
                end,
            }
        end
        for index = 1, #controls, 2 do
            Row(controls[index], controls[index + 1] or { type = "label", text = "" })
        end
    elseif pageName == "Items" then
        local searchY = y
        Row({ type = "label", text = "Search locked items" })
        if prebuild then return math.abs(y) end
        if not searchBox then searchBox = CreateSearchBox(parent) end
        searchBox:SetParent(parent)
        searchBox:ClearAllPoints()
        searchBox:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -40, searchY - 11)
        searchBox:SetSize(math.min(280, math.max(120, parent:GetWidth() - 240)), 28)
        if searchBox:GetText() ~= query then searchBox:SetText(query) end
        searchBox:Show()
        local locations, entries = {}, {}
        for _, item in ipairs(ns.Inventory()) do locations[item.guid] = item end
        local search = query:match("^%s*(.-)%s*$"):lower()
        for guid, record in pairs(ns.db.locks) do
            if type(record) == "table" then
                local item = locations[guid]
                local name = CopyName(item or record)
                if search == "" or (name .. " " .. tostring(record.id or "") .. " " .. guid
                    .. " " .. (record.owner or "")):lower():find(search, 1, true) then
                    entries[#entries + 1] = { guid = guid, record = record, item = item }
                end
            end
        end
        table.sort(entries, function(a, b)
            local aName, bName = CopyName(a.item or a.record), CopyName(b.item or b.record)
            if aName ~= bName then return aName < bName end
            return a.guid < b.guid
        end)
        local last = math.max(1, math.ceil(#entries / PAGE_SIZE))
        page = math.max(1, math.min(page, last))
        if #entries == 0 then
            Row({ type = "label", text = query == "" and "No locked items." or "No matching items." })
        end
        for index = (page - 1) * PAGE_SIZE + 1, math.min(page * PAGE_SIZE, #entries) do
            local slot = index - (page - 1) * PAGE_SIZE
            local row = itemRows[slot]
            if not row then row = CreateItemRow(parent); itemRows[slot] = row end
            local entry = entries[index]
            local item, record = entry.item, entry.record
            row.entry = entry
            row:SetParent(parent)
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", parent, "TOPLEFT", 20, y)
            row:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -20, y)
            row.name:SetText((item and item.link) or record.link or ("Item #" .. tostring(record.id)))
            local position = item and ("Bag " .. item.bag .. ", slot " .. item.slot) or "Not in your bags"
            row.detail:SetText(position .. (record.owner and ("  |  " .. record.owner) or "")
                .. (not item and ("  |  " .. entry.guid:sub(-8)) or ""))
            row.icon:SetTexture(C_Item.GetItemIconByID(record.id) or "Interface\\Icons\\INV_Misc_QuestionMark")
            row.action:SetEnabled(not InCombatLockdown())
            row:Show()
            y = y - 52
        end
        if last > 1 then
            Row({ type = "button", text = "Previous", disabled = function() return page == 1 end,
                  onClick = function() page = page - 1; Refresh() end },
                { type = "button", text = "Next", disabled = function() return page == last end,
                  onClick = function() page = page + 1; Refresh() end })
        end
    end
    return math.abs(y)
end

function ns.RegisterOptions()
    if not EllesmereUI.RegisterPlugin then
        ns.Print("This EllesmereUI version does not provide the public Plugin API. Update the original addon.")
        return false
    end
    return EllesmereUI.RegisterPlugin(ns.id, {
        label = "Draxtilities",
        modules = {{ key = "Protection", title = "Item Protection",
            description = "Confirm before selling, deleting, auctioning or scrapping locked items.",
            pages = { "Settings", "Items" }, buildPage = BuildPage,
            onPageCacheRestore = function() ns.RefreshOptions() end }},
    })
end
