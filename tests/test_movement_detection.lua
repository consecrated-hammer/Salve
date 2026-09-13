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

detector:Start()
equal(detector:Sample(0.10), nil, "sampling waits for its short interval")
equal(detector:Sample(0.05), nil, "normal speed establishes a baseline")
equal(detector.lastStatus, "normal run speed 8.33", "diagnostic preserves normal baseline")

current, runSpeed = 4.16, 4.16
local movement = detector:Sample(0.15)
equal(movement.kind, "SLOW", "a sharp maximum ground-speed drop is a slow")
equal(movement.baseline, 8.33, "slow retains the prior normal baseline")
equal(detector.lastStatus, "speed reduced to 4.16 from 8.33", "diagnostic preserves speed reduction")
equal(detector:Sample(0.15), nil, "persistent slow alerts only once")

current, runSpeed = 8.33, 8.33
equal(detector:Sample(0.15).kind, "CLEAR", "normal speed clears the active prompt")
current, runSpeed = 4.16, 4.16
assert(detector:Sample(0.15), "a later new speed drop alerts again")
equal(detector:AcknowledgeRemoval().kind, "CLEAR", "using the suggested movement action clears its cue")

detector.alerted = true
current, runSpeed = 8.33, 8.33
equal(detector:CheckRecovery().kind, "CLEAR", "stopping at normal speed clears a stale cue")

detector:Stop()
equal(detector:Sample(1), nil, "stopped movement never samples speed")
print("movement detection tests passed")
