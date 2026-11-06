if EUI_CLIENT_BLOCKED then return end
local _, ns = ...
local controller
ns.Register("scrapping", {
    title = "Native Scrapping",
    description = "Confirms the native Scrap button, rechecks every selected copy and removes locks only after successful removal.",
    events = { "SCRAPPING_MACHINE_PENDING_ITEM_CHANGED", "PLAYER_INTERACTION_MANAGER_FRAME_SHOW",
        "PLAYER_INTERACTION_MANAGER_FRAME_HIDE", "ADDON_LOADED",
        "UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_FAILED" },
    Start = function()
        if not controller then
            controller = ns.CreatePanelGuard({
                title = "Scrap protected items", track = true,
                Target = function()
                    return ScrappingMachineFrame and ScrappingMachineFrame:IsVisible()
                        and ScrappingMachineFrame.ScrapButton or nil
                end,
                Collect = function()
                    local items = {}
                    for index = 0, 8 do
                        local location = C_ScrappingMachineUI.GetCurrentPendingScrapItemLocationByIndex(index)
                        local item = ns.CaptureLocation(location)
                        if location and location:HasAnyLocation() and C_Item.DoesItemExist(location) and not item then
                            return {}, "", "A scrap copy cannot be identified yet. Try again."
                        end
                        if item then items[#items + 1] = item end
                    end
                    return items, ns.Signature(items)
                end,
            })
            function controller.Event(event, unit, _, spellID)
                if (event == "UNIT_SPELLCAST_INTERRUPTED" or event == "UNIT_SPELLCAST_FAILED")
                    and unit == "player" and spellID == C_ScrappingMachineUI.GetScrapSpellID() then
                    controller.Cancel()
                end
            end
        end
        return controller
    end,
})
