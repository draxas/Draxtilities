"""Lua 5.1 regression checks with API doubles; no WoW client or taint simulation."""

from pathlib import Path
import re
import unittest

from lupa.lua51 import LuaRuntime


ROOT = Path(__file__).resolve().parents[1]


class RuntimeTests(unittest.TestCase):
    def setUp(self):
        self.initialize_runtime()

    def initialize_runtime(self, locale="enUS"):
        self.lua = LuaRuntime()
        self.lua.execute((ROOT / "tests/wow_mock.lua").read_text(encoding="utf-8"))
        self.lua.globals().test.locale = locale
        self.ns = self.lua.table()
        self.lua.globals().ns = self.ns
        for name in ("Locale.lua", "Core.lua", "Store.lua", "Bindings.lua", "Confirm.lua", "PanelGuard.lua", "TypedDelete.lua"):
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

    def test_italian_catalog_covers_runtime_text_and_format_arguments(self):
        self.initialize_runtime("itIT")
        rawget = self.lua.eval("rawget")
        for entry in (ROOT / "Draxtilities.toc").read_text(encoding="utf-8").splitlines():
            if not entry.endswith(".lua") or entry == "Locale.lua":
                continue
            source = (ROOT / entry).read_text(encoding="utf-8")
            for literal in re.findall(r'L\[("(?:[^"\\]|\\.)*")\]', source):
                key = self.lua.execute("return " + literal)
                with self.subTest(file=entry, text=key):
                    translation = rawget(self.ns.L, key)
                    self.assertIsInstance(translation, str, "Missing Italian translation")
                    self.assertTrue(translation)
                    self.assertEqual(re.findall(r"%[sd]", key), re.findall(r"%[sd]", translation))

    def test_italian_ui_navigation_confirmations_and_locked_spell_message(self):
        self.initialize_runtime("itIT")
        for name in ("Bags", "Cursor", "Merchant", "Auctions", "Scrapping"):
            self.load(f"Modules/{name}.lua")
        self.load("Options.lua")
        self.run_lua("""
            test.event('ADDON_LOADED', 'Draxtilities')
            local module = test.plugin.modules[1]
            assert(module.key == 'Protection' and module.title == 'Protezione oggetti')
            assert(module.pages[1] == 'Impostazioni' and module.pages[2] == 'Oggetti')
            test.buildPage('Impostazioni', true)
            assert(test.findControl('Controlli borse EUI').disabled())
            test.buildPage('Impostazioni')
            test.findControl('Attiva protezione oggetti').setValue(true)
            assert(ns.active.bags and ns.active.cursor and ns.db.modules.bags)
            assert(ns.modules.bags.description:find('Disincantamento', 1, true))

            local opened
            EllesmereUI.OpenPlugin = function(id, key, page)
                assert(id == 'Draxtilities' and key == 'Protection')
                opened = page
                assert(page == 'Oggetti' or page == 'Impostazioni')
            end
            SlashCmdList.DRAXTILITIES('items')
            assert(opened == 'Oggetti')
            SlashCmdList.DRAXTILITIES('')
            assert(opened == 'Impostazioni')
            EUI_MainBagFrame:Show()
            ns.Refresh()
            ns.active.bags.launcher.scripts.OnClick(ns.active.bags.launcher, 'RightButton')
            assert(opened == 'Oggetti')

            test.put(0, 1, 'Item-A', 100, 1, 1)
            assert(ns.Toggle(0, 1))
            local parent = CreateFrame('Frame')
            parent:SetID(0)
            local target = CreateFrame('Button', nil, parent)
            target:SetID(1)
            test.paint(target, { bag = 0, slot = 1, info = { itemID = 100 } })
            local layer = ns.active.bags.layers[target]
            test.spellTarget = true
            layer.scripts.OnClick(layer, 'LeftButton')
            assert(test.messages[#test.messages] == '|cff0cd29fDraxtilities:|r Questo oggetto è bloccato.')
            assert(test.spellTarget and test.items['0:1'].guid == 'Item-A' and ns.db.locks['Item-A'])
            test.spellTarget = false
            test.cursor = test.location(0, 1)
            ns.Refresh()
            ns.active.cursor.world.scripts.OnClick(nil, 'LeftButton')
            assert(test.confirm.title == 'Elimina un oggetto protetto')
            assert(test.confirm.message:find(' (borsa 0, scomparto 1)', 1, true))
            assert(test.confirm.confirmText == 'Continua' and test.confirm.cancelText == 'Annulla')
            test.confirm.onCancel()
            ClearCursor()
            assert(ns.db.locks['Item-A'])

            ns.db.locks['Absent-copy'] = { id = 300 }
            test.buildPage('Oggetti', true)
            test.buildPage('Oggetti')
            assert(test.findControl('Cerca oggetti bloccati') and test.searchBox())
            for _, row in ipairs(test.itemRows()) do
                assert(row.action.text == 'Sblocca')
                if row.entry.guid == 'Absent-copy' then
                    assert(row.name.text == 'Oggetto #300' and row.detail.text:find('Non presente nelle tue borse', 1, true))
                else
                    assert(row.detail.text:find('Borsa 0, scomparto 1', 1, true))
                end
            end
            ns.BeginBagBinding()
            local dialog = DraxtilitiesBindingCapture
            assert(dialog.apply.text == 'Salva tasto' and dialog.clear.text == 'Rimuovi tasto')
            assert(dialog.hint.text:find('Premi una combinazione di tasti', 1, true))
            test.bindings['K'] = 'TOGGLEQUESTLOG'
            dialog.scripts.OnKeyDown(dialog, 'K')
            assert(dialog.hint.text:find('Attualmente assegnato a: TOGGLEQUESTLOG', 1, true))
            ns.CancelBagBinding()
        """)

    def test_untranslated_client_locale_uses_english_and_unknown_keys_fall_back(self):
        self.initialize_runtime("frFR")
        self.load("Options.lua")
        self.run_lua("""
            ns.RegisterOptions()
            assert(test.plugin.modules[1].title == 'Item Protection')
            assert(test.plugin.modules[1].pages[1] == 'Settings')
            assert(ns.L['This item is locked.'] == 'This item is locked.')
            assert(ns.L['Future untranslated text'] == 'Future untranslated text')
            test.buildPage('Settings')
            assert(test.findControl('Enable Item Protection'))
        """)

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

    def test_native_guard_follows_visibility_without_inventory_events(self):
        self.run_lua("""
            ns.active.bags = {}
            test.put(0, 1, 'Item-A')
            ns.db.locks['Item-A'] = { id = 100 }
            local target = CreateFrame('Button')
            local guard = ns.CreatePanelGuard({ title = 'Test', Target = function() return target end,
                Collect = function() return { ns.Capture(0, 1) }, 'same' end })
            guard.running = true
            guard.Refresh()
            test.click(guard.button)
            test.confirm.onConfirm()
            target:Hide()
            test.update(0.3)
            assert(not guard.button:IsShown(), 'hidden native button left an invisible click blocker')
            target:Show()
            test.update(0.3)
            assert(guard.button:IsShown(), 'native button reappeared without its safeguard')
            test.click(guard.button)
            assert(not target.clicks and ns.pending, 'permission survived hiding the native button')
            ns.CancelRequest()
            guard.running = false
            guard.Stop()
            test.update(0.3)
            assert(not guard.button:IsShown(), 'stopped native guard was restored by its watcher')
        """)

    def test_native_guard_cancels_only_its_pending_confirmation_when_closed(self):
        self.run_lua("""
            ns.active.bags = {}
            test.put(0, 1, 'Item-A')
            ns.db.locks['Item-A'] = { id = 100 }
            local target = CreateFrame('Button')
            local guard = ns.CreatePanelGuard({ title = 'Test', Target = function() return target end,
                Collect = function() return { ns.Capture(0, 1) }, 'same' end })
            guard.running = true
            guard.Refresh()
            test.click(guard.button)
            local old = test.confirm
            target:Hide()
            guard.Refresh()
            assert(not ns.pending, 'closed native panel left its confirmation open')
            target:Show()
            guard.Refresh()
            old.onConfirm()
            test.click(guard.button)
            assert(not target.clicks and ns.pending, 'old confirmation authorized a reopened panel')
            ns.Request('Other action', { ns.Capture(0, 1) }, nil, function() end)
            local other = ns.pending
            target:Hide()
            guard.Refresh()
            assert(ns.pending == other, 'closing a native panel cancelled another action')
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
        files = [line for line in (ROOT / "Draxtilities.toc").read_text(encoding="utf-8").splitlines()
                 if line.endswith(".lua")]
        for locale in ("enUS", "itIT"):
            with self.subTest(locale=locale):
                self.lua = LuaRuntime()
                self.lua.execute((ROOT / "tests/wow_mock.lua").read_text(encoding="utf-8"))
                self.lua.globals().test.locale = locale
                self.ns = self.lua.table()
                self.lua.globals().ns = self.ns
                for name in files:
                    self.load(name)
                self.run_lua("""
                    assert(not ns.db, 'the addon initialized before ADDON_LOADED')
                    test.event('ADDON_LOADED', 'Draxtilities')
                    assert(test.plugin.label == 'Draxtilities')
                    assert(#ns.order == 5 and next(ns.active) == nil)
                    assert(#test.plugin.modules[1].pages == 2)
                    assert(test.plugin.modules[1].pages[1] == ns.L['Settings'] and not ns.db.itemProtectionEnabled)
                    for _, key in ipairs(ns.order) do assert(ns.db.modules[key] == true) end
                """)

    def test_client_gate_prevents_all_runtime_initialization(self):
        self.lua = LuaRuntime()
        self.ns = self.lua.table()
        self.lua.globals().EUI_CLIENT_BLOCKED = True
        for entry in (ROOT / "Draxtilities.toc").read_text(encoding="utf-8").splitlines():
            if entry.endswith(".lua"):
                self.load(entry)
        self.assertEqual(list(self.ns.keys()), [])
        self.assertIsNone(self.lua.globals().Draxtilities)

    def test_item_protection_master_switch_preserves_actions_locks_and_shortcut(self):
        for name in ("Bags", "Cursor", "Merchant", "Auctions", "Scrapping"):
            self.load(f"Modules/{name}.lua")
        self.load("Options.lua")
        self.run_lua("""
            DraxtilitiesDB = {}
            ns.InitStore()
            ns.RegisterOptions()
            assert(not ns.db.itemProtectionEnabled and next(ns.active) == nil)
            for _, key in ipairs(ns.order) do assert(ns.db.modules[key] == true) end
            test.buildPage('Settings')
            assert(test.findControl('EUI bag controls').disabled())
            test.findControl('Enable Item Protection').setValue(true)
            for _, key in ipairs(ns.order) do assert(ns.active[key]) end
            assert(ns.SetProtectionOption('auctions', false))
            assert(not ns.active.auctions and ns.active.bags)
            test.put(0, 1, 'Item-A')
            assert(ns.Toggle(0, 1) and ns.SetBagBinding('ALT-L'))
            assert(ns.SetProtectionEnabled(false))
            assert(next(ns.active) == nil and ns.db.locks['Item-A'])
            assert(ns.db.modules.bags and not ns.db.modules.auctions and ns.db.bagLockKey == 'ALT-L')
            assert(GetBindingAction('ALT-L', true) == '')
            assert(ns.SetProtectionEnabled(true))
            assert(ns.active.bags and not ns.active.auctions and ns.db.locks['Item-A'])
            assert(GetBindingAction('ALT-L', true):find('DraxtilitiesLockBinding', 1, true))
            test.combat = true
            assert(not ns.SetProtectionEnabled(false) and not ns.SetProtectionOption('bags', false))
            assert(ns.db.itemProtectionEnabled and ns.active.bags)
        """)

    def test_legacy_action_preferences_migrate_without_enabling_other_actions(self):
        for name in ("Bags", "Cursor", "Merchant", "Auctions", "Scrapping"):
            self.load(f"Modules/{name}.lua")
        self.load("Options.lua")
        self.run_lua("""
            DraxtilitiesDB = { companion = { modules = { bags = true, merchant = false },
                locks = { ['Old-copy'] = { id = 100 } }, bagLockKey = 'ALT-L' } }
            test.event('ADDON_LOADED', 'Draxtilities')
            assert(ns.db.itemProtectionEnabled and ns.active.bags)
            assert(not ns.active.cursor and not ns.active.merchant and not ns.active.auctions and not ns.active.scrapping)
            assert(ns.db.modules.cursor == false and ns.db.locks['Old-copy'] and ns.db.bagLockKey == 'ALT-L')
            ns.SetProtectionEnabled(false)
            assert(ns.db.modules.bags and not ns.db.modules.merchant)
            ns.InitStore()
            assert(not ns.db.itemProtectionEnabled, 'saved disabled master switch was inferred from its action preferences')
            assert(next(ns.active) == nil and ns.db.locks['Old-copy'])
        """)

    def test_disabled_module_remains_inactive_after_load_with_prepared_actions(self):
        for name in ("Bags", "Cursor", "Merchant", "Auctions", "Scrapping"):
            self.load(f"Modules/{name}.lua")
        self.load("Options.lua")
        self.run_lua("""
            DraxtilitiesDB = { companion = { itemProtectionEnabled = false,
                modules = { bags = true, cursor = true }, bagLockKey = 'ALT-L' } }
            test.event('ADDON_LOADED', 'Draxtilities')
            assert(next(ns.active) == nil and GetBindingAction('ALT-L', true) == '')
            assert(ns.SetProtectionOption('bags', false))
            assert(next(ns.active) == nil and not ns.db.modules.bags)
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

    def test_bag_shortcut_restores_normal_key_when_module_is_disabled(self):
        self.load("Modules/Bags.lua")
        self.run_lua("""
            test.bindings['ALT-L'] = 'TOGGLEQUESTLOG'
            ns.db.bagLockKey = 'ALT-L'
            ns.UpdateBagBinding()
            assert(GetBindingAction('ALT-L', true) == 'TOGGLEQUESTLOG')
            assert(ns.SetEnabled('bags', true))
            test.pressKey('ALT-L')
            assert(ns.active.bags.mode)
            test.pressKey('ALT-L')
            assert(not ns.active.bags.mode)
            assert(ns.SetEnabled('bags', false))
            assert(GetBindingAction('ALT-L', true) == 'TOGGLEQUESTLOG')
            assert(ns.db.bagLockKey == 'ALT-L')
            assert(ns.SetEnabled('bags', true))
            assert(GetBindingAction('ALT-L', true):find('DraxtilitiesLockBinding', 1, true))
            assert(ns.SetBagBinding(nil))
            assert(GetBindingAction('ALT-L', true) == 'TOGGLEQUESTLOG')
        """)

    def test_shortcut_requires_enabled_module_and_does_not_act_in_combat(self):
        self.load("Modules/Bags.lua")
        self.run_lua("""
            assert(not ns.SetBagBinding('ALT-L'))
            ns.BeginBagBinding()
            assert(not DraxtilitiesBindingCapture)
            assert(ns.SetEnabled('bags', true))
            assert(ns.SetBagBinding('ALT-L'))
            test.combat = true
            test.event('PLAYER_REGEN_DISABLED')
            test.pressKey('ALT-L')
            assert(not ns.active.bags.mode)
            assert(not ns.SetBagBinding('ALT-M'))
            test.combat = false
            test.event('PLAYER_REGEN_ENABLED')
            assert(not ns.active.bags.mode, 'selection was queued during combat')
            test.pressKey('ALT-L')
            assert(ns.active.bags.mode)
        """)

    def test_shortcut_capture_requires_acceptance_and_cancels_on_combat(self):
        self.load("Modules/Bags.lua")
        self.run_lua("""
            assert(ns.SetEnabled('bags', true))
            assert(ns.SetBagBinding('ALT-L'))
            test.bindings['K'] = 'TOGGLEQUESTLOG'
            ns.BeginBagBinding()
            local dialog = DraxtilitiesBindingCapture
            assert(not dialog.apply:IsEnabled())
            assert(GetBindingAction('ALT-L', true) == '')
            dialog.scripts.OnKeyDown(dialog, 'LSHIFT')
            assert(not dialog.pendingKey)
            dialog.scripts.OnKeyDown(dialog, 'K')
            assert(ns.db.bagLockKey == 'ALT-L' and dialog.pendingKey == 'K')
            assert(dialog.hint.text:find('TOGGLEQUESTLOG', 1, true))
            dialog.apply.scripts.OnClick()
            assert(ns.db.bagLockKey == 'K' and not dialog:IsShown() and not dialog.keyboard)
            ns.BeginBagBinding()
            dialog.scripts.OnKeyDown(dialog, 'M')
            dialog.scripts.OnKeyDown(dialog, 'ESCAPE')
            assert(ns.db.bagLockKey == 'K' and not dialog:IsShown())
            ns.BeginBagBinding()
            dialog.scripts.OnKeyDown(dialog, 'L')
            test.combat = true
            test.event('PLAYER_REGEN_DISABLED')
            assert(not dialog:IsShown() and not dialog.pendingKey and not dialog.keyboard)
            test.combat = false
            test.event('PLAYER_REGEN_ENABLED')
            assert(GetBindingAction('K', true):find('DraxtilitiesLockBinding', 1, true))
            assert(ns.db.bagLockKey == 'K')
            ns.BeginBagBinding()
            assert(ns.SetEnabled('bags', false))
            assert(not dialog:IsShown() and GetBindingAction('K', true) == 'TOGGLEQUESTLOG')
        """)

    def test_items_only_lists_saved_locks_with_search_and_unlock(self):
        self.load("Options.lua")
        self.run_lua("""
            ns.RegisterOptions()
            test.put(0, 1, 'Item-A', 100).link = '[Runed sword]'
            test.put(0, 2, 'Item-B', 100).link = '[Unprotected sword]'
            ns.db.locks['Item-A'] = { id = 100, link = '[Runed sword]', owner = 'Test-Realm' }
            ns.db.locks['Item-Away'] = { id = 300, link = '[Old shield]', owner = 'Alt-Realm' }
            test.buildPage('Items')
            local rows = test.itemRows()
            assert(#rows == 2 and #test.controls == 1)
            assert(rows[1].name.text == '[Old shield]' and rows[2].name.text == '[Runed sword]')
            assert(not test.findControl('Show') and not test.findControl('Sort by'))
            test.typeSearch('  aLt-Realm  ')
            test.buildPage('Items')
            rows = test.itemRows()
            assert(#rows == 1 and rows[1].entry.guid == 'Item-Away')
            assert(rows[1].detail.text:find('Not in your bags', 1, true))
            assert(rows[1].action:IsEnabled() and next(ns.active) == nil)
            rows[1].action.scripts.OnClick()
            assert(not ns.db.locks['Item-Away'] and ns.db.locks['Item-A'])
            test.buildPage('Items')
            assert(#test.itemRows() == 0 and test.hasText('No matching items.'))
            test.typeSearch('100')
            test.buildPage('Items')
            assert(#test.itemRows() == 1)
        """)

    def test_item_tooltip_rechecks_location_and_falls_back_to_saved_item(self):
        self.load("Options.lua")
        self.run_lua("""
            ns.RegisterOptions()
            test.put(0, 1, 'Item-A')
            ns.db.locks['Item-A'] = { id = 100, link = '[Original copy]' }
            test.buildPage('Items')
            local row = test.itemRows()[1]
            GameTooltip:Hide()
            if row.scripts.OnEnter then row.scripts.OnEnter(row) end
            assert(not GameTooltip:IsShown(), 'hovering the row showed the item tooltip')
            row.iconTarget.scripts.OnEnter(row.iconTarget)
            assert(test.tooltip.bag == 0 and test.tooltip.slot == 1)
            assert(GameTooltip.owner == row.iconTarget and GameTooltip.anchor == 'ANCHOR_CURSOR')
            test.put(0, 1, 'Item-B', 200)
            row.iconTarget.scripts.OnEnter(row.iconTarget)
            assert(test.tooltip.link == '[Original copy]' and not test.tooltip.bag)
            row.iconTarget.scripts.OnLeave(row.iconTarget)
            assert(not GameTooltip:IsShown())
            row.action.scripts.OnClick()
            assert(not ns.db.locks['Item-A'] and test.items['0:1'].guid == 'Item-B')
            ns.db.locks['Missing-link'] = { id = 300 }
            test.buildPage('Items')
            row = test.itemRows()[1]
            row.iconTarget.scripts.OnEnter(row.iconTarget)
            assert(test.tooltip.id == 300)
            row:Hide()
            assert(not GameTooltip:IsShown(), 'hiding the row left its icon tooltip visible')
        """)

    def test_locked_item_pagination_preserves_copies_and_reuses_rows(self):
        self.load("Options.lua")
        self.run_lua("""
            ns.RegisterOptions()
            for index = 1, 16 do
                ns.db.locks[string.format('Item-%02d', index)] = { id = 100, link = '[Same item]' }
            end
            test.buildPage('Items')
            local rows = test.itemRows()
            assert(#rows == 12 and rows[1].entry.guid == 'Item-01' and rows[12].entry.guid == 'Item-12')
            local frames = #test.frames
            test.findControl('Next').onClick()
            test.buildPage('Items')
            rows = test.itemRows()
            assert(#rows == 4 and rows[1].entry.guid == 'Item-13' and rows[4].entry.guid == 'Item-16')
            assert(#test.frames == frames, 'list rebuilt frames instead of reusing its rows')
            test.typeSearch('Item-01')
            test.buildPage('Items')
            rows = test.itemRows()
            assert(#rows == 1 and rows[1].entry.guid == 'Item-01' and not test.findControl('Next'))
            test.buildPage('Settings')
            assert(#test.itemRows() == 0, 'item rows stayed visible on Settings')
        """)

    def test_options_prebuild_does_not_scan_inventory_or_create_item_rows(self):
        self.load("Options.lua")
        self.run_lua("""
            ns.RegisterOptions()
            ns.Inventory = function() error('inventory read during prebuild') end
            test.buildPage('Items', true)
            assert(test.findControl('Search locked items') and #test.itemRows() == 0)
            assert(not DraxtilitiesBindingCapture and next(test.overrides) == nil)
            test.buildPage('Settings', true)
            assert(test.findControl('Enable Item Protection') and test.findControl('Lock or unlock bag items'))
            assert(not DraxtilitiesBindingCapture and next(test.overrides) == nil)
        """)

    def test_inventory_refresh_waits_until_search_editing_finishes(self):
        self.load("Modules/Bags.lua")
        self.load("Options.lua")
        self.run_lua("""
            ns.RegisterOptions()
            assert(ns.SetEnabled('bags', true))
            EllesmereUI.IsShown = function() return true end
            EllesmereUI.GetPluginModuleKey = function() return 'Protection' end
            EllesmereUI.GetActiveModule = function() return 'Protection' end
            local refreshed = 0
            EllesmereUI.RefreshPage = function() refreshed = refreshed + 1 end
            test.buildPage('Items')
            test.searchBox():SetFocus()
            test.event('BAG_UPDATE_DELAYED')
            assert(refreshed == 0 and ns.optionsDirty)
            test.searchBox():ClearFocus()
            assert(refreshed == 1 and not ns.optionsDirty)
            test.event('BAG_UPDATE_DELAYED')
            assert(refreshed == 2)
        """)

    def test_one_skin_registration_covers_lazily_created_frames(self):
        self.load("Modules/Bags.lua")
        self.load("Options.lua")
        self.run_lua("""
            test.event('ADDON_LOADED', 'Draxtilities')
            assert(test.skinRegistrations == 1)
            local shells = 0
            test.skinCallback({ Shell = function() shells = shells + 1 end,
                Button = function() end, Font = function() end })
            assert(ns.SetEnabled('bags', true))
            ns.BeginBagBinding()
            ns.CancelBagBinding()
            ns.ToggleBagSelection()
            assert(shells == 2 and test.skinRegistrations == 1)
        """)

    def test_live_search_preserves_focus_and_cursor_across_new_eui_wrappers(self):
        self.load("Options.lua")
        self.run_lua("""
            ns.RegisterOptions()
            ns.db.locks['Sword'] = { id = 100, link = '[Sword]' }
            ns.db.locks['Shield'] = { id = 200, link = '[Shield]' }
            test.buildPage('Items')
            local box = test.searchBox()
            local frames, refreshed = #test.frames, 0
            EllesmereUI.IsShown = function() return true end
            EllesmereUI.GetPluginModuleKey = function() return 'Protection' end
            EllesmereUI.GetActiveModule = function() return 'Protection' end
            EllesmereUI.RefreshPage = function()
                refreshed = refreshed + 1
                test.pageParent:Hide()
                box:Hide()
                test.pageParent = CreateFrame('Frame')
                test.buildPage('Items')
            end
            test.typeSearch('S')
            assert(#test.itemRows() == 2 and refreshed == 1)
            test.typeSearch('Sw')
            assert(#test.itemRows() == 1 and test.itemRows()[1].entry.guid == 'Sword')
            test.typeSearch('Swo')
            assert(refreshed == 3 and test.searchBox() == box and box:HasFocus() and box:GetCursorPosition() == 3)
            test.typeSearch('Sw')
            assert(refreshed == 4 and box:GetCursorPosition() == 2)
            test.typeSearch('Sword', 2)
            assert(refreshed == 5 and box:HasFocus() and box:GetCursorPosition() == 2)
            test.typeSearch('')
            assert(#test.itemRows() == 2 and refreshed == 6 and test.searchBox() == box)
            assert(#test.frames == frames + 6, 'our search field or list rows were recreated on each keystroke')
            box:SetText('programmatic update')
            assert(refreshed == 6, 'programmatic text changes triggered recursive refreshes')
        """)

    def test_search_typing_appends_after_refresh_instead_of_replacing_selection(self):
        self.load("Options.lua")
        self.run_lua("""
            ns.RegisterOptions()
            ns.db.locks['Sword'] = { id = 100, link = '[Sword]' }
            ns.db.locks['Shield'] = { id = 200, link = '[Shield]' }
            test.buildPage('Items')
            local box = test.searchBox()
            EllesmereUI.IsShown = function() return true end
            EllesmereUI.GetPluginModuleKey = function() return 'Protection' end
            EllesmereUI.GetActiveModule = function() return 'Protection' end
            EllesmereUI.RefreshPage = function()
                test.pageParent:Hide()
                box:Hide()
                test.pageParent = CreateFrame('Frame')
                test.buildPage('Items')
            end
            box:SetFocus()
            test.insertSearch('S')
            test.insertSearch('w')
            test.insertSearch('o')
            assert(box:GetText() == 'Swo', 'the next character replaced the text selected by the refresh')
            assert(#test.itemRows() == 1 and test.itemRows()[1].entry.guid == 'Sword')
            assert(box.selectionStart == box.selectionEnd and box:GetCursorPosition() == 3)
            box:SetCursorPosition(1)
            test.insertSearch('h')
            assert(box:GetText() == 'Shwo' and box:GetCursorPosition() == 2)
            box:HighlightText() -- deliberate Select All must still replace the query
            test.insertSearch('Shield')
            assert(box:GetText() == 'Shield' and test.itemRows()[1].entry.guid == 'Shield')
            assert(box.selectionStart == box.selectionEnd)
        """)

    def test_bag_footer_button_follows_parent_visibility_and_module_lifecycle(self):
        self.load("Modules/Bags.lua")
        self.run_lua("""
            local oldPosition = { point = 'TOP', relativePoint = 'TOP', x = 12, y = -90 }
            ns.db.bagButtonPosition = oldPosition
            assert(ns.SetEnabled('bags', true))
            local bags = ns.active.bags
            local button = bags.launcher
            assert(button and button:GetParent() == EUI_MainBagFrame and not button:IsVisible())
            assert(not button.scripts.OnDragStart and not button.scripts.OnDragStop)
            assert(not EUI_MainBagFrame.scripts.OnShow and not EUI_MainBagFrame.scripts.OnHide)
            EUI_MainBagFrame:Show()
            button.scripts.OnUpdate(button, 0.3)
            assert(button:IsVisible() and button.fits and button.mouseEnabled, 'empty bags have no usable footer button')
            local point, relative, relativePoint, x, y = button:GetPoint()
            assert(point == 'BOTTOMLEFT' and relative == EUI_MainBagFrame and relativePoint == 'BOTTOMLEFT')
            assert(x >= 6 and y == 4)
            button.scripts.OnClick(button, 'LeftButton')
            assert(bags.mode and button.selection:IsShown())
            button.scripts.OnClick(button, 'LeftButton')
            assert(not bags.mode and not button.selection:IsShown())
            local opened
            EllesmereUI.OpenPlugin = function(_, _, page) opened = page end
            button.scripts.OnClick(button, 'RightButton')
            assert(opened == 'Items' and not bags.mode)
            button.scripts.OnClick(button, 'LeftButton')
            EUI_MainBagFrame:Hide()
            button.scripts.OnHide() -- native child OnHide when its parent closes
            assert(not button:IsVisible() and not bags.mode)
            EUI_MainBagFrame:Show()
            button.scripts.OnUpdate(button, 0.3)
            assert(button:IsVisible() and button.fits and not bags.mode)
            test.combat = true
            test.event('PLAYER_REGEN_DISABLED')
            assert(not button:IsVisible())
            button.scripts.OnClick(button, 'LeftButton')
            assert(not bags.mode)
            test.combat = false
            test.event('PLAYER_REGEN_ENABLED')
            assert(button:IsVisible() and not bags.mode)
            assert(ns.SetEnabled('bags', false))
            assert(not button:IsVisible())
            assert(ns.db.bagButtonPosition == oldPosition, 'legacy saved data was removed or overwritten')
        """)

    def test_footer_button_avoids_money_currencies_and_reserved_resize_corner(self):
        self.load("Modules/Bags.lua")
        self.run_lua("""
            EUI_MainBagFrame:Show()
            local currency = CreateFrame('Frame', nil, test.bagFooter)
            currency.rect = { 110, 107, 350, 17 }
            local upperRow = CreateFrame('Frame', nil, test.bagFooter)
            upperRow.rect = { 100, 135, 600, 20 }
            local outside = CreateFrame('Frame', nil, test.bagFooter)
            outside.rect = { 800, 104, 20, 20 }
            assert(ns.SetEnabled('bags', true))
            local button = ns.active.bags.launcher
            local _, _, _, offset = button:GetPoint()
            assert(button.fits and offset >= 364 and offset + 22 <= 446)
            assert(offset + 22 <= 600 - 44)
            assert(EUI_BagMoneyFrame.rect[1] == 550 and currency.rect[3] == 350)
            assert(next(EUI_BagMoneyFrame.scripts) == nil and next(test.bagFooter.scripts) == nil)
            currency.rect = { 100, 104, 600, 22 }
            button.scripts.OnUpdate(button, 0.3)
            assert(not button.fits and button.alpha == 0 and not button.mouseEnabled)
            button.scripts.OnClick(button, 'LeftButton')
            assert(not ns.active.bags.mode, 'the invisible button still accepted clicks')
            currency:Hide()
            button.scripts.OnUpdate(button, 0.3)
            assert(button.fits and button.alpha == 1 and button.mouseEnabled)
            local pendingLayout = CreateFrame('Frame', nil, test.bagFooter)
            button.scripts.OnUpdate(button, 0.3)
            assert(not button.fits and not button.mouseEnabled, 'button overlapped a footer control with pending geometry')
            pendingLayout.rect = { 100, 135, 600, 20 }
            button.scripts.OnUpdate(button, 0.3)
            assert(button.fits and button.mouseEnabled)
        """)

    def test_footer_button_waits_for_named_frames_without_disabling_bag_safeguards(self):
        self.load("Modules/Bags.lua")
        self.run_lua("""
            local root, money = EUI_MainBagFrame, EUI_BagMoneyFrame
            EUI_MainBagFrame = nil
            assert(ns.SetEnabled('bags', true))
            local bags = ns.active.bags
            assert(not bags.launcher and test.paint)
            EUI_MainBagFrame, EUI_BagMoneyFrame = root, nil
            root:Show()
            bags.Refresh()
            assert(bags.launcher and not bags.launcher.fits)
            EUI_BagMoneyFrame = money
            bags.launcher.scripts.OnUpdate(bags.launcher, 0.3)
            assert(bags.launcher.fits and bags.launcher:GetParent() == root)
        """)

    def test_locked_bag_item_blocks_spell_clicks_without_protected_cancellation(self):
        self.load("Modules/Bags.lua")
        self.run_lua("""
            test.put(0, 1, 'Item-A')
            ns.db.locks['Item-A'] = { id = 100 }
            assert(ns.SetEnabled('bags', true))
            local parent = CreateFrame('Frame')
            parent:SetID(0)
            local target = CreateFrame('Button', nil, parent)
            target:SetID(1)
            test.paint(target, { bag = 0, slot = 1, info = { itemID = 100 } })
            local layer = ns.active.bags.layers[target]
            test.spellTarget = true
            layer.scripts.OnClick(layer, 'LeftButton')
            assert(test.spellTarget, 'the addon tried to cancel targeting instead of consuming the click')
            assert(test.items['0:1'].guid == 'Item-A' and ns.db.locks['Item-A'] and not test.cursor)
            assert(test.messages[#test.messages]:find('This item is locked', 1, true))
            layer.scripts.OnClick(layer, 'LeftButton')
            assert(test.spellTarget and test.items['0:1'].guid == 'Item-A' and ns.db.locks['Item-A'])
            test.spellTarget = false
            test.spellTargetID = true
            layer.scripts.OnClick(layer, 'LeftButton')
            assert(test.spellTargetID and test.items['0:1'].guid == 'Item-A' and not test.cursor)
            assert(ns.db.locks['Item-A'] and not test.confirm and not ns.pending)
            test.put(0, 1, 'Item-B', 200)
            test.spellTarget = true
            layer.scripts.OnClick(layer, 'LeftButton')
            assert(test.spellTarget and test.items['0:1'].guid == 'Item-B')
            assert(ns.db.locks['Item-A'] and not ns.db.locks['Item-B'])
        """)


if __name__ == "__main__":
    unittest.main()
