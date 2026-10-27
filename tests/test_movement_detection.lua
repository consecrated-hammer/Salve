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
ns.db = { movementAlertsEnabled = false }
detector:Reset()
equal(detector:Sample(10), nil, "master switch suppresses speed detection")
equal(detector.baseline, nil, "disabled detector does not collect a baseline")
ns.db.movementAlertsEnabled = true
detector:Reset()
equal(detector:AcknowledgeRemoval().kind, "CLEAR",
    "using a movement action clears a cue even before speed detection alerted")
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

-- Fear/stun can lower maximum speed too. They must not be interpreted as a
-- Freedom-removable slow, or become the normal baseline during zone settling.
local control = false
HasFullControl = function() return control end
current, runSpeed = 0, 0
equal(detector:Sample(0.15).kind, "BLOCKED", "loss of control clears an existing movement prompt")
equal(detector.alerted, false, "blocked samples do not consume the next actionable slow")
equal(detector:Sample(0.15), nil, "ongoing control loss does not repeatedly clear UI")
control = true
current, runSpeed = 0, 0
equal(detector:Sample(0.15).kind, "RECHECK", "recovery requests an explicit root/snare recheck")
equal(detector:Sample(0.15), nil, "transient post-control zero speed is not a slow")
equal(detector:Sample(0.15), nil, "speed recovery has a short settling window")
current, runSpeed = 4.16, 4.16
equal(detector:Sample(0.15).kind, "SLOW", "a continuing slow can alert after control returns")
local effects = {}
C_LossOfControl = {
    GetActiveLossOfControlDataCount = function() return #effects end,
    GetActiveLossOfControlData = function(index) return effects[index] end,
    GetActiveLossOfControlDataByUnit = function() error("must use player-only APIs") end,
}
for _, kind in ipairs({ "FEAR", "FEAR_MECHANIC", "HORROR", "STUN", "STUN_MECHANIC", "CONFUSE", "POSSESS", "SILENCE", "PACIFYSILENCE" }) do
    effects = { { locType = "ROOT" }, { locType = kind } }
    detector.controlBlocked = false
    equal(detector:Sample(0.15).kind, "BLOCKED", "root plus " .. kind .. " is not actionable")
end
effects = { { locType = "ROOT" }, { locType = "SNARE" }, { locType = "DISARM" } }
equal(detector:ControlBlockReason(), nil, "roots, snares and disarm do not block movement spells")
equal(detector:Sample(0.15).kind, "RECHECK", "movement-only control data restores root rechecks")
detector:Sample(0.15)
detector:Sample(0.15)
equal(detector:Sample(0.15).kind, "SLOW", "movement-only control data retains slow alerts")
local secret = {}
issecretvalue = function(value) return value == secret end
control = secret
equal(detector:Sample(0.15).kind, "BLOCKED", "secret control state fails closed")
control = true
effects = { { locType = secret } }
detector.controlBlocked = false
equal(detector:Sample(0.15).kind, "BLOCKED", "secret loss-of-control classification fails closed")
C_LossOfControl.GetActiveLossOfControlDataCount = function() error("API failure") end
detector.controlBlocked = false
equal(detector:Sample(0.15).kind, "BLOCKED", "unavailable control data fails closed")
C_LossOfControl = nil
HasFullControl = function() return false end
detector:Reset()
current, runSpeed = 1, 1
for _ = 1, 80 do detector:Sample(0.15) end
equal(detector.baseline, nil, "incapacitated speed cannot establish the baseline")
print("movement control suppression tests passed")
