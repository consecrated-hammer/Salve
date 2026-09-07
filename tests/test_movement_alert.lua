local function equal(actual, expected, label)
    if actual ~= expected then
        error(("%s: expected %s, got %s"):format(label, tostring(expected), tostring(actual)))
    end
end

local emitted = {}
CombatText_StandardScroll = "scroll"
CombatText_AddMessage = function(message, scroll, r, g, b, kind)
    emitted[#emitted + 1] = { message = message, scroll = scroll, kind = kind }
end

local ns = { db = { movementTextNotification = true } }
assert(loadfile("Features/MovementAlert.lua"))("Salve", ns)

equal(ns.MovementAlert:Notify("party2", { locType = "ROOT" },
    { name = "Blessing of Freedom" }), true,
    "Freedom text emits for a rooted party member")
equal(emitted[1].message, "|cffffa020PARTY 2 ROOTED - BLESSING OF FREEDOM|r",
    "Freedom text names the party slot and action without reading an aura")

ns.MovementAlert:Notify("player", { locType = "SNARE" }, { name = "Blessing of Freedom" })
equal(emitted[2].message, "|cffffa020YOU SNARED - BLESSING OF FREEDOM|r",
    "Freedom text distinguishes a player snare")

ns.db.movementTextNotification = false
equal(ns.MovementAlert:Notify("party1", { locType = "ROOT" },
    { name = "Blessing of Freedom" }), false,
    "movement text respects its independent setting")
equal(#emitted, 2, "disabled setting emits no text")

print("movement alert tests passed")
