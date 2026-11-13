local function equal(actual, expected, label)
    if actual ~= expected then
        error(("%s: expected %s, got %s"):format(label, tostring(expected), tostring(actual)))
    end
end

local ns = {
    db = { bindings = {}, escapes = {} },
    spellID = 4987,
    spellName = "Cleanse",
    knownDispels = { { id = 4987, name = "Cleanse" } },
    knownEscapes = { { id = 1044, name = "Blessing of Freedom" } },
}

C_Spell = { GetSpellTexture = function(id) return id end }

assert(loadfile("Features/Bindings.lua"))("Salve", ns)

local defaults = ns.Bindings:List()
equal(#defaults, 1, "one detected dispel gets one default binding")
equal(defaults[1].key, "BUTTON1", "primary dispel defaults to left click")

ns.db.escapes[1044] = true
defaults = ns.Bindings:List()
equal(#defaults, 2, "enabled escape adds a second automatic binding")
equal(defaults[2].key, "BUTTON2", "enabled escape defaults to right click")
equal(ns.Bindings:SpellID(defaults[2]), 1044,
    "right-click default uses the enabled movement removal")
ns.db.escapes[1044] = nil

ns.secondaryName = "Cauterizing Flame"
ns.secondaryID = 374251
defaults = ns.Bindings:List()
equal(#defaults, 2, "distinct secondary dispel gets a second binding")
equal(defaults[2].key, "BUTTON2", "secondary dispel defaults to right click")

ns.secondaryName = "Cleanse"
ns.secondaryID = 4987
equal(#ns.Bindings:List(), 1, "duplicate secondary spell is not exposed")

ns.secondaryName, ns.secondaryID = nil, nil
equal(ns.Bindings:ClearSpellBinding(1044), false,
    "clearing an unbound escape reports no change")
equal(ns.db.bindingsCustom, nil,
    "clearing an unbound escape preserves automatic bindings")
ns.secondaryName = "Cauterizing Flame"
ns.secondaryID = 374251
equal(#ns.Bindings:List(), 2,
    "automatic defaults still follow later spell changes")
ns.secondaryName, ns.secondaryID = nil, nil

local ok = ns.Bindings:SetSpellBinding(1044, "BUTTON2")
equal(ok, true, "escape spell accepts a mouse binding")
equal(ns.Bindings:KeysForSpell(1044)[1], "BUTTON2",
    "escape binding is exposed on its spell row")
equal(ns.Bindings:Describe(ns.db.bindings[2]), "no dispel known",
    "disabled escape binding is not armed")

ns.db.escapes[1044] = true
equal(ns.Bindings:Describe(ns.db.bindings[2]), "Blessing of Freedom",
    "enabled escape binding resolves its spell")
local attrs = {}
local box = {
    SetAttribute = function(_, key, value) attrs[key] = value end,
}
ns.Bindings:Apply(box)
equal(attrs.type2, "spell", "escape binding installs a secure spell action")
equal(attrs.spell2, "Blessing of Freedom",
    "escape binding casts the selected removal spell")

local conflict, message = ns.Bindings:SetSpellBinding(1044, "BUTTON1")
equal(conflict, false, "a mouse chord cannot replace another spell implicitly")
equal(message, "Left click is already assigned to Cleanse (automatic)",
    "binding conflict identifies the existing action")

local _, _, why = ns.Bindings:SetSpellBinding(1044, "BUTTON1")
equal(why, "conflict", "a taken chord is reported as a conflict, so settings can offer Replace")
equal(ns.Bindings:SetSpellBinding(1044, "BUTTON1", true), true, "Replace takes the chord")
equal(ns.Bindings:KeysForSpell(1044)[1], "BUTTON1", "the new spell owns it")
equal(#ns.Bindings:KeysForSpell(ns.spellID), 0, "and the old one is left unbound")
ns.Bindings:SetSpellBinding(ns.spellID, "BUTTON1", true)

ns.Bindings:ClearSpellBinding(1044)
equal(#ns.Bindings:KeysForSpell(1044), 0, "escape binding can be cleared")

ns.knownEscapes = {
    { id = 1044, name = "Blessing of Freedom" },
    { id = 1022, name = "Blessing of Protection" },
}
ns.db.escapes[1044] = nil
equal(ns.Bindings:SetSpellBinding(1044, "BUTTON2"), true, "disabled escape can retain a saved chord")
equal(ns.Bindings:Describe(ns.db.bindings[#ns.db.bindings]), "no dispel known", "disabled escape reports as unarmed")
equal(ns.Bindings:SetSpellBinding(1022, "BUTTON2"), true, "unarmed escape does not reserve a mouse chord")
equal(#ns.Bindings:KeysForSpell(1044), 0, "replacement removes the stale unarmed chord")
equal(ns.Bindings:KeysForSpell(1022)[1], "BUTTON2", "replacement owns the requested chord")

ns.Bindings:ClearSpellBinding(4987)
ns.Bindings:ClearSpellBinding(1022)
equal(#ns.Bindings:List(), 0,
    "clearing the final action does not silently restore defaults")

-- A saved custom binding to an earlier legacy rank follows the same spell
-- family after the character trains the higher rank.
ns.knownDispels = { { id = 988, name = "Dispel Magic", aliases = { 527, 988 } } }
ns.db.bindings = { { key = "BUTTON1", spell = 527 } }
ns.db.bindingsCustom = true
equal(ns.Bindings:SpellID(ns.db.bindings[1]), 988,
    "legacy-rank binding resolves to the current learned rank")
equal(ns.Bindings:Describe(ns.db.bindings[1]), "Dispel Magic",
    "legacy-rank binding retains its action after a trainer upgrade")
equal(ns.Bindings:IsDispelSpell(988), true,
    "current learned rank drives cooldown matching")

print("binding tests passed")

-- Retirement preserves every individual action and clears only the old command.
for _, forever in ipairs({ false, true }) do
    ns.isCamelot = forever
    ns.spellName, ns.spellID = "Cure Poison", 8946
    ns.secondaryName, ns.secondaryID = "Remove Curse", 2782
    ns.knownDispels = { { id = 8946, name = "Cure Poison" }, { id = 2782, name = "Remove Curse" } }
    local primary = { key = "SHIFT-BUTTON2", role = "PRIMARY" }
    local secondary = { key = "CTRL-BUTTON4", role = "SECONDARY" }
    local custom = { key = "BUTTON5", action = "TARGET" }
    ns.db.bindings = { { key = "BUTTON1", role = "BOTH" }, primary, secondary, custom, { key = "ALT-BUTTON3", spell = "BOTH" } }
    ns.db.bindingsCustom = true
    local old = "CLICK SalveMouseoverBoth:LeftButton"
    local individual = "CLICK SalveMouseoverPrimary:LeftButton"
    local gameKeys = { F = old, ["SHIFT-BUTTON4"] = old, ["CTRL-MOUSEWHEELUP"] = old, ["ALT-SHIFT-MOUSEWHEELDOWN"] = old,
        G = individual, ["ALT-X"] = "JUMP" }
    local locked, saves, notices, rebuilds = true, 0, 0, 0
    local attributes = { type = "macro", macrotext = "old combined macro" }
    _G.SalveMouseoverBoth = { SetAttribute = function(_, key, value)
        assert(not locked, "no secure attributes written in combat")
        attributes[key] = value
    end }
    InCombatLockdown = function() return locked end
    GetBindingKey = function(command)
        local keys = {}
        for key, action in pairs(gameKeys) do if action == command then keys[#keys + 1] = key end end
        table.sort(keys)
        return keys[1], keys[2] -- model the client returning only two at once
    end
    GetBindingAction = function(key) return gameKeys[key] end
    SetBinding = function(key, action)
        assert(not locked, "no binding writes in combat")
        assert(action == nil and gameKeys[key] == old, "only retired command keys removed")
        gameKeys[key] = nil
        ns.Bindings:RetireCombined() -- model UPDATE_BINDINGS re-entry
        return true
    end
    GetCurrentBindingSet = function() return 2 end
    SaveBindings = function(set)
        assert(not locked and set == 2, "save only the active binding set out of combat")
        saves = saves + 1
        ns.Bindings:RetireCombined() -- SaveBindings can send the event too
    end
    ns.Print = function(message)
        assert(message:find("Bind each dispel separately", 1, true), "actionable retirement notice")
        notices = notices + 1
    end
    ns.RequestRebuild = function() rebuilds = rebuilds + 1 end
    ns.Bindings.combinedRemovalNotified, ns.Bindings.retiredCombinedChoices = nil, nil
    equal(ns.Bindings:RetireCombined(), false, "retirement defers protected work in combat")
    equal(#ns.db.bindings, 5, "deferred migration does not edit the saved list yet")
    equal(gameKeys.F, old, "keys preserved while locked")
    equal(notices, 0, "no premature notice")
    equal(attributes.macrotext, "old combined macro", "old button untouched in combat")
    -- A pending legacy entry cannot appear as a new action or run through Apply.
    equal(#ns.Bindings:List(), 3, "retired entries hidden even before deferred cleanup")
    local list = ns.db.bindings
    equal(ns.Bindings:SetSpellBinding("BOTH", "BUTTON1", true), false, "new combined grid requests refused")
    equal(ns.db.bindings, list, "refusal keeps all choices")
    locked = false
    equal(ns.Bindings:RetireCombined(), true, "retirement completes after combat")
    equal(#ns.db.bindings, 3, "only retired grid entries removed")
    equal(ns.db.bindings[1], primary, "primary entry preserved")
    equal(ns.db.bindings[2], secondary, "secondary entry preserved")
    equal(ns.db.bindings[3], custom, "custom action preserved")
    equal(gameKeys.F, nil, "keyboard key removed")
    equal(gameKeys["SHIFT-BUTTON4"], nil, "modified mouse key removed")
    equal(gameKeys["CTRL-MOUSEWHEELUP"], nil, "wheel key removed")
    equal(gameKeys["ALT-SHIFT-MOUSEWHEELDOWN"], nil, "multiple modifiers removed")
    equal(gameKeys.G, individual, "individual mouseover command preserved")
    equal(gameKeys["ALT-X"], "JUMP", "unrelated game action preserved")
    equal(saves, 1, "all removals persisted with one save")
    equal(notices, 1, "one retirement notice")
    equal(attributes.type, nil, "old secure button inert")
    equal(attributes.macrotext, nil, "old macro removed")
    equal(rebuilds, 1, "grid removal requests one rebuild")
    ns.Bindings:RetireCombined()
    equal(saves, 1, "repeated event does not save again")
    equal(notices, 1, "repeated event does not repeat notice")
    equal(rebuilds, 1, "repeated event does not rebuild again")
    -- Individual spell attributes remain separate, and old combined attrs clear.
    local attrs = { type1 = "macro", macrotext1 = "old combined macro" }
    local box = { unit = "party1", appliedAttrs = { "type1", "macrotext1" },
        SetAttribute = function(_, key, value) assert(not locked); attrs[key] = value end }
    ns.Bindings:Apply(box)
    equal(attrs.type1, nil, "retired chord stays unassigned")
    equal(attrs.macrotext1, nil, "grid drops previous combined macro")
    equal(attrs["shift-spell2"], "Cure Poison", "primary click remains usable")
    equal(attrs["ctrl-spell4"], "Remove Curse", "secondary click remains usable")
    ns.db.bindings = { { key = "BUTTON1", role = "BOTH" } }
    ns.db.bindingsCustom = false
    ns.Bindings:RetireCombined()
    equal(#ns.Bindings:List(), 0, "removing final combined entry never restores an arbitrary cure")
    equal(ns.db.bindingsCustom, true, "empty custom list remains explicit")
    equal(notices, 1, "further legacy choices do not spam the notice")
    _G.SalveMouseoverBoth = nil
end
-- Engine failures release the guard and retain a save that failed after unbind.
do
    local old = "CLICK SalveMouseoverBoth:LeftButton"
    local keys = { F = old, G = "JUMP" }
    local writes, saves, notices, reports = 0, 0, 0, 0
    local retry = { db = { bindings = {}, bindingsCustom = true }, Print = function() notices = notices + 1 end }
    assert(loadfile("Features/Bindings.lua"))("Salve", retry)
    InCombatLockdown = function() return false end
    GetCurrentBindingSet = function() return 1 end
    GetBindingKey = function(command) if keys.F == command then return "F" end end
    GetBindingAction = function(key) return keys[key] end
    geterrorhandler = function() return function() reports = reports + 1 end end
    SetBinding = function(key)
        writes = writes + 1
        if writes == 1 then error("test unbind failure") end
        keys[key] = nil
        retry.Bindings:RetireCombined()
        return true
    end
    SaveBindings = function()
        saves = saves + 1
        if saves == 1 then error("test save failure") end
        retry.Bindings:RetireCombined()
    end
    local ok, why = retry.Bindings:RetireCombined()
    equal(ok, false, "unbind error reported")
    assert(why:find("test unbind failure", 1, true))
    equal(retry.Bindings.retiringCombined, false, "error releases reentrancy guard")
    equal(notices, 0, "failed cleanup has not notified")
    ok, why = retry.Bindings:RetireCombined()
    equal(ok, false, "save error reported")
    assert(why:find("test save failure", 1, true))
    equal(keys.F, nil, "key was removed before the failed save")
    equal(retry.Bindings.retirementPendingSaves[1], true, "failed save remains pending")
    equal(retry.Bindings.retiringCombined, false, "save error also releases guard")
    equal(retry.Bindings:RetireCombined(), true, "later safe event completes pending save")
    equal(saves, 2, "save retried after keys already removed")
    equal(keys.G, "JUMP", "unrelated key preserved through retries")
    equal(notices, 1, "one notice after successful retry")
    equal(retry.db.combinedDispelNoticePending, nil, "delivered notice metadata cleared")
    equal(reports, 2, "engine errors surfaced once per distinct error")
    retry.Bindings:RetireCombined()
    equal(saves, 2, "no-op does not save again")
    equal(notices, 1, "no-op does not notify again")
    geterrorhandler = nil
end

-- An explicit refusal cannot save unrelated changes; an actual clear still saves.
do
    local old = "CLICK SalveMouseoverBoth:LeftButton"
    local keys, saves, notices, clear = { F = old, G = "JUMP" }, 0, 0, false
    local retry = { db = { bindings = {}, bindingsCustom = true }, Print = function() notices = notices + 1 end }
    assert(loadfile("Features/Bindings.lua"))("Salve", retry)
    GetCurrentBindingSet = function() return 1 end
    GetBindingKey = function(command) if keys.F == command then return "F" end end
    GetBindingAction = function(key) return keys[key] end
    SetBinding = function(key) if clear then keys[key] = nil end; return false end
    SaveBindings = function() saves = saves + 1 end
    equal(retry.Bindings:RetireCombined(), false, "explicit refusal remains pending")
    equal(saves, 0, "refusal does not save unrelated changes")
    equal(notices, 0, "refusal does not claim completed cleanup")
    clear = true
    equal(retry.Bindings:RetireCombined(), true, "actual key clear recognized despite false result")
    equal(saves, 1, "an actual clear is persisted")
    equal(keys.G, "JUMP", "unrelated binding preserved")
    equal(notices, 1, "successful cleanup notifies once")
end

-- Never commit Blizzard's pending edits. Retry after Cancel restores the final set.
for _, editorName in ipairs({ "KeyBindingFrame", "SettingsPanel" }) do
    local old = "CLICK SalveMouseoverBoth:LeftButton"
    local persisted = { [1] = { F = old, J = "JUMP" }, [2] = { W = old, T = "TOGGLEMAP" } }
    local function copy(source) local out = {}; for key, value in pairs(source) do out[key] = value end; return out end
    local active, keys, saves, notices, hooks = 1, copy(persisted[1]), 0, 0, 0
    local timers = {}
    local retry = { db = { bindings = {}, bindingsCustom = true }, Print = function() notices = notices + 1 end }
    assert(loadfile("Features/Bindings.lua"))("Salve", retry)
    local panel = { shown = true }
    function panel:IsShown() return self.shown end
    function panel:HookScript(script, callback) equal(script, "OnHide", "only close is hooked"); self.hide = callback; hooks = hooks + 1 end
    C_Timer = { After = function(delay, callback) equal(delay, 0, "retry waits for transaction close"); timers[#timers + 1] = callback end }
    _G[editorName] = panel -- lazily created Blizzard UI
    GetCurrentBindingSet = function() return active end
    GetBindingKey = function(command)
        for key, action in pairs(keys) do if action == command then return key end end
    end
    GetBindingAction = function(key) return keys[key] end
    SetBinding = function(key)
        assert(not panel.shown, "no key writes during pending edits")
        equal(keys[key], old, "only retired command removed")
        keys[key] = nil; retry.Bindings:RetireCombined(); return true
    end
    SaveBindings = function(set)
        assert(not panel.shown, "no save during pending edits")
        equal(set, active, "save applies to final active binding set")
        persisted[set] = copy(keys); saves = saves + 1
        retry.Bindings:RetireCombined()
    end
    keys.J = "UNSAVED_EDIT"
    equal(retry.Bindings:RetireCombined(), false, "editing defers migration")
    retry.Bindings:RetireCombined()
    equal(hooks, 1, "one hide hook per detected editor")
    equal(keys.F, old, "old command untouched during editing")
    equal(saves, 0, "unsaved edits not committed")
    -- Switch binding sets while editing, then Cancel/Discard after Hide.
    active, keys = 2, copy(persisted[2]); keys.T = "UNSAVED_EDIT"
    panel.shown = false; panel.hide()
    equal(#timers, 1, "closing queues one retry")
    retry.Bindings:RetireCombined() -- UPDATE_BINDINGS inside the closing transaction
    equal(saves, 0, "close-time event cannot race Discard")
    keys = copy(persisted[2]) -- Blizzard completes Discard before the next frame
    timers[1]()
    equal(saves, 1, "cleanup saved only after transaction settled")
    equal(keys.W, nil, "retired key removed from final active set")
    equal(persisted[2].T, "TOGGLEMAP", "discarded user edit stays discarded")
    equal(persisted[1].F, old, "inactive set never forced or overwritten")
    equal(notices, 1, "one cleanup notice")
    active, keys = 1, copy(persisted[1])
    retry.Bindings:RetireCombined()
    equal(persisted[1].F, nil, "other set cleaned when later activated")
    equal(persisted[1].J, "JUMP", "earlier unsaved edit never committed")
    equal(notices, 1, "binding-set activation does not repeat notice")
    equal(hooks, 1, "hide hook does not accumulate")
    -- Optional timer absence must not wedge every future safe event.
    C_Timer = nil; keys.F = old; panel.shown = true
    equal(retry.Bindings:RetireCombined(), false, "timer-less editing still defers")
    panel.shown = false; panel.hide()
    equal(retry.Bindings.retirementCloseQueued, nil, "no unavailable timer leaves a permanent queue latch")
    equal(retry.Bindings:RetireCombined(), true, "later safe event retries without a timer")
    equal(keys.F, nil, "later safe event clears retired key")
    _G[editorName], C_Timer = nil, nil
end
print("test_bindings ok")
