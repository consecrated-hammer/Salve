local addonName, ns = ...

-- ============================================================
-- Extra cell: your target or focus, in the next grid spot
-- ============================================================
-- One more secure box bound to the "target" (or "focus") token instead of a
-- group slot, so a random you click in the open world lights up like a
-- party member when they carry something you can remove.
--
-- Everything that has to work in a fight does, without Lua deciding:
--   * the click: the unit attribute is the token itself, so the game aims it
--     at whoever is targeted at the moment of the click;
--   * showing it: a secure state driver, "[@target,help,nodead] show; hide";
--   * the debuff colour: the same native container as every other cell,
--     set to the token once, then refreshed with UpdateAllAuras on every
--     target change (the pattern TPerl's target frame uses in combat).
--
-- ☠ IT MUST NEVER SHOW THE PREVIOUS TARGET'S DEBUFF. If the refresh is
--   refused, the cell's holder goes fully transparent until a refresh works.
--   Alpha is not protected, so that works in combat too.
--
-- Group members can be targeted as well. The state driver can't tell, so the
-- holder fades the cell out when the game says the target is in the group
-- (a secret answer goes through SetAlphaFromBoolean). A faded cell still
-- takes clicks, and a click still cleanses exactly who it would have shown.

ns.ExtraCell = { refreshOK = 0, refreshFailed = 0, refreshOKInCombat = 0 }
local ExtraCell = ns.ExtraCell

local UNITS = { TARGET = "target", FOCUS = "focus" }
local EVENTS = { target = "PLAYER_TARGET_CHANGED", focus = "PLAYER_FOCUS_CHANGED" }

local function isSecret(value)
    return issecretvalue and issecretvalue(value) and true or false
end

function ExtraCell:Unit()
    return UNITS[ns.db and ns.db.extraCell or "OFF"]
end

-- Built with the panel: a holder for the fade, and the box inside it.
function ExtraCell:Create(panelFrame)
    if self.box then return self.box end
    local holder = CreateFrame("Frame", nil, panelFrame)
    holder:SetAllPoints(panelFrame)
    self.holder = holder
    self.box = ns.Box.Create("Extra", holder)
    self.box.isExtraCell = true
    self.box:Hide()
    return self.box
end

-- Out of combat only: Panel:Rebuild calls this after placing the group.
-- `index` is the next grid position, `layout` the group's layout, `cell` an
-- attachment's position to sit after, when attached.
function ExtraCell:Rebuild(index, layout, lastCell)
    local box = self.box
    if not box then return end
    local unit = ns.CanDispel() and self:Unit() or nil

    if RegisterStateDriver then pcall(UnregisterStateDriver, box, "visibility") end
    if not unit then
        if box.unit then ns.Binding:Park(box) end
        box.unit = nil
        box:Hide()
        self.boundEvent = nil
        self:Listen()
        return
    end

    ns.Box.Bind(box, unit)
    ns.Box.Restyle(box)
    if lastCell then
        ns.Panel:PlaceBoxAt(box, {
            x = lastCell.x, y = lastCell.y - (layout.height + layout.spacing),
        }, layout)
    else
        ns.Panel:PlaceBox(box, index, layout)
    end

    if not ns.Binding:Attach(box, unit) then
        -- No native colour means the cell could only ever look clean: keep it
        -- off screen rather than offer a box that can't light up.
        box:Hide()
        self.lastFailure = ns.Binding.lastFailure or "aura container unavailable"
        self.boundEvent = nil
        self:Listen()
        return
    end
    self.lastFailure = nil

    RegisterStateDriver(box, "visibility", "[@" .. unit .. ",help,nodead] show; hide")
    self.boundEvent = EVENTS[unit]
    self:Listen()
    self:Changed()
end

-- The target or focus changed: repoint the colour, name and fades.
function ExtraCell:Changed()
    local box = self.box
    if not (box and box.unit and box.auraContainer) then return end
    local c = box.auraContainer
    local ok = c.UpdateAllAuras and pcall(c.UpdateAllAuras, c)
    if ok then
        self.refreshOK = self.refreshOK + 1
        if InCombatLockdown and InCombatLockdown() then
            self.refreshOKInCombat = self.refreshOKInCombat + 1
        end
        self.stale = false
    else
        self.refreshFailed = self.refreshFailed + 1
        self.stale = true
    end
    self:Record()
    ns.Box.Restyle(box)
    if ns.Range then ns.Range:Apply(box) end
    self:ApplyFade()
end

-- Holder alpha: hidden while stale, faded out for group members.
function ExtraCell:ApplyFade()
    local holder, box = self.holder, self.box
    if not (holder and box and box.unit) then return end
    if self.stale then
        holder:SetAlpha(0)
        return
    end
    if not (ns.db and ns.db.extraCellSkipGroup ~= false) then
        holder:SetAlpha(1)
        return
    end
    local inGroup = false
    -- You have your own cell already.
    if UnitIsUnit then
        local ok, value = pcall(UnitIsUnit, box.unit, "player")
        if ok then inGroup = value end
    end
    if not isSecret(inGroup) and not inGroup and UnitPlayerOrPetInRaid then
        local ok, value = pcall(UnitPlayerOrPetInRaid, box.unit)
        if ok then inGroup = value end
    end
    if not isSecret(inGroup) and not inGroup and UnitPlayerOrPetInParty then
        local ok, value = pcall(UnitPlayerOrPetInParty, box.unit)
        if ok then inGroup = value end
    end
    if isSecret(inGroup) then
        if holder.SetAlphaFromBoolean then
            holder:SetAlphaFromBoolean(inGroup, 0, 1)
        else
            holder:SetAlpha(1)
        end
    else
        holder:SetAlpha(inGroup and 0 or 1)
    end
end

-- Kept with the secrecy counts so a key or raid can be checked afterwards
-- from SavedVariables.
function ExtraCell:Record()
    if type(SalveClickLog) ~= "table" then return end
    SalveClickLog.extraCell = {
        unit = self.box and self.box.unit,
        refreshOK = self.refreshOK,
        refreshOKInCombat = self.refreshOKInCombat,
        refreshFailed = self.refreshFailed,
        last = date and date("%Y-%m-%d %H:%M") or nil,
    }
end

function ExtraCell:DiagnosticLines()
    local unit = self.box and self.box.unit
    return {
        "Extra cell: " .. (unit or "off")
            .. ", refreshes " .. self.refreshOK .. " (in combat " .. self.refreshOKInCombat .. ")"
            .. ", refused " .. self.refreshFailed
            .. (self.lastFailure and (", " .. self.lastFailure) or ""),
    }
end

local frame = CreateFrame("Frame")
frame:SetScript("OnEvent", function(_, event)
    if event == ExtraCell.boundEvent then
        ExtraCell:Changed()
    elseif event == "GROUP_ROSTER_UPDATE" then
        ExtraCell:ApplyFade()
    end
end)

function ExtraCell:Listen()
    for _, event in pairs(EVENTS) do pcall(frame.UnregisterEvent, frame, event) end
    pcall(frame.UnregisterEvent, frame, "GROUP_ROSTER_UPDATE")
    if self.boundEvent then
        pcall(frame.RegisterEvent, frame, self.boundEvent)
        pcall(frame.RegisterEvent, frame, "GROUP_ROSTER_UPDATE")
    end
end
