local addonName, ns = ...

-- ============================================================
-- Lockout debuffs
-- ============================================================
-- Some spells leave a debuff that stops them being cast on the same person
-- again for a while: Forbearance after Blessing of Protection. Salve shows it
-- on the cooldown bar with the member's name (by default), on their cell, or
-- both, so a click isn't wasted. Off by default, and only shown when a spell
-- it blocks is bound on Actions. It shows only while active, whatever Show
-- when ready says.
--
-- ☠ Salve can't see the debuff itself. Blizzard lets addons pick one debuff
--   out on a friendly unit only when the spell is flagged never secret
--   (Blizzard_AuraContainerUtil's identity gate), so this follows the
--   player's OWN casts instead: the cell they clicked, or the target name the
--   client reports when the cast is sent. Another paladin's Forbearance isn't
--   seen. /salve cooldowns says whether Forbearance is never secret on this
--   client, which would allow reading it properly.

ns.Lockouts = { active = {}, sent = {}, missed = 0 }
local Lockouts = ns.Lockouts

Lockouts.DEBUFFS = {
    -- Forbearance: Blessing of Protection, Blessing of Spellwarding and Lay
    -- on Hands on a target, Divine Shield on yourself.
    { id = 25771, duration = 30,
      causes = { [1022] = "TARGET", [204018] = "TARGET", [633] = "TARGET", [642] = "SELF" },
      blocks = { 1022, 204018, 633, 642 } },
}

-- How long after a cell click its cast still counts as that click's.
local CLICK_WINDOW = 2

local function secret(value)
    return issecretvalue and issecretvalue(value)
end

local function debuffFor(spellID)
    for _, debuff in ipairs(Lockouts.DEBUFFS) do
        if debuff.causes[spellID] then return debuff, debuff.causes[spellID] end
    end
end

-- Lockouts that block a spell bound on Actions.
function Lockouts:Relevant()
    local bound = {}
    for _, id in ipairs(ns.Cooldowns and ns.Cooldowns:BoundSpells() or {}) do bound[id] = true end
    local out = {}
    for _, debuff in ipairs(self.DEBUFFS) do
        for _, id in ipairs(debuff.blocks) do
            if bound[id] then
                out[#out + 1] = debuff
                break
            end
        end
    end
    return out
end

function Lockouts:Enabled()
    return ns.db and ns.db.lockoutIcons == true and #self:Relevant() > 0 or false
end

-- "BAR", "CELL" or "BOTH".
function Lockouts:Placement()
    return ns.db and ns.db.lockoutPlacement or "BAR"
end

function Lockouts:OnBar()
    local placement = self:Placement()
    return placement == "BAR" or placement == "BOTH"
end

function Lockouts:OnCells()
    local placement = self:Placement()
    return placement == "CELL" or placement == "BOTH"
end

-- From the box's OnClick hook. The binding table already says which spell
-- that button casts on this cell; nothing secure is read.
function Lockouts:NoteClick(box, button)
    if not (ns.db and ns.db.lockoutIcons and box and ns.Bindings) then return end
    local key = ns.Bindings:Capture(button)
    local action = key and box.clickAuditActions and box.clickAuditActions[key]
    if not (action and type(action.spellID) == "number" and debuffFor(action.spellID)) then return end
    self.lastClick = { unit = box.unit, spellID = action.spellID, time = GetTime() }
end

-- UNIT_SPELLCAST_SENT carries the target's name for casts made any other way
-- (keybinds, mouseover, other frames). Kept only when it's readable.
function Lockouts:NoteSent(unit, target, castGUID, spellID)
    if unit ~= "player" or not (ns.db and ns.db.lockoutIcons) then return end
    if secret(spellID) or secret(target) or secret(castGUID) then return end
    if type(spellID) ~= "number" or not debuffFor(spellID) then return end
    if type(target) ~= "string" or target == "" or castGUID == nil then return end
    self.sent[castGUID] = target
end

local function groupUnits()
    local units = { "player" }
    if IsInRaid and IsInRaid() then
        for index = 1, 40 do units[#units + 1] = "raid" .. index end
    else
        for index = 1, 4 do units[#units + 1] = "party" .. index end
    end
    return units
end

function Lockouts:UnitByName(target)
    if type(target) ~= "string" then return nil end
    for _, unit in ipairs(groupUnits()) do
        if UnitExists(unit) then
            local name, realm = UnitName(unit)
            if not secret(name) and not secret(realm) and type(name) == "string" then
                local full = (type(realm) == "string" and realm ~= "") and (name .. "-" .. realm) or name
                if target == name or target == full then return unit end
            end
        end
    end
    return nil
end

-- A GUID follows the person through a roster reshuffle; the unit token is
-- the fallback when the GUID is restricted.
local function key(unit)
    local guid = UnitGUID and UnitGUID(unit)
    if guid ~= nil and not secret(guid) then return guid end
    return unit
end

-- From UNIT_SPELLCAST_SUCCEEDED, before the cooldown refresh.
function Lockouts:NoteCast(unit, castGUID, spellID)
    if unit ~= "player" or not (ns.db and ns.db.lockoutIcons) then return end
    if secret(spellID) or type(spellID) ~= "number" then return end
    local debuff, how = debuffFor(spellID)
    if not debuff then return end

    local target
    if how == "SELF" then
        target = "player"
    else
        -- A talent can cast a different spell from the one bound (Spellwarding
        -- for Protection), so any click on a spell with the same lockout counts.
        local click = self.lastClick
        if click and debuffFor(click.spellID) == debuff and GetTime() - click.time <= CLICK_WINDOW then
            target = click.unit
        end
        if not target and castGUID ~= nil and not secret(castGUID) then
            target = self:UnitByName(self.sent[castGUID])
        end
    end
    if castGUID ~= nil and not secret(castGUID) then self.sent[castGUID] = nil end
    self.lastClick = nil
    if not target then
        self.missed = self.missed + 1
        return
    end
    self:Start(target, debuff)
end

function Lockouts:Start(unit, debuff)
    -- The name is kept for the bar label. It may be secret; it only ever goes
    -- to SetText.
    local entry = { unit = unit, name = UnitName(unit), start = GetTime(),
        duration = debuff.duration, spellID = debuff.id }
    self.active[key(unit)] = entry
    if C_Timer and C_Timer.After then
        C_Timer.After(debuff.duration + 0.1, function() Lockouts:Expire() end)
    end
    self:Refresh()
end

function Lockouts:Expire()
    local now = GetTime()
    for id, entry in pairs(self.active) do
        if now >= entry.start + entry.duration then self.active[id] = nil end
    end
    -- Abandoned sends (a cast that never went off) shouldn't pile up.
    self.sent = {}
    self:Refresh()
end

function Lockouts:ForUnit(unit)
    if not unit then return nil end
    local entry = self.active[key(unit)] or self.active[unit]
    if entry and GetTime() < entry.start + entry.duration then return entry end
    return nil
end

-- Active lockouts for the bar, oldest first, or none when they belong on
-- the cells.
function Lockouts:BarEntries()
    local out = {}
    if not (self:Enabled() and self:OnBar()) then return out end
    local now = GetTime()
    for _, entry in pairs(self.active) do
        if now < entry.start + entry.duration then out[#out + 1] = entry end
    end
    table.sort(out, function(a, b) return a.start < b.start end)
    return out
end

function Lockouts:Refresh()
    if ns.Panel and ns.Panel.boxes and ns.Box and ns.Box.UpdateLockoutIcon then
        local on = self:Enabled() and self:OnCells()
        for _, box in ipairs(ns.Panel.boxes) do
            if box.unit or box.lockoutIcon then
                ns.Box.UpdateLockoutIcon(box, on and self:ForUnit(box.unit) or nil)
            end
        end
    end
    if ns.CooldownBar and ns.CooldownBar.UpdateLockouts then ns.CooldownBar:UpdateLockouts() end
end

function Lockouts:DiagnosticLines()
    local count = 0
    for _ in pairs(self.active) do count = count + 1 end
    return {
        "Lockouts: " .. ((ns.db and ns.db.lockoutIcons) and "on" or "off")
            .. " (" .. self:Placement():lower() .. "), " .. tostring(#self:Relevant()) .. " relevant, "
            .. tostring(count) .. " active, " .. tostring(self.missed) .. " casts without a known target",
    }
end
