local addonName, ns = ...

ns.Panel = {}
local Panel = ns.Panel

local MAX_BOXES = 40

Panel.boxes = {}

-- The frame itself is anchored to the edge selected by Grid flow. Reversing
-- cell coordinates alone would change roster order but still make a growing
-- frame expand across the edge the player lined up with another addon.
function Panel:GrowthAnchor()
    if ns.db.orientation == "VERTICAL" then
        return ns.db.verticalGrowth == "UP" and "BOTTOMLEFT" or "TOPLEFT"
    end
    return ns.db.horizontalGrowth == "LEFT" and "TOPRIGHT" or "TOPLEFT"
end

function Panel:SavePositionFromFrame(frame)
    if not frame then return false end
    local anchor = self:GrowthAnchor()
    local left, right = frame:GetLeft(), frame:GetRight()
    local top, bottom = frame:GetTop(), frame:GetBottom()
    if not (left and right and top and bottom) then return false end

    local x = anchor == "TOPRIGHT" and right or left
    local y = anchor == "BOTTOMLEFT" and bottom or top
    ns.db.point = { anchor, "BOTTOMLEFT", x, y }
    return true
end

function Panel:NormalizeGrowthAnchor(frame)
    if not frame then return false end
    local point, _, relativePoint = frame:GetPoint()
    local desired = self:GrowthAnchor()
    if point == desired and relativePoint == "BOTTOMLEFT" then return true end
    if not self:SavePositionFromFrame(frame) then return false end
    local saved = ns.db.point
    frame:ClearAllPoints()
    frame:SetPoint(saved[1], UIParent, saved[2], saved[3], saved[4])
    return true
end

-- One geometry function owns both live and test panels. The test panel is not
-- a scaled drawing inside Settings: it is laid out in UIParent with these exact
-- box dimensions, gaps, wrap rules and overall scale.
function Panel:Layout(count)
    local db = ns.db
    local cols = math.max(1, db.columns)
    local across, down
    if db.orientation == "VERTICAL" then
        across, down = math.ceil(count / cols), math.min(count, cols)
    else
        across, down = math.min(count, cols), math.ceil(count / cols)
    end
    return {
        count = count,
        columns = cols,
        width = db.boxWidth,
        height = db.boxHeight,
        spacing = db.spacing,
        scale = db.scale,
        orientation = db.orientation,
        horizontalGrowth = db.horizontalGrowth or "RIGHT",
        verticalGrowth = db.verticalGrowth or "DOWN",
        across = across,
        down = down,
        frameWidth = across * db.boxWidth + math.max(0, across - 1) * db.spacing,
        frameHeight = down * db.boxHeight + math.max(0, down - 1) * db.spacing,
    }
end

function Panel:PlaceBox(box, index, layout)
    local n0 = index - 1
    local col, row
    if layout.orientation == "VERTICAL" then
        col, row = math.floor(n0 / layout.columns), n0 % layout.columns
        if layout.verticalGrowth == "UP" then row = layout.down - 1 - row end
    else
        col, row = n0 % layout.columns, math.floor(n0 / layout.columns)
        if layout.horizontalGrowth == "LEFT" then col = layout.across - 1 - col end
    end

    box:SetSize(layout.width, layout.height)
    box:ClearAllPoints()
    box:SetPoint("TOPLEFT", box:GetParent(), "TOPLEFT",
        col * (layout.width + layout.spacing),
        -row * (layout.height + layout.spacing))
end

-- ── Roster ─────────────────────────────────────────────────────────────────

local function unitList()
    local units = {}

    -- ☠ No show/hide decisions here. Which GROUP you are in decides how many
    --   boxes exist; WHETHER the panel is on screen is Features/Visibility.lua's
    --   job, via a state driver that keeps working in combat.
    if IsInRaid() then
        for i = 1, MAX_RAID_MEMBERS or 40 do
            local u = "raid" .. i
            if UnitExists(u) then units[#units + 1] = u end
        end
    elseif IsInGroup() then
        units[1] = "player"
        for i = 1, 4 do
            local u = "party" .. i
            if UnitExists(u) then units[#units + 1] = u end
        end
    else
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

    self:NormalizeGrowthAnchor(self.frame)
    local failures = 0
    local units    = ns.CanDispel() and unitList() or {}
    local layout = self:Layout(#units)

    for i = 1, MAX_BOXES do
        local box  = self.boxes[i]
        local unit = units[i]

        if unit then
            ns.Box.Bind(box, unit)
            ns.Box.Restyle(box)

            self:PlaceBox(box, i, layout)
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
    self.frame:SetScale(layout.scale)

    if n > 0 then
        self.frame:SetSize(layout.frameWidth, layout.frameHeight)
    end

    -- ☠ Visibility is a STATE DRIVER, not Show()/Hide(). The panel is protected,
    --   so Lua may not show or hide it in combat -- which is precisely when a
    --   "hide out of combat" rule needs to act. Blizzard's secure environment
    --   evaluates the rule instead. See Features/Visibility.lua.
    ns.Visibility:Apply(self.frame, n > 0)

    ns.Handle:Update()


    -- Warn ONCE per session. Silent binding failure is the worst outcome here:
    -- the panel looks perfectly healthy and simply never lights up, which reads
    -- as "no debuffs" rather than "broken". Told once, not every rebuild.
    if failures > 0 then
        ns.Binding.lastFailure = failures .. " of " .. #units .. " boxes, "
            .. date("%H:%M:%S")
        if not self.warnedFailure then
            self.warnedFailure = true
            ns.Print("|cffff4444" .. failures .. " box(es) could not bind to the aura engine.|r "
                .. "They will click but never light up. Run |cffffd100/salve debug|r.")
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
    self:NormalizeGrowthAnchor(self.frame)
end
