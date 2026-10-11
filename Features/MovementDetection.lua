local addonName, ns = ...

-- Player-only movement signals. This knows nothing about classes, spells,
-- locations or output; it only emits a conservative SLOW observation when
-- Blizzard reports the player's ground-speed value has dropped sharply.  That
-- value remains meaningful while standing still; current travel speed does not.
ns.MovementDetection = {}
local Detector = ns.MovementDetection

local SAMPLE_PERIOD = 0.15
local BASELINE_SETTLE_SECONDS = 10.0
local DROP_RATIO = 0.70
local RECOVERY_RATIO = 0.90

local function plain(value)
    if issecretvalue and issecretvalue(value) then return nil end
    return value
end

local CAST_BLOCKING_CONTROL = {
    FEAR = true, FEAR_MECHANIC = true, HORROR = true, CONFUSE = true,
    STUN = true, STUN_MECHANIC = true, POSSESS = true,
    SILENCE = true, PACIFYSILENCE = true,
}

-- A speed reduction alone cannot distinguish a snare from incapacitation.
-- Use only player control APIs, never another unit's data or live auras.
function Detector:ControlBlockReason()
    if type(HasFullControl) == "function" then
        local ok, control = pcall(HasFullControl)
        control = plain(control)
        if not ok or type(control) ~= "boolean" then return "player control unavailable or secret" end
        if not control then return "player is not in control" end
    end
    local api = C_LossOfControl
    if not (api and api.GetActiveLossOfControlDataCount and api.GetActiveLossOfControlData) then
        return nil
    end
    local ok, count = pcall(api.GetActiveLossOfControlDataCount)
    count = plain(count)
    if not ok or type(count) ~= "number" or count ~= count or count < 0 or count > 64 then
        return "player loss-of-control state unavailable or secret"
    end
    for index = 1, count do
        local readable, kind = pcall(function()
            local data = api.GetActiveLossOfControlData(index)
            return data and data.locType
        end)
        local secret = issecretvalue and issecretvalue(kind)
        kind = plain(kind)
        if not readable or secret or (kind ~= nil and type(kind) ~= "string") then
            return "player loss-of-control classification unavailable or secret"
        end
        if kind and CAST_BLOCKING_CONTROL[kind] then return "player control blocked by " .. kind end
    end
    return nil
end

local function median(values)
    local sorted = {}
    for index, value in ipairs(values) do sorted[index] = value end
    table.sort(sorted)
    return sorted[math.floor((#sorted + 1) / 2)]
end

function Detector:Reset()
    self.elapsed, self.baseline, self.baselineSamples, self.settleElapsed, self.alerted =
        0, nil, {}, 0, false
    self.active = true
    self.controlBlocked, self.resumeDelay = false, 0
    self.lastStatus = "monitoring player ground speed"
end

function Detector:AcknowledgeRemoval()
    self.alerted = false
    self.lastStatus = "movement action used; awaiting speed recovery"
    return { kind = "CLEAR" }
end

function Detector:Sample(elapsed)
    if not self.active then return nil end
    self.elapsed = (self.elapsed or 0) + (tonumber(elapsed) or 0)
    if self.elapsed < SAMPLE_PERIOD then return nil end
    local sampleElapsed = self.elapsed
    self.elapsed = 0
    local blocked = self:ControlBlockReason()
    if blocked then
        local wasBlocked = self.controlBlocked
        self.controlBlocked = true
        self.alerted = false
        self.lastStatus = blocked
        -- Clear an earlier prompt too; once control returns a continuing slow
        -- may produce a fresh observation against the retained normal speed.
        return not wasBlocked and { kind = "BLOCKED" } or nil
    end
    if self.controlBlocked then
        self.controlBlocked, self.resumeDelay = false, 0.30
        self.lastStatus = "control restored; rechecking active roots and snares"
        return { kind = "RECHECK" }
    end
    if (self.resumeDelay or 0) > 0 then
        self.resumeDelay = math.max(0, self.resumeDelay - sampleElapsed)
        self.lastStatus = "waiting for ground speed to settle after control recovery"
        return nil
    end
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

    -- Establish one conservative normal reference per zone, then retain it.
    -- Zone transitions can report the departing transport or movement state for
    -- several seconds. During the zone-settle window, retain a short history
    -- of positive ground speeds and use its median. A transient transfer-speed
    -- high or a one-sample low cannot poison the normal reference; a zero run
    -- speed remains a valid severe impairment once a positive reference is
    -- known.
    if not self.baseline then
        if runSpeed <= 0 then
            self.lastStatus = "awaiting a normal ground-speed reference"
            return nil
        end
        local samples = self.baselineSamples
        samples[#samples + 1] = runSpeed
        self.settleElapsed = (self.settleElapsed or 0) + sampleElapsed
        if self.settleElapsed < BASELINE_SETTLE_SECONDS then
            self.lastStatus = "awaiting a settled ground-speed reference"
            return nil
        end
        self.baseline, self.baselineSamples, self.settleElapsed = median(samples), nil, nil
        self.lastStatus = ("normal run speed %.2f"):format(self.baseline)
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
