local function equal(actual, expected, label)
    if actual ~= expected then
        error(("%s: expected %s, got %s"):format(label, tostring(expected), tostring(actual)))
    end
end

local current, runSpeed = 8.33, 8.33
GetUnitSpeed = function(unit)
    equal(unit, "player", "speed detector observes only the player")
    return current, runSpeed
end

local ns = {}
assert(loadfile("Features/MovementDetection.lua"))("Salve", ns)
local detector = ns.MovementDetection
detector:Reset()
equal(detector:Sample(0.10), nil, "sampling waits for its short interval")
equal(detector:Sample(0.05), nil, "first normal sample begins the settle window")
equal(detector.lastStatus, "awaiting a settled ground-speed reference", "diagnostic records baseline settling")
for _ = 1, 66 do detector:Sample(0.15) end
equal(detector.lastStatus, "normal run speed 8.33", "diagnostic preserves normal baseline")

current, runSpeed = 4.16, 4.16
local movement = detector:Sample(0.15)
equal(movement.kind, "SLOW", "a sharp maximum ground-speed drop is a slow")
equal(movement.baseline, 8.33, "slow retains the prior normal baseline")
equal(detector.lastStatus, "speed reduced to 4.16 from 8.33", "diagnostic preserves speed reduction")
equal(detector:Sample(0.15), nil, "persistent slow alerts only once")

current, runSpeed = 8.33, 8.33
equal(detector:Sample(0.15).kind, "CLEAR", "normal speed clears the active prompt")
current, runSpeed = 12, 12
equal(detector:Sample(0.15), nil, "temporary speed boost does not replace normal reference")
current, runSpeed = 8.33, 8.33
equal(detector:Sample(0.15), nil, "speed after a boost is not a false slow")
current, runSpeed = 4.16, 4.16
assert(detector:Sample(0.15), "a later new speed drop alerts again")
equal(detector:AcknowledgeRemoval().kind, "CLEAR", "using the suggested movement action clears its cue")

current, runSpeed = 0, 4.16
equal(detector:Sample(1).kind, "SLOW", "standing still retains the active slow state")
current, runSpeed = 0, 8.33
equal(detector:Sample(0.15).kind, "CLEAR", "standing still at normal run speed clears the prompt")
current, runSpeed = 0, 0
equal(detector:Sample(0.15).kind, "SLOW", "zero ground speed is a severe slow")

-- Zone transfers can briefly expose an anomalous high or low movement state.
-- Use neither one as the new normal reference when the settled zone returns
-- the real ground speed.
detector:Reset()
current, runSpeed = 12, 12
equal(detector:Sample(0.15), nil, "zone-transition speed starts only a settling baseline")
current, runSpeed = 3, 3
equal(detector:Sample(0.15), nil, "one transient low sample does not become the baseline")
current, runSpeed = 8.33, 8.33
for _ = 1, 66 do detector:Sample(0.15) end
equal(detector.lastStatus, "normal run speed 8.33", "settled zone speed becomes the normal reference")
print("movement detection tests passed")
