local addonName, ns = ...

-- ============================================================
-- Movement-impairing effects, and what removes them
-- ============================================================
-- Salve's dispel path rests on RAID_PLAYER_DISPELLABLE, which is defined by
-- dispelName -- Magic, Curse, Disease, Poison. Roots and snares mostly have NO
-- dispelName, so that filter never returns them and the panel is structurally
-- blind to a whole category of thing you can actually fix.
--
-- ☠ THERE IS NO ENGINE FILTER FOR "ROOTED". Blizzard exposes no
--   RAID_PLAYER_ROOTED, so this category can only be driven by a curated list
--   of spell IDs fed to AddAuraSlot's candidateFilters.includeSpellIDs. That is
--   a general mechanism they do provide; we are just using it for a category
--   they did not pre-package.
--
-- SCOPE IS THE INTERESTING PART. Some answers are castable on an ally
-- (Blessing of Freedom); most are personal (Blink). A personal escape is still
-- worth showing -- on YOUR OWN cell only, as "you can get out of this" -- but
-- it must never light someone else's cell, because you cannot help them.
--
-- ☠ THE LIST BELOW IS CANDIDATES, NOT TRUTH. Several entries are mobility
--   rather than a true removal, and some are talent-gated. Which ones count is
--   a judgement about your own play, so nothing here is enabled until you pick
--   it in the options. That is deliberate: it keeps Salve from asserting things
--   about your class that it cannot verify.

ns.Escape = {}
local Escape = ns.Escape

ns.ESCAPE_ALLY = "ALLY"   -- castable on another group member
ns.ESCAPE_SELF = "SELF"   -- personal; lights your own cell only

-- id, scope, and a note shown in the options so the choice is informed.
ns.ESCAPE_SPELLS = {
    PALADIN = {
        { id = 1044,   scope = "ALLY", note = "Removes and prevents movement impairment." },
        { id = 1022,   scope = "ALLY", note = "Blessing of Protection — physical effects." },
    },
    MONK = {
        { id = 116841, scope = "ALLY", note = "Tiger's Lust — removes movement impairment." },
    },
    HUNTER = {
        { id = 54216,  scope = "ALLY", note = "Master's Call — needs a pet out." },
    },
    MAGE = {
        { id = 1953,   scope = "SELF", note = "Blink — breaks roots and snares." },
        { id = 212653, scope = "SELF", note = "Shimmer — replaces Blink if talented." },
        { id = 45438,  scope = "SELF", note = "Ice Block — clears everything, but it is a major cooldown." },
    },
    DEATHKNIGHT = {
        { id = 212552, scope = "SELF", note = "Wraith Walk — removes movement impairment." },
        { id = 48265,  scope = "SELF", note = "Death's Advance — passive resistance if talented." },
    },
    DRUID = {
        { id = 783,    scope = "SELF", note = "Travel Form — shifting breaks roots." },
        { id = 768,    scope = "SELF", note = "Cat Form — shifting breaks roots." },
    },
    SHAMAN = {
        { id = 58875,  scope = "SELF", note = "Spirit Walk — Enhancement only." },
        { id = 2645,   scope = "SELF", note = "Ghost Wolf — breaks snares with the right talent." },
    },
    WARLOCK = {
        { id = 48020,  scope = "SELF", note = "Demonic Circle: Teleport — needs a circle down." },
    },
    DEMONHUNTER = {
        { id = 195072, scope = "SELF", note = "Fel Rush." },
        { id = 198793, scope = "SELF", note = "Vengeful Retreat." },
    },
    ROGUE = {
        { id = 36554,  scope = "SELF", note = "Shadowstep — needs a target." },
        { id = 2983,   scope = "SELF", note = "Sprint — speed, not a removal." },
    },
    WARRIOR = {
        { id = 6544,   scope = "SELF", note = "Heroic Leap." },
    },
    EVOKER = {
        { id = 358267, scope = "SELF", note = "Hover — flight, not a removal." },
    },
    PRIEST = {},   -- no reliable movement-impairment break
}

-- ── What this character has ────────────────────────────────────────────────

ns.knownEscapes = {}

local function known(spellID)
    if IsPlayerSpell and IsPlayerSpell(spellID) then return true end
    if IsSpellKnown and IsSpellKnown(spellID) then return true end
    return false
end

local function nameOf(spellID)
    if C_Spell and C_Spell.GetSpellInfo then
        local info = C_Spell.GetSpellInfo(spellID)
        return info and info.name
    end
end

