local addonName, ns = ...

-- ============================================================
-- Aura sounds
-- ============================================================
-- C_UnitAuras.AddAuraSound is the only native route that works for private
-- auras. It accepts a unit token and one spell ID -- never an aura filter -- so
-- Salve keeps the code here and loads small, typed data modules only when their
-- instance is entered. See Salve_Data_* and data/modules.json.

ns.Sound = {}
local Sound = ns.Sound

-- Use an addon-relative filename for both PlaySoundFile and native aura sounds.
-- Blizzard's old virtual Sound\\Interface path is rejected by the Midnight
-- client, while numeric FileDataIDs were accepted without producing native
-- aura audio. This original Salve tone ships with the addon under its GPL.
local DEFAULT_SOUND = "Interface\\AddOns\\Salve\\Media\\DispelAlert.ogg"
local DATA_META = "X-Salve-LoadOn-InstanceID"
local PRIORITY_META = "X-Salve-Data-Priority"

local VALID_DISPEL = {}
for _, dispelType in ipairs(ns.DISPEL_TYPES) do VALID_DISPEL[dispelType] = true end

Sound.sources = {}
Sound.loaders = {}
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
local moduleLoading = false
local applyTimer

local function plain(value)
    if issecretvalue and issecretvalue(value) then return nil end
    return value
end

local function addOnCount()
    if C_AddOns and C_AddOns.GetNumAddOns then return C_AddOns.GetNumAddOns() end
    return GetNumAddOns and GetNumAddOns() or 0
end

local function addOnName(index)
    if C_AddOns and C_AddOns.GetAddOnName then return C_AddOns.GetAddOnName(index) end
    if GetAddOnInfo then return GetAddOnInfo(index) end
end

local function addOnMetadata(name, key)
    if C_AddOns and C_AddOns.GetAddOnMetadata then
        return C_AddOns.GetAddOnMetadata(name, key)
    end
    return GetAddOnMetadata and GetAddOnMetadata(name, key)
end

local function loadAddOn(name)
    if C_AddOns and C_AddOns.LoadAddOn then return C_AddOns.LoadAddOn(name) end
    return LoadAddOn and LoadAddOn(name)
end

local function isAddOnLoaded(name)
    if C_AddOns and C_AddOns.IsAddOnLoaded then
        local _, loaded = C_AddOns.IsAddOnLoaded(name)
        return loaded
    end
    return IsAddOnLoaded and IsAddOnLoaded(name) or false
end

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

-- ── Load-on-demand module discovery ───────────────────────────────────────

function Sound:DiscoverModules()
    self.loaders = {}
    for index = 1, addOnCount() do
        local name = addOnName(index)
        local instances = name and addOnMetadata(name, DATA_META)
        if name and name:match("^Salve_Data_") and instances then
            local priority = tonumber(addOnMetadata(name, PRIORITY_META)) or 0
            for rawID in tostring(instances):gmatch("%d+") do
                local instanceID = tonumber(rawID)
                local current = self.loaders[instanceID]
                -- A later season may revisit an old dungeon. Highest priority
                -- wins, so zoning there loads the newest installed manifest.
                if not current or priority > current.priority then
                    self.loaders[instanceID] = { name = name, priority = priority }
                end
            end
        end
    end
end

-- Public API called by Salve_Data_* at file scope.
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
    if self.activeInstanceID > 0 and not moduleLoading then self:RequestRefresh() end
    return true
end

function Sound:KnownCurated(instanceID, spellID)
    local loader = self.loaders[instanceID]
    local preferred = loader and self.sources[loader.name]
    local sourceList = preferred and { preferred } or self.sources
    for _, instances in pairs(sourceList) do
        local instance = instances[instanceID]
        if instance then
            for _, record in ipairs(instance.debuffs) do
                if record.spellID == spellID then return true end
            end
        end
    end
    return false
end

function Sound:PruneLearned(instanceID, scopeKey)
    if not instanceID or instanceID <= 0 then return end
    local bucket = ns.db and ns.db.learned
        and ns.db.learned[scopeKey or ("instance:" .. instanceID)]
    if not bucket or type(bucket.spells) ~= "table" then return end
    for spellID in pairs(bucket.spells) do
        if self:KnownCurated(instanceID, spellID) then bucket.spells[spellID] = nil end
    end
end

function Sound:LoadCurrentModule()
    local loader = self.loaders[self.activeInstanceID]
    self.activeModule = loader and loader.name or nil
    if not loader then return true end
    if isAddOnLoaded(loader.name) then
        if self.sources[loader.name] then return true end
        self.lastFailure = loader.name .. " is loaded but registered no Salve data"
        return false
    end

    moduleLoading = true
    local ok, loaded, reason = pcall(loadAddOn, loader.name)
    moduleLoading = false
    if not ok or loaded == false or loaded == nil then
        self.lastFailure = "could not load " .. loader.name .. ": "
            .. tostring(reason or (ok and "unknown" or loaded))
        return false
    end
    return true
end

-- ── Active-instance selection and registration ────────────────────────────

function Sound:NeedsData()
    return ns.db and (ns.db.soundEnabled or ns.db.learnMode)
end

function Sound:ActivateCurrentInstance()
    if InCombatLockdown and InCombatLockdown() then
        activationPending = true
        return
    end
    activationPending = false

    self.activeInstanceName, self.activeInstanceID = currentInstance()
    self.activeScopeKey, self.activeScopeName, self.activeScopeType, self.activeScopeID =
        currentScope(self.activeInstanceName, self.activeInstanceID)

    if ns.db.learnMode and self.learningScopeKey ~= self.activeScopeKey then
        local oldScope = self.learningScopeKey
        ns.db.learnMode = false
        self.learningScopeKey = nil
        if oldScope then
            ns.Print("learn mode automatically turned off after leaving " .. oldScope)
        end
    end
    self.activeModule = nil
    self.lastFailure = nil

    if self:NeedsData() then self:LoadCurrentModule() end
    self:PruneLearned(self.activeInstanceID, self.activeScopeKey)
    self:Refresh()
    self:UpdateLearnRegistration()
