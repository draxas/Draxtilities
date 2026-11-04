if EUI_CLIENT_BLOCKED then return end
local _, ns = ...
local controller
ns.Register("auctions", {
    title = "Native Auctions",
    description = "Confirms the native Post button. Price, duration, quantity and exact copy are rechecked. Third-party auction addons are excluded.",
    events = { "AUCTION_HOUSE_SHOW", "AUCTION_HOUSE_CLOSED", "ADDON_LOADED",
        "ITEM_SEARCH_RESULTS_UPDATED", "ITEM_SEARCH_RESULTS_ADDED" },
    Start = function()
        if not controller then
            controller = ns.CreatePanelGuard({
                title = "Auction a protected item",
                Target = function()
                    local sell = AuctionHouseFrame and AuctionHouseFrame.ItemSellFrame
                    return sell and sell:IsVisible() and sell.PostButton or nil
                end,
                Collect = function()
                    local sell = AuctionHouseFrame and AuctionHouseFrame.ItemSellFrame
                    if not sell or not sell:IsVisible() then return {}, "" end
                    local location, duration, quantity, bid, buyout = sell:GetPostDetails()
                    local item = ns.CaptureLocation(location)
                    if not item then
                        if location and location:HasAnyLocation() and C_Item.DoesItemExist(location) then
                            return {}, "", "The auction copy cannot be identified yet. Try again."
                        end
                        return {}, ""
                    end
                    if quantity and quantity > 1 then
                        for _, copy in ipairs(ns.Inventory()) do
                            if copy.id == item.id and ns.IsLocked(copy) then
                                return {}, "", "Post one copy at a time when matching protected copies are in your bags."
                            end
                        end
                    end
                    local signature = ns.Signature({ item }) .. ":" .. tostring(duration)
                        .. ":" .. tostring(quantity) .. ":" .. tostring(bid) .. ":" .. tostring(buyout)
                    return { item }, signature
                end,
            })
        end
        return controller
    end,
})
