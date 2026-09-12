local function equal(actual, expected, label)
    if actual ~= expected then
        error(("%s: expected %s, got %s"):format(label, tostring(expected), tostring(actual)))
    end
end

local class = "PRIEST"
local knownSpells = { [527] = true }

UnitClass = function() return class, class end
IsPlayerSpell = function(spellID) return knownSpells[spellID] or false end
IsSpellKnown = function() return false end
C_Spell = {
    GetSpellInfo = function(spellID)
        return { name = "Spell " .. spellID }
    end,
}

local ns = { DISPEL_TYPES = { "Magic", "Curse", "Disease", "Poison" } }
assert(loadfile("Features/Dispel.lua"))("Salve", ns)

-- Older-client fallback: an untalented Priest must not advertise Disease.
equal(ns.UpdateDispelSpell(), true, "initial Priest dispel selection changes")
equal(#ns.knownDispels, 1, "untalented Priest has one dispel")
equal(ns.primaryCures.Magic, true, "Purify covers Magic")
equal(ns.primaryCures.Disease, nil, "Purify does not claim untalented Disease removal")

-- Improved Purify modifies Purify itself, rather than adding a separate cast.
knownSpells[390632] = true
equal(ns.UpdateDispelSpell(), false, "talent upgrade leaves the selected spell unchanged")
equal(ns.primaryCures.Disease, true, "Improved Purify adds Disease coverage")

-- Shadow's separate Purify Disease remains available as a secondary answer.
knownSpells[213634] = true
knownSpells[390632] = nil
equal(ns.UpdateDispelSpell(), true, "learning Purify Disease changes selection")
equal(ns.secondaryID, 213634, "Purify Disease is the Disease secondary")

-- When Retail's spellbook API is present, off-spec entries are never made
-- clickable even if the broad known-spell API reports them.
local spellbookItems = {
    { spellID = 527, isOffSpec = false },
    { spellID = 213634, isOffSpec = true },
}
Enum = {
    SpellBookSpellBank = { Player = 1 },
    SpellBookItemType = { Spell = 1 },
}
for _, item in ipairs(spellbookItems) do item.itemType = Enum.SpellBookItemType.Spell end
C_SpellBook = {
    GetNumSpellBookSkillLines = function() return 1 end,
    GetSpellBookSkillLineInfo = function() return { itemIndexOffset = 0, numSpellBookItems = #spellbookItems } end,
    GetSpellBookItemInfo = function(index) return spellbookItems[index] end,
}
equal(ns.UpdateDispelSpell(), true, "active spellbook changes the available set")
equal(#ns.knownDispels, 1, "off-spec Purify Disease is excluded")
equal(ns.secondaryID, nil, "off-spec spells cannot become a secondary cast")

-- Passive upgrades apply only to a castable active spell and cover the other
-- talent-expanded dispels Salve supports.
C_SpellBook, Enum = nil, nil
class, knownSpells = "DRUID", { [88423] = true, [392378] = true }
ns.UpdateDispelSpell()
equal(ns.primaryCures.Magic, true, "Nature's Cure covers Magic")
equal(ns.primaryCures.Curse, true, "Improved Nature's Cure adds Curse")
equal(ns.primaryCures.Poison, true, "Improved Nature's Cure adds Poison")

class, knownSpells = "SHAMAN", { [77130] = true }
ns.UpdateDispelSpell()
equal(ns.primaryCures.Magic, true, "Purify Spirit covers Magic")
equal(ns.primaryCures.Curse, nil, "Purify Spirit does not claim Curse without its talent")
knownSpells[383016] = true
ns.UpdateDispelSpell()
equal(ns.primaryCures.Curse, true, "Improved Purify Spirit adds Curse")

class, knownSpells = "MONK", { [115450] = true }
ns.UpdateDispelSpell()
equal(ns.primaryCures.Magic, true, "Mistweaver Detox covers Magic")
equal(ns.primaryCures.Poison, nil, "Detox requires its improvement for Poison")
knownSpells[388874] = true
ns.UpdateDispelSpell()
equal(ns.primaryCures.Poison, true, "Improved Detox adds Poison")
equal(ns.primaryCures.Disease, true, "Improved Detox adds Disease")

class, knownSpells = "MONK", { [218164] = true }
ns.UpdateDispelSpell()
equal(ns.primaryCures.Magic, nil, "non-Mistweaver Detox does not claim Magic")
equal(ns.primaryCures.Poison, true, "non-Mistweaver Detox covers Poison")
equal(ns.primaryCures.Disease, true, "non-Mistweaver Detox covers Disease")

-- Singe Magic is an Imp-only Command Demon override, not a permanent Warlock
-- spellbook entry. The panel must remain absent with another demon active.
local commandDemonOverride = 119898
C_Spell.GetOverrideSpell = function() return commandDemonOverride end
class, knownSpells = "WARLOCK", {}
equal(ns.UpdateDispelSpell(), true, "changing from Monk clears an unavailable Warlock dispel")
equal(#ns.knownDispels, 0, "Warlock without an Imp has no friendly dispel armed")
equal(ns.CanDispel(), false, "Warlock without an Imp cannot promise a dispel")

commandDemonOverride = 212623
equal(ns.UpdateDispelSpell(), true, "Imp override arms Singe Magic")
equal(#ns.knownDispels, 1, "Imp exposes one friendly dispel")
equal(ns.spellID, 212623, "Singe Magic is the secure spell")
equal(ns.primaryCures.Magic, true, "Singe Magic covers Magic")

commandDemonOverride = 119898
equal(ns.UpdateDispelSpell(), true, "losing the Imp removes Singe Magic")
equal(#ns.knownDispels, 0, "former Imp dispel is no longer exposed")

print("dispel tests passed")
