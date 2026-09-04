local addonName, ns = ...

-- ============================================================
-- Aura sounds
-- ============================================================
-- C_UnitAuras.AddAuraSound is the only native route that works for private
-- auras. It accepts a unit token and one spell ID -- never an aura filter -- so
-- Salve keeps a small, typed catalogue in Catalog/Curated.lua and selects only the
-- current instance's records for registration. See data/modules.json.

ns.Sound = {}
local Sound = ns.Sound

-- Use an addon-relative filename for both PlaySoundFile and native aura sounds.
-- Blizzard's old virtual Sound\\Interface path is rejected by the Midnight
-- client, while numeric FileDataIDs were accepted without producing native
-- aura audio. This original Salve tone ships with the addon under its GPL.
local DEFAULT_SOUND = "Interface\\AddOns\\Salve\\Media\\DispelAlert.ogg"
-- A movement impairment needs to be unmistakable from the ordinary dispel
-- alert. This is Blizzard's Entangling Roots end-state sound, available as a
-- Retail FileDataID and intentionally not affected by the dispel-tone setting.
local MOVEMENT_WARNING_SOUND = 3151600

local VALID_DISPEL = {}
for _, dispelType in ipairs(ns.DISPEL_TYPES) do VALID_DISPEL[dispelType] = true end

Sound.sources = {}
Sound.handles = {}
Sound.registered = 0
Sound.expected = 0
Sound.activeInstanceID = 0
Sound.activeInstanceName = "World"
Sound.activeScopeKey = "world:0"
Sound.activeScopeName = "Outdoor world"
Sound.activeModule = nil
Sound.lastFailure = nil
Sound.learnFrames = {}
Sound.learningScopeKey = nil
Sound.pendingLearnUnits = {}

local refreshPending = false
local activationPending = false
local applyTimer

local function registrationUnsafe()
    if ns.StructuralChangesUnsafe then return ns.StructuralChangesUnsafe() end
    return InCombatLockdown and InCombatLockdown() or false
end

local function plain(value)
    if issecretvalue and issecretvalue(value) then return nil end
    return value
end
Sound.Plain = plain

local function currentInstance()
    if not GetInstanceInfo then return "World", 0 end
    local name, _, _, _, _, _, _, instanceID = GetInstanceInfo()
    return name or "World", tonumber(instanceID) or 0
end

local function currentScope(instanceName, instanceID)
    if instanceID > 0 then
        return "instance:" .. instanceID, instanceName, "instance", instanceID
    end

    local mapID = C_Map and C_Map.GetBestMapForUnit
        and tonumber(C_Map.GetBestMapForUnit("player"))
    local mapInfo = mapID and C_Map.GetMapInfo and C_Map.GetMapInfo(mapID)
    if mapID then
        return "map:" .. mapID,
            (mapInfo and mapInfo.name) or ("Outdoor map " .. mapID),
            "map", mapID
    end
    return "world:0", "Unscoped outdoor world", "world", 0
end

