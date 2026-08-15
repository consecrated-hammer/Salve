local addonName, ns = ...

-- ============================================================
-- Aura sounds
-- ============================================================
-- ☠ THE ONLY SUPPORTED CHANNEL, AND IT IS KEYED PER SPELL ID.
--
-- Two hand-rolled approaches were tried in game on 2026-08-15 and BOTH were
-- refused: HookScript("OnShow") on the engine's aura button, then creating a
-- child frame under that button and hooking its OnShow. The button subtree is
-- sealed against tainted script attachment, which matches DandersFrames' note
-- that even OnUpdate drivers do not tick inside it. Do not try a third variant.
--
-- C_UnitAuras.AddAuraSound is the sanctioned route, and its history says why it
-- exists: it replaced AddPrivateAuraAppliedSound. PRIVATE auras are ones addons
-- cannot see at all, and in 12.1 Blizzard made most encounter debuffs private.
-- Sound is the one feedback channel deliberately left open for auras you are not
-- allowed to inspect -- which is exactly our case.
--
-- The price is that it takes a spellID, not a filter. Salve never learns what it
-- is dispelling, so the IDs have to come from somewhere else: a companion addon
-- (Salve_SeasonData) that can be updated without touching this one.

ns.Sound = {}
local Sound = ns.Sound

local DEFAULT_SOUND = "Sound\\Interface\\AlarmClockWarning3.ogg"

-- Registered spell IDs, keyed by the addon that supplied them so a companion can
-- be disabled or updated without disturbing the others.
Sound.sources    = {}
Sound.handles    = {}
Sound.registered = 0

