local function equal(actual, expected, label)
    if actual ~= expected then
        error(("%s: expected %s, got %s"):format(label, tostring(expected), tostring(actual)))
    end
end

local emitted = {}
local registered = {}
local handler
issecretvalue = function() return false end
CreateFrame = function()
    return {
        SetScript = function(_, _, callback) handler = callback end,
        RegisterEvent = function(_, event) registered[event] = true end,
        UnregisterEvent = function(_, event) registered[event] = nil end,
    }
end
CombatText_StandardScroll = {}
CombatText_AddMessage = function(message, scroll, r, g, b, style)
    emitted[#emitted + 1] = { message = message, scroll = scroll, r = r, g = g, b = b, style = style }
end
UnitGUID = function(unit) return unit == "player" and "Player-1" or nil end

local event = {
    0, "SPELL_AURA_APPLIED", false, "Creature-1", "Caster", 0, 0,
    "Player-1", "Player", 0, 0, 1272896,
}
CombatLogGetCurrentEventInfo = function() return unpack(event) end

local ns = {
    db = { selfDispelNotification = true },
    Sound = {
        Plain = function(value) return value end,
        ActiveSelfDispelAlerts = function()
            return { [1272896] = { name = "Xal'atath's Bargain: Devour" } }
        end,
    },
}

assert(loadfile("Features/SelfAlert.lua"))("Salve", ns)
ns.SelfAlert:Update()
equal(registered.COMBAT_LOG_EVENT_UNFILTERED, true,
    "listener is active only while a matching self-dispel alert is relevant")
ns.SelfAlert:OnCombatLog()
equal(#emitted, 1, "matching self aura emits one combat-text instruction")
equal(emitted[1].message, "|cffff3838Xal'atath's Bargain: Devour - DISPEL YOURSELF|r",
    "self-dispel instruction names the exact aura")
equal(emitted[1].scroll, CombatText_StandardScroll, "instruction uses floating combat text")

event[8] = "Player-2"
ns.SelfAlert:OnCombatLog()
equal(#emitted, 1, "party member applications never emit another player's instruction")

event[8] = "Player-1"
event[2] = "SPELL_AURA_REMOVED"
ns.SelfAlert:OnCombatLog()
equal(#emitted, 1, "aura removals do not create duplicate instructions")

event[2] = "SPELL_AURA_APPLIED"
ns.db.selfDispelNotification = false
ns.SelfAlert:OnCombatLog()
equal(#emitted, 1, "notification option suppresses combat text")
ns.SelfAlert:Update()
equal(registered.COMBAT_LOG_EVENT_UNFILTERED, nil,
    "disabled notification unregisters the combat-log listener")

print("self-dispel alert tests passed")
