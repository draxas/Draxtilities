if EUI_CLIENT_BLOCKED then return end
local _, ns = ...

function ns.Stale()
    ns.Print("The item or action changed. Try again.")
end

function ns.Request(title, items, validate, execute, trackRemoval, dismiss, disclaimer)
    if InCombatLockdown() or not next(ns.active) then return false end
    local cursor = ns.active.cursor
    if cursor and cursor.IsTyping() then ns.Print("Finish the native deletion dialog first."); return false end
    ns.CancelRequest()
    local request = { dismiss = dismiss }
    local names, protected = {}, {}
    for _, item in ipairs(items) do
        if ns.IsLocked(item) then
            protected[item.guid] = true
            if #names < 6 then
                names[#names + 1] = (item.link or ("#" .. item.id))
                    .. " (bag " .. tostring(item.bag) .. ", slot " .. tostring(item.slot) .. ")"
            end
        end
    end
    if #names == 0 then return false end
    ns.pending = request
    local function Cancel()
        if ns.pending == request then
            ns.pending = nil
            if dismiss then dismiss() end
        end
    end
    request.handle = EllesmereUI:ShowConfirmPopup({
        title = title,
        message = "This action affects protected copies.\n\n" .. table.concat(names, "\n"),
        disclaimer = disclaimer or "This confirmation applies only to this action. Surviving copies keep their locks.",
        confirmText = "Continue", cancelText = "Cancel",
        onCancel = Cancel, onDismiss = Cancel,
        onConfirm = function()
            if ns.pending ~= request then return end
            local valid = not InCombatLockdown() and next(ns.active) ~= nil
            for _, item in ipairs(items) do
                local now = ns.CaptureLocation(item.location)
                if not now or now.guid ~= item.guid or (protected[item.guid] and not ns.IsLocked(item)) then
                    valid = false; break
                end
            end
            if valid and validate then valid = validate() == true end
            if not valid then Cancel(); ns.Stale(); return end
            ns.pending = nil
            if trackRemoval then ns.WatchRemoval(items) end
            execute()
        end,
    })
    return true
end
