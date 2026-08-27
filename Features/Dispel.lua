local addonName, ns = ...

-- ============================================================
-- What to CAST. Not what to detect.
-- ============================================================
-- Detection is entirely Blizzard's: AuraBinding hands the engine a HARMFUL
-- filter plus the dispel schools resolved here. This file works out both which
-- spell to put on the secure button and which schools its native candidate
-- filter should include.
--
-- ☠ THE CANDIDATE FILTER IS BROADER THAN ANY SINGLE SPELL. It covers everything the
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
        -- Improved Purify is a hidden passive, so it must be checked
        -- separately from the active spellbook entry for Purify.
        { id = 527,    Magic = true, upgrades = {
            { id = 390632, Disease = true },                          -- Improved Purify
        } },                                                           -- Purify
        { id = 213634,                              Disease = true },  -- Purify Disease
    },
    DRUID = {
        { id = 88423,  Magic = true, upgrades = {
            { id = 392378, Poison = true, Curse = true },              -- Improved Nature's Cure
        } },                                                           -- Nature's Cure
        { id = 2782,                 Poison = true, Curse = true },    -- Remove Corruption
    },
    SHAMAN = {
        { id = 77130,  Magic = true, upgrades = {
            { id = 383016,                Curse = true },              -- Improved Purify Spirit
        } },                                                           -- Purify Spirit
        { id = 51886,                               Curse = true },    -- Cleanse Spirit
    },
    MONK = {
        { id = 115450, Magic = true, upgrades = {
            { id = 388874, Poison = true, Disease = true },            -- Improved Detox
        } },                                                           -- Detox (Mistweaver)
        { id = 218164,               Poison = true, Disease = true },  -- Detox
    },
    EVOKER = {
        { id = 360823, Magic = true, Poison = true },                  -- Naturalize
        { id = 365585,               Poison = true },                  -- Expunge
        -- ☠ Cauterizing Flame is the reason this file resolves two spells.
        --   It is available alongside Naturalize, covers schools Naturalize
        --   cannot, and the engine filter counts it. `limited` keeps it OFF
        --   left click: it is on a long cooldown, so making it the primary --
        --   which raw coverage counting would -- means routine Poison cleansing
        --   spends it and then fails, while Naturalize sits unused on the other
        --   button.
        { id = 374251, Poison = true, Curse = true, Disease = true, limited = true },
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

-- IsPlayerSpell / IsSpellKnown can include abilities exposed for another
-- specialization. That is useful for passive talent checks below, but it is
-- unsafe for a secure click-to-cast button. Retail's player spellbook marks
-- those entries as isOffSpec, so build a current-spec castable set when that
-- API is available and retain the legacy check only for older clients.
local function activeSpellbook()
    if not (C_SpellBook and C_SpellBook.GetNumSpellBookSkillLines
        and C_SpellBook.GetSpellBookSkillLineInfo and C_SpellBook.GetSpellBookItemInfo
        and Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player) then
        return nil
    end

    local ok, lineCount = pcall(C_SpellBook.GetNumSpellBookSkillLines)
    if not ok or type(lineCount) ~= "number" then return nil end

    local spells = {}
    local spellType = Enum.SpellBookItemType and Enum.SpellBookItemType.Spell
    for lineIndex = 1, math.min(lineCount, 128) do
        local lineOK, lineInfo = pcall(C_SpellBook.GetSpellBookSkillLineInfo, lineIndex)
        local offset = lineOK and lineInfo and tonumber(lineInfo.itemIndexOffset)
        local count = lineOK and lineInfo and tonumber(lineInfo.numSpellBookItems)
        if offset and count and count > 0 then
            for itemOffset = 1, math.min(count, 1024) do
                local itemOK, item = pcall(C_SpellBook.GetSpellBookItemInfo,
                    offset + itemOffset, Enum.SpellBookSpellBank.Player)
                local isSpell = itemOK and type(item) == "table"
                    and (spellType == nil and type(item.spellID) == "number"
                        or item.itemType == spellType)
                if isSpell and item.isOffSpec ~= true and type(item.spellID) == "number" then
                    spells[item.spellID] = true
                end
            end
        end
    end
    return spells
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
    for _, upgrade in ipairs(entry.upgrades or {}) do
        if known(upgrade.id) then
            for _, t in ipairs(ns.DISPEL_TYPES) do
                if upgrade[t] and not set[t] then set[t] = true n = n + 1 end
            end
        end
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

    -- Everything the character actually has. Exposed so the options panel can
    -- offer the real list rather than a guess.
    local castable = activeSpellbook()
    local available = {}
    ns.knownDispels = available
    for _, entry in ipairs(list) do
        if (castable and castable[entry.id]) or (not castable and known(entry.id)) then
            local name = nameOf(entry.id)
            if name then
                local set, n = coverage(entry)
                available[#available + 1] = {
                    id = entry.id, name = name, cures = set, count = n,
                    limited = entry.limited,
                }
            end
        end
    end

    -- Primary: the broadest REPEATABLE dispel.
    --
    -- ☠ Coverage alone is the wrong measure. A cooldown-limited spell can cover
    --   more schools than the spammable one and still be the wrong thing to put
    --   on the button you press every few seconds -- you spend it on a routine
    --   debuff and then have nothing when the school it uniquely covers lands.
    --   Repeatability first, then coverage.
    local best
    for _, s in ipairs(available) do
        if not s.limited and (not best or s.count > best.count) then best = s end
    end

    -- Only fall back to a cooldown spell if it is genuinely all there is.
    if not best then
        for _, s in ipairs(available) do
            if not best or s.count > best.count then best = s end
        end
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

-- "Magic, Poison" for the options panel and the probe.
function ns.CuresText(cures)
    local parts = {}
    for _, t in ipairs(ns.DISPEL_TYPES) do
        if cures and cures[t] then parts[#parts + 1] = t end
    end
    if #parts == 0 then return "nothing" end
    return table.concat(parts, ", ")
end
