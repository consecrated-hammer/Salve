local addonName, ns = ...

-- ============================================================
-- Unit secrecy log
-- ============================================================
-- Records which unit facts the client hides from addons, and where: raid
-- markers, roles, names, GUIDs, class and the charm check. Each answers an
-- open design question (the marker icon, skip and priority lists, charm
-- alerts), and Blizzard doesn't document when they turn secret.
--
-- Counts only, keyed by situation ("party mplus combat"), saved in the
-- diagnostics block beside the click log. Nothing about the unit itself is
-- stored. Every read is pcall'd and a value is only compared after
-- issecretvalue says it's readable.

ns.Secrecy = {}
local Secrecy = ns.Secrecy

local MAX_CONTEXTS = 48
local MAX_PLACES = 6
local THROTTLE = 5
local TICK = 15

local function isSecret(value)
    return issecretvalue and issecretvalue(value) and true or false
end

local function readable(value)
    return value ~= nil and not isSecret(value)
end

local FIELDS = {
    { key = "marker", read = function(unit) return GetRaidTargetIndex(unit) end },
    { key = "role", read = function(unit) return UnitGroupRolesAssigned(unit) end },
    { key = "name", read = function(unit) return UnitName(unit) end },
    { key = "guid", read = function(unit) return UnitGUID(unit) end },
    { key = "class", read = function(unit) return select(2, UnitClass(unit)) end },
    { key = "canAttack", read = function(unit) return UnitCanAttack("player", unit) end },
}
Secrecy.FIELDS = FIELDS

function Secrecy:Enabled()
    return not (ns.db and ns.db.unitSecrecyLog == false)
end

function Secrecy:Store()
    if type(SalveClickLog) ~= "table" then SalveClickLog = {} end
    local store = SalveClickLog.secrecy
    if type(store) ~= "table" or type(store.contexts) ~= "table" then
        store = { contexts = {}, schemaVersion = 1 }
        SalveClickLog.secrecy = store
    end
    return store
end

