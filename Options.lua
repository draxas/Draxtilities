if EUI_CLIENT_BLOCKED then return end
local _, ns = ...
local protectedOnly, page = true, 1
local PAGE_SIZE = 12

local function BuildPage(pageName, parent, yOffset)
    local EUI, W = EllesmereUI, EllesmereUI.Widgets
    local y = yOffset
    local function Section(title)
        local _, h = W:SectionHeader(parent, title, y); y = y - h
    end
    local function Row(left, right)
        local _, h = W:DualRow(parent, y, left, right); y = y - h
    end
    local function Refresh() ns.RefreshOptions() end
    if pageName == "Modules" then
        Section("INDEPENDENT MODULES - ALL OFF BY DEFAULT")
        local configs = {}
        for _, key in ipairs(ns.order) do
            local id, spec = key, ns.modules[key]
            configs[#configs + 1] = { type = "toggle", text = spec.title, noCapture = true,
                tooltip = spec.description, disabled = InCombatLockdown,
                getValue = function() return ns.active[id] ~= nil end,
                setValue = function(value) if ns.SetEnabled(id, value) then Refresh() end end }
        end
        for index = 1, #configs, 2 do
            Row(configs[index], configs[index + 1] or {
                type = "label", text = "Review Coverage before relying on these safeguards." })
        end
        Section("MANAGE LOCKS")
        Row({ type = "label", text = "/dt lock", tooltip = "Toggles bag selection. Open or reopen the EUI bags once after enabling Bag Locks. Esc or the Done button ends selection." },
            { type = "button", text = "Toggle cursor copy", disabled = function()
                return InCombatLockdown() or not next(ns.active) or GetCursorInfo() ~= "item"
              end,
              onClick = function()
                  local item = ns.CaptureLocation(C_Cursor.GetCursorItem())
                  if item and item.bag and ns.Toggle(item.bag, item.slot) then ClearCursor(); Refresh() end
              end })
        Row({ type = "label", text = "Exact copies in the Items tab", tooltip = "Every non-stackable copy in the current bags has its own row, including copies hidden by EUI grouping. Use the GUID suffix and bag/slot to distinguish them." },
            { type = "label", text = "Non-stackable items only",
              tooltip = "Each protected copy is identified by its GUID. Items that can stack cannot be protected, even when you hold only one." })
    elseif pageName == "Coverage" then
        Section("WHAT IS COVERED")
        Row({ type = "label", text = "Bag Locks", tooltip = ns.modules.bags.description },
            { type = "label", text = "Cursor Safeguards", tooltip = ns.modules.cursor.description })
        Row({ type = "label", text = "Native action buttons", tooltip = "Enable the corresponding module. When protected copies are involved, press the native action button to show an EUI confirmation. Confirm the popup, then press the native action button again to execute the action after revalidation. Actions involving no protected copies proceed immediately." },
            { type = "label", text = "Out of combat", tooltip = "Combat cancels pending confirmations and permissions. No destructive action is replayed when combat ends." })
        Section("EXCLUDED INTEGRATIONS AND ALTERNATIVES")
        Row({ type = "label", text = "EUI auto-sell and Sell Junk", tooltip = "Not intercepted. Disable automatic selling in EUI and other addons. Use manual right-click sales with Bag Locks, or Blizzard's native Sell All Junk with Native Junk Sale enabled." },
            { type = "label", text = "EUI automatic container opening", tooltip = "Not intercepted. Disable automatic opening and open containers manually after checking the Items tab. A lock is not a game-level inventory lock." })
        Row({ type = "label", text = "Quick Actions and item spells", tooltip = "Disenchanting and other item-targeted spells, including EUI Quick Actions, are not covered. Explicitly unlock the chosen copy in Items before using those actions. Direct spell targeting onto our protected bag control is blocked, but other entry points are not intercepted." },
            { type = "label", text = "Header and Protected Items filter", tooltip = "The original EUI header, sidebar and Junk mode are untouched. Use /dt lock or a macro for selection, and the Items tab with Protected only enabled instead of the old sidebar filter." })
        Row({ type = "label", text = "Grouped copies", tooltip = "Bag badges refer to the exact copy represented by EUI's slot. The companion cannot change EUI's merge rules. Use Items to manage every copy individually." },
            { type = "label", text = "Mail, trade, crafting and other addons", tooltip = "Not intercepted, including macros and third-party auction/scrap tools. The companion provides safeguards only for the routes listed above, never universal destruction prevention." })
    else
        Section("EXACT COPIES")
        Row({ type = "toggle", text = "Protected only", getValue = function() return protectedOnly end,
              setValue = function(value) protectedOnly = value; page = 1; Refresh() end },
            { type = "button", text = "Refresh", onClick = Refresh })
        if EUI.IsSearchPrebuild() then return math.abs(y) end
        local inventory, locations, entries = ns.Inventory(), {}, {}
        for _, item in ipairs(inventory) do locations[item.guid] = item end
        if protectedOnly then
            for guid, record in pairs(ns.db.locks) do
                entries[#entries + 1] = { guid = guid, record = record, item = locations[guid] }
            end
            table.sort(entries, function(a, b) return a.guid < b.guid end)
        else
            for _, item in ipairs(inventory) do
                entries[#entries + 1] = { guid = item.guid, record = item, item = item }
            end
        end
        local last = math.max(1, math.ceil(#entries / PAGE_SIZE))
        page = math.max(1, math.min(page, last))
        Row({ type = "label", text = "Copies: " .. #entries },
            { type = "label", text = "Page " .. page .. " / " .. last })
        for index = (page - 1) * PAGE_SIZE + 1, math.min(page * PAGE_SIZE, #entries) do
            local entry = entries[index]
            local guid, item = entry.guid, entry.item
            local locked = ns.db.locks[guid] ~= nil
            local position = item and ("Bag " .. item.bag .. ", slot " .. item.slot) or "Not in this character's bags"
            Row({ type = "label", text = (entry.record.link or ("#" .. tostring(entry.record.id))) .. " [" .. guid:sub(-8) .. "]",
                  tooltip = position .. "\n" .. (entry.record.owner or "") .. "\n" .. guid, rawTooltip = true },
                { type = "button", text = locked and "Remove protection" or "Protect this copy",
                  disabled = function() return InCombatLockdown() or (not locked and not next(ns.active)) end,
                  onClick = function()
                      if locked then ns.Remove(guid)
                      else
                          local now = ns.Capture(item.bag, item.slot)
                          if not now or now.guid ~= guid then ns.Stale(); Refresh(); return end
                          ns.Toggle(item.bag, item.slot)
                      end
                      Refresh()
                  end })
        end
        Row({ type = "button", text = "Previous", disabled = function() return page == 1 end,
              onClick = function() page = page - 1; Refresh() end },
            { type = "button", text = "Next", disabled = function() return page == last end,
              onClick = function() page = page + 1; Refresh() end })
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
            description = "Independent modules. Read Coverage for the actions this companion can actually intercept.",
            pages = { "Modules", "Items", "Coverage" }, buildPage = BuildPage }},
    })
end
