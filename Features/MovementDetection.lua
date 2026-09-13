local addonName, ns = ...

-- Player-only movement signals. This knows nothing about classes, spells,
-- locations or output; it only emits a conservative SLOW observation when
-- Blizzard reports the player's ground-speed value has dropped sharply.  That
-- value remains meaningful while standing still; current travel speed does not.
ns.MovementDetection = {}
local Detector = ns.MovementDetection

local SAMPLE_PERIOD = 0.15
local DROP_RATIO = 0.70
local RECOVERY_RATIO = 0.90

local function plain(value)
    if issecretvalue and issecretvalue(value) then return nil end
    return value
end

function Detector:Reset()
    self.elapsed, self.baseline, self.alerted = 0, nil, false
    self.active = true
    self.lastStatus = "monitoring player ground speed"
end

function Detector:AcknowledgeRemoval()
    if not self.alerted then return nil end
    self.alerted = false
    self.lastStatus = "movement action used; awaiting speed recovery"
    return { kind = "CLEAR" }
end

function Detector:Sample(elapsed)
    if not self.active then return nil end
    self.elapsed = (self.elapsed or 0) + (tonumber(elapsed) or 0)
    if self.elapsed < SAMPLE_PERIOD then return nil end
    self.elapsed = 0
    if type(GetUnitSpeed) ~= "function" then
        self.lastStatus = "player speed API unavailable"
        return nil
    end
    if (IsSwimming and IsSwimming("player")) or (IsFlying and IsFlying("player"))
        or (IsMounted and IsMounted()) then
        self.lastStatus = "speed sampling skipped outside ground movement"
        return nil
    end

    local ok, _, runSpeed = pcall(GetUnitSpeed, "player")
    if not ok then
        self.lastStatus = "player speed unavailable or secret"
        return nil
    end
    runSpeed = plain(runSpeed)
    if type(runSpeed) ~= "number" then
        self.lastStatus = "player speed unavailable or secret"
        return nil
    end

    -- Establish one normal reference per zone, then retain it.  Raising the
    -- reference for a temporary speed boost would turn ordinary speed after
    -- that boost expires into a permanent false slow.  A zero run speed is a
    -- valid severe impairment once a positive reference is known.
    if not self.baseline then
        if runSpeed <= 0 then
            self.lastStatus = "awaiting a normal ground-speed reference"
            return nil
        end
        self.baseline = runSpeed
        self.lastStatus = ("normal run speed %.2f"):format(runSpeed)
        return nil
    end

    if runSpeed >= self.baseline * RECOVERY_RATIO then
        local wasAlerted = self.alerted
        self.alerted = false
        self.lastStatus = ("normal run speed %.2f"):format(runSpeed)
        return wasAlerted and { kind = "CLEAR" } or nil
    end
    if self.alerted or runSpeed > self.baseline * DROP_RATIO then
        self.lastStatus = ("normal run speed %.2f"):format(runSpeed)
        return nil
    end
    self.alerted = true
    self.lastStatus = ("speed reduced to %.2f from %.2f"):format(runSpeed, self.baseline)
    return { kind = "SLOW", locType = "SLOW", baseline = self.baseline, runSpeed = runSpeed }
end
