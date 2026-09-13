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
ns.ESCAPE_AREA = "AREA"   -- ground-area group utility; place it near allies

-- id, scope, and a note shown in the options so the choice is informed.
ns.ESCAPE_SPELLS = {
    PALADIN = {
        { id = 1044,   scope = "ALLY", universalMovement = true,
            note = "Removes and prevents movement impairment." },
        { id = 1022,   scope = "ALLY", note = "Blessing of Protection — physical effects." },
        { id = 642,    scope = "SELF", note = "Divine Shield — emergency self-clear; causes Forbearance." },
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
        { id = 235450, scope = "SELF", requires = 386828,
            note = "Prismatic Barrier — Energized Barriers removes snares." },
        { id = 235313, scope = "SELF", requires = 386828,
            note = "Blazing Barrier — Energized Barriers removes snares." },
        { id = 11426,  scope = "SELF", requires = 386828,
            note = "Ice Barrier — Energized Barriers removes snares." },
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
        { id = 192077, scope = "AREA", requires = 462817,
            note = "Wind Rush Totem — Jet Stream removes snares for allies in its area." },
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

    local before = ns.knownEscapes
    local list = {}

    for _, entry in ipairs(candidates) do
        if known(entry.id) and (not entry.requires or known(entry.requires)) then
            local name = nameOf(entry.id)
            if name then
                list[#list + 1] = {
                    id = entry.id, name = name,
                    scope = entry.scope, universalMovement = entry.universalMovement,
                    note = entry.note,
                }
            end
        end
    end

    ns.knownEscapes = list
    if #list ~= #before then return true end
    for i, spell in ipairs(list) do
        if not before[i] or before[i].id ~= spell.id then return true end
    end
    return false
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
        if s.scope == ns.ESCAPE_ALLY or s.scope == ns.ESCAPE_AREA then return true end
    end
    return false
end

function Escape:Active()
    return #self:Enabled() > 0
end

-- The movement cooldown indicator follows the first enabled removal in the
-- options order. This is normally the only enabled spell (for example,
-- Blessing of Freedom); keeping it deterministic also makes its sweep
-- meaningful when several candidate abilities are known.
function Escape:CooldownSpellID()
    local first = self:Enabled()[1]
    return first and first.id or nil
end

function Escape:SweepSpellIDs()
    local selected = ns.db and ns.db.movementSweepSpellIDs or {}
    local out = {}
    for _, spell in ipairs(self:Enabled()) do
        local keys = ns.Bindings and ns.Bindings:KeysForSpell(spell.id) or {}
        if selected[spell.id] and #keys > 0 then out[#out + 1] = spell.id end
    end
    return out
end

-- Compatibility for callers from older option builds. New rendering uses the
-- full list: separate clock-hand edges can coexist on one Salve cell.
function Escape:SweepSpellID()
    return self:SweepSpellIDs()[1]
end

function Escape:CanSweepForUnit(spellID, unit)
    for _, spell in ipairs(self:Enabled()) do
        if spell.id == spellID then
            return spell.scope == ns.ESCAPE_ALLY or spell.scope == ns.ESCAPE_AREA
                or self:IsPlayerUnit(unit)
        end
    end
    return false
end

function Escape:IsEnabledSpell(spellID)
    if type(spellID) ~= "number" then return false end
    for _, spell in ipairs(self:Enabled()) do
        if spell.id == spellID then return true end
    end
    return false
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

-- Only reviewed source data may drive the movement overlay. A ROOT/SNARE
-- classification is evidence that an effect impairs movement, not proof that
-- the selected escape removes it. Auto-captured observations stay in the
-- learned catalogue until reviewed and promoted into movement.csv.
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
    return list
end

function Escape:IsVerifiedMovement(spellID)
    if type(spellID) ~= "number" then return false end
    for _, set in pairs(self.sources) do
        if set[spellID] then return true end
    end
    return false
end

-- ── Capture ────────────────────────────────────────────────────────────────
--
-- Aura data itself does not carry the mechanic. Blizzard's loss-of-control
-- feed does: LOSS_OF_CONTROL_ADDED identifies the affected unit and its
-- effect index, while C_LossOfControl supplies the ROOT/SNARE type and spell
-- ID. That is the automatic learning path used here; guessing from every
-- non-dispellable aura would fill the list with harmless effects.
--
-- Learning and notifications use only the player's own API and events.
local function capture(id, name)
    if type(id) ~= "number" or ns.learned.movement[id] then return false end
    ns.learned.movement[id] = type(name) == "string" and name or true
    ns.Print(("captured |cffffd100%d|r  %s"):format(id, tostring(name or "?")))
    if ns.RequestRebuildSoon then ns.RequestRebuildSoon(0.05) end
    return true
end

function Escape:CaptureLossOfControl(unit, effectIndex)
    if unit ~= "player" then return false end
    self.lastCaptureStatus = "player event received"
    if not (ns.db and C_LossOfControl) then return false end
    if type(effectIndex) ~= "number" then return false end

    local getter = C_LossOfControl.GetActiveLossOfControlData
    if not getter then
        self.lastCaptureStatus = "player loss-of-control API unavailable"
        return false
    end
    local ok, data = pcall(getter, effectIndex)
    if not ok or type(data) ~= "table" then
        self.lastCaptureStatus = "player loss-of-control data unavailable"
        return false
    end

    local function plain(v)
        if issecretvalue and issecretvalue(v) then return nil end
        return v
    end
    local locType = plain(data.locType)
    if locType == nil then
        self.lastCaptureStatus = "movement classification unavailable or secret"
        return false, false
    end
    -- Loss-of-control entries are transient: by the time a player opens a
    -- diagnostic window, GetActiveLossOfControlData commonly returns nothing.
    -- Preserve the readable classification here so an unfamiliar hazard can
    -- be evaluated from a report without guessing from its dungeon or name.
    local spellID = plain(data.spellID)
    local displayText = plain(data.displayText)
    if locType ~= "ROOT" and locType ~= "SNARE" then
        local detail = tostring(locType)
        if type(spellID) == "number" then detail = detail .. ", spell " .. spellID end
        if type(displayText) == "string" and displayText ~= "" then
            detail = detail .. " (" .. displayText .. ")"
        end
        self.lastCaptureStatus = "not a root or snare: " .. detail
        return false, false
    end
    self.lastCaptureStatus = "player " .. locType .. " detected"

    ns.learned.movement = ns.learned.movement or {}
    local movement = {
        spellID = spellID,
        name = displayText,
        locType = locType,
    }
    -- The second result says the effect is reviewed for the live overlay and
    -- alert. It deliberately remains false for auto-captured discoveries.
    return capture(spellID, movement.name), self:IsVerifiedMovement(spellID), movement
end

function Escape:IsPlayerUnit(unit)
    if unit == "player" then return true end
    if type(unit) ~= "string" or not UnitIsUnit then return false end
    local ok, same = pcall(UnitIsUnit, unit, "player")
    return ok and same == true
end

-- Movement warnings are personal, even when the selected spell can target allies.
function Escape:CanWarnForUnit(unit)
    return unit == "player" and self:Active()
end

-- A broadly-worded warning needs a stronger promise than a curated spell-ID
-- match. Blessing of Freedom explicitly removes and prevents movement
-- impairment, so a ROOT or SNARE from Blizzard's loss-of-control feed is
-- enough to alert for the player. Other escapes keep the
-- reviewed-ID gate above: mobility is not proof it answers an arbitrary root.
function Escape:UniversalMovementAlertSpell(unit, movement)
    if unit ~= "player" then return nil end
    if not movement or (movement.locType ~= "ROOT" and movement.locType ~= "SNARE") then
        return nil
    end
    for _, spell in ipairs(self:Enabled()) do
        if spell.universalMovement then
            return spell
        end
    end
    return nil
end

function Escape:DumpCaptured()
    local ids = {}
    for id in pairs((ns.learned and ns.learned.movement) or {}) do ids[#ids + 1] = id end
    table.sort(ids)
    if #ids == 0 then
        ns.Print("nothing captured yet — keep playing content with roots or snares")
        return
    end
    ns.Print(("%d captured; review before activating:"):format(#ids))
    for _, id in ipairs(ids) do
        print(("    %d, -- %s"):format(id, tostring(ns.learned.movement[id])))
    end
end
