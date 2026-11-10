-- Hide on flights: the panel's state driver says "hide" between takeoff and
-- landing, the movement text stays off screen, and a landing in combat waits
-- for the rebuild queue instead of touching the protected panel.

local function equal(actual, expected, label)
    if actual ~= expected then
        error(("%s: expected %s, got %s"):format(label, tostring(expected), tostring(actual)), 2)
    end
end

local drivers, locked, rebuilds = {}, false, 0
function RegisterStateDriver(frame, state, rule) drivers[frame] = rule end
function UnregisterStateDriver(frame) drivers[frame] = nil end
function InCombatLockdown() return locked end

local listeners = { takeoff = {}, landing = {} }
local function fire(kind)
    for _, fn in ipairs(listeners[kind]) do fn({}) end
end

local cleared = 0
local ns = {
    db = { visibilityMode = "ALWAYS", visibility = {}, hideOnFlights = true },
    HammerCore = { Flights = {
        OnTakeoff = function(_, fn) listeners.takeoff[#listeners.takeoff + 1] = fn end,
        OnLanding = function(_, fn) listeners.landing[#listeners.landing + 1] = fn end,
    } },
    MovementAlert = { Clear = function() cleared = cleared + 1 end },
}
function ns.RequestRebuild() rebuilds = rebuilds + 1 end
assert(loadfile("Features/Visibility.lua"))("Salve", ns)
local V = ns.Visibility
equal(#listeners.takeoff, 1, "Salve listens for takeoff")
equal(#listeners.landing, 1, "Salve listens for landing")

local panel = { Hide = function() end }
V:Apply(panel, true)
equal(drivers[panel], "show", "the panel shows on the ground")

fire("takeoff")
equal(V:HiddenForFlight(), true, "a flight hides Salve")
equal(drivers[panel], "hide", "takeoff swaps the rule to hide")
equal(cleared, 1, "takeoff clears the movement text")
equal(V:Rule(), "hide", "rebuilds mid-flight keep the panel hidden")

fire("landing")
equal(V:HiddenForFlight(), false, "landing ends the flight")
equal(drivers[panel], "show", "landing brings the panel back")

-- Conditions still apply after landing.
ns.db.visibility.inCombat = true
fire("takeoff")
equal(drivers[panel], "hide", "a flight overrides visibility conditions")
fire("landing")
equal(drivers[panel], "[combat] show; hide", "landing restores the conditions")
ns.db.visibility.inCombat = nil

-- A landing into a fight can't re-register the driver; it queues a rebuild.
fire("takeoff")
locked = true
fire("landing")
equal(drivers[panel], "hide", "the protected panel is left alone in combat")
equal(rebuilds, 1, "the landing queues a rebuild for after combat")
equal(V:Rule(), "show", "the queued rebuild shows the panel")
locked = false

-- The setting off: flights change nothing.
ns.db.hideOnFlights = false
fire("takeoff")
equal(V:HiddenForFlight(), false, "Hide on flights off keeps Salve up")
equal(drivers[panel], "show", "the rule stays show with the setting off")
ns.db.hideOnFlights = true
V:Refresh()
equal(drivers[panel], "hide", "turning it on mid-flight hides straight away")
fire("landing")

-- A panel with no cells stays hidden either way.
V:Apply(panel, false)
fire("takeoff")
fire("landing")
equal(drivers[panel], nil, "an empty panel gets no driver")

-- Movement text: chat still prints, the screen stays quiet.
local printed = {}
local frame = { Hide = function() end, Show = function(self) self.shown = true end,
    SetSize = function() end, SetFrameStrata = function() end, SetClampedToScreen = function() end,
    SetMovable = function() end, RegisterForDrag = function() end, SetScript = function() end,
    EnableMouse = function() end, ClearAllPoints = function() end, SetPoint = function() end,
    StopMovingOrSizing = function() end,
    CreateFontString = function() return { SetAllPoints = function() end, SetText = function() end } end }
function CreateFrame() return frame end
UIParent = {}
ns.db.movementTextNotification, ns.db.movementTextOutput = true, "BOTH"
ns.Print = function(message) printed[#printed + 1] = message end
ns.MovementAlert = nil
assert(loadfile("Features/MovementAlert.lua"))("Salve", ns)
ns.MovementAlert:Frame()
fire("takeoff")
equal(ns.MovementAlert:Notify("player", { locType = "ROOT" }, { name = "Blessing of Freedom" }), true,
    "a flight still handles the alert")
equal(#printed, 1, "chat output still prints mid-flight")
equal(frame.shown, nil, "the on-screen text stays hidden mid-flight")
fire("landing")
ns.MovementAlert:Notify("player", { locType = "ROOT" }, { name = "Blessing of Freedom" })
equal(frame.shown, true, "the on-screen text is back after landing")

print("flights ok")
