local function equal(actual, expected, label)
    if actual ~= expected then
        error(("%s: expected %s, got %s"):format(label, tostring(expected), tostring(actual)))
    end
end

local prints, rebuilds = {}, 0
local record = { locType = "ROOT", spellID = 12345, displayText = "Test Root" }

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
equal(ns.Escape:CaptureLossOfControl("party1", 2), false,
    "automatic capture respects disabled learning")
equal(ns.learned.movement[34567], nil, "disabled learning stores nothing")

print("escape tests passed")