-- Unit tokens we ever bind to. Fixed and finite, so registration is a one-time
-- cost at login rather than something the roster churns.
local UNIT_TOKENS = { "player" }
for i = 1, 4  do UNIT_TOKENS[#UNIT_TOKENS + 1] = "party" .. i end
for i = 1, 40 do UNIT_TOKENS[#UNIT_TOKENS + 1] = "raid"  .. i end

-- ── Public API for companion addons ────────────────────────────────────────
--
--   Salve.Sound:RegisterDebuffs("Salve_SeasonData", { 1257085, 1257087, ... })
--
-- Call it at file scope; Salve re-registers everything on the next login or
-- whenever a source changes.

function Sound:RegisterDebuffs(source, spellIDs)
    if type(source) ~= "string" or type(spellIDs) ~= "table" then return false end

    local set = {}
    for _, id in ipairs(spellIDs) do
        if type(id) == "number" then set[id] = true end
    end

    self.sources[source] = set
    self:Apply()
    return true
end

function Sound:UnregisterSource(source)
    self.sources[source] = nil
    self:Apply()
end

-- Every spell ID across every source, plus everything learn mode has found,
-- de-duplicated. Learned IDs are ADDITIVE -- the curated list is the floor, not
-- the ceiling, so a debuff the season data missed still gets an alert once you
-- have met it.
function Sound:AllSpellIDs()
    local seen, list = {}, {}

    local function add(id)
        if type(id) == "number" and not seen[id] then
            seen[id] = true
            list[#list + 1] = id
        end
    end

    for _, set in pairs(self.sources) do
        for id in pairs(set) do add(id) end
    end
    for id in pairs((ns.db and ns.db.learned) or {}) do add(id) end

    return list
end

-- ── Registration ───────────────────────────────────────────────────────────

local function soundArg()
    local file = (ns.db and ns.db.soundFile) or DEFAULT_SOUND
    if type(file) == "number" then return "soundFileID", file end
    return "soundFileName", file
end

function Sound:Clear()
    local remove = C_UnitAuras and (C_UnitAuras.RemoveAuraSound
        or C_UnitAuras.RemoveAuraAppliedSound)
    if remove then
        for _, id in ipairs(self.handles) do pcall(remove, id) end
    end
    -- ☠ A leaked registration is the failure mode here: the handle outlives the
    --   config that created it and the sound keeps firing with no way to stop
    --   it short of a reload. Always empty the list, even if removal failed.
    self.handles    = {}
    self.registered = 0
end

function Sound:Apply()
    if not C_UnitAuras then return end

    self:Clear()
    if not (ns.db and ns.db.soundEnabled) then return end

    local add = C_UnitAuras.AddAuraSound or C_UnitAuras.AddAuraAppliedSound
    if not add then return end

    -- "Added" only. ApplicationsIncreased would fire on every stack of a
    -- ticking debuff, and Removed announces the problem going away, which is
    -- not what an alert is for. (There is no ApplicationsDecreased trigger.)
    local trigger
    if C_UnitAuras.AddAuraSound then
        trigger = Enum and Enum.UnitAuraSoundTrigger and Enum.UnitAuraSoundTrigger.Added
        if trigger == nil then return end
    end

    local ids = self:AllSpellIDs()
    if #ids == 0 then return end

    local argKey, argVal = soundArg()
    local channel = (ns.db and ns.db.soundChannel) or "Master"

    for _, unit in ipairs(UNIT_TOKENS) do
        for _, spellID in ipairs(ids) do
            local info = {
                unitToken = unit, spellID = spellID, outputChannel = channel,
            }
            info[argKey] = argVal

            local ok, handle
            if trigger then
                ok, handle = pcall(add, trigger, info)
            else
                ok, handle = pcall(add, info)   -- pre-rename client
            end

            if ok and handle then
                self.handles[#self.handles + 1] = handle
                self.registered = self.registered + 1
            end
        end
    end
end

function Sound:Test()
    local file = (ns.db and ns.db.soundFile) or DEFAULT_SOUND
    PlaySoundFile(file, (ns.db and ns.db.soundChannel) or "Master")
end

-- ── Learn mode ─────────────────────────────────────────────────────────────
--
-- The spell IDs have to come from somewhere, and inventing them is worse than
-- having none: a wrong ID is a sound that never fires with nothing to say why.
--
-- So Salve can harvest them from your own play. Where an aura is READABLE --
-- open world, older content, anything Blizzard has not made private -- this
-- records the spell IDs it sees under the dispellable filter. Paste the result
-- into the companion addon.
--
-- ☠ EVERY READ IS GUARDED. issecretvalue turns "would throw" into "reads as
--   absent", which is the same fail-closed shape BuffReminders uses. A secret
--   is simply skipped; nothing is compared, indexed or measured.
-- ⚠ It will therefore learn nothing from current raid encounters, whose
--   debuffs are private. That is the whole reason the curated list exists.

local function plain(v)
    if issecretvalue and issecretvalue(v) then return nil end
    return v
end

function Sound:Learn(unit)
    if not (ns.db and ns.db.learnMode) then return end
    if not C_UnitAuras or not C_UnitAuras.GetAuraDataByIndex then return end

    for i = 1, 40 do
        local aura = plain(C_UnitAuras.GetAuraDataByIndex(unit, i, ns.DISPELLABLE_FILTER))
        if not aura then break end

        local id   = plain(aura.spellId)
        local name = plain(aura.name)
        if id and not ns.db.learned[id] then
            ns.db.learned[id] = name or true
            ns.Print(("learned |cffffd100%d|r  %s"):format(id, tostring(name or "?")))
            -- ☠ Debounced. Re-registering is 45 unit tokens times every known
            --   spell; doing that per aura seen would stall on a pull.
            self:ScheduleApply()
        end
    end
end

-- Prints the harvest in a form that can be pasted straight into the companion.
function Sound:DumpLearned()
    local ids = {}
    for id in pairs((ns.db and ns.db.learned) or {}) do ids[#ids + 1] = id end
    table.sort(ids)

    if #ids == 0 then
        ns.Print("nothing learned yet — turn learn mode on and play through some "
            .. "content whose debuffs are not private")
        return
    end

    ns.Print(("%d learned — these are already active; paste into "
        .. "Salve_SeasonData/Data.lua to share them:"):format(#ids))
    for _, id in ipairs(ids) do
        print(("    %d, -- %s"):format(id, tostring(ns.db.learned[id])))
    end
end

-- Coalesces a burst of discoveries into one re-registration.
local applyPending
function Sound:ScheduleApply()
    if applyPending then return end
    applyPending = true
    C_Timer.After(2, function()
        applyPending = false
        Sound:Apply()
    end)
end

-- ☠ UNIT_AURA is registered ONLY while learning. Salve's whole claim is that it
--   runs no aura handler; leaving one installed would quietly make that false.
function Sound:ToggleLearn(on)
    ns.db.learnMode = on and true or false

    local frame = _G.SalveEventFrame
    if not frame then return end

    if ns.db.learnMode then
        frame:RegisterEvent("UNIT_AURA")
        ns.Print("learn mode ON — play through content whose debuffs are not "
            .. "private, then |cffffd100/salve learned|r")
    else
        frame:UnregisterEvent("UNIT_AURA")
        ns.Print("learn mode off")
    end
end
