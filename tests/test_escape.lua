local function equal(actual, expected, label)
    if actual ~= expected then
        error(("%s: expected %s, got %s"):format(label, tostring(expected), tostring(actual)))
    end
end

local prints, rebuilds = {}, 0
local record = { locType = "ROOT", spellID = 12345, displayText = "Test Root" }
local knownSpells = { [1953] = true }

UnitClass = function() return "Mage", "MAGE" end
IsPlayerSpell = function(id) return knownSpells[id] or false end
IsSpellKnown = function() return false end
C_Spell = {
    GetSpellInfo = function(id)
        return { name = id == 1953 and "Blink" or "Shimmer" }
    end,
}

C_LossOfControl = {
    GetActiveLossOfControlDataByUnit = function(unit, index)
        equal(unit, "party1", "loss-of-control unit")
        equal(index, 2, "loss-of-control index")
        return record
    end,
}

local ns = {
    db = { learnMode = true },
    learned = { movement = {} },
    Print = function(message) prints[#prints + 1] = message end,
    RequestRebuildSoon = function() rebuilds = rebuilds + 1 end,
}

assert(loadfile("Features/Escape.lua"))("Salve", ns)

equal(ns.Escape:Update(), true, "initial known escape changes the list")
equal(ns.knownEscapes[1].id, 1953, "Blink is initially detected")
knownSpells = { [212653] = true }
equal(ns.Escape:Update(), true,
    "equal-count talent replacement changes the known escape list")
equal(ns.knownEscapes[1].id, 212653, "Shimmer replaces Blink")
equal(ns.Escape:Update(), false, "unchanged escape list is stable")

equal(ns.Escape:RegisterMovement("Salve_Data_Test", { 45678 }), true,
    "curated movement registration succeeds")
local curated = ns.Escape:AllSpellIDs()
equal(#curated, 1, "curated movement ID is active before learning")
equal(curated[1], 45678, "curated movement ID is retained")
rebuilds = 0

equal(ns.Escape:CaptureLossOfControl("party1", 2), true,
    "automatic root capture succeeds")
equal(ns.learned.movement[12345], "Test Root", "automatic root stores spell")
equal(rebuilds, 1, "automatic root requests panel rebuild")
equal(#prints, 1, "automatic root reports capture")
equal(ns.Escape:CaptureLossOfControl("party1", 2), false,
    "automatic root de-duplicates spell")

record = { locType = "STUN", spellID = 23456, displayText = "Test Stun" }
equal(ns.Escape:CaptureLossOfControl("party1", 2), false,
    "non-movement loss of control is ignored")
equal(ns.learned.movement[23456], nil, "stun is not stored")

ns.db.learnMode = false
record = { locType = "SNARE", spellID = 34567, displayText = "Test Snare" }
equal(ns.Escape:CaptureLossOfControl("party1", 2), true,
    "stale preference cannot disable automatic capture")
equal(ns.learned.movement[34567], "Test Snare",
    "always-on learning stores movement effects")

print("escape tests passed")
