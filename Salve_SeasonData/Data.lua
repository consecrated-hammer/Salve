-- ============================================================
-- Dispellable debuffs — current season
-- ============================================================
-- Spell IDs of debuffs worth an audible alert. Salve registers each with
-- C_UnitAuras.AddAuraSound, which is the only route that works on the private
-- auras most encounter debuffs became in 12.1.
--
-- ☠ ONLY LIST DEBUFFS YOU CAN ACTUALLY DISPEL. A wrong or undispellable ID is
--   not a harmless extra: it is a sound that fires when you can do nothing
--   about it, or one that never fires with nothing to say why.
--
-- HOW TO FIND IDS
--   1. /salve learn        turn harvesting on
--   2. play                Salve records dispellable debuffs it can read
--   3. /salve learned      prints them ready to paste below
--
--   Learn mode reads auras only where the game permits it, so it will find
--   nothing in a current raid -- those debuffs are private, which is precisely
--   why this file exists. For those, take the ID from Wowhead's journal entry
--   for the ability and confirm the debuff type is one you can remove.
--
-- The list is deliberately EMPTY rather than seeded with guesses. An invented
-- ID is worse than a missing one: it fails silently and looks like a bug in the
-- addon rather than a gap in the data.

local SPELL_IDS = {
    -- ── Dungeons ───────────────────────────────────────────────────────────
    -- 1257085, -- Consuming Miasma (stage 1) — UNVERIFIED, from a BigWigs
    -- 1257087, -- Consuming Miasma (stage 2) — comment marked "(Dispels)".
    --             Confirm the school is one you can remove before enabling.

    -- ── Raid ───────────────────────────────────────────────────────────────
}

-- Salve is a RequiredDeps, so it is loaded and its API exists by the time this
-- file runs. Guarded anyway: a missing API should disable the sound, not throw.
if Salve and Salve.Sound and Salve.Sound.RegisterDebuffs then
    Salve.Sound:RegisterDebuffs("Salve_SeasonData", SPELL_IDS)
end
