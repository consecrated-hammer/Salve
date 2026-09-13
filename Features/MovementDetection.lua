local addonName, ns = ...

-- Player-only movement signals. This knows nothing about classes, spells,
-- locations or output; it only emits a conservative SLOW observation when
-- Blizzard reports the player's maximum ground speed has dropped sharply.
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
    self.active = false
    self.lastStatus = "waiting for player movement"
end

function Detector:Start()
    self.active = true
end

function Detector:Stop()
    self.active = false
    self.elapsed = 0
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

    local current, runSpeed = GetUnitSpeed("player")
    current, runSpeed = plain(current), plain(runSpeed)
    if type(current) ~= "number" or type(runSpeed) ~= "number" or current <= 0 or runSpeed <= 0 then
        self.lastStatus = "player speed unavailable or secret"
        return nil
    end
    if not self.baseline or runSpeed > self.baseline then
        self.baseline, self.alerted = runSpeed, false
        self.lastStatus = ("normal run speed %.2f"):format(runSpeed)
        return nil
    end

    if runSpeed >= self.baseline * RECOVERY_RATIO then
        local wasAlerted = self.alerted
        self.alerted = false
        self.lastStatus = ("normal run speed %.2f"):format(runSpeed)
        return wasAlerted and { kind = "CLEAR" } or nil
    end
    if self.alerted or runSpeed > self.baseline * DROP_RATIO then return nil end
    self.alerted = true
    self.lastStatus = ("speed reduced to %.2f from %.2f"):format(runSpeed, self.baseline)
    return { kind = "SLOW", locType = "SLOW", baseline = self.baseline, runSpeed = runSpeed }
end
