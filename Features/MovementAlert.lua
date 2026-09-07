local addonName, ns = ...

-- Text instructions for roots and snares that an enabled universally-applicable
-- action can answer. This deliberately receives only the plain loss-of-control
-- classification and unit token; it never inspects an aura or claims a cell is
-- lit/actionable.

ns.MovementAlert = {}
local MovementAlert = ns.MovementAlert

local function unitLabel(unit)
    if unit == "player" then return "YOU" end
    local party = type(unit) == "string" and unit:match("^party(%d+)$")
    if party then return "PARTY " .. party end
    local raid = type(unit) == "string" and unit:match("^raid(%d+)$")
    if raid then return "RAID " .. raid end
    return "A GROUP MEMBER"
end

local function show(message)
    if CombatText_AddMessage and CombatText_StandardScroll then
        pcall(CombatText_AddMessage, message, CombatText_StandardScroll,
            1, 0.63, 0.12, "crit")
        return
    end
    if UIErrorsFrame and UIErrorsFrame.AddMessage then
        pcall(UIErrorsFrame.AddMessage, UIErrorsFrame, message, 1, 0.63, 0.12)
    end
end

function MovementAlert:Notify(unit, movement, spell)
    if not (ns.db and ns.db.movementTextNotification and spell) then return false end
    local effect = movement and movement.locType == "SNARE" and "SNARED" or "ROOTED"
    show("|cffffa020" .. unitLabel(unit) .. " " .. effect .. " - "
        .. tostring(spell.name or "MOVEMENT REMOVAL"):upper() .. "|r")
    return true
end
