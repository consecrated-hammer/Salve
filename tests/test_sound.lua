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
        soundChannel = "Master",
        soundFile = nil,
        learnMode = false,
    },
    learned = { auras = {}, movement = {} },
    knownDispels = {
        { cures = { Magic = true } },
    },
}
function ns.Print() end
function ns.CuresText() return "test" end

issecretvalue = function() return false end
InCombatLockdown = function() return false end
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
PlaySoundFile = function() return true end
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

local loadCalls = 0
local loadedName
local addonNames = { "Salve_Data_Test_Old", "Salve_Data_Test" }
C_AddOns = {
    GetNumAddOns = function() return #addonNames end,
    GetAddOnName = function(index) return addonNames[index] end,
    GetAddOnMetadata = function(name, key)
        if key == "X-Salve-LoadOn-InstanceID" then return "2993" end
        if key == "X-Salve-Data-Priority" then
            return name == "Salve_Data_Test" and "2" or "1"
        end
    end,
}

local chunk = assert(loadfile("Features/Sound.lua"))
chunk("Salve", ns)

C_AddOns.LoadAddOn = function(name)
    loadCalls = loadCalls + 1
    loadedName = name
    ns.Sound:RegisterData(name, {
        [2993] = {
            name = "Test Instance",
            debuffs = {
                { spellID = 1001, dispelType = "Magic", verified = true },
                { spellID = 1002, dispelType = "Disease", verified = true },
                { spellID = 1003, dispelType = "Poison", verified = false },
            },
        },
    })
    return true
end

ns.Sound:DiscoverModules()
ns.Sound:ActivateCurrentInstance()
equal(loadCalls, 0, "disabled mode does not load data")
equal(ns.Sound.registered, 0, "disabled mode registers nothing")

ns.db.soundEnabled = true
ns.Sound:ActivateCurrentInstance()
equal(loadCalls, 1, "enabled mode loads current module")
equal(loadedName, "Salve_Data_Test", "highest-priority module wins")
equal(#ns.Sound:ActiveRecords(), 1, "records filtered by cure type and verification")
equal(ns.Sound.registered, 3, "one spell registered for current party tokens")
equal(added[1].unit, "player", "party includes player")
equal(added[2].unit, "party1", "party includes first member")
equal(added[3].unit, "party2", "party includes second member")
equal(added[1].soundFileName, "Interface\\AddOns\\Salve\\Media\\DispelAlert.ogg",
    "default native sound uses Salve's bundled filename payload")

ns.db.learnMode = true
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

ns.db.soundEnabled = false
ns.Sound:OnSettingChanged("soundEnabled")
equal(ns.Sound.registered, 0, "disabling sound clears registrations")
ns.Sound:SetLearning(false, true)
equal(ns.Sound.activeModule, nil, "sound and learning off make data dormant")
for index = 1, 5 do
    equal(createdFrames[index].event, nil, "disabled learning listener " .. index)
end

ns.Sound.lastFailure = "old transient failure"
ns.db.soundEnabled = true
ns.Sound:RequestRefresh()
equal(ns.Sound.lastFailure, nil, "successful refresh clears stale failure")

local loadsBeforeChannelChange = loadCalls
ns.Sound:OnSettingChanged("soundChannel")
equal(loadCalls, loadsBeforeChannelChange, "channel change does not activate data module")

-- Outdoor learning is map-scoped and cannot remain enabled after leaving.
ns.db.soundEnabled = false
currentInstanceName, currentInstanceID = "World", 0
ns.Sound:SetLearning(true, true)
equal(ns.Sound.activeScopeKey, "map:42", "outdoor learning uses map ID")
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
equal(next(ns.Sound.pendingLearnUnits), nil, "disabling learning clears deferred units")
ns.Sound:SetLearning(true, true)

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
