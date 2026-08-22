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

ns.VERSION = ns.GetMetadata("Version") or "1.4.0"
-- Development revision for distinguishing synced installs that share the same
-- release version. Surface this in /salve debug before debugging live code.
ns.REVISION = "1.4.0-settings12"

-- The four dispel schools, in the order the options UI lists them.
ns.DISPEL_TYPES = { "Magic", "Curse", "Disease", "Poison" }

-- Aura presence remains entirely engine-driven. The accompanying native
-- candidate filter in AuraBinding limits HARMFUL auras to the dispel schools
-- covered by this character's detected spells. This is broader and more
-- accurate than RAID_PLAYER_DISPELLABLE, whose internal raid flag omits some
-- manually curable dungeon and legacy auras.
ns.DISPELLABLE_FILTER = "HARMFUL"

function ns.Print(msg)
    print("|cff66ddaaSalve:|r " .. tostring(msg or ""))
end

-- Deferred work ------------------------------------------------------------
-- Secure attributes and frame geometry may only be written outside combat.
-- Anything needing them while locked down queues here and replays on
-- PLAYER_REGEN_ENABLED. Engine-bound visuals never come through here: the
-- whole point of the binding is that they keep working in combat untouched.

local pending = false

function ns.RequestRebuild()
    if InCombatLockdown() then
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
