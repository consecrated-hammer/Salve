local addonName, ns = ...

ns.Panel = {}
local Panel = ns.Panel

local MAX_BOXES = 40

Panel.boxes = {}

function Panel:SetMovementPrompt(spell, active)
    local spellID = spell and spell.id
    local key = spellID and ns.Bindings and ns.Bindings:FirstKeyForSpell(spellID)
    for _, box in ipairs(self.boxes) do
        local isPlayer = box.unit == "player"
            or (ns.Escape and ns.Escape.IsPlayerUnit and ns.Escape:IsPlayerUnit(box.unit))
        if isPlayer then
            ns.Box.SetMovementPrompt(box, active and key ~= nil)
        end
    end
end

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

-- An attachment's cell position, already relative to the frame's top left.
function Panel:PlaceBoxAt(box, cell, layout)
    box:SetSize(layout.width, layout.height)
    box:ClearAllPoints()
    box:SetPoint("TOPLEFT", box:GetParent(), "TOPLEFT", cell.x, cell.y)
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

-- ── Sort order ─────────────────────────────────────────────────────────────
-- Sorting only permutes which box gets which unit token, and it runs inside
-- Rebuild, so out of combat and outside encounters only. A roster change in
-- combat still waits for the next rebuild, sorted or not.

local function readable(value)
    return value ~= nil and not (issecretvalue and issecretvalue(value))
end

-- Retail 12 moved the spec lookups into C_SpecializationInfo; the globals
-- are only a fallback for clients that still have them.
local function playerSpecRole()
    local api = C_SpecializationInfo
    local getSpec = api and api.GetSpecialization or GetSpecialization
    local getRole = api and api.GetSpecializationRole or GetSpecializationRole
    if not (getSpec and getRole) then return nil end
    local ok, spec = pcall(getSpec)
    if not ok or not readable(spec) or type(spec) ~= "number" then return nil end
    local okRole, role = pcall(getRole, spec)
    return okRole and readable(role) and role or nil
end

-- ☠ Compare nothing that might be secret. UnitName can be secret in
--   restricted content and comparing one is a hard error, so an unreadable
--   name or role becomes nil and that member falls back to group order.
local function unitEntry(unit, index)
    local isPlayer = unit == "player"
        or (ns.Escape and ns.Escape.IsPlayerUnit and ns.Escape:IsPlayerUnit(unit)) or false
    local role = UnitGroupRolesAssigned and UnitGroupRolesAssigned(unit)
    if not readable(role) or (role ~= "TANK" and role ~= "HEALER" and role ~= "DAMAGER") then
        role = isPlayer and playerSpecRole() or nil
    end
    local name = UnitName and UnitName(unit)
    if not readable(name) or type(name) ~= "string" or name == ""
        or name == UNKNOWNOBJECT then
        name = nil
    end
    return { unit = unit, index = index, role = role, name = name, isPlayer = isPlayer }
end

