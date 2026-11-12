-- The unit secrecy log: counts by situation, never compares a secret.
local wow = dofile("tests/hammercore/wow.lua")
wow.Install()

local function equal(actual, expected, label)
    if actual ~= expected then
        error(("%s: expected %s, got %s"):format(label, tostring(expected), tostring(actual)))
    end
end

local secret = setmetatable({}, { __eq = function() error("compared a secret") end,
    __lt = function() error("compared a secret") end })
issecretvalue = function(v) return v == nil and false or rawequal(v, secret) end

local inCombat, encounter, instanceType, mplus = false, false, "party", false
InCombatLockdown = function() return inCombat end
IsEncounterInProgress = function() return encounter end
IsInInstance = function() return true, instanceType end
C_ChallengeMode = { IsChallengeModeActive = function() return mplus end }
GetInstanceInfo = function() return "Test Dungeon" end
date = function() return "2026-11-12 18:00" end

GetRaidTargetIndex = function(unit) return unit == "party1" and 8 or nil end
UnitGroupRolesAssigned = function() return "TANK" end
UnitName = function() return "Someone" end
UnitGUID = function() return "Player-1-2" end
UnitClass = function() return "Paladin", "PALADIN" end
UnitCanAttack = function() return false end

local ns = { db = { unitSecrecyLog = true } }
assert(loadfile("Features/Secrecy.lua"))("Salve", ns)
local S = ns.Secrecy

equal(S:Context(), "party idle", "dungeon out of combat")
S:Sample("test", 100, { "player", "party1" })
local entry = SalveClickLog.secrecy.contexts["party idle"]
equal(entry.samples, 1, "one sample")
equal(entry.fields.marker.readable, 1, "one readable marker")
equal(entry.fields.marker.none, 1, "one member without a marker")
S:Sample("again", 102, { "player" })
equal(entry.samples, 1, "throttled inside five seconds")

-- A key, mid-boss, with markers and names hidden.
mplus, encounter = true, true
equal(S:Context(), "party mplus boss", "key boss pull")
GetRaidTargetIndex = function() return secret end
UnitName = function() return secret end
S:Sample("ENCOUNTER_START", 200, { "player", "party1" })
local boss = SalveClickLog.secrecy.contexts["party mplus boss"]
equal(boss.fields.marker.secret, 2, "secret markers counted")
equal(boss.fields.name.secret, 2, "secret names counted")
equal(boss.fields.role.readable, 2, "readable roles counted")
equal(boss.places[1], "Test Dungeon", "place noted when something was secret")

GetRaidTargetIndex = function() error("restricted") end
S:Sample("tick", 300, { "player" })
equal(boss.fields.marker.error, 1, "a failing read is counted, not raised")

local lines = S:DiagnosticLines()
local text = table.concat(lines, "\n")
assert(text:find("party mplus boss %(2 samples%)"), "summary lists the context")
assert(text:find("marker 0/2/0/err 1", 1, false), "summary shows marker counts: " .. text)

ns.db.unitSecrecyLog = false
S:Sample("off", 400, { "player" })
equal(boss.samples, 2, "switched off records nothing")

S:Clear()
equal(SalveClickLog.secrecy, nil, "clear empties the log")
