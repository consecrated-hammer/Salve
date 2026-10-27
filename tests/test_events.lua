local function equal(actual, expected, label)
    if actual ~= expected then
        error(("%s: expected %s, got %s"):format(label, tostring(expected), tostring(actual)))
    end
end

local handler, onUpdate
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
local movementPrompts = 0
local movementPromptClears = 0
local selfAlertUpdates = 0
local speedObservation
local activeControlIndex = 4
C_LossOfControl = { GetActiveLossOfControlDataCount = function() return 1 end }

CreateFrame = function()
    return {
        SetScript = function(_, script, callback)
            if script == "OnEvent" then handler = callback end
            if script == "OnUpdate" then onUpdate = callback end
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
            if index == 1 then index = activeControlIndex end
            if index == 5 then return false, false, nil end
            return false, unit == "player" and index == 4,
                { locType = "ROOT", spellID = index == 4 and 1234 or 2345 }
        end,
        MovementAlertSpell = function(_, unit, movement)
            if movement and (movement.locType == "ROOT" or movement.locType == "SLOW")
                and (unit == "player" or unit == "party1") then
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
    Panel = {
        SetMovementPrompt = function(_, spell, active)
            if not active then
                equal(spell, nil, "clearing a movement prompt has no spell")
                movementPromptClears = movementPromptClears + 1
                return
            end
            equal(spell.id, 1044, "movement prompt uses Freedom")
            equal(active, true, "movement prompt is enabled")
            movementPrompts = movementPrompts + 1
        end,
    },
    MovementDetection = {
        Reset = function() end,
        AcknowledgeRemoval = function() return { kind = "CLEAR" } end,
        Sample = function() return speedObservation end,
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
equal(registered.PLAYER_STARTED_MOVING, nil,
    "ground-speed detector does not depend on movement start events")
equal(registered.PLAYER_STOPPED_MOVING, nil,
    "ground-speed detector continues sampling while stationary")
equal(registered.UNIT_PET, nil,
    "pet changes use the player-only unit subscription")
equal(registered.COMBAT_LOG_EVENT_UNFILTERED, nil,
    "shared event router never subscribes to high-volume combat-log traffic")

handler(nil, "PLAYER_REGEN_DISABLED")
equal(previewStops, 1, "combat start closes live panel preview")

handler(nil, "PLAYER_LEAVING_WORLD")
equal(movementPrompts, 0, "leaving the world clears any player movement prompt before transfer speeds arrive")

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

local clearsBeforeMovementCast = movementPromptClears
handler(nil, "UNIT_SPELLCAST_SUCCEEDED", "player", "cast-guid", 1044)
equal(#timers, 3, "movement removal schedules one deferred border-sweep refresh")
equal(movementPromptClears, clearsBeforeMovementCast + 1,
    "using a movement action clears its orange cue even without an active speed alert")
timers[3].callback()
equal(movementRefreshes, 1, "movement removal refreshes border-sweep widgets")

handler(nil, "UNIT_SPELLCAST_SUCCEEDED", "party1", "cast-guid", 4987)
equal(#timers, 3, "another unit's dispel does not schedule a sweep")

handler(nil, "LOSS_OF_CONTROL_ADDED", "player", 4)
timers[#timers].callback()
equal(movementWarnings, 1, "player movement impairment plays one warning")
equal(movementTextAlerts, 1, "player movement impairment receives Freedom text")
equal(movementPrompts, 1, "player root receives the movement action prompt")
handler(nil, "LOSS_OF_CONTROL_ADDED", "party1", 4)
equal(movementWarnings, 1, "party movement is ignored")
equal(movementTextAlerts, 1, "party movement produces no text")
handler(nil, "LOSS_OF_CONTROL_ADDED", "party1", 5)
equal(movementWarnings, 1, "non-movement loss of control never triggers Freedom")
equal(movementTextAlerts, 1, "non-movement loss of control emits no Freedom text")

speedObservation = { kind = "SLOW", locType = "SLOW" }
onUpdate(nil, 0.15)
equal(movementWarnings, 1, "inferred speed observation never plays a movement warning")
equal(movementTextAlerts, 1, "inferred slows produce no text until opted in")
equal(movementPrompts, 1, "inferred slows leave the player cell unlit until opted in")
ns.db = { inferredSlowAlertsEnabled = true }
onUpdate(nil, 0.15)
equal(movementWarnings, 1, "opted-in inferred slow stays silent")
equal(movementTextAlerts, 2, "opted-in inferred slow uses the player text path")
equal(movementPrompts, 2, "opted-in inferred slow lights the player-cell cue")
ns.db = nil

handler(nil, "LOSS_OF_CONTROL_ADDED", "player", 3)
activeControlIndex = 3
timers[#timers].callback()
equal(movementWarnings, 1, "unreviewed loss-of-control effect stays silent despite a matching ability")
equal(movementPrompts, 2, "unreviewed loss-of-control effect stays unlit")
handler(nil, "LOSS_OF_CONTROL_ADDED", "player", 5)
equal(movementWarnings, 1, "missing loss-of-control data stays silent")
ns.Escape.MovementAlertSpell = function() return nil end
handler(nil, "LOSS_OF_CONTROL_ADDED", "player", 4)
activeControlIndex = 4
timers[#timers].callback()
equal(movementWarnings, 1, "verified effect without a matching enabled remedy stays silent")
equal(movementPrompts, 2, "no remedy means no orange cue either")
speedObservation = { kind = "CLEAR" }
onUpdate(nil, 0.15)
equal(movementWarnings, 1, "clearing movement state is silent")

local blocked = "player is not in control"
local clearedText = 0
ns.MovementDetection.ControlBlockReason = function() return blocked end
ns.MovementAlert.Clear = function() clearedText = clearedText + 1 end
ns.Escape.MovementAlertSpell = function(_, _, movement)
    if movement then return { id = 1044, name = "Blessing of Freedom" } end
end
local beforeText, beforeSound, beforePrompt = movementTextAlerts, movementWarnings, movementPrompts
speedObservation = { kind = "SLOW", locType = "SLOW" }
onUpdate(nil, 0.15)
handler(nil, "LOSS_OF_CONTROL_ADDED", "player", 4)
timers[#timers].callback()
equal(movementTextAlerts, beforeText, "incapacitation suppresses inferred and explicit movement text")
equal(movementWarnings, beforeSound, "incapacitation suppresses movement sound")
equal(movementPrompts, beforePrompt, "incapacitation suppresses the orange movement cue")
equal(clearedText >= 2, true, "incapacitation dismisses existing on-screen prompts")
blocked = nil
speedObservation = { kind = "RECHECK" }
onUpdate(nil, 0.15)
timers[#timers].callback()
equal(movementTextAlerts, beforeText + 1, "control recovery restores explicit root alerts")
equal(movementWarnings, beforeSound + 1, "a root outlasting fear regains its verified sound")
equal(movementPrompts, beforePrompt + 1, "a root outlasting fear regains its orange cue")

handler(nil, "LOSS_OF_CONTROL_ADDED", "player", 4)
blocked = "simultaneous fear"
timers[#timers].callback()
equal(movementWarnings, beforeSound + 1, "deferred root alert observes simultaneous fear before playing sound")

blocked = nil
local beforeExpired = movementTextAlerts
handler(nil, "LOSS_OF_CONTROL_ADDED", "player", 4)
activeControlIndex = 3
timers[#timers].callback()
equal(movementTextAlerts, beforeExpired, "an expired new root does not re-alert an older unrelated root")

-- Unidentified effects must not collide with another anonymous root.
local originalCapture = ns.Escape.CaptureLossOfControl
ns.Escape.CaptureLossOfControl = function()
    return false, false, { locType = "ROOT" }
end
local beforeAnonymous, timersBeforeAnonymous = movementTextAlerts, #timers
handler(nil, "LOSS_OF_CONTROL_ADDED", "player", 4)
equal(#timers, timersBeforeAnonymous, "anonymous root does not schedule an ambiguous effect recheck")
equal(movementTextAlerts, beforeAnonymous, "anonymous root cannot re-alert a different anonymous effect")
ns.Escape.CaptureLossOfControl = originalCapture

-- Exercise the actual detector/event handoff, not just a fabricated RECHECK.
assert(loadfile("Features/MovementDetection.lua"))("Salve", ns)
local actualDetector = ns.MovementDetection
actualDetector:Reset()
actualDetector.baseline = 8.33
local fullControl = false
HasFullControl = function() return fullControl end
GetUnitSpeed = function() return 0, 0 end
C_LossOfControl.GetActiveLossOfControlData = function() return { locType = "ROOT" } end
activeControlIndex = 4
handler(nil, "LOSS_OF_CONTROL_ADDED", "player", 4)
timers[#timers].callback()
equal(actualDetector.controlBlocked, true, "event marks the actual detector blocked")
onUpdate(nil, 0.15)
fullControl = true
local beforeRecovery = movementTextAlerts
onUpdate(nil, 0.15)
timers[#timers].callback()
equal(movementTextAlerts, beforeRecovery + 1, "actual detector recovery rechecks the surviving root")
onUpdate(nil, 0.15)
onUpdate(nil, 0.15)
onUpdate(nil, 0.15)
equal(movementTextAlerts, beforeRecovery + 1, "explicit recovered root is not overwritten by a duplicate SLOWED alert")

ns.db = { movementAlertsEnabled = true, inferredSlowAlertsEnabled = true }
ns.Escape.MovementAlertSpell = function() return nil end
local unboundPrompts, unboundText = movementPrompts, movementTextAlerts
speedObservation = { kind = "CLEAR" }
onUpdate(nil, 0.15)
speedObservation = { kind = "SLOW", locType = "SLOW" }
onUpdate(nil, 0.15)
equal(movementPrompts, unboundPrompts, "opted-in inferred slow needs an enabled movement spell for its cue")
equal(movementTextAlerts, unboundText, "opted-in inferred slow needs an enabled movement spell for text")

ns.db = { movementAlertsEnabled = false, inferredSlowAlertsEnabled = true }
ns.Escape.MovementAlertSpell = function(_, _, movement)
    if movement then return { id = 1044, name = "Blessing of Freedom" } end
end
local soundsBefore, textBefore, promptsBefore = movementWarnings, movementTextAlerts, movementPrompts
local timersBefore = #timers
handler(nil, "LOSS_OF_CONTROL_ADDED", "player", 4)
onUpdate(nil, 1)
equal(#timers, timersBefore, "disabled movement alerts do not queue a new root recheck")
equal(movementWarnings, soundsBefore, "master switch suppresses event-driven movement sound")
equal(movementTextAlerts, textBefore, "master switch suppresses event-driven movement text")
equal(movementPrompts, promptsBefore, "master switch suppresses event-driven movement cue")
speedObservation = { kind = "SLOW", locType = "SLOW" }
onUpdate(nil, 0.15)
equal(movementTextAlerts, textBefore, "master switch overrides the inferred-slow opt-in for text")
equal(movementPrompts, promptsBefore, "master switch overrides the inferred-slow opt-in for the cue")

print("event routing tests passed")
