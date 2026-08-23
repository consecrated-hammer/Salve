local function equal(actual, expected, label)
    if actual ~= expected then
        error(("%s: expected %s, got %s"):format(label, tostring(expected), tostring(actual)))
    end
end

local combatLocked = false
local encounterActive = false
local rebuilds = 0

InCombatLockdown = function() return combatLocked end
IsEncounterInProgress = function() return encounterActive end
C_AddOns = {
    GetAddOnMetadata = function(_, key)
        return key == "Version" and "1.4.2" or nil
    end,
}

local ns = {
    Panel = {
        Rebuild = function() rebuilds = rebuilds + 1 end,
    },
}

assert(loadfile("Core.lua"))("Salve", ns)

ns.RequestRebuild()
equal(rebuilds, 1, "ordinary out-of-combat rebuild runs immediately")

encounterActive = true
equal(ns.StructuralChangesUnsafe(), true,
    "active encounter remains structurally locked outside combat")
ns.RequestRebuild()
equal(rebuilds, 1, "encounter-time rebuild is deferred")
ns.FlushPending()
equal(rebuilds, 1, "pending rebuild stays queued while encounter is active")

encounterActive = false
ns.FlushPending()
equal(rebuilds, 2, "queued rebuild runs after encounter ends")

combatLocked = true
equal(ns.StructuralChangesUnsafe(), true, "ordinary combat remains locked")

print("core tests passed")
