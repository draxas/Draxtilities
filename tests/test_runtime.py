"""Lua 5.1 regression checks with API doubles; no WoW client or taint simulation."""

from pathlib import Path
import unittest

from lupa.lua51 import LuaRuntime


ROOT = Path(__file__).resolve().parents[1]


class RuntimeTests(unittest.TestCase):
    def setUp(self):
        self.lua = LuaRuntime()
        self.lua.execute((ROOT / "tests/wow_mock.lua").read_text(encoding="utf-8"))
        self.ns = self.lua.table()
        self.lua.globals().ns = self.ns
        for name in ("Core.lua", "Store.lua", "Confirm.lua", "PanelGuard.lua", "TypedDelete.lua"):
            self.load(name)
        self.lua.execute("ns.InitStore()")

    def load(self, name):
        self.lua.compile((ROOT / name).read_text(encoding="utf-8-sig"), name="@" + name)("Draxtilities", self.ns)

    def run_lua(self, source):
        self.lua.execute(source)

    def test_all_runtime_files_compile(self):
        files = list(ROOT.glob("*.lua")) + list((ROOT / "Modules").glob("*.lua"))
        for path in files:
            with self.subTest(file=path.name):
                self.lua.compile(path.read_text(encoding="utf-8-sig"), name="@" + path.name)

    def test_defaults_and_existing_data(self):
        self.run_lua("""
            assert(next(ns.db.modules) == nil and next(ns.db.locks) == nil)
            ns.db.modules.bags = true
            ns.db.locks['Item-A'] = { id = 100 }
            ns.InitStore()
            assert(ns.db.modules.bags and ns.db.locks['Item-A'])
        """)

    def test_locks_distinguish_identical_copies(self):
        self.run_lua("""
            ns.active.bags = {}
            test.put(0, 1, 'Item-A')
            test.put(0, 2, 'Item-B')
            assert(ns.Toggle(0, 1))
            assert(ns.IsLocked(ns.Capture(0, 1)))
            assert(not ns.IsLocked(ns.Capture(0, 2)))
        """)

    def test_stackable_single_item_is_rejected(self):
        self.run_lua("""
            ns.active.bags = {}
            test.put(0, 1, 'Item-A', 100, 200)
            assert(not ns.Toggle(0, 1))
            assert(next(ns.db.locks) == nil)
        """)

    def test_missing_data_and_secret_guid_are_rejected(self):
        self.run_lua("""
            ns.active.bags = {}
            local item = test.put(0, 1, 'Item-A')
            item.stack = nil
            assert(not ns.Toggle(0, 1) and test.requested == 100)
            item.guid = { secret = true }
            assert(ns.Capture(0, 1) == nil)
        """)

    def test_stale_confirmation_does_not_act_on_another_copy(self):
        self.run_lua("""
            ns.active.bags = {}
            test.put(0, 1, 'Item-A')
            ns.Toggle(0, 1)
            local executed = false
            assert(ns.Request('Test', { ns.Capture(0, 1) }, nil, function() executed = true end))
            test.put(0, 1, 'Item-B')
            test.confirm.onConfirm()
            assert(not executed and ns.pending == nil)
        """)

    def test_cancelled_and_combat_confirmations_do_not_execute(self):
        self.run_lua("""
            ns.active.bags = {}
            test.put(0, 1, 'Item-A')
            ns.Toggle(0, 1)
            local executed = false
            ns.Request('Test', { ns.Capture(0, 1) }, nil, function() executed = true end)
            local confirm = test.confirm
            ns.Cancel()
            confirm.onConfirm()
            assert(not executed)
            ns.Request('Test', { ns.Capture(0, 1) }, nil, function() executed = true end)
            test.combat = true
            test.confirm.onConfirm()
            assert(not executed)
        """)

    def test_native_permission_is_one_use_and_revalidates(self):
        self.run_lua("""
            ns.active.bags = {}
            test.put(0, 1, 'Item-A')
            ns.Toggle(0, 1)
            local target = CreateFrame('Button')
            local price = 10
            local guard = ns.CreatePanelGuard({ title = 'Test', Target = function() return target end,
                Collect = function() return { ns.Capture(0, 1) }, tostring(price) end })
            guard.running = true
            guard.Refresh()
            test.click(guard.button)
            assert(not target.clicks)
            test.confirm.onConfirm()
            assert(not target.clicks)
            price = 20
            test.click(guard.button)
            assert(not target.clicks)
            test.confirm.onConfirm()
            test.click(guard.button)
            assert(target.clicks == 1)
            test.click(guard.button)
            assert(target.clicks == 1 and ns.pending)
        """)

    def test_absent_inventory_does_not_remove_unobserved_locks(self):
        self.run_lua("""
            ns.db.locks['Item-A'] = { id = 100 }
            ns.ReconcileRemovals()
            assert(ns.db.locks['Item-A'])
        """)

    def test_observed_destruction_removes_only_consumed_copy(self):
        self.run_lua("""
            test.put(0, 1, 'Item-A')
            test.put(0, 2, 'Item-B')
            ns.db.locks['Item-A'], ns.db.locks['Item-B'] = { id = 100 }, { id = 100 }
            ns.WatchRemoval({ ns.Capture(0, 1) })
            test.items['0:1'] = nil
            ns.ReconcileRemovals()
            assert(not ns.db.locks['Item-A'] and ns.db.locks['Item-B'])
        """)

    def test_cancelled_action_cannot_remove_a_later_sold_copy(self):
        self.run_lua("""
            ns.active.bags = {}
            test.put(0, 1, 'Item-A')
            ns.db.locks['Item-A'] = { id = 100 }
            ns.WatchRemoval({ ns.Capture(0, 1) })
            ns.Cancel()
            ns.ReconcileRemovals()
            test.items['0:1'] = nil -- later sale, outside the cancelled destruction
            ns.ReconcileRemovals()
            assert(ns.db.locks['Item-A'], 'cancelled destruction removed a subsequently sold copy lock')
        """)

    def test_cancelled_native_delete_does_not_watch_a_later_sale(self):
        self.load("Modules/Cursor.lua")
        self.run_lua("""
            assert(ns.SetEnabled('cursor', true))
            test.put(0, 1, 'Item-A', 100, 1, 1)
            ns.db.locks['Item-A'] = { id = 100 }
            test.cursor = test.location(0, 1)
            ns.Refresh()
            ns.active.cursor.world.scripts.OnClick(nil, 'LeftButton')
            test.confirm.onConfirm()
            ClearCursor() -- cancel the native popup
            test.event('CURSOR_CHANGED')
            test.items['0:1'] = nil -- later sale
            ns.ReconcileRemovals()
            assert(ns.db.locks['Item-A'], 'cancelled native deletion left a removal watch active')
        """)

    def test_unavailable_native_delete_does_not_start_removal_tracking(self):
        self.load("Modules/Cursor.lua")
        self.run_lua("""
            assert(ns.SetEnabled('cursor', true))
            test.put(0, 1, 'Item-A', 100, 1, 1)
            ns.db.locks['Item-A'] = { id = 100 }
            test.cursor = test.location(0, 1)
            ns.Refresh()
            GameEvent = nil
            ns.active.cursor.world.scripts.OnClick(nil, 'LeftButton')
            test.confirm.onConfirm()
            ClearCursor()
            test.items['0:1'] = nil
            ns.ReconcileRemovals()
            assert(ns.db.locks['Item-A'])
        """)

    def test_typed_delete_requires_native_then_eui_acceptance(self):
        self.load("Modules/Cursor.lua")
        self.run_lua("""
            assert(ns.SetEnabled('cursor', true))
            test.put(0, 1, 'Item-A')
            ns.db.locks['Item-A'] = { id = 100 }
            test.cursor = test.location(0, 1)
            ns.Refresh()
            ns.active.cursor.world.scripts.OnClick(nil, 'LeftButton')
            local key = 'DRAXTILITIES_DELETE_GOOD_ITEM'
            local dialog = test.popups[key]
            assert(dialog and not test.confirm)
            StaticPopupDialogs[key].OnAccept(dialog, dialog.data)
            StaticPopup_Hide(key)
            assert(test.confirm and test.items['0:1'])
            test.confirm.onConfirm()
            ns.ReconcileRemovals()
            assert(not test.items['0:1'] and not ns.db.locks['Item-A'])
        """)

    def test_closed_native_panel_discards_only_its_removal_watch(self):
        self.run_lua("""
            ns.active.bags = {}
            test.put(0, 1, 'Item-A')
            test.put(0, 2, 'Item-B')
            ns.db.locks['Item-A'], ns.db.locks['Item-B'] = { id = 100 }, { id = 100 }
            local target = CreateFrame('Button')
            local guard = ns.CreatePanelGuard({ title = 'Scrap', track = true,
                Target = function() return target end,
                Collect = function() return { ns.Capture(0, 1) }, 'same' end })
            guard.running = true
            guard.Refresh()
            test.click(guard.button)
            test.confirm.onConfirm()
            test.click(guard.button)
            ns.WatchRemoval({ ns.Capture(0, 2) })
            target:Hide()
            guard.Refresh()
            test.items['0:1'], test.items['0:2'] = nil, nil
            ns.ReconcileRemovals()
            assert(ns.db.locks['Item-A'] and not ns.db.locks['Item-B'])
        """)

    def test_interrupted_scrapping_cannot_remove_a_later_sold_copy(self):
        self.load("Modules/Scrapping.lua")
        self.run_lua("""
            ScrappingMachineFrame = CreateFrame('Frame')
            ScrappingMachineFrame.ScrapButton = CreateFrame('Button', nil, ScrappingMachineFrame)
            test.put(0, 1, 'Item-A')
            ns.db.locks['Item-A'] = { id = 100 }
            C_ScrappingMachineUI.GetCurrentPendingScrapItemLocationByIndex = function(index)
                if index == 0 then return test.location(0, 1) end
            end
            assert(ns.SetEnabled('scrapping', true))
            local guard = ns.active.scrapping
            test.click(guard.button)
            test.confirm.onConfirm()
            test.click(guard.button)
            test.event('UNIT_SPELLCAST_INTERRUPTED', 'player', 'cast-guid', 123)
            test.items['0:1'] = nil
            ns.ReconcileRemovals()
            assert(ns.db.locks['Item-A'])
        """)

    def test_native_panel_can_appear_after_its_show_event(self):
        self.load("Modules/Merchant.lua")
        self.run_lua("""
            assert(ns.SetEnabled('merchant', true))
            test.event('MERCHANT_SHOW')
            MerchantFrame = CreateFrame('Frame')
            MerchantFrame.selectedTab = 1
            MerchantSellAllJunkButton = CreateFrame('Button', nil, MerchantFrame)
            test.flushTimers()
            assert(ns.active.merchant.button and ns.active.merchant.button:IsShown())
        """)

    def test_complete_addon_loads_with_all_modules_off(self):
        for name in ("Bags", "Cursor", "Merchant", "Auctions", "Scrapping"):
            self.load(f"Modules/{name}.lua")
        self.load("Options.lua")
        self.run_lua("""
            test.event('ADDON_LOADED', 'Draxtilities')
            assert(test.plugin.label == 'Draxtilities')
            assert(#ns.order == 5 and next(ns.active) == nil)
            assert(#test.plugin.modules[1].pages == 3)
        """)

    def test_bag_selection_and_hidden_slot_cleanup(self):
        self.load("Modules/Bags.lua")
        self.run_lua("""
            test.put(0, 1, 'Item-A')
            assert(ns.SetEnabled('bags', true))
            local parent = CreateFrame('Frame')
            parent:SetID(0)
            local target = CreateFrame('Button', nil, parent)
            target:SetID(1)
            test.paint(target, { bag = 0, slot = 1, info = { itemID = 100 } })
            local bags = ns.active.bags
            bags.SetMode(true)
            local layer = bags.layers[target]
            layer.scripts.OnClick(layer, 'LeftButton')
            assert(ns.db.locks['Item-A'] and bags.mode)
            layer.scripts.OnClick(layer, 'RightButton')
            assert(not bags.mode and layer:IsVisible())
            target:Hide()
            layer.scripts.OnUpdate(layer)
            assert(not layer:IsVisible(), 'overlay stayed visible after its EUI slot was hidden')
        """)


if __name__ == "__main__":
    unittest.main()
