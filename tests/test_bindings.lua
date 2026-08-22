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

ns.Bindings:ClearSpellBinding(1044)
equal(#ns.Bindings:KeysForSpell(1044), 0, "escape binding can be cleared")
ns.Bindings:ClearSpellBinding(4987)
equal(#ns.Bindings:List(), 0,
    "clearing the final action does not silently restore defaults")

print("binding tests passed")
