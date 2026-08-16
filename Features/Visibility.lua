local addonName, ns = ...

-- ============================================================
-- When the panel is on screen
-- ============================================================
-- ☠ THIS CANNOT BE DONE WITH Show() AND Hide(). The panel holds secure action
--   buttons, so it is a protected frame, and showing or hiding a protected
--   frame during combat is a blocked action. Any Lua-driven "hide in combat"
--   would therefore fail at exactly the moment it was asked to work.
--
-- The supported route is a STATE DRIVER: we hand Blizzard a macro conditional
-- string and the secure environment evaluates it, including mid-combat. This is
-- the same mechanism action bars use to fade out of combat.
--
-- Everything expressible as a macro conditional is therefore free; anything
-- that is not (instance type, for example) would need re-registering from Lua
-- out of combat, which is why the condition list below stops where it does.

ns.Visibility = {}
local Visibility = ns.Visibility

-- Ordered for the options list. `cond` is the macro conditional that makes the
-- panel visible when it matches.
ns.VIS_CONDITIONS = {
    { key = "inCombat",    label = "In combat",        cond = "[combat]" },
    { key = "outOfCombat", label = "Out of combat",    cond = "[nocombat]" },
    { key = "solo",        label = "Solo",             cond = "[nogroup]" },
    { key = "inParty",     label = "In a party",       cond = "[group:party]" },
    { key = "inRaid",      label = "In a raid group",  cond = "[group:raid]" },
}

-- Builds the conditional string. Conditions are OR-ed: the panel shows if ANY
-- ticked condition matches, which is what "combine conditions" means to a
-- reader. With none ticked, the base mode applies unconditionally.
function Visibility:Rule()
    local db = ns.db

    if db.visibilityMode == "NEVER" then return "hide" end

    local parts = {}
    for _, c in ipairs(ns.VIS_CONDITIONS) do
        if db.visibility and db.visibility[c.key] then
            parts[#parts + 1] = c.cond .. " show"
        end
    end

    if #parts == 0 then return "show" end
    return table.concat(parts, "; ") .. "; hide"
end

-- ☠ Registering a driver is itself a protected operation, so this is called
--   only from Panel:Rebuild, which is already gated on InCombatLockdown.
function Visibility:Apply(frame, hasBoxes)
    if not frame or InCombatLockdown() then return end

    UnregisterStateDriver(frame, "visibility")

    if not hasBoxes then
        -- Nothing to show. Hide outright rather than leaving a driver that
        -- would reveal an empty frame.
        frame:Hide()
        return
    end

    RegisterStateDriver(frame, "visibility", self:Rule())
end

-- Human-readable summary for the options button, e.g. "In combat, Solo".
function Visibility:Summary()
    local db = ns.db
    if db.visibilityMode == "NEVER" then return "Never" end

    local names = {}
    for _, c in ipairs(ns.VIS_CONDITIONS) do
        if db.visibility and db.visibility[c.key] then
            names[#names + 1] = c.label
        end
    end

    if #names == 0 then return "Always" end
    if #names > 2 then return #names .. " conditions" end
    return table.concat(names, ", ")
end
