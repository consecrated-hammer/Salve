local function equal(actual, expected, label)
    if actual ~= expected then
        error(("%s: expected %s, got %s"):format(label, tostring(expected), tostring(actual)))
    end
end

local ns = {
    DISPEL_TYPES = { "Magic", "Curse", "Disease", "Poison" },
    DISPELLABLE_FILTER = "HARMFUL",
    db = {
        soundEnabled = false,
        dispelSoundEnabled = false,
        movementSoundEnabled = false,
        soundChannel = "Master",
        soundFile = nil,
        learnMode = true,
    },
    learned = { auras = {}, movement = {} },
    knownDispels = {
        { cures = { Magic = true } },
    },
}
function ns.Print() end
function ns.CuresText() return "test" end

issecretvalue = function() return false end
local encounterActive = false
InCombatLockdown = function() return false end
function ns.StructuralChangesUnsafe()
    return InCombatLockdown() or encounterActive
end
local currentInstanceName, currentInstanceID = "Test Instance", 2993
local currentMapID, currentMapName = 42, "Duskwood"
GetInstanceInfo = function()
    return currentInstanceName, nil, nil, nil, nil, nil, nil, currentInstanceID
end
C_Map = {
    GetBestMapForUnit = function() return currentMapID end,
    GetMapInfo = function() return { name = currentMapName } end,
}
IsInRaid = function() return false end
IsInGroup = function() return true end
GetNumSubgroupMembers = function() return 2 end
GetNumGroupMembers = function() return 3 end
local playedSound = {}
PlaySoundFile = function(file, channel)
    playedSound[#playedSound + 1] = { file = file, channel = channel }
    return true
end
Enum = { UnitAuraSoundTrigger = { Added = 0 } }
local createdFrames = {}
CreateFrame = function()
    local frame = { event = nil, unit = nil, script = nil }
    function frame:SetScript(_, callback) self.script = callback end
    function frame:RegisterUnitEvent(event, unit)
        self.event, self.unit = event, unit
    end
    function frame:UnregisterEvent(event)
        if self.event == event then self.event, self.unit = nil, nil end
    end
    createdFrames[#createdFrames + 1] = frame
    return frame
end
_G.SalveEventFrame = { UnregisterEvent = function() end }
C_Timer = {
    NewTimer = function(_, callback)
        return { Cancel = function() end, callback = callback }
    end,
}

local added, removed, nextHandle = {}, {}, 0
C_UnitAuras = {
    AddAuraSound = function(_, info)
        nextHandle = nextHandle + 1
        added[#added + 1] = {
            unit = info.unitToken,
            spellID = info.spellID,
            soundFileID = info.soundFileID,
            soundFileName = info.soundFileName,
        }
        return nextHandle
    end,
    RemoveAuraSound = function(handle)
        removed[#removed + 1] = handle
    end,
}

local chunk = assert(loadfile("Features/Sound.lua"))
chunk("Salve", ns)

ns.Sound:RegisterData("Salve", {
    [2993] = {
        name = "Test Instance",
        debuffs = {
            { spellID = 1001, dispelType = "Magic", verified = true },
            { spellID = 1002, dispelType = "Disease", verified = true },
            { spellID = 1003, dispelType = "Poison", verified = false },
        },
    },
    ["map:42"] = {
        name = "Duskwood",
        debuffs = {
            { spellID = 2002, dispelType = "Disease", verified = true },
        },
    },
})
ns.Sound:ActivateCurrentInstance()
equal(ns.Sound.activeModule, "Built-in catalogue", "current data is built into Salve")
local curatedIDs = ns.Sound:ActiveCuratedSpellIDs()
equal(#curatedIDs, 1, "only verified current-instance spells can drive the cell overlay")
equal(curatedIDs[1], 1001, "overlay list excludes schools the character cannot cure")
equal(ns.Sound.registered, 0, "sound disabled registers no alerts")
equal(ns.Sound:PlayMovementWarning(), false,
    "movement warning respects the shared alert-sound toggle")
equal(#createdFrames, 3, "always-on learning creates one listener per party unit")

ns.db.dispelSoundEnabled = true
ns.db.movementSoundEnabled = true
ns.Sound:ActivateCurrentInstance()
equal(ns.Sound:PlayMovementWarning(), true,
    "movement warning plays through the selected alert path")
equal(playedSound[#playedSound].file, 3151600,
    "movement warning uses Blizzard's Entangling Roots end-state sound")
equal(playedSound[#playedSound].channel, "Master",
    "movement warning uses the configured output channel")
equal(ns.Sound:TestMovement(true), true,
    "movement sound test uses the movement-warning alert path")
equal(#ns.Sound:ActiveRecords(), 1, "records filtered by cure type and verification")
equal(ns.Sound.registered, 3, "one spell registered for current party tokens")
equal(added[1].unit, "player", "party includes player")
equal(added[2].unit, "party1", "party includes first member")
equal(added[3].unit, "party2", "party includes second member")
equal(added[1].soundFileName, "Interface\\AddOns\\Salve\\Media\\DispelAlert.ogg",
    "default native sound uses Salve's bundled filename payload")

ns.db.movementSoundEnabled = false
equal(ns.Sound:PlayMovementWarning(), false,
    "snare-removal sound can be disabled independently")
equal(ns.Sound.registered, 3,
    "disabling snare-removal sound keeps dispel registrations active")
ns.db.movementSoundEnabled = true

ns.Sound:UpdateLearnRegistration()
equal(#createdFrames, 3, "learning creates one listener per party unit")
equal(createdFrames[1].unit, "player", "first listener scopes player")
equal(createdFrames[2].unit, "party1", "second listener scopes party member")
equal(createdFrames[3].unit, "party2", "third listener scopes party member")

ns.knownDispels = { { cures = { Disease = true } } }
ns.Sound:OnDispelChanged()
equal(#removed, 3, "old registrations removed on dispel change")
equal(ns.Sound.registered, 3, "new cure school registered")
equal(added[#added].spellID, 1002, "disease record selected")

IsInRaid = function() return true end
GetNumGroupMembers = function() return 5 end
ns.Sound:OnRosterChanged()
equal(ns.Sound.registered, 5, "raid uses one token per member")
equal(#createdFrames, 5, "learning expands to one listener per raid unit")
for index = 1, 5 do
    equal(createdFrames[index].unit, "raid" .. index, "raid learning listener " .. index)
end
for index = #added - 4, #added do
    if added[index].unit == "player" then error("raid registrations duplicated the player alias") end
end

ns.db.dispelSoundEnabled = false
ns.Sound:OnSettingChanged("dispelSoundEnabled")
equal(ns.Sound.registered, 0, "disabling sound clears registrations")
equal(ns.Sound:PlayMovementWarning(), true,
    "disabling dispel sound keeps snare-removal sound active")
ns.Sound:SetLearning(false, true)
equal(ns.db.learnMode, true, "compatibility call cannot disable learning")
equal(ns.Sound.activeModule, "Built-in catalogue",
    "learning keeps built-in data active when sound is disabled")
for index = 1, 5 do
    equal(createdFrames[index].event, "UNIT_AURA",
        "always-on learning listener " .. index)
end

ns.Sound.lastFailure = "old transient failure"
ns.db.dispelSoundEnabled = true
ns.Sound:RequestRefresh()
equal(ns.Sound.lastFailure, nil, "successful refresh clears stale failure")

local addedBeforeEncounter = #added
local removedBeforeEncounter = #removed
encounterActive = true
ns.Sound:RequestRefresh()
equal(#added, addedBeforeEncounter,
    "active encounter defers new aura-sound registrations")
equal(#removed, removedBeforeEncounter,
    "active encounter preserves working aura-sound registrations")
encounterActive = false
ns.Sound:FlushPending()
equal(#removed > removedBeforeEncounter, true,
    "queued sound refresh runs once the encounter ends")
equal(ns.Sound.lastFailure, nil,
    "deferred sound refresh does not report a transient rejection")

ns.Sound:OnSettingChanged("soundChannel")
equal(ns.Sound.activeModule, "Built-in catalogue",
    "channel change keeps the built-in catalogue selected")

-- Outdoor learning is map-scoped and cannot remain enabled after leaving.
ns.db.dispelSoundEnabled = false
currentInstanceName, currentInstanceID = "World", 0
ns.Sound:SetLearning(true, true)
equal(ns.Sound.activeScopeKey, "map:42", "outdoor learning uses map ID")
equal(ns.Sound.activeModule, "Built-in catalogue", "map-scoped catalogue activates outdoors")
local mapRecords = ns.Sound:ActiveCuratedSpellIDs()
equal(#mapRecords, 1, "outdoor catalogue selects only the active map")
equal(mapRecords[1], 2002, "outdoor catalogue selects the map spell ID")
equal(ns.db.learnMode, true, "learning active in original outdoor map")
local auraReads = 0
C_UnitAuras.GetAuraDataByIndex = function(_, index)
    auraReads = auraReads + 1
    if index == 1 then
        return { spellId = 2001, name = "Spider Venom", dispelName = "Disease" }
    end
end
InCombatLockdown = function() return true end
UnitAffectingCombat = function() return true end
ns.Sound:Learn("raid1")
equal(auraReads, 0, "learning never reads secret combat auras")
equal(ns.Sound.pendingLearnUnits.raid1, true, "combat learning defers the unit")

InCombatLockdown = function() return false end
UnitAffectingCombat = function() return false end
ns.Sound:FlushPendingLearning()
equal(auraReads, 2, "deferred unit is scanned after combat")
equal(next(ns.Sound.pendingLearnUnits), nil, "deferred learning queue drains")
ns.Sound:Learn("raid1")
equal(ns.learned.auras["map:42"].spells[2001].name, "Spider Venom",
    "outdoor discovery stored in map bucket")

C_UnitAuras.GetAuraDataByIndex = function()
    error("secret aura")
end
ns.Sound:Learn("raid1")
equal(ns.Sound.pendingLearnUnits.raid1, true, "unexpected secret lookup is contained")
ns.Sound:SetLearning(false, true)
equal(ns.Sound.pendingLearnUnits.raid1, true,
    "compatibility call cannot discard deferred learning")

currentMapID, currentMapName = 43, "Westfall"
ns.Sound:ActivateCurrentInstance()
equal(ns.db.learnMode, true, "learning keeps running across a scope change")
equal(ns.Sound.learningScopeKey, ns.Sound.activeScopeKey, "learning re-scoped to the new zone")
-- The listener STAYS registered across a scope change. Dropping it was the
-- mechanism behind the old self-disabling behaviour; learning now follows you
-- from zone to zone, which is the point for movement-impairing effects.
for index = 1, 5 do
    equal(createdFrames[index].event, "UNIT_AURA",
        "scope change keeps listener " .. index .. " registered")
end

print("sound tests passed")