end

function Sound:ActiveRecords()
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

    local loader = self.loaders[self.activeInstanceID]
    local instances = loader and self.sources[loader.name]
    local instance = instances and instances[self.activeInstanceID]
    if instance then
        for _, record in ipairs(instance.debuffs) do add(record) end
    end

    local bucket = ns.db and ns.db.learned and ns.db.learned[self.activeScopeKey]
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
    if InCombatLockdown and InCombatLockdown() then
        refreshPending = true
        return
    end
    refreshPending = false

    if not self:Clear() then return end
    -- A successful clear starts a fresh apply attempt. Do not keep showing an
    -- error from an earlier transient failure after registrations recover.
    self.lastFailure = nil
    self.expected = 0
    if not (ns.db and ns.db.soundEnabled) then return end

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
    if InCombatLockdown and InCombatLockdown() then
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
    if not (ns.db and ns.db.learnMode) then
        self.pendingLearnUnits = {}
        return
    end

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
    if key == "soundEnabled" then
        -- Enabling may need to load the current instance module; disabling
        -- must make it inactive and remove all registrations.
        self:ActivateCurrentInstance()
    else
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

-- ── Opt-in learning ───────────────────────────────────────────────────────

function Sound:UpdateLearnRegistration()
    -- Stop using the main event frame for aura traffic. A dedicated frame per
    -- unit avoids RegisterUnitEvent's fixed unit-argument limit in full raids.
    local mainFrame = _G.SalveEventFrame
    if mainFrame then mainFrame:UnregisterEvent("UNIT_AURA") end
    for _, listener in ipairs(self.learnFrames) do
        listener:UnregisterEvent("UNIT_AURA")
    end
    self.learnUnits = {}
    if not (ns.db and ns.db.learnMode) then return end

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

function Sound:SetLearning(on, quiet)
    ns.db.learnMode = on and true or false
    if ns.db.learnMode then
        self.activeInstanceName, self.activeInstanceID = currentInstance()
        self.activeScopeKey, self.activeScopeName, self.activeScopeType, self.activeScopeID =
            currentScope(self.activeInstanceName, self.activeInstanceID)
        self.learningScopeKey = self.activeScopeKey
    else
        self.learningScopeKey = nil
        self.pendingLearnUnits = {}
    end
    self:ActivateCurrentInstance()
    if quiet then return end
    if ns.db.learnMode then
        ns.Print("learn mode ON for " .. self.activeScopeName
            .. " — it turns off automatically when you leave")
    else
        ns.Print("learn mode off")
    end
end

function Sound:Learn(unit)
    if not (ns.db and ns.db.learnMode and self.learnUnits and self.learnUnits[unit]) then return end
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
        -- never turn optional learning into a user-visible Lua error.
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
            local learned = ns.db.learned
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
                if ns.db.soundEnabled then self:ScheduleRefresh() end
            end
        end
    end
end

function Sound:DumpLearned()
    local scopeKeys = {}
    for scopeKey, bucket in pairs((ns.db and ns.db.learned) or {}) do
        if type(scopeKey) == "string" and type(bucket) == "table"
            and type(bucket.spells) == "table" and next(bucket.spells) then
            scopeKeys[#scopeKeys + 1] = scopeKey
        end
    end
    table.sort(scopeKeys)

    if #scopeKeys == 0 then
        ns.Print("nothing learned — use |cffffd100/salve learn on|r in content with readable auras")
        return
    end

    for _, scopeKey in ipairs(scopeKeys) do
        local bucket = ns.db.learned[scopeKey]
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
    ns.db.learned = {}
    self:RequestRefresh()
    ns.Print("learned spell IDs cleared")
end

-- ── Diagnostics ───────────────────────────────────────────────────────────

function Sound:StatusText()
    local loader
    if not self:NeedsData() then
        loader = "data dormant (sound and learning are off)"
    else
        loader = self.activeModule or "no matching data module"
    end
    local records = self:ActiveRecords()
    return ("%s (%s)\n%s\n%d actionable spell IDs; %d/%d registrations active"):format(
        self.activeScopeName or "World", self.activeScopeKey or "world:0",
        loader, #records, self.registered, self.expected)
end

function Sound:Report()
    ns.Print("sound report")
    ns.Print("  enabled: " .. (ns.db.soundEnabled and "yes" or "no"))
    ns.Print("  learning: " .. (ns.db.learnMode and "yes" or "no"))
    ns.Print("  instance: " .. tostring(self.activeInstanceName) .. " ("
        .. tostring(self.activeInstanceID) .. ")")
    ns.Print("  learning scope: " .. tostring(self.activeScopeName) .. " ("
        .. tostring(self.activeScopeKey) .. ")")
    local moduleStatus = self.activeModule or "none"
    if not self:NeedsData() then moduleStatus = "dormant (sound and learning are off)" end
    ns.Print("  module: " .. moduleStatus)
    ns.Print("  cures: " .. ns.CuresText(self:CurrentCures()))
    ns.Print("  actionable IDs: " .. tostring(#self:ActiveRecords()))
    ns.Print("  registrations: " .. tostring(self.registered) .. "/" .. tostring(self.expected))
    local argKey, argVal = soundArg()
    ns.Print("  payload: " .. argKey .. " = " .. tostring(argVal))
    if self.lastFailure then ns.Print("  |cffff4444last failure:|r " .. self.lastFailure) end
end