-- Shared by the live panel and the test panel. Each entry carries `index`
-- (its group order), `isPlayer`, and optional readable `role` and `name`.
function Panel:SortEntries(entries)
    local db = ns.db
    local mode, selfPosition = db.sortMode or "GROUP", db.sortSelf or "SORTED"

    local rank = {}
    if mode == "ROLE" then
        local position = 0
        for role in string.gmatch(db.sortRoleOrder or "TANK,HEALER,DAMAGER", "[^,]+") do
            position = position + 1
            rank[role] = position
        end
    end

    -- A total order: every tie falls through to group order, so table.sort's
    -- instability can never shuffle equal members between rebuilds.
    local function before(a, b)
        if mode == "ROLE" then
            local ra, rb = rank[a.role] or 4, rank[b.role] or 4
            if ra ~= rb then return ra < rb end
        elseif mode == "NAME" then
            local na, nb = a.name and a.name:lower(), b.name and b.name:lower()
            if na and nb then
                if na ~= nb then return na < nb end
            elseif na or nb then
                return na ~= nil
            end
        end
        return a.index < b.index
    end

    local player, rest = nil, {}
    for _, entry in ipairs(entries) do
        if selfPosition ~= "SORTED" and entry.isPlayer and not player then
            player = entry
        else
            rest[#rest + 1] = entry
        end
    end
    table.sort(rest, before)

    local sorted = {}
    if db.sortReverse then
        for i = #rest, 1, -1 do sorted[#sorted + 1] = rest[i] end
    else
        sorted = rest
    end
    if player then
        table.insert(sorted, selfPosition == "FIRST" and 1 or #sorted + 1, player)
    end
    return sorted
end

function Panel:SortUnits(units)
    local db = ns.db
    if (db.sortMode or "GROUP") == "GROUP" and not db.sortReverse
        and (db.sortSelf or "SORTED") == "SORTED" then
        return units
    end
    local entries = {}
    for index, unit in ipairs(units) do entries[index] = unitEntry(unit, index) end
    local sorted = {}
    for index, entry in ipairs(self:SortEntries(entries)) do sorted[index] = entry.unit end
    return sorted
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
    if not self.frame
        or (ns.StructuralChangesUnsafe and ns.StructuralChangesUnsafe())
        or (not ns.StructuralChangesUnsafe and InCombatLockdown()) then
        return
    end

    local failures = 0
    local units    = ns.CanDispel() and unitList()
        or (ns.PersonalDispel and ns.PersonalDispel:Enabled() and { "player" }) or {}
    local layout = self:Layout(#units)
    -- Scale first: attaching measures in screen pixels, which depends on it.
    self.frame:SetScale(layout.scale)

    -- Attached beside a host, the host's order wins and cells follow its
    -- frames by unit. Otherwise Salve's own sort and grid apply.
    local plan = ns.Attach and ns.Attach:Plan(units, layout, self.frame:GetEffectiveScale())
    if not (plan and plan.cells) and ns.CanDispel() then units = self:SortUnits(units) end
    if plan then
        self.frame:ClearAllPoints()
        self.frame:SetPoint(plan.point, plan.anchor, plan.anchorPoint, plan.x, plan.y)
    else
        -- Coming back from an attachment: return to the saved position, which
        -- attaching never overwrites.
        if self.attached then
            local p = ns.db.point
            self.frame:ClearAllPoints()
            self.frame:SetPoint(p[1], UIParent, p[2], p[3], p[4])
        end
        -- ☠ Size before normalising. The frame may still carry the attached
        --   plan's size, and normalising re-saves the point from its edges.
        if #units > 0 then self.frame:SetSize(layout.frameWidth, layout.frameHeight) end
        self:NormalizeGrowthAnchor(self.frame)
    end
    self.attached = plan ~= nil

    for i = 1, MAX_BOXES do
        local box  = self.boxes[i]
        local unit = units[i]
        if unit and ns.PersonalDispel then unit = ns.PersonalDispel:CellUnit(unit) end

        if unit then
            ns.Box.Bind(box, unit)
            ns.Box.Restyle(box)

            if plan and plan.cells then
                self:PlaceBoxAt(box, plan.cells[i], layout)
            else
                self:PlaceBox(box, i, layout)
            end
            box:Show()

            -- Hand the box to the engine. After this it runs without us.
            -- A failure means that member's box will render and click but never
            -- light up, so record it rather than letting it pass unnoticed.
            if ns.CanDispel() then
                if not ns.Binding:Attach(box, unit) then failures = failures + 1 end
            else
                ns.Binding:Park(box)
            end
            if ns.PersonalDispel then ns.PersonalDispel:Attach(box, unit) end
        else
            -- Park, don't detach: the container is expensive and unreclaimable,
            -- and a shrinking group is a routine event, not a teardown.
            ns.Binding:Park(box)
            box.unit = nil
            if box.personalDispelHolder then box.personalDispelHolder:SetAlpha(0) end
            box:Hide()
        end
    end

    local n = #units
    if n > 0 then
        self.frame:SetSize(plan and plan.width or layout.frameWidth,
            plan and plan.height or layout.frameHeight)
    end

    -- ☠ Visibility is a STATE DRIVER, not Show()/Hide(). The panel is protected,
    --   so Lua may not show or hide it in combat -- which is precisely when a
    --   "hide out of combat" rule needs to act. Blizzard's secure environment
    --   evaluates the rule instead. See Features/Visibility.lua.
    ns.Visibility:Apply(self.frame, n > 0)

    ns.Handle:Update()
    if ns.Options and ns.Options.RefreshAttachStatus then ns.Options.RefreshAttachStatus() end

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
    -- Attached, the host decides where Salve goes. Re-measure instead.
    if self.attached then
        ns.RequestRebuild()
        return
    end
    local p = ns.db.point
    self.frame:ClearAllPoints()
    self.frame:SetPoint(p[1], UIParent, p[2], p[3], p[4])
    self:NormalizeGrowthAnchor(self.frame)
end
