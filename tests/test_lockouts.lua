local function equal(actual, expected, label)
    if actual ~= expected then
        error(("%s: expected %s, got %s"):format(label, tostring(expected), tostring(actual)))
    end
end

local now = 100
function GetTime() return now end
function issecretvalue(value) return type(value) == "table" and value.secret == true end
local timers = {}
C_Timer = { After = function(delay, fn) timers[#timers + 1] = { delay = delay, fn = fn } end }
function IsInRaid() return false end
local roster = {
    player = { name = "Kev", guid = "Player-1" },
    party1 = { name = "Tank", realm = "Other", guid = "Player-2" },
    party2 = { name = "Rogue", guid = "Player-3" },
}
function UnitExists(unit) return roster[unit] ~= nil end
function UnitName(unit) local r = roster[unit]; return r and r.name, r and r.realm end
function UnitGUID(unit) local r = roster[unit]; return r and r.guid end
local modifiers = false
function IsAltKeyDown() return modifiers end
function IsControlKeyDown() return false end
function IsShiftKeyDown() return false end

local BOP, SPELLWARDING, DIVINE_SHIELD, FREEDOM, FORBEARANCE = 1022, 204018, 642, 1044, 25771
local bound = { BOP }
local shown = {}
local ns = {
    db = { lockoutIcons = true, lockoutPlacement = "CELL" },
    Cooldowns = { BoundSpells = function() return bound end },
    Box = { UpdateLockoutIcon = function(box, entry) shown[box.unit] = entry end },
}
local barUpdates = 0
ns.CooldownBar = { UpdateLockouts = function() barUpdates = barUpdates + 1 end }
assert(loadfile("Features/Bindings.lua"))("Salve", ns)
assert(loadfile("Features/Lockouts.lua"))("Salve", ns)
local L = ns.Lockouts

local function cell(unit, actions)
    return { unit = unit, clickAuditActions = actions }
end
local tank = cell("party1", { BUTTON2 = { spellID = BOP } })
local rogue = cell("party2", { BUTTON2 = { spellID = BOP }, BUTTON1 = { spellID = FREEDOM } })
local me = cell("player", { BUTTON2 = { spellID = BOP } })
ns.Panel = { boxes = { me, tank, rogue } }

equal(#L:Relevant(), 1, "Forbearance matters with Protection bound")
bound = { FREEDOM }
equal(L:Enabled(), false, "nothing to show without a blocked spell bound")
bound = { BOP }
equal(L:Enabled(), true, "on with Protection bound")

-- A cell click followed by the cast puts Forbearance on that member.
L:NoteClick(tank, "RightButton")
L:NoteCast("player", "cast-1", BOP)
equal(shown.party1 and shown.party1.spellID, FORBEARANCE, "clicked member gets Forbearance")
equal(shown.party1.duration, 30, "for thirty seconds")
equal(shown.party2, nil, "nobody else does")
equal(timers[#timers].delay > 30, true, "an expiry is scheduled")

-- A talent override still counts as the clicked spell.
L:NoteClick(rogue, "RightButton")
now = 101
L:NoteCast("player", "cast-2", SPELLWARDING)
equal(shown.party2 ~= nil, true, "Spellwarding after a Protection click counts")

-- A stale click doesn't claim a later keybind cast.
shown = {}
L.active = {}
L:NoteClick(rogue, "RightButton")
now = 110
L:NoteCast("player", "cast-3", BOP)
equal(shown.party2, nil, "an old click isn't trusted")
equal(L.missed, 1, "the cast is counted as untracked")

-- Casts from elsewhere use the readable sent target name, realm and all.
L:NoteSent("player", "Tank-Other", "cast-4", BOP)
L:NoteCast("player", "cast-4", BOP)
equal(shown.party1 ~= nil, true, "a keybind cast finds its target by name")
L:NoteSent("player", { secret = true }, "cast-5", BOP)
L:NoteCast("player", "cast-5", BOP)
equal(L.missed, 2, "a secret target name is never compared")

-- Divine Shield is always yourself.
L:NoteCast("player", "cast-6", DIVINE_SHIELD)
equal(shown.player ~= nil, true, "Divine Shield puts Forbearance on you")

-- Unrelated and secret casts do nothing.
local before = L.missed
L:NoteCast("player", "cast-7", FREEDOM)
L:NoteCast("player", "cast-8", { secret = true })
equal(L.missed, before, "other spells are ignored")

-- It follows the person, not the slot, when the GUID is readable.
roster.party1, roster.party2 = roster.party2, roster.party1
L:Refresh()
equal(shown.party2 ~= nil, true, "Forbearance moves with its member")
equal(shown.party1, nil, "the new party1 is clear")
roster.party1, roster.party2 = roster.party2, roster.party1

-- Expiry clears it.
now = 200
L:Expire()
equal(shown.party1, nil, "it clears when it runs out")
equal(shown.player, nil, "yours too")

-- On the bar (the default): oldest first, named, and off the cells.
ns.db.lockoutPlacement = nil
equal(L:Placement(), "BAR", "the bar is the default place")
L:NoteClick(tank, "RightButton")
L:NoteCast("player", "cast-10", BOP)
now = 205
L:NoteCast("player", "cast-11", DIVINE_SHIELD)
local entries = L:BarEntries()
equal(#entries, 2, "both lockouts go on the bar")
equal(entries[1].name, "Tank", "oldest first, with the member's name")
equal(entries[2].name, "Kev", "then yours")
equal(shown.party1, nil, "the cell stays clear")
equal(barUpdates > 0, true, "the bar is told")
ns.db.lockoutPlacement = "BOTH"
L:Refresh()
equal(shown.party1 ~= nil and #L:BarEntries() == 2, true, "both shows it on the cell and the bar")
ns.db.lockoutPlacement = "CELL"
L:Refresh()
equal(#L:BarEntries(), 0, "cell only leaves the bar alone")
now = 300
L:Expire()
ns.db.lockoutPlacement = "BAR"
equal(#L:BarEntries(), 0, "expired lockouts leave the bar")

-- Switched off, nothing is tracked or shown.
ns.db.lockoutIcons = false
L:NoteClick(tank, "RightButton")
L:NoteCast("player", "cast-9", BOP)
equal(next(L.active), nil, "off tracks nothing")

print("lockout tests passed")

-- WoW Forever has its own Forbearance: a minute, every rank, and its own spells.
do
    local foreverShown, foreverBound = {}, { 5599 }
    local forever = {
        isCamelot = true,
        db = { lockoutIcons = true, lockoutPlacement = "CELL" },
        Cooldowns = { BoundSpells = function() return foreverBound end },
        Box = { UpdateLockoutIcon = function(box, entry) foreverShown[box.unit] = entry end },
        CooldownBar = { UpdateLockouts = function() end },
    }
    assert(loadfile("Features/Bindings.lua"))("Salve", forever)
    assert(loadfile("Features/Lockouts.lua"))("Salve", forever)
    local F = forever.Lockouts
    forever.Panel = { boxes = {
        { unit = "player" },
        { unit = "party1", clickAuditActions = { BUTTON2 = { spellID = 10278 } } },
    } }
    equal(F:Enabled(), true, "a higher rank bound turns it on")

    for _, id in ipairs({ 642, 1020, 498, 5573, 1311015 }) do
        foreverShown, F.active = {}, {}
        F:NoteCast("player", "self-" .. id, id)
        equal(foreverShown.player and foreverShown.player.duration, 60,
            "spell " .. id .. " puts a minute of Forbearance on you")
    end

    foreverShown, F.active = {}, {}
    F:NoteClick(forever.Panel.boxes[2], "RightButton")
    F:NoteCast("player", "bop-3", 10278)
    equal(foreverShown.party1 and foreverShown.party1.duration, 60, "rank 3 Protection on a member")

    foreverShown, F.active = {}, {}
    local missed = F.missed
    for _, id in ipairs({ 633, 2800, 10310, 204018 }) do
        F:NoteCast("player", "none-" .. id, id)
    end
    equal(next(foreverShown), nil, "Lay on Hands and Retail's Spellwarding don't start it")
    equal(F.missed, missed, "and don't count as untracked casts")
end
