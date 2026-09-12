local function equal(actual, expected, label)
    if actual ~= expected then
        error(("%s: expected %s, got %s"):format(label, tostring(expected), tostring(actual)))
    end
end

local handler
local registered = {}
local unitRegistrations = {}
local timers = {}
local refreshes = 0
local movementRefreshes = 0
local previewStops = 0
local optionsRefreshes = 0
local rebuilds = 0
local dispelRefreshes = 0
local pendingFlushes = 0
local movementWarnings = 0
local movementTextAlerts = 0
local selfAlertUpdates = 0

CreateFrame = function()
    return {
        SetScript = function(_, script, callback)
            if script == "OnEvent" then handler = callback end
        end,
        RegisterEvent = function(_, event)
            registered[event] = true
        end,
        RegisterUnitEvent = function(_, event, unit)
            unitRegistrations[event] = unit
        end,
    }
end

C_Timer = {
    After = function(delay, callback)
        timers[#timers + 1] = { delay = delay, callback = callback }
    end,
}

local ns = {
    UpdateDispelSpell = function() return false end,
    Escape = {
        Update = function() return true end,
        CaptureLossOfControl = function(_, unit, index)
            if index == 5 then return false, false, nil end
            return false, unit == "player" and index == 4,
                { locType = "ROOT" }
        end,
        CanWarnForUnit = function(_, unit) return unit == "player" end,
        UniversalMovementAlertSpell = function(_, unit, movement)
            if movement and movement.locType == "ROOT" and (unit == "player" or unit == "party1") then
                return { id = 1044, name = "Blessing of Freedom" }
            end
        end,
    },
    Options = {
        RefreshDispel = function() optionsRefreshes = optionsRefreshes + 1 end,
        RefreshTroubleshooting = function() end,
    },
    Sound = {
        OnDispelChanged = function() dispelRefreshes = dispelRefreshes + 1 end,
        FlushPending = function() pendingFlushes = pendingFlushes + 1 end,
        PlayMovementWarning = function() movementWarnings = movementWarnings + 1 end,
    },
    MovementAlert = {
        Notify = function(_, unit, movement, spell)
            equal(spell.id, 1044, "movement text uses Freedom")
            movementTextAlerts = movementTextAlerts + 1
        end,
    },
    SelfAlert = {
        Update = function() selfAlertUpdates = selfAlertUpdates + 1 end,
    },
    RequestRebuild = function() rebuilds = rebuilds + 1 end,
    FlushPending = function() pendingFlushes = pendingFlushes + 1 end,
    Binding = {
        ObserveMovementCast = function(_, unit, spellID)
            return unit == "player" and spellID == 1044 and spellID or nil
        end,
        ObserveDispelCast = function(_, unit, spellID)
            return unit == "player" and spellID == 4987
        end,
        RefreshCooldowns = function() refreshes = refreshes + 1 end,
        RefreshMovementCooldowns = function(_, _, spellID)
            equal(spellID, 1044, "movement cooldown receives the spell that was cast")
            movementRefreshes = movementRefreshes + 1
        end,
    },
    Preview = {
        Stop = function() previewStops = previewStops + 1 end,
    },
}

assert(loadfile("Core/Events.lua"))("Salve", ns)

equal(unitRegistrations.UNIT_SPELLCAST_SUCCEEDED, "player",
    "cast-success event registered as a unit event")
equal(unitRegistrations.UNIT_PET, "player",
    "pet-change registration is player-only")
equal(registered.SPELL_UPDATE_COOLDOWN, nil,
    "global cooldown update event remains unregistered")
equal(registered.PLAYER_REGEN_DISABLED, true,
    "combat start is registered to close preview safely")
equal(registered.ENCOUNTER_END, true,
    "encounter end is registered to release structural rebuilds")
equal(registered.UNIT_PET, nil,
    "pet changes use the player-only unit subscription")
equal(registered.COMBAT_LOG_EVENT_UNFILTERED, nil,
    "shared event router never subscribes to high-volume combat-log traffic")

handler(nil, "PLAYER_REGEN_DISABLED")
equal(previewStops, 1, "combat start closes live panel preview")

handler(nil, "ENCOUNTER_END")
equal(pendingFlushes, 0, "encounter-end rebuild waits for engine state to settle")
equal(#timers, 1, "encounter end schedules one deferred structural flush")
timers[1].callback()
equal(pendingFlushes, 2,
    "encounter end releases queued sound and panel structural work")

handler(nil, "SPELLS_CHANGED")
equal(optionsRefreshes, 1,
    "escape-only spell discovery refreshes the Dispels page immediately")
equal(dispelRefreshes, 0,
    "escape-only spell discovery does not rebuild sound registrations")
equal(rebuilds, 1, "escape-only spell discovery rebuilds the panel")
equal(selfAlertUpdates, 1, "spell discovery refreshes the self-dispel listener")

handler(nil, "UNIT_PET", "party1")
equal(rebuilds, 1, "another unit's pet does not change the player's dispels")
handler(nil, "UNIT_PET", "player")
equal(rebuilds, 2, "the player's pet change refreshes Imp-only dispels")

handler(nil, "UNIT_SPELLCAST_SUCCEEDED", "player", "cast-guid", 4987)
equal(refreshes, 0, "dispel cooldown is not read inside the early cast event")
equal(#timers, 2, "successful player dispel schedules one deferred refresh")
equal(timers[2].delay, 0, "dispel refresh waits one event-loop tick")
timers[2].callback()
equal(refreshes, 1, "deferred dispel refresh reaches cooldown widgets")

handler(nil, "UNIT_SPELLCAST_SUCCEEDED", "player", "cast-guid", 12345)
equal(#timers, 2, "ordinary player casts do not schedule a GCD sweep")

handler(nil, "UNIT_SPELLCAST_SUCCEEDED", "player", "cast-guid", 1044)
equal(#timers, 3, "movement removal schedules one deferred border-sweep refresh")
timers[3].callback()
equal(movementRefreshes, 1, "movement removal refreshes border-sweep widgets")

handler(nil, "UNIT_SPELLCAST_SUCCEEDED", "party1", "cast-guid", 4987)
equal(#timers, 3, "another unit's dispel does not schedule a sweep")

handler(nil, "LOSS_OF_CONTROL_ADDED", "player", 4)
equal(movementWarnings, 1, "player movement impairment plays one warning")
equal(movementTextAlerts, 1, "player movement impairment receives Freedom text")
handler(nil, "LOSS_OF_CONTROL_ADDED", "party1", 4)
equal(movementWarnings, 1, "party movement is ignored")
equal(movementTextAlerts, 1, "party movement produces no text")
handler(nil, "LOSS_OF_CONTROL_ADDED", "party1", 5)
equal(movementWarnings, 1, "non-movement loss of control never triggers Freedom")
equal(movementTextAlerts, 1, "non-movement loss of control emits no Freedom text")

print("event routing tests passed")
