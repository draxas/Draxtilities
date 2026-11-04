if EUI_CLIENT_BLOCKED then return end
local _, ns = ...
local controller
ns.Register("merchant", {
    title = "Native Junk Sale",
    description = "Confirms protected poor-quality copies sold with Blizzard's Sell All Junk button. EUI's own buttons and automatic sales are excluded.",
    events = { "MERCHANT_SHOW", "MERCHANT_CLOSED", "ADDON_LOADED" },
    Start = function()
        if not controller then
            controller = ns.CreatePanelGuard({
                title = "Sell protected junk",
                Target = function()
                    if MerchantFrame and MerchantFrame:IsVisible() and MerchantFrame.selectedTab == 1 then
                        return MerchantSellAllJunkButton
                    end
                end,
                Collect = function()
                    local items = {}
                    for bag = 0, Enum.BagIndex.ReagentBag do
                        for slot = 1, C_Container.GetContainerNumSlots(bag) do
                            local info = C_Container.GetContainerItemInfo(bag, slot)
                            if info and info.quality == Enum.ItemQuality.Poor and not info.hasNoValue then
                                local item = ns.Capture(bag, slot)
                                if not item then return {}, "", "An item cannot be identified yet. Try again." end
                                items[#items + 1] = item
                            end
                        end
                    end
                    return items, ns.Signature(items)
                end,
            })
        end
        return controller
    end,
})
