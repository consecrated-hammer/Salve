local addonName, ns = ...

ns.Panel = {}
local Panel = ns.Panel

local MAX_BOXES = 40

Panel.boxes = {}

-- ── Roster ─────────────────────────────────────────────────────────────────

local function unitList()
    local units = {}
    local db = ns.db

    if IsInRaid() then
        if not db.showInRaid then return units end
        for i = 1, MAX_RAID_MEMBERS or 40 do
            local u = "raid" .. i
            if UnitExists(u) then units[#units + 1] = u end
        end
    elseif IsInGroup() then
        if not db.showInParty then return units end
        units[1] = "player"
        for i = 1, 4 do
            local u = "party" .. i
            if UnitExists(u) then units[#units + 1] = u end
        end
    else
        if not db.showInSolo then return units end
        units[1] = "player"
    end

    return units
end

-- ── Creation ───────────────────────────────────────────────────────────────

function Panel:Create()
    if self.frame then return end

    local f = CreateFrame("Frame", "SalveFrame", UIParent)
    f:SetClampedToScreen(true)
    -- Movable, but never dragged by its own surface: the boxes cover it
    -- completely. UI/Mover.lua raises a handle above them instead.
    f:SetMovable(true)

    local p = ns.db.point
    f:SetPoint(p[1], UIParent, p[2], p[3], p[4])

    self.frame = f

    for i = 1, MAX_BOXES do
        self.boxes[i] = ns.Box.Create(i, f)
        self.boxes[i]:Hide()
    end

    ns.Handle:Create(f)
    ns.Handle:Update()
end

-- ── Rebuild ────────────────────────────────────────────────────────────────
-- Writes secure attributes and geometry, so out of combat only. Everything
-- inside is cheap and runs on roster changes, not on aura ticks.

function Panel:Rebuild()
    if not self.frame or InCombatLockdown() then return end

    -- ☠ ARM THE SOUND SUPPRESSION FIRST, BEFORE ANY BINDING HAPPENS. Binding a
    --   slot makes the engine fire its show event for auras that are ALREADY
    --   present, and those events arrive DURING the Attach loop below. Arming
    --   afterwards left a window in which a login, a /reload or a roster change
    --   mid-fight set off the alert for every debuff currently up -- the exact
    --   noise the settle window exists to prevent.
    ns.Sound:Settle()

    local db       = ns.db
    local failures = 0
    local units    = ns.CanDispel() and unitList() or {}
    local cols  = math.max(1, db.columns)
    local w, h  = db.boxWidth, db.boxHeight
    local pad   = db.spacing

    for i = 1, MAX_BOXES do
        local box  = self.boxes[i]
        local unit = units[i]

        if unit then
            ns.Box.Bind(box, unit)
            ns.Box.Restyle(box)

            -- HORIZONTAL fills across then wraps down; VERTICAL fills down then
            -- wraps across. `cols` is the wrap point in both cases.
            local n0 = i - 1
            local col, row
            if db.orientation == "VERTICAL" then
                col, row = math.floor(n0 / cols), n0 % cols
            else
                col, row = n0 % cols, math.floor(n0 / cols)
            end

            box:SetSize(w, h)
            box:ClearAllPoints()
            box:SetPoint("TOPLEFT", self.frame, "TOPLEFT",
                col * (w + pad), -row * (h + pad))
            box:Show()

            -- Hand the box to the engine. After this it runs without us.
            -- A failure means that member's box will render and click but never
            -- light up, so record it rather than letting it pass unnoticed.
            if not ns.Binding:Attach(box, unit) then
                failures = failures + 1
            end
        else
            -- Park, don't detach: the container is expensive and unreclaimable,
            -- and a shrinking group is a routine event, not a teardown.
            ns.Binding:Park(box)
            box.unit = nil
            box:Hide()
        end
    end

    local n = #units
    self.frame:SetScale(db.scale)

    if n > 0 then
        -- The wrap axis swaps with the orientation, so the frame's extent does
        -- too: horizontal grows wide then tall, vertical grows tall then wide.
        local across, down
        if db.orientation == "VERTICAL" then
            across, down = math.ceil(n / cols), math.min(n, cols)
        else
            across, down = math.min(n, cols), math.ceil(n / cols)
        end
        self.frame:SetSize(across * w + (across - 1) * pad,
                           down * h + (down - 1) * pad)
        self.frame:Show()
    else
        self.frame:Hide()
    end

    ns.Handle:Update()

    -- Re-arm: the window is measured from the LAST binding, and UpdateAllAuras
    -- can deliver its show events a frame or two after Attach returns.
    ns.Sound:Settle()

    -- Warn ONCE per session. Silent binding failure is the worst outcome here:
    -- the panel looks perfectly healthy and simply never lights up, which reads
    -- as "no debuffs" rather than "broken". Told once, not every rebuild.
    if failures > 0 then
        ns.Binding.lastFailure = failures .. " of " .. #units .. " boxes, "
            .. date("%H:%M:%S")
        if not self.warnedFailure then
            self.warnedFailure = true
            ns.Print("|cffff4444" .. failures .. " box(es) could not bind to the aura engine.|r "
                .. "They will click but never light up. Run |cffffd100/salve probe|r.")
        end
    end
end

-- ── Restyle ────────────────────────────────────────────────────────────────
-- Names and dimming only. Safe in combat: touches nothing secure and nothing
-- the engine owns.

function Panel:Restyle()
    if not self.frame then return end
    for i = 1, MAX_BOXES do
        local box = self.boxes[i]
        if box.unit then ns.Box.Restyle(box) end
    end
end

-- ☠ Re-anchoring a frame full of protected buttons is a blocked action in
--   combat. /salve reset and the options button can both land here mid-fight,
--   so defer rather than firing a taint error and silently not moving.
function Panel:ApplyPosition()
    if not self.frame then return end

    if InCombatLockdown() then
        ns.deferredPosition = true
        ns.Print("panel will move when you leave combat")
        return
    end

    ns.deferredPosition = false
    local p = ns.db.point
    self.frame:ClearAllPoints()
    self.frame:SetPoint(p[1], UIParent, p[2], p[3], p[4])
end