-- Rebuilt on spec change like the dispel list. Returns true when it changed.
function Escape:Update()
    local _, class = UnitClass("player")
    local candidates = ns.ESCAPE_SPELLS[class] or {}

    local before = #ns.knownEscapes
    local list = {}

    for _, entry in ipairs(candidates) do
        if known(entry.id) then
            local name = nameOf(entry.id)
            if name then
                list[#list + 1] = {
                    id = entry.id, name = name,
                    scope = entry.scope, note = entry.note,
                }
            end
        end
    end

    ns.knownEscapes = list
    return #list ~= before
end

-- Only the ones you have ticked. Nothing is on by default -- see the header.
function Escape:Enabled()
    local chosen = (ns.db and ns.db.escapes) or {}
    local out = {}
    for _, s in ipairs(ns.knownEscapes) do
        if chosen[s.id] then out[#out + 1] = s end
    end
    return out
end

-- Does anything you have selected work on someone else?
function Escape:HasAllyEscape()
    for _, s in ipairs(self:Enabled()) do
        if s.scope == ns.ESCAPE_ALLY then return true end
    end
    return false
end

function Escape:Active()
    return #self:Enabled() > 0
end

-- ── The debuffs it applies to ──────────────────────────────────────────────
--
-- Sources register root/snare spell IDs the same way they register dispellable
-- ones, so a season data addon can carry both.
--
-- ⚠ CURATED DATA IS THIN HERE AND THAT IS EXPECTED. Blizzard's journal only
--   describes BOSS abilities, and dungeon roots and snares come overwhelmingly
--   from TRASH, which the journal does not cover at all -- a DB2 join over the
--   whole Season 1 and Season 2 pool yields three spells. Learn mode is the
--   real source for this category, and unlike encounter debuffs it works:
--   private auras are an encounter-mechanic measure, and trash snares are not
--   private. So this list fills in by playing.

Escape.sources = {}

function Escape:RegisterMovement(source, spellIDs)
    if type(source) ~= "string" or type(spellIDs) ~= "table" then return false end
    local set = {}
    for _, id in ipairs(spellIDs) do
        if type(id) == "number" then set[id] = true end
    end
    self.sources[source] = set
    if ns.RequestRebuildSoon then ns.RequestRebuildSoon(0.05) end
    return true
end

-- Everything registered, plus everything learned. Used as
-- candidateFilters.includeSpellIDs on the movement slot.
function Escape:AllSpellIDs()
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
    for id in pairs((ns.learned and ns.learned.movement) or {}) do add(id) end
    return list
end

-- ── Capture ────────────────────────────────────────────────────────────────
--
-- Aura data itself does not carry the mechanic. Blizzard's loss-of-control
-- feed does: LOSS_OF_CONTROL_ADDED identifies the affected group unit and its
-- effect index, while C_LossOfControl supplies the ROOT/SNARE type and spell
-- ID. That is the automatic learning path used here; guessing from every
-- non-dispellable aura would fill the list with harmless effects.
--
-- Learning mode captures roots and snares automatically, including on group
-- members, from that loss-of-control feed.
local function capture(id, name)
    if type(id) ~= "number" or ns.learned.movement[id] then return false end
    ns.learned.movement[id] = type(name) == "string" and name or true
    ns.Print(("captured |cffffd100%d|r  %s"):format(id, tostring(name or "?")))
    if ns.RequestRebuildSoon then ns.RequestRebuildSoon(0.05) end
    return true
end

function Escape:CaptureLossOfControl(unit, effectIndex)
    if not (ns.db and ns.db.learnMode and C_LossOfControl) then return false end
    if type(effectIndex) ~= "number" then return false end

    local getter = C_LossOfControl.GetActiveLossOfControlDataByUnit
    local ok, data
    if getter and type(unit) == "string" then
        ok, data = pcall(getter, unit, effectIndex)
    elseif unit == "player" and C_LossOfControl.GetActiveLossOfControlData then
        ok, data = pcall(C_LossOfControl.GetActiveLossOfControlData, effectIndex)
    else
        return false
    end
    if not ok or type(data) ~= "table" then return false end

    local function plain(v)
        if issecretvalue and issecretvalue(v) then return nil end
        return v
    end
    local locType = plain(data.locType)
    if locType ~= "ROOT" and locType ~= "SNARE" then return false end

    ns.learned.movement = ns.learned.movement or {}
    return capture(plain(data.spellID), plain(data.displayText))
end

function Escape:DumpCaptured()
    local ids = {}
    for id in pairs((ns.learned and ns.learned.movement) or {}) do ids[#ids + 1] = id end
    table.sort(ids)
    if #ids == 0 then
        ns.Print("nothing captured yet — enable learning and keep playing")
        return
    end
    ns.Print(("%d captured, all active:"):format(#ids))
    for _, id in ipairs(ids) do
        print(("    %d, -- %s"):format(id, tostring(ns.learned.movement[id])))
    end
end
