-- ============================================================
-- Dispellable debuffs — current season
-- ============================================================
-- Spell IDs of debuffs Salve should sound an alert for. Salve registers each
-- with C_UnitAuras.AddAuraSound, the only route that works on the private auras
-- most encounter debuffs became in 12.1.
--
-- GENERATED, NOT HAND-WRITTEN. Source: wago.tools DB2, joining
-- JournalEncounterSection (encounter abilities) against SpellCategories
-- (DispelType), keeping only DispelType 1-4 -- Magic, Curse, Disease, Poison.
-- Every entry below is therefore a debuff the game itself classifies as
-- removable, not a guess about what looks dispellable.
--
-- ☠ NOTHING HERE IS INVENTED. If an ID is wrong the sound simply never fires,
--   which is indistinguishable from a broken addon -- so add IDs only from DB2
--   or from /salve learn, never from memory.
--
-- TO REFRESH FOR A NEW SEASON
--   Re-run the join with the new JournalInstance IDs. Salve itself does not
--   change; this file is the whole update, which is why it is its own addon.
--
-- Learn mode adds to this list at runtime and persists what it finds, so
-- anything missed here is picked up by playing.

local SPELL_IDS = {
    -- ── Altar of Fangs ──────────────────────────────────────
    -- Rav'i
    1296069, -- Regurgitate (Disease)

    -- ── Sporefall ───────────────────────────────────────────
    -- Rotmire
    1221714, -- Poison Burst (Poison)

    -- ── The Dreamrift ───────────────────────────────────────
    -- Chimaerus the Undreamt God
    1249017, -- Fearsome Cry (Magic)
    1257087, -- Consuming Miasma (Magic)

    -- ── The Venomous Abyss ──────────────────────────────────
    -- Entombed Sentinels
    1284471, -- Blighted Blood (Magic)
    -- Vashnik the Malignant
    1295173, -- Exploding Infection (Magic)
    -- Ula'tek
    1287036, -- Poisonous Bite (Poison)
    1301800, -- Acidic Burst (Poison)
    1305650, -- Anguished Cry (Magic)

    -- ── The Voidspire ───────────────────────────────────────
    -- Imperator Averzian
    1275059, -- Black Miasma (Curse)
    -- Vorasius
    1259186, -- Blisterburst (Magic)
    1272527, -- Creep Spit (Magic)
    -- Lightblinded Vanguard
    1258514, -- Blinding Light (Magic)
    -- Crown of the Cosmos
    1233865, -- Null Corona (Magic)
    1261531, -- Corrupting Essence (Magic)

    -- ⚠ March on Quel'Danas returned no dispellable abilities from the journal
    --   data. That may be correct, or its encounters may not be linked in DB2
    --   yet. Worth confirming in game with /salve learn.
}

-- Salve is a RequiredDeps, so its API exists by the time this runs. Guarded
-- anyway: a missing API should disable the sound, not throw.
if Salve and Salve.Sound and Salve.Sound.RegisterDebuffs then
    Salve.Sound:RegisterDebuffs("Salve_SeasonData", SPELL_IDS)
end
