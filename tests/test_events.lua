local function equal(actual, expected, label)
    if actual ~= expected then
        error(("%s: expected %s, got %s"):format(label, tostring(expected), tostring(actual)))
    end
end

local handler
local registered = {}
local unitRegistration
local timers = {}
local refreshes = 0
local previewStops = 0
local optionsRefreshes = 0
local rebuilds = 0
local dispelRefreshes = 0

CreateFrame = function()
    return {
        SetScript = function(_, script, callback)
            if script == "OnEvent" then handler = callback end
        end,
        RegisterEvent = function(_, event)
            registered[event] = true
        end,
        RegisterUnitEvent = function(_, event, unit)
            unitRegistration = { event = event, unit = unit }
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
    Escape = { Update = function() return true end },
    Options = {
        RefreshDispel = function() optionsRefreshes = optionsRefreshes + 1 end,
        RefreshTroubleshooting = function() end,
    },
    Sound = { OnDispelChanged = function() dispelRefreshes = dispelRefreshes + 1 end },
    RequestRebuild = function() rebuilds = rebuilds + 1 end,
    Binding = {
        ObserveDispelCast = function(_, unit, spellID)
            return unit == "player" and spellID == 4987
        end,
        RefreshCooldowns = function() refreshes = refreshes + 1 end,
    },
    Preview = {
        Stop = function() previewStops = previewStops + 1 end,
    },
}

assert(loadfile("Core/Events.lua"))("Salve", ns)

equal(unitRegistration.event, "UNIT_SPELLCAST_SUCCEEDED",
    "cast-success event registered as a unit event")
equal(unitRegistration.unit, "player", "cast-success registration is player-only")
equal(registered.SPELL_UPDATE_COOLDOWN, nil,
    "global cooldown update event remains unregistered")
equal(registered.PLAYER_REGEN_DISABLED, true,
    "combat start is registered to close preview safely")

handler(nil, "PLAYER_REGEN_DISABLED")
equal(previewStops, 1, "combat start closes live panel preview")

handler(nil, "SPELLS_CHANGED")
equal(optionsRefreshes, 1,
    "escape-only spell discovery refreshes the Dispels page immediately")
equal(dispelRefreshes, 0,
    "escape-only spell discovery does not rebuild sound registrations")
equal(rebuilds, 1, "escape-only spell discovery rebuilds the panel")

handler(nil, "UNIT_SPELLCAST_SUCCEEDED", "player", "cast-guid", 4987)
equal(refreshes, 0, "dispel cooldown is not read inside the early cast event")
equal(#timers, 1, "successful player dispel schedules one deferred refresh")
equal(timers[1].delay, 0, "dispel refresh waits one event-loop tick")
timers[1].callback()
equal(refreshes, 1, "deferred dispel refresh reaches cooldown widgets")

handler(nil, "UNIT_SPELLCAST_SUCCEEDED", "player", "cast-guid", 12345)
equal(#timers, 1, "ordinary player casts do not schedule a GCD sweep")

handler(nil, "UNIT_SPELLCAST_SUCCEEDED", "party1", "cast-guid", 4987)
equal(#timers, 1, "another unit's dispel does not schedule a sweep")

print("event routing tests passed")
