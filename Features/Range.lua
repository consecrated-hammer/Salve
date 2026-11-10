local addonName, ns = ...

-- ============================================================
-- Out-of-range fading and the debuff-tooltip hover fix
-- ============================================================
-- Range: the primary dispel's own range check, which answers with a plain
-- true or false even in combat. When it has no answer, UnitInRange's (often
-- secret) result goes straight into SetAlphaFromBoolean, never into an `if`.
-- The same approach as Danders, Ellesmere and TPerl. Your own cell never
-- fades. Alpha isn't protected, so this is safe on secure cells in combat.
--
-- Hover: with "Show Blizzard debuff tooltip" on, Blizzard's aura button takes mouse
-- motion over a lit cell, so the box can miss its OnEnter. A light poll of
-- IsMouseOver (plain frame geometry, nothing secret) shows Salve's tooltip
-- anyway.

ns.Range = { lastStatus = "not checked" }
local Range = ns.Range

local RANGE_INTERVAL = 0.5
local HOVER_INTERVAL = 0.1

local function isSecret(value)
    return issecretvalue and issecretvalue(value) and true or false
end

local function spellInRange(unit)
    local spellID = ns.spellID
    if type(spellID) ~= "number" then return nil end
    if C_Spell and C_Spell.IsSpellInRange then
        local ok, result = pcall(C_Spell.IsSpellInRange, spellID, unit)
        if ok then return result end
        return nil
    end
    if IsSpellInRange and GetSpellInfo then
        local name = GetSpellInfo(spellID)
        if name then
            local ok, result = pcall(IsSpellInRange, name, unit)
            if ok and result ~= nil then return result == 1 end
        end
    end
    return nil
end

-- Returns a plain boolean, a secret boolean, or nil (no answer: stay solid).
function Range:InRange(unit)
    if not unit or unit == "player" then return true end
    if UnitExists and not UnitExists(unit) then return true end
    local result = spellInRange(unit)
    if isSecret(result) then
        self.lastStatus = "dispel range (secret)"
        return result
    end
    if result ~= nil then
        self.lastStatus = "dispel range"
        return result and true or false
    end
    if UnitInRange then
        local ok, inRange = pcall(UnitInRange, unit)
        if ok and isSecret(inRange) then
            self.lastStatus = "group range (secret)"
            return inRange
        end
        if ok and type(inRange) == "boolean" then
            self.lastStatus = "group range"
            return inRange
        end
    end
    self.lastStatus = "no answer"
    return nil
end

function Range:Apply(box)
    if not box or not box.unit then return end
    local faded = ns.db and ns.db.outOfRangeAlpha or 1
    if faded >= 1 then
        box:SetAlpha(1)
        return
    end
    local inRange = self:InRange(box.unit)
    if isSecret(inRange) then
        if box.SetAlphaFromBoolean then
            box:SetAlphaFromBoolean(inRange, 1, faded)
        else
            box:SetAlpha(1)
        end
    elseif inRange == false then
        box:SetAlpha(faded)
    else
        box:SetAlpha(1)
    end
end

local function liveBoxes()
    return ns.Panel and ns.Panel.boxes or {}
end

function Range:UpdateAll()
    for _, box in ipairs(liveBoxes()) do
        if box.unit and box:IsShown() then self:Apply(box) end
    end
end

function Range:UpdateUnit(unit)
    for _, box in ipairs(liveBoxes()) do
        if box.unit == unit and box:IsShown() then self:Apply(box) end
    end
end

function Range:Hover()
    local db = ns.db
    if not (db and db.showTooltip and db.tooltipDebuff ~= false) then return end
    local hovered
    for _, box in ipairs(liveBoxes()) do
        if box.unit and box:IsVisible() and box:IsMouseOver() then hovered = box break end
    end
    if hovered then
        if not GameTooltip:IsOwned(hovered) then ns.Box.ShowTooltip(hovered) end
        self.hovered = hovered
    elseif self.hovered then
        ns.Box.HideTooltip(self.hovered)
        self.hovered = nil
    end
end

function Range:DiagnosticLines()
    return {
        "Out of range opacity: " .. tostring(ns.db and ns.db.outOfRangeAlpha),
        "Range check: " .. tostring(self.lastStatus),
        "Debuff tooltip: " .. ((ns.db and ns.db.tooltipDebuff ~= false) and "on" or "off"),
    }
end

function Range:Start()
    if self.frame or not CreateFrame then return end
    local f = CreateFrame("Frame")
    local rangeElapsed, hoverElapsed = 0, 0
    f:SetScript("OnUpdate", function(_, elapsed)
        rangeElapsed = rangeElapsed + elapsed
        hoverElapsed = hoverElapsed + elapsed
        if rangeElapsed >= RANGE_INTERVAL then
            rangeElapsed = 0
            Range:UpdateAll()
        end
        if hoverElapsed >= HOVER_INTERVAL then
            hoverElapsed = 0
            Range:Hover()
        end
    end)
    pcall(f.RegisterEvent, f, "UNIT_IN_RANGE_UPDATE")
    f:SetScript("OnEvent", function(_, _, unit) Range:UpdateUnit(unit) end)
    self.frame = f
end
