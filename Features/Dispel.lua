local addonName, ns = ...

-- ============================================================
-- What to CAST. Not what to detect.
-- ============================================================
-- Detection is entirely Blizzard's: ns.DISPELLABLE_FILTER already means
-- "debuffs this character can remove", resolved engine-side. This file only
-- works out which spell to put on the secure button.
--
-- ☠ THE FILTER IS BROADER THAN ANY SINGLE SPELL. It covers everything the
--   character can remove across EVERY dispel they know. A Preservation Evoker
--   with Cauterizing Flame gets Curse and Disease boxes lit, and Naturalize
--   cannot touch either. Picking one spell and hoping meant the panel promised
--   dispels the button could not deliver -- lit boxes that fizzle.
--
-- So we resolve a PRIMARY (the broadest single dispel known) and, when the
-- class has a second spell covering schools the primary misses, a SECONDARY
-- bound to right click. Between them they cover everything the filter can
-- light, and the box's colour tells you which button you want.

local SPELLS = {
    PALADIN = {
        { id = 4987,   Magic = true, Poison = true, Disease = true },  -- Cleanse
        { id = 213644,               Poison = true, Disease = true },  -- Cleanse Toxins
    },
    PRIEST = {
        { id = 527,    Magic = true,                Disease = true },  -- Purify
        { id = 213634,                              Disease = true },  -- Purify Disease
    },
    DRUID = {
        { id = 88423,  Magic = true, Poison = true, Curse = true },    -- Nature's Cure
        { id = 2782,                 Poison = true, Curse = true },    -- Remove Corruption
    },
    SHAMAN = {
        { id = 77130,  Magic = true,                Curse = true },    -- Purify Spirit
        { id = 51886,                               Curse = true },    -- Cleanse Spirit
    },
    MONK = {
        { id = 115450, Magic = true, Poison = true, Disease = true },  -- Detox (Mistweaver)
        { id = 218164,               Poison = true, Disease = true },  -- Detox
    },
    EVOKER = {
        { id = 360823, Magic = true, Poison = true },                  -- Naturalize
        { id = 365585,               Poison = true },                  -- Expunge
        -- ☠ Cauterizing Flame is the reason this file resolves two spells.
        --   It is available alongside Naturalize, covers schools Naturalize
        --   cannot, and the engine filter counts it.
        { id = 374251, Poison = true, Curse = true, Disease = true },  -- Cauterizing Flame
    },
    MAGE = {
        { id = 475,                                 Curse = true },    -- Remove Curse
    },
}

ns.spellID      = nil   -- primary, on left click
ns.spellName    = nil
ns.primaryCures = {}

ns.secondaryID    = nil -- covers what the primary cannot, on right click
ns.secondaryName  = nil
ns.secondaryCures = {}

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

local function coverage(entry)
    local set, n = {}, 0
    for _, t in ipairs(ns.DISPEL_TYPES) do
        if entry[t] then set[t] = true n = n + 1 end
    end
    return set, n
end

-- Returns true when either selection changed, so callers know to rebuild.
function ns.UpdateDispelSpell()
    local _, class = UnitClass("player")
    local list = SPELLS[class]

    local oldPrimary, oldSecondary = ns.spellID, ns.secondaryID

    ns.spellID, ns.spellName, ns.primaryCures      = nil, nil, {}
    ns.secondaryID, ns.secondaryName, ns.secondaryCures = nil, nil, {}

    if not list then
        return oldPrimary ~= nil or oldSecondary ~= nil
    end

    -- Everything the character actually has.
    local available = {}
    for _, entry in ipairs(list) do
        if known(entry.id) then
            local name = nameOf(entry.id)
            if name then
                local set, n = coverage(entry)
                available[#available + 1] =
                    { id = entry.id, name = name, cures = set, count = n }
            end
        end
    end

    -- Primary: the broadest. Ties go to the earlier entry, which is the
    -- spec-appropriate one in every table above.
    local best
    for _, s in ipairs(available) do
        if not best or s.count > best.count then best = s end
    end
    if not best then
        return oldPrimary ~= nil or oldSecondary ~= nil
    end

    ns.spellID, ns.spellName, ns.primaryCures = best.id, best.name, best.cures

    -- Secondary: whichever known spell adds the most schools the primary
    -- misses. Nil for every class whose one dispel already covers its range,
    -- which is most of them.
    local bestExtra, bestGain = nil, 0
    for _, s in ipairs(available) do
        if s.id ~= best.id then
            local gain = 0
            for t in pairs(s.cures) do
                if not best.cures[t] then gain = gain + 1 end
            end
            if gain > bestGain then bestExtra, bestGain = s, gain end
        end
    end

    if bestExtra then
        ns.secondaryID    = bestExtra.id
        ns.secondaryName  = bestExtra.name
        ns.secondaryCures = bestExtra.cures
    end

    return ns.spellID ~= oldPrimary or ns.secondaryID ~= oldSecondary
end

function ns.CanDispel()
    return ns.spellName ~= nil
end

-- Human-readable "Magic, Poison" for the options panel.
function ns.CuresText(cures)
    local parts = {}
    for _, t in ipairs(ns.DISPEL_TYPES) do
        if cures[t] then parts[#parts + 1] = t end
    end
    if #parts == 0 then return "nothing" end
    return table.concat(parts, ", ")
end
