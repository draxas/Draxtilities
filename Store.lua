if EUI_CLIENT_BLOCKED then return end
local _, ns = ...
local removals = {}
ns.loading = {}

function ns.InitStore()
    if type(DraxtilitiesDB) ~= "table" then DraxtilitiesDB = {} end
    if type(DraxtilitiesDB.companion) ~= "table" then DraxtilitiesDB.companion = {} end
    ns.db = DraxtilitiesDB.companion
    if type(ns.db.modules) ~= "table" then ns.db.modules = {} end
    if type(ns.db.locks) ~= "table" then ns.db.locks = {} end
    ns.db.version = 1
end

function ns.CaptureLocation(location)
    if not location or not location:HasAnyLocation() or not C_Item.DoesItemExist(location) then return end
    local guid = C_Item.GetItemGUID(location)
    if (issecretvalue and issecretvalue(guid)) or type(guid) ~= "string" or guid == "" then return end
    local id = C_Item.GetItemID(location)
    if type(id) ~= "number" then return end
    local bag, slot = location:GetBagAndSlot()
    return { guid = guid, id = id, link = C_Item.GetItemLink(location),
        location = location, bag = bag, slot = slot }
end

function ns.Capture(bag, slot)
    if type(bag) ~= "number" or type(slot) ~= "number" or slot < 1 then return end
    return ns.CaptureLocation(ItemLocation:CreateFromBagAndSlot(bag, slot))
end

function ns.IsLocked(item)
    return item ~= nil and type(ns.db.locks[item.guid]) == "table"
end

function ns.Eligible(item)
    return item and C_Item.GetItemMaxStackSize(item.location) == 1 or false
end

function ns.Toggle(bag, slot)
    if not next(ns.active) or InCombatLockdown() then return false end
    local item = ns.Capture(bag, slot)
    if not item then return false end
    if ns.IsLocked(item) then ns.db.locks[item.guid] = nil
    else
        local maxStack = C_Item.GetItemMaxStackSize(item.location)
        if not maxStack then
            ns.loading[item.id] = true
            C_Item.RequestLoadItemDataByID(item.id)
            ns.Print("Item data is loading. Try again.")
            return false
        end
        if maxStack ~= 1 then ns.Print("Only items that cannot stack can be protected."); return false end
        ns.db.locks[item.guid] = { id = item.id, link = item.link, owner = GetUnitName("player", true) }
    end
    ns.Cancel()
    ns.Refresh()
    return true
end

function ns.Remove(guid)
    if InCombatLockdown() then return end
    ns.db.locks[guid] = nil
    ns.Cancel()
    ns.Refresh()
end

function ns.Inventory()
    local items = {}
    for bag = 0, Enum.BagIndex.ReagentBag do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local item = ns.Capture(bag, slot)
            if item and (ns.Eligible(item) or ns.IsLocked(item)) then items[#items + 1] = item end
        end
    end
    table.sort(items, function(a, b)
        if a.bag ~= b.bag then return a.bag < b.bag end
        return a.slot < b.slot
    end)
    return items
end

function ns.WatchRemoval(items)
    local ticket = {}
    for _, item in ipairs(items) do
        if ns.IsLocked(item) then removals[item.guid] = { item = item, ticket = ticket } end
    end
    return ticket
end

function ns.CancelRemovals(ticket)
    for guid, watch in pairs(removals) do
        if not ticket or watch.ticket == ticket then removals[guid] = nil end
    end
end

function ns.CancelRemoval(guid)
    removals[guid] = nil
end

function ns.ReconcileRemovals()
    for guid, watch in pairs(removals) do
        local original = watch.item
        local location = C_Item.GetItemLocation(guid)
        if location and location:HasAnyLocation() and C_Item.DoesItemExist(location) then
            local now = ns.CaptureLocation(location)
            if now and now.guid == guid and (now.bag ~= original.bag or now.slot ~= original.slot) then
                removals[guid] = nil
            end
        else
            local cursorLocation = C_Cursor.GetCursorItem()
            local cursor = ns.CaptureLocation(cursorLocation)
            local unknownCursor = cursorLocation and cursorLocation:HasAnyLocation()
                and C_Item.DoesItemExist(cursorLocation) and not cursor
            if not unknownCursor and (not cursor or cursor.guid ~= guid) then
                ns.db.locks[guid], removals[guid] = nil, nil
            end
        end
    end
end

function ns.Signature(items)
    local parts = {}
    for _, item in ipairs(items) do
        parts[#parts + 1] = item.guid .. ":" .. tostring(item.bag) .. ":" .. tostring(item.slot)
    end
    table.sort(parts)
    return table.concat(parts, "|")
end
