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

    if db.visibilityMode == "NEVER" or self:HiddenForFlight() then return "hide" end

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
--   only from Panel:Rebuild, which is already gated on InCombatLockdown, and
--   Refresh below, which checks it first.
function Visibility:Apply(frame, hasBoxes)
    if not frame or InCombatLockdown() then return end
    -- Remembered so Refresh can swap the rule without a full rebuild.
    self.frame, self.hasBoxes = frame, hasBoxes

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

-- ── Hide on flights ───────────────────────────────────────────────────────
-- HammerCore's flight tracking (flights = { estimates = false } in Setup.lua)
-- says when a flight path takes off and lands, including a reload mid-flight.
-- While flying, the rule above is "hide": the panel, its handle and cooldown
-- bar go, and the on-screen movement text stays quiet.
--
-- ☠ Swapping the rule re-registers the state driver, which is protected. Out
--   of combat that happens straight away. In combat (a landing into a fight)
--   it waits for RequestRebuild's PLAYER_REGEN_ENABLED replay; a panel can't
--   be shown from Lua mid-fight any other way.

Visibility.onFlight = false

function Visibility:HiddenForFlight()
    return self.onFlight and ns.db ~= nil and ns.db.hideOnFlights ~= false
end

-- Re-applies the current rule to the panel, or queues a rebuild that does.
function Visibility:Refresh()
    if not self.frame then return end
    if InCombatLockdown() then
        ns.RequestRebuild()
        return
    end
    self:Apply(self.frame, self.hasBoxes)
end

function Visibility:SetFlying(flying)
    flying = flying and true or false
    if self.onFlight == flying then return end
    self.onFlight = flying
    if self:HiddenForFlight() and ns.MovementAlert then ns.MovementAlert:Clear() end
    self:Refresh()
end

local HC = ns.HammerCore
if HC and HC.Flights then
    HC.Flights:OnTakeoff(function() Visibility:SetFlying(true) end)
    HC.Flights:OnLanding(function() Visibility:SetFlying(false) end)
end
