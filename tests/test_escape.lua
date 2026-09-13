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
local spellNames = {
    [1953] = "Blink", [212653] = "Shimmer", [235450] = "Prismatic Barrier",
    [192077] = "Wind Rush Totem",
}
C_Spell = { GetSpellInfo = function(id) return { name = spellNames[id] or "Test spell" } end }

C_LossOfControl = {
    GetActiveLossOfControlData = function(index)
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

local divineShield
for _, spell in ipairs(ns.ESCAPE_SPELLS.PALADIN) do
    if spell.id == 642 then divineShield = spell break end
end
equal(divineShield.scope, ns.ESCAPE_SELF,
    "Divine Shield is offered only for the Paladin's own movement impairment")

equal(ns.Escape:Update(), true, "initial known escape changes the list")
equal(ns.knownEscapes[1].id, 1953, "Blink is initially detected")
knownSpells = { [212653] = true }
equal(ns.Escape:Update(), true,
    "equal-count talent replacement changes the known escape list")
equal(ns.knownEscapes[1].id, 212653, "Shimmer replaces Blink")
equal(ns.Escape:Update(), false, "unchanged escape list is stable")

-- Talent-gated movement breaks must not appear merely because the ordinary
-- class spell is known: the passive talent is the part that removes snares.
knownSpells = { [235450] = true }
equal(ns.Escape:Update(), true, "barrier replaces Shimmer in the detected list")
equal(#ns.knownEscapes, 0, "barrier stays hidden without Energized Barriers")
knownSpells = { [235450] = true, [386828] = true }
equal(ns.Escape:Update(), true, "Energized Barriers changes the detected list")
equal(ns.knownEscapes[1].id, 235450, "talented Mage barrier is discoverable")

UnitClass = function() return "Shaman", "SHAMAN" end
knownSpells = { [192077] = true, [462817] = true }
equal(ns.Escape:Update(), true, "Jet Stream changes the detected class list")
equal(ns.knownEscapes[1].scope, ns.ESCAPE_AREA,
    "Jet Stream Wind Rush Totem is an area movement action")

equal(ns.Escape:RegisterMovement("Salve", { 45678 }), true,
    "curated movement registration succeeds")
local curated = ns.Escape:AllSpellIDs()
equal(#curated, 1, "curated movement ID is active before learning")
equal(curated[1], 45678, "curated movement ID is retained")
rebuilds = 0

equal(ns.Escape:CaptureLossOfControl("player", 2), true,
    "automatic root capture succeeds")
equal(ns.learned.movement[12345], "Test Root", "automatic root stores spell")
equal(rebuilds, 1, "automatic root requests panel rebuild")
equal(#prints, 1, "automatic root reports capture")
local afterCapture = ns.Escape:AllSpellIDs()
equal(#afterCapture, 1, "auto-captured roots do not activate the movement overlay")
equal(afterCapture[1], 45678, "only reviewed movement data drives the overlay")
local capturedAgain, isVerifiedMovement = ns.Escape:CaptureLossOfControl("player", 2)
equal(capturedAgain, false,
    "automatic root de-duplicates spell")
equal(isVerifiedMovement, false,
    "unreviewed roots do not become live movement impairments")

record = { locType = "STUN", spellID = 23456, displayText = "Test Stun" }
equal(ns.Escape:CaptureLossOfControl("player", 2), false,
    "non-movement loss of control is ignored")
equal(ns.learned.movement[23456], nil, "stun is not stored")
equal(ns.Escape.lastCaptureStatus, "not a root or snare: STUN, spell 23456 (Test Stun)",
    "non-movement diagnostic preserves the transient event details")

ns.db.learnMode = false
record = { locType = "SNARE", spellID = 34567, displayText = "Test Snare" }
equal(ns.Escape:CaptureLossOfControl("player", 2), true,
    "stale preference cannot disable automatic capture")
equal(ns.learned.movement[34567], "Test Snare",
    "always-on learning stores movement effects")

UnitClass = function() return "Mage", "MAGE" end
knownSpells = { [212653] = true }
ns.Escape:Update()
UnitIsUnit = function(left, right) return left == "raid2" and right == "player" end
equal(ns.Escape:IsPlayerUnit("player"), true, "player token is recognized")
equal(ns.Escape:IsPlayerUnit("raid2"), true, "player raid token is recognized")
equal(ns.Escape:IsPlayerUnit("party1"), false, "other unit is not treated as the player")
ns.db.escapes = { [212653] = true }
equal(ns.Escape:CanWarnForUnit("player"), true,
    "a selected personal escape warns for the player")
equal(ns.Escape:CanWarnForUnit("party1"), false,
    "a selected personal escape stays silent for party members")
ns.Escape.HasAllyEscape = function() return true end
equal(ns.Escape:CanWarnForUnit("party1"), false,
    "an ally-targeted escape still ignores party members")

UnitClass = function() return "Paladin", "PALADIN" end
knownSpells = { [1044] = true }
ns.Escape:Update()
ns.db.escapes = { [1044] = true }
local freedom = ns.Escape:UniversalMovementAlertSpell("player", { locType = "ROOT" })
equal(freedom.id, 1044,
    "Blessing of Freedom universally alerts for the player")
equal(ns.Escape:UniversalMovementAlertSpell("player", { locType = "SNARE" }).id, 1044,
    "Blessing of Freedom universally alerts for the player")
equal(ns.Escape:UniversalMovementAlertSpell("party1", { locType = "STUN" }), nil,
    "Blessing of Freedom never claims it can answer a non-movement effect")

C_LossOfControl.GetActiveLossOfControlDataByUnit = function() error("restricted API must not be called") end
record = { locType = "ROOT", spellID = 34568 }
assert(ns.Escape:CaptureLossOfControl("player", 2))
assert(not ns.Escape:CaptureLossOfControl("party1", 2))
issecretvalue = function(value) return value == "SECRET" end
record = { locType = "SECRET" }
assert(not ns.Escape:CaptureLossOfControl("player", 2))
assert(ns.Escape.lastCaptureStatus == "movement classification unavailable or secret")
print("escape tests passed")