-- "none", "party", "raid", "pvp", "arena" or "scenario", then "mplus" in a
-- key, then "boss", "combat" or "idle".
function Secrecy:Context()
    local kind = "none"
    local ok, _, instanceType = pcall(IsInInstance)
    if ok and readable(instanceType) and type(instanceType) == "string" then kind = instanceType end
    local parts = { kind }
    local cm = C_ChallengeMode
    if cm and cm.IsChallengeModeActive then
        local okActive, active = pcall(cm.IsChallengeModeActive)
        if okActive and readable(active) and active then parts[#parts + 1] = "mplus" end
    end
    local boss = IsEncounterInProgress and IsEncounterInProgress()
    if readable(boss) and boss then
        parts[#parts + 1] = "boss"
    elseif InCombatLockdown and InCombatLockdown() then
        parts[#parts + 1] = "combat"
    else
        parts[#parts + 1] = "idle"
    end
    return table.concat(parts, " ")
end

local function placeName()
    if not GetInstanceInfo then return nil end
    local ok, name = pcall(GetInstanceInfo)
    if ok and readable(name) and type(name) == "string" and name ~= "" then return name end
    return nil
end

local function units()
    local list = {}
    for _, box in ipairs(ns.Panel and ns.Panel.boxes or {}) do
        if box.unit then list[#list + 1] = box.unit end
    end
    if #list == 0 then list[1] = "player" end
    return list
end

-- One pass over the group. `now` and `unitList` are for tests.
function Secrecy:Sample(reason, now, unitList)
    if not self:Enabled() then return end
    now = now or (GetTime and GetTime()) or 0
    local key = self:Context()
    self.lastSample = self.lastSample or {}
    if self.lastSample[key] and now - self.lastSample[key] < THROTTLE then return end
    self.lastSample[key] = now

    local store = self:Store()
    local entry = store.contexts[key]
    if not entry then
        local count = 0
        for _ in pairs(store.contexts) do count = count + 1 end
        if count >= MAX_CONTEXTS then return end
        entry = { samples = 0, fields = {}, places = {} }
        store.contexts[key] = entry
    end
    entry.samples = entry.samples + 1
    entry.last = date and date("%Y-%m-%d %H:%M") or nil
    entry.lastReason = reason

    local anySecret = false
    for _, unit in ipairs(unitList or units()) do
        for _, field in ipairs(FIELDS) do
            local counts = entry.fields[field.key]
            if not counts then
                counts = { readable = 0, secret = 0, none = 0, error = 0 }
                entry.fields[field.key] = counts
            end
            local ok, value = pcall(field.read, unit)
            if not ok then
                counts.error = counts.error + 1
            elseif isSecret(value) then
                counts.secret = counts.secret + 1
                anySecret = true
            elseif value == nil then
                counts.none = counts.none + 1
            else
                counts.readable = counts.readable + 1
            end
        end
    end

    -- Where secrets turned up, so a result can be matched to a dungeon or boss.
    local place = anySecret and placeName()
    if place then
        local seen = false
        for _, existing in ipairs(entry.places) do
            if existing == place then seen = true break end
        end
        if not seen then
            entry.places[#entry.places + 1] = place
            if #entry.places > MAX_PLACES then table.remove(entry.places, 1) end
        end
    end
end

function Secrecy:Clear()
    if type(SalveClickLog) == "table" then SalveClickLog.secrecy = nil end
    self.lastSample = {}
end

function Secrecy:DiagnosticLines()
    local lines = { "Unit secrecy log (" .. (self:Enabled() and "on" or "off") .. "):" }
    local store = type(SalveClickLog) == "table" and SalveClickLog.secrecy
    local keys = {}
    for key in pairs(store and store.contexts or {}) do keys[#keys + 1] = key end
    table.sort(keys)
    if #keys == 0 then
        lines[#lines + 1] = "  nothing recorded yet"
        return lines
    end
    for _, key in ipairs(keys) do
        local entry = store.contexts[key]
        local parts = {}
        for _, field in ipairs(FIELDS) do
            local c = entry.fields[field.key]
            if c then
                parts[#parts + 1] = field.key .. " " .. c.readable .. "/" .. c.secret
                    .. "/" .. c.none .. (c.error > 0 and ("/err " .. c.error) or "")
            end
        end
        lines[#lines + 1] = "  " .. key .. " (" .. entry.samples .. " samples): "
            .. table.concat(parts, ", ")
        if #entry.places > 0 then
            lines[#lines + 1] = "    secret at: " .. table.concat(entry.places, ", ")
        end
    end
    lines[#lines + 1] = "  counts are readable/secret/none"
    return lines
end

-- ── Triggers ───────────────────────────────────────────────────────────────
-- Markers and roles change on their own events; combat and boss pulls are
-- when secrecy is most likely, so those also sample two seconds in and then
-- every fifteen seconds until the fight ends.

local frame = CreateFrame("Frame")
local ticker

local function stopTicker()
    if ticker then ticker:Cancel() ticker = nil end
end

local function startTicker()
    if ticker or not (C_Timer and C_Timer.NewTicker) then return end
    ticker = C_Timer.NewTicker(TICK, function()
        local fighting = (InCombatLockdown and InCombatLockdown())
            or (IsEncounterInProgress and readable(IsEncounterInProgress()) and IsEncounterInProgress())
        if fighting then Secrecy:Sample("tick") else stopTicker() end
    end)
end

frame:SetScript("OnEvent", function(_, event)
    if not Secrecy:Enabled() then return end
    if event == "PLAYER_REGEN_DISABLED" or event == "ENCOUNTER_START" or event == "CHALLENGE_MODE_START" then
        Secrecy:Sample(event)
        if C_Timer and C_Timer.After then
            C_Timer.After(2, function() Secrecy:Sample(event .. " +2s") end)
        end
        startTicker()
    else
        Secrecy:Sample(event)
    end
end)

for _, event in ipairs({ "RAID_TARGET_UPDATE", "PLAYER_REGEN_DISABLED", "ENCOUNTER_START",
    "CHALLENGE_MODE_START", "PLAYER_ROLES_ASSIGNED", "GROUP_ROSTER_UPDATE", "PLAYER_ENTERING_WORLD" }) do
    -- Not every client knows every event; registering an unknown one errors.
    pcall(frame.RegisterEvent, frame, event)
end
