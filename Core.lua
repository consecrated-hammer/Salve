local addonName, ns = ...

-- Single namespace table, exposed for the options companion and for anyone
-- poking at it from a macro. AllowAddOnTableAccess in the TOC makes this legal.
_G.Salve = ns

ns.name    = addonName
function ns.GetMetadata(key)
    if C_AddOns and C_AddOns.GetAddOnMetadata then
        return C_AddOns.GetAddOnMetadata(addonName, key)
    end
    return GetAddOnMetadata and GetAddOnMetadata(addonName, key)
end

ns.VERSION = ns.GetMetadata("Version") or "1.5.15-dev7"
-- Development revision for distinguishing synced installs that share the same
-- release version. Surface this in /salve debug before debugging live code.
ns.REVISION = "1.5.15-dev7"

-- The four dispel schools, in the order the options UI lists them.
ns.DISPEL_TYPES = { "Magic", "Curse", "Disease", "Poison" }

-- A lit normal-dispel cell is a promise that the character can answer the
-- aura. AuraBinding uses Blizzard's per-character dispellable classification;
-- strict movement spell-ID matching is unavailable for friendly unit frames.
ns.DISPELLABLE_FILTER = "HARMFUL|RAID_PLAYER_DISPELLABLE"

function ns.Print(msg)
    print("|cff66ddaaSalve:|r " .. tostring(msg or ""))
end

-- Deferred work ------------------------------------------------------------
-- Secure attributes and frame geometry may only be written outside combat.
-- Anything needing them while locked down queues here and replays on
-- PLAYER_REGEN_ENABLED. Engine-bound visuals never come through here: the
-- whole point of the binding is that they keep working in combat untouched.

local pending = false

-- Blizzard can briefly release ordinary combat lockdown while an encounter is
-- still active. AuraContainer creation remains unsafe in that window because
-- encounter auras are still secret. Treat both states as one structural lock:
-- the already-bound panel keeps working, and queued changes wait for the real
-- encounter boundary instead of replacing healthy containers with rejected
-- ones.
function ns.StructuralChangesUnsafe()
    if InCombatLockdown and InCombatLockdown() then return true end
    return IsEncounterInProgress and IsEncounterInProgress() and true or false
end

function ns.RequestRebuild()
    if ns.StructuralChangesUnsafe() then
        pending = true
        return
    end
    pending = false
    if ns.Panel and ns.Panel.Rebuild then
        ns.Panel:Rebuild()
    end
end

function ns.FlushPending()
    if pending then ns.RequestRebuild() end
end

-- Debounced rebuild, for settings rather than events.
--
-- ☠ A slider fires OnValueChanged on EVERY tick of a drag. Rebuilding straight
--   away meant one drag of the box-width slider in a raid tore down and rebuilt
--   an AuraContainer per member per tick -- and those frames are never
--   reclaimed by the client, so a single drag could strand thousands of them
--   for the rest of the session. Coalesce instead: only the value you settle on
--   costs anything.
local rebuildTimer

function ns.RequestRebuildSoon(delay)
    if rebuildTimer then rebuildTimer:Cancel() end
    rebuildTimer = C_Timer.NewTimer(delay or 0.3, function()
        rebuildTimer = nil
        ns.RequestRebuild()
    end)
end