-- Only real group tokens are registered. In a raid the player already owns one
-- of raid1..N, so adding the "player" alias as well would risk a double sound.
function Sound:CurrentUnitTokens()
    local units = {}
    if IsInRaid and IsInRaid() then
        local n = GetNumGroupMembers and GetNumGroupMembers() or 0
        for i = 1, n do units[#units + 1] = "raid" .. i end
    elseif IsInGroup and IsInGroup() then
        units[1] = "player"
        local n = GetNumSubgroupMembers and GetNumSubgroupMembers() or 0
        for i = 1, n do units[#units + 1] = "party" .. i end
    else
        units[1] = "player"
    end
    return units
end

function Sound:CurrentCures()
    local cures = {}
    for _, spell in ipairs(ns.knownDispels or {}) do
        for dispelType in pairs(spell.cures or {}) do cures[dispelType] = true end
    end
    return cures
end

-- Public API called by Catalog/Curated.lua at file scope.
function Sound:RegisterData(source, instances)
    if type(source) ~= "string" or type(instances) ~= "table" then return false end

    local normalized = {}
    for instanceID, instance in pairs(instances) do
        instanceID = tonumber(instanceID)
        if instanceID and type(instance) == "table" then
            local entry = {
                name = instance.name,
                season = instance.season,
                coverage = instance.coverage,
                debuffs = {},
            }
            local seen = {}
            for _, record in ipairs(instance.debuffs or {}) do
                local spellID = type(record) == "table" and tonumber(record.spellID)
                local dispelType = type(record) == "table" and record.dispelType
                if spellID and VALID_DISPEL[dispelType] and record.verified == true
                    and not seen[spellID] then
                    seen[spellID] = true
                    entry.debuffs[#entry.debuffs + 1] = record
                end
            end
            normalized[instanceID] = entry
        end
    end

    self.sources[source] = normalized
    self:PruneLearned(self.activeInstanceID)
    if self.activeInstanceID > 0 then self:RequestRefresh() end
    return true
end

function Sound:KnownCurated(instanceID, spellID)
    local instance = self.sources.Salve and self.sources.Salve[instanceID]
    if instance then
        for _, record in ipairs(instance.debuffs) do
            if record.spellID == spellID then return true end
        end
    end
    return false
end

function Sound:PruneLearned(instanceID, scopeKey)
    if not instanceID or instanceID <= 0 then return end
    local bucket = ns.learned and ns.learned.auras
        and ns.learned.auras[scopeKey or ("instance:" .. instanceID)]
    if not bucket or type(bucket.spells) ~= "table" then return end
    for spellID in pairs(bucket.spells) do
        if self:KnownCurated(instanceID, spellID) then bucket.spells[spellID] = nil end
    end
end

-- ── Active-instance selection and registration ────────────────────────────

function Sound:NeedsData()
    return ns.db ~= nil
end

local function dispelSoundEnabled()
    if not ns.db then return false end
    if ns.db.dispelSoundEnabled ~= nil then return ns.db.dispelSoundEnabled end
    return ns.db.soundEnabled == true
end

local function movementSoundEnabled()
    if not ns.db then return false end
    if ns.db.movementSoundEnabled ~= nil then return ns.db.movementSoundEnabled end
    return ns.db.soundEnabled == true
end

function Sound:ActivateCurrentInstance()
    if registrationUnsafe() then
        activationPending = true
        return
    end
    activationPending = false

    self.activeInstanceName, self.activeInstanceID = currentInstance()
    self.activeScopeKey, self.activeScopeName, self.activeScopeType, self.activeScopeID =
        currentScope(self.activeInstanceName, self.activeInstanceID)

    -- ☠ Changing zone RE-SCOPES learning; it never switches it off. Doing so
    --   defeated the whole point for movement data, which only
    --   accumulates by running dungeons.
    if self.learningScopeKey ~= self.activeScopeKey then
        local oldScope = self.learningScopeKey
        self.learningScopeKey = self.activeScopeKey
        if oldScope and self.activeScopeName then
            ns.Print("learning now scoped to " .. self.activeScopeName)
        end
    end
    self.activeModule = self.sources.Salve and "Built-in catalogue" or nil
    self.lastFailure = nil

    self:PruneLearned(self.activeInstanceID, self.activeScopeKey)
    self:Refresh()
    self:UpdateLearnRegistration()
end

-- The cell overlay is deliberately stricter than sounds and learning: it may
-- only make a clickable promise for a reviewed catalogue entry in the current
-- instance.  A learned record is useful evidence for a later review, but it
-- is not evidence that the selected spell can remove the aura.
function Sound:ActiveCuratedRecords()
    local cures = self:CurrentCures()
    local seen, records = {}, {}

    local function add(record)
        if type(record) ~= "table" then return end
        local spellID = tonumber(record.spellID)
        if spellID and cures[record.dispelType] and not seen[spellID] then
            seen[spellID] = true
            records[#records + 1] = record
        end
    end

    local instances = self.sources.Salve
    local instance = instances and instances[self.activeInstanceID]
    if instance then
        for _, record in ipairs(instance.debuffs) do add(record) end
    end

    table.sort(records, function(a, b) return a.spellID < b.spellID end)
    return records
end

function Sound:ActiveCuratedSpellIDs()
    local records = self:ActiveCuratedRecords()
    local ids = {}
    for _, record in ipairs(records) do ids[#ids + 1] = record.spellID end
    return ids
end

-- A tiny subset of curated dispels may be server-scripted, so Blizzard gives
-- them no normal dispel icon even though a player's Cleanse can remove them.
-- These records can request a self-only combat-text instruction. This returns
-- only effects this character has a matching cure for in the active scope.
function Sound:ActiveSelfDispelAlerts()
    local cures, alerts = self:CurrentCures(), {}
    local instances = self.sources.Salve
    local instance = instances and instances[self.activeInstanceID]
    if not instance then return alerts end
    for _, record in ipairs(instance.debuffs) do
        if record.selfAlert == true and cures[record.dispelType] then
            alerts[record.spellID] = record
        end
    end
    return alerts
end

function Sound:ActiveRecords()
    local records = self:ActiveCuratedRecords()
    local seen = {}
    for _, record in ipairs(records) do seen[record.spellID] = true end

    local cures = self:CurrentCures()
    local function add(record)
        if type(record) ~= "table" then return end
        local spellID = tonumber(record.spellID)
        if spellID and cures[record.dispelType] and not seen[spellID] then
            seen[spellID] = true
            records[#records + 1] = record
        end
    end

    local bucket = ns.learned and ns.learned.auras and ns.learned.auras[self.activeScopeKey]
    if bucket and type(bucket.spells) == "table" then
        for _, record in pairs(bucket.spells) do add(record) end
    end

    table.sort(records, function(a, b) return a.spellID < b.spellID end)
    return records
end

local function soundArg()
    local file = (ns.db and ns.db.soundFile) or DEFAULT_SOUND
    if type(file) == "number" then return "soundFileID", file end
    return "soundFileName", file
end

function Sound:Clear()
    if #self.handles == 0 then
        self.registered = 0
        return true
    end

    local remove = C_UnitAuras and (C_UnitAuras.RemoveAuraSound
        or C_UnitAuras.RemoveAuraAppliedSound)
    if not remove then
        self.lastFailure = "the client has no aura-sound removal API"
        return false
    end

    local failed = {}
    for _, handle in ipairs(self.handles) do
        if not pcall(remove, handle) then failed[#failed + 1] = handle end
    end
    self.handles = failed
    self.registered = #failed
    if #failed > 0 then
        self.lastFailure = tostring(#failed) .. " aura-sound registrations could not be removed"
        return false
    end
    return true
end

function Sound:Refresh()
    if registrationUnsafe() then
        refreshPending = true
        return
    end
    refreshPending = false

    if not self:Clear() then return end
    -- A successful clear starts a fresh apply attempt. Do not keep showing an
    -- error from an earlier transient failure after registrations recover.
    self.lastFailure = nil
    self.expected = 0
    if not dispelSoundEnabled() then return end

    local add = C_UnitAuras and (C_UnitAuras.AddAuraSound
        or C_UnitAuras.AddAuraAppliedSound)
    if not add then
        self.lastFailure = "the client has no supported aura-sound API"
        return
    end

    local trigger
    if C_UnitAuras.AddAuraSound then
        trigger = Enum and Enum.UnitAuraSoundTrigger and Enum.UnitAuraSoundTrigger.Added
        if trigger == nil then
            self.lastFailure = "UnitAuraSoundTrigger.Added is unavailable"
            return
        end
    end

    local records = self:ActiveRecords()
    local units = self:CurrentUnitTokens()
    self.expected = #records * #units
    if self.expected == 0 then return end

    local argKey, argVal = soundArg()
    local channel = ns.db.soundChannel or "Master"
    for _, unit in ipairs(units) do
        for _, record in ipairs(records) do
            local info = {
                unitToken = unit,
                spellID = record.spellID,
                outputChannel = channel,
            }
            info[argKey] = argVal

            local ok, handle
            if trigger then
                ok, handle = pcall(add, trigger, info)
            else
                ok, handle = pcall(add, info)
            end
            if ok and handle then
                self.handles[#self.handles + 1] = handle
                self.registered = self.registered + 1
            elseif not self.lastFailure then
                self.lastFailure = "registration rejected for spell "
                    .. tostring(record.spellID) .. " on " .. unit
            end
        end
    end
end

function Sound:RequestRefresh()
    if registrationUnsafe() then
        refreshPending = true
    else
        self:Refresh()
    end
end

function Sound:ScheduleRefresh()
    if applyTimer then return end
    applyTimer = C_Timer.NewTimer(2, function()
        applyTimer = nil
        Sound:RequestRefresh()
    end)
end

function Sound:FlushPending()
    if activationPending then
        self:ActivateCurrentInstance()
    elseif refreshPending then
        self:Refresh()
    end
end

function Sound:FlushPendingLearning()
    local pending = self.pendingLearnUnits
    self.pendingLearnUnits = {}
    for unit in pairs(pending) do
        self:Learn(unit)
    end
end

function Sound:OnRosterChanged()
    self:RequestRefresh()
    -- Run this last so a listener-registration error is not immediately
    -- cleared by an otherwise successful sound refresh.
    self:UpdateLearnRegistration()
end

function Sound:OnDispelChanged()
    self:RequestRefresh()
end

function Sound:OnSettingChanged(key)
    if key == "soundEnabled" or key == "dispelSoundEnabled" then
        -- Enabling may need to load the current instance module; disabling
        -- must make it inactive and remove all registrations.
        self:ActivateCurrentInstance()
    elseif key ~= "movementSoundEnabled" then
        -- Channel/file changes only replace existing native registrations.
        self:RequestRefresh()
    end
end

function Sound:Test(quietSuccess)
    local file = (ns.db and ns.db.soundFile) or DEFAULT_SOUND
    local channel = (ns.db and ns.db.soundChannel) or "Master"
    local ok, willPlay, handle = pcall(PlaySoundFile, file, channel)
    if ok and willPlay then
        if not quietSuccess then ns.Print("test sound accepted on " .. channel) end
        return true, handle
    end
    ns.Print("|cffff4444test sound was rejected|r on " .. channel
        .. " (file " .. tostring(file) .. ")")
    return false
end

-- Roots and snares cannot use C_UnitAuras.AddAuraSound: unlike dispels they
-- have no per-instance curated sound registration and this warning is only for
-- the player who can use a selected personal escape. LOSS_OF_CONTROL_ADDED is
-- already the authoritative player event, so play the same user-selected
-- alert once for each new movement impairment.
function Sound:PlayMovementWarning()
    if not movementSoundEnabled() then return false end
    local channel = ns.db.soundChannel or "Master"
    local ok, willPlay, handle = pcall(PlaySoundFile, MOVEMENT_WARNING_SOUND, channel)
    if ok and willPlay then return true, handle end
    self.lastMovementSoundFailure = tostring(willPlay or "PlaySoundFile rejected the alert")
    return false
end

function Sound:TestMovement(quietSuccess)
    local ok, handle = self:PlayMovementWarning()
    if ok then
        if not quietSuccess then
            ns.Print("snare-removal sound accepted on " .. ((ns.db and ns.db.soundChannel) or "Master"))
        end
        return true, handle
    end
    if not quietSuccess then
        ns.Print("snare-removal sound could not play: "
            .. tostring(self.lastMovementSoundFailure or "sound alerts are disabled"))
    end
    return false
end

-- ── Always-on learning ────────────────────────────────────────────────────

function Sound:UpdateLearnRegistration()
    -- Stop using the main event frame for aura traffic. A dedicated frame per
    -- unit avoids RegisterUnitEvent's fixed unit-argument limit in full raids.
    local mainFrame = _G.SalveEventFrame
    if mainFrame then mainFrame:UnregisterEvent("UNIT_AURA") end
    for _, listener in ipairs(self.learnFrames) do
        listener:UnregisterEvent("UNIT_AURA")
    end
    self.learnUnits = {}
    local units = self:CurrentUnitTokens()
    for index, unit in ipairs(units) do
        self.learnUnits[unit] = true
        local listener = self.learnFrames[index]
        if not listener then
            listener = CreateFrame("Frame")
            listener:SetScript("OnEvent", function(_, event, eventUnit)
                if event == "UNIT_AURA" then Sound:Learn(eventUnit) end
            end)
            self.learnFrames[index] = listener
        end
        local ok = pcall(listener.RegisterUnitEvent, listener, "UNIT_AURA", unit)
        if not ok then
            self.learnUnits[unit] = nil
            self.lastFailure = "could not scope UNIT_AURA learning to " .. unit
        end
    end
end

function Sound:SetLearning(_, quiet)
    -- Compatibility entry point for old slash commands and callers. Learning
    -- is no longer a preference and cannot be switched off.
    ns.db.learnMode = true
    self.activeInstanceName, self.activeInstanceID = currentInstance()
    self.activeScopeKey, self.activeScopeName, self.activeScopeType, self.activeScopeID =
        currentScope(self.activeInstanceName, self.activeInstanceID)
    self.learningScopeKey = self.activeScopeKey
    self:ActivateCurrentInstance()
    if quiet then return end
    ns.Print("aura learning is always on for " .. self.activeScopeName)
end

function Sound:Learn(unit)
    if not (ns.db and self.learnUnits and self.learnUnits[unit]) then return end
    if not C_UnitAuras or not C_UnitAuras.GetAuraDataByIndex then return end

    -- Midnight makes aura lookups secret while the observed unit is in combat.
    -- Calling the getter at all in that state raises a taint error before an
    -- addon can inspect or reject the returned value. Treat that as a normal
    -- deferred observation and retry after PLAYER_REGEN_ENABLED instead.
    if (InCombatLockdown and InCombatLockdown())
        or (UnitAffectingCombat and UnitAffectingCombat(unit)) then
        self.pendingLearnUnits[unit] = true
        return
    end

    local cures = self:CurrentCures()
    for index = 1, 40 do
        -- The combat checks cover the known restriction. Keep the API call
        -- protected too: a future secret-value rule or unusual unit state must
        -- never turn learning into a user-visible Lua error.
        local ok, result = pcall(C_UnitAuras.GetAuraDataByIndex,
            unit, index, ns.DISPELLABLE_FILTER)
        if not ok then
            self.pendingLearnUnits[unit] = true
            return
        end
        local aura = plain(result)
        if not aura then break end

        local spellID = plain(aura.spellId)
        local name = plain(aura.name)
        local dispelType = plain(aura.dispelName)
        if type(spellID) == "number" and VALID_DISPEL[dispelType] and cures[dispelType]
            and not self:KnownCurated(self.activeInstanceID, spellID) then
            local learned = ns.learned.auras
            local bucket = learned[self.activeScopeKey]
            if type(bucket) ~= "table" or type(bucket.spells) ~= "table" then
                bucket = {
                    name = self.activeScopeName,
                    scopeType = self.activeScopeType,
                    scopeID = self.activeScopeID,
                    spells = {},
                }
                learned[self.activeScopeKey] = bucket
            end
            if not bucket.spells[spellID] then
                bucket.spells[spellID] = {
                    spellID = spellID,
                    dispelType = dispelType,
                    name = type(name) == "string" and name or "?",
                    provenance = "in-game learn",
                }
                ns.Print(("learned |cffffd100%d|r  %s (%s) in %s"):format(
                    spellID, tostring(name or "?"), dispelType, self.activeScopeName))
                if dispelSoundEnabled() then self:ScheduleRefresh() end
            end
        end
    end
end

function Sound:DumpLearned()
    local scopeKeys = {}
    for scopeKey, bucket in pairs((ns.learned and ns.learned.auras) or {}) do
        if type(scopeKey) == "string" and type(bucket) == "table"
            and type(bucket.spells) == "table" and next(bucket.spells) then
            scopeKeys[#scopeKeys + 1] = scopeKey
        end
    end
    table.sort(scopeKeys)

    if #scopeKeys == 0 then
        ns.Print("nothing learned yet — keep playing content with readable auras")
        return
    end

    for _, scopeKey in ipairs(scopeKeys) do
        local bucket = ns.learned.auras[scopeKey]
        ns.Print(("learned in %s (%s):"):format(bucket.name or "unknown location", scopeKey))
        local spellIDs = {}
        for spellID in pairs(bucket.spells) do spellIDs[#spellIDs + 1] = spellID end
        table.sort(spellIDs)
        for _, spellID in ipairs(spellIDs) do
            local record = bucket.spells[spellID]
            print(("    %d, -- %s (%s)"):format(
                spellID, tostring(record.name or "?"), tostring(record.dispelType or "?")))
        end
    end
end

function Sound:ClearLearned()
    ns.learned.auras = {}
    self:RequestRefresh()
    ns.Print("learned spell IDs cleared")
end

-- ── Diagnostics ───────────────────────────────────────────────────────────

function Sound:StatusText()
    local loader
    if not self:NeedsData() then
        loader = "no active data"
    else
        loader = self.activeModule or "no matching built-in data"
    end
    local records = self:ActiveRecords()
    return ("%s (%s)\n%s\n%d actionable spell IDs; %d/%d registrations active"):format(
        self.activeScopeName or "World", self.activeScopeKey or "world:0",
        loader, #records, self.registered, self.expected)
end

function Sound:Report()
    ns.Print("sound report")
    ns.Print("  dispel sound: " .. (dispelSoundEnabled() and "yes" or "no"))
    ns.Print("  snare-removal sound: " .. (movementSoundEnabled() and "yes" or "no"))
    ns.Print("  learning: always on")
    ns.Print("  instance: " .. tostring(self.activeInstanceName) .. " ("
        .. tostring(self.activeInstanceID) .. ")")
    ns.Print("  learning scope: " .. tostring(self.activeScopeName) .. " ("
        .. tostring(self.activeScopeKey) .. ")")
    local moduleStatus = self.activeModule or "none"
    if not self:NeedsData() then moduleStatus = "no active data" end
    ns.Print("  catalogue: " .. moduleStatus)
    ns.Print("  cures: " .. ns.CuresText(self:CurrentCures()))
    ns.Print("  actionable IDs: " .. tostring(#self:ActiveRecords()))
    ns.Print("  registrations: " .. tostring(self.registered) .. "/" .. tostring(self.expected))
    local argKey, argVal = soundArg()
    ns.Print("  payload: " .. argKey .. " = " .. tostring(argVal))
    if self.lastFailure then ns.Print("  |cffff4444last failure:|r " .. self.lastFailure) end
end
