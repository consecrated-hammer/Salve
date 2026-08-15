local addonName, ns = ...

-- Single namespace table, exposed for the options companion and for anyone
-- poking at it from a macro. AllowAddOnTableAccess in the TOC makes this legal.
_G.Salve = ns

ns.name    = addonName
ns.VERSION = "0.1.0"

-- The four dispel schools, in the order the options UI lists them.
ns.DISPEL_TYPES = { "Magic", "Curse", "Disease", "Poison" }

-- Blizzard's filter for "harmful, and I personally can remove it". Class- and
-- spec-aware, resolved engine-side. This single string replaces every
-- can-I-dispel-this table an addon used to need.
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
