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

-- Both dispels on one click: a two-line macro aimed at the cell's slot.
do
    ns.db.bindings, ns.db.bindingsCustom = {}, nil
    ns.spellName, ns.spellID = "Cure Poison", 8946
    ns.secondaryName, ns.secondaryID = nil, nil
    equal(ns.Bindings:BothSpells(), nil, "no Both without a second dispel")
    equal(ns.Bindings:SetSpellBinding("BOTH", "BUTTON1", true), true, "unarmed Both still saves")
    ns.Bindings:ClearSpellBinding("BOTH")

    ns.secondaryName, ns.secondaryID = "Remove Curse", 2782
    equal(ns.Bindings:BothSpells(), nil, "no Both on Retail")
    ns.isCamelot = true
    ns.db.bindings, ns.db.bindingsCustom = {}, nil
    equal(ns.Bindings:SetSpellBinding("BOTH", "BUTTON1"), false, "Both asks before taking the dispel's click")
    equal(ns.Bindings:SetSpellBinding("BOTH", "BUTTON1", true), true, "Replace binds Both")
    local entry
    for _, e in ipairs(ns.Bindings:List()) do if e.role == ns.ROLE_BOTH then entry = e end end
    equal(entry and entry.key, "BUTTON1", "Both saved on left click")
    equal(ns.Bindings:Describe(entry), "Cure Poison or Remove Curse (automatic)", "Both row describes itself")

    local attrs = {}
    local box = { unit = "raid5", SetAttribute = function(_, k, v) attrs[k] = v end }
    ns.Bindings:Apply(box)
    equal(attrs.type1, "macro", "left click runs a macro")
    equal(attrs.macrotext1, "/cast [@raid5] Cure Poison\n/cast [@raid5] Remove Curse",
        "macro aims both lines at the cell's slot")

    ns.db.bothDispelsOrder = "SECONDARY"
    ns.Bindings:Apply(box)
    equal(attrs.macrotext1, "/cast [@raid5] Remove Curse\n/cast [@raid5] Cure Poison",
        "order setting swaps the lines")
    ns.Bindings:SetSpellBinding(8946, "BUTTON2")
    ns.Bindings:Apply(box)
    equal(attrs.type2, "spell", "a plain spell click sits beside Both")
    equal(attrs.macrotext1 ~= nil, true, "Both kept on left click")

    ns.Bindings:ClearSpellBinding("BOTH")
    ns.Bindings:Apply(box)
    equal(attrs.type1, nil, "clearing Both removes the macro click")
    equal(attrs.macrotext1, nil, "and its text")
    ns.db.bothDispelsOrder = nil
    ns.spellName, ns.spellID = "Abolish Poison", 2893
    local first, second = ns.Bindings:BothSpells()
    equal(first[1], "Remove Curse", "Abolish never goes first: it casts with nothing to remove")
    equal(second[1], "Abolish Poison", "Abolish goes last")
    ns.db.bothDispelsOrder = "SECONDARY"
    first = ns.Bindings:BothSpells()
    equal(first[1], "Remove Curse", "the order setting can't put Abolish first")
    ns.db.bothDispelsOrder = nil
    ns.isCamelot = nil
end
print("test_bindings ok")
