local addonName, ns = ...

-- ============================================================
-- The drag handle
-- ============================================================
-- Decursive kept a small permanent grip beside its grid rather than hiding
-- movement behind an unlock mode, and it is the better idea: the panel cannot
-- be dragged by its own surface (the boxes are buttons and cover every pixel),
-- and at 20x20 with everyone clean there is almost nothing on screen to aim at.
--
-- So the grip is always there unless you turn it off, and it is the only thing
-- that moves the panel.

ns.Handle = {}
local Handle = ns.Handle

local SIZE = 10

function Handle:Position()
    if not self.frame or not ns.Panel or not ns.Panel.frame then return end
    local h, parent = self.frame, ns.Panel.frame
    local position = ns.db.handlePosition or "TOPLEFT"
    local halfCell = (ns.db.boxWidth or 20) / 2

    h:ClearAllPoints()
    if position == "LEFT" then
        h:SetPoint("RIGHT", parent, "LEFT", -1, 0)
    elseif position == "TOP" then
        h:SetPoint("BOTTOM", parent, "TOP", 0, 1)
    elseif position == "TOPRIGHT" then
        h:SetPoint("BOTTOM", parent, "TOPRIGHT", -halfCell, 1)
    elseif position == "RIGHT" then
        h:SetPoint("LEFT", parent, "RIGHT", 1, 0)
    elseif position == "BOTTOMRIGHT" then
        h:SetPoint("TOP", parent, "BOTTOMRIGHT", -halfCell, -1)
    elseif position == "BOTTOM" then
        h:SetPoint("TOP", parent, "BOTTOM", 0, -1)
    elseif position == "BOTTOMLEFT" then
        h:SetPoint("TOP", parent, "BOTTOMLEFT", halfCell, -1)
    else
        -- Top-left is centred over cell 1 rather than hanging off the panel's
        -- corner. That keeps the default useful even for unusual grid shapes.
        h:SetPoint("BOTTOM", parent, "TOPLEFT", halfCell, 1)
    end
end

function Handle:Create(parent)
    if self.frame then return self.frame end

    local h = CreateFrame("Button", "SalveHandle", parent)
    h:SetSize(SIZE, SIZE)
    h:SetFrameLevel(parent:GetFrameLevel() + 20)
    h:RegisterForDrag("LeftButton")
    h:EnableMouse(true)

    local tex = h:CreateTexture(nil, "ARTWORK")
    tex:SetAllPoints()
    tex:SetColorTexture(0.58, 0.43, 0.22, 0.85)
    h.tex = tex

    local edge = h:CreateTexture(nil, "OVERLAY")
    edge:SetPoint("TOPLEFT", -1, 1)
    edge:SetPoint("BOTTOMRIGHT", 1, -1)
    edge:SetColorTexture(0, 0, 0, 0.9)
    edge:SetDrawLayer("BACKGROUND")

    h:SetScript("OnDragStart", function(self)
        if InCombatLockdown() then
            ns.Print("can't move the panel in combat")
            return
        end
        self.dragging = true
        parent:StartMoving()
    end)

    h:SetScript("OnDragStop", function(self)
        -- ☠ Only release a drag we actually started. OnDragStop fires even when
        --   OnDragStart bailed out, and StopMovingOrSizing repositions a frame
        --   full of secure buttons -- a blocked action in combat. Refusing the
        --   drag and then moving the panel anyway is the worst of both.
        if not self.dragging then return end
        self.dragging = nil

        -- ☠ A drag begun out of combat can END in it, and StopMovingOrSizing is
        --   protected. Swallowing that failure is not enough: the panel stays
        --   attached to the cursor with nothing scheduled to release it, so it
        --   follows the mouse for the rest of the fight. Queue the release and
        --   finish it the moment combat ends.
        if InCombatLockdown() then
            ns.pendingDragStop = true
            ns.Print("panel will settle where you dropped it when combat ends")
            return
        end

        Handle:Release()
    end)

    h:SetScript("OnEnter", function(self)
        self.tex:SetColorTexture(1, 0.82, 0.26, 1)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Salve")
        GameTooltip:AddLine("Drag: move the panel", 0.85, 0.85, 0.85)
        GameTooltip:AddLine("Right-click: options", 0.85, 0.85, 0.85)
        GameTooltip:Show()
    end)

    h:SetScript("OnLeave", function(self)
        self.tex:SetColorTexture(0.58, 0.43, 0.22, 0.85)
        GameTooltip:Hide()
    end)

    h:RegisterForClicks("RightButtonUp")
    h:SetScript("OnClick", function() ns.OpenOptions() end)

    self.frame = h
    self:Position()
    return h
end

-- Stops the panel following the cursor and records where it ended up. Safe to
-- call twice; only meaningful out of combat.
function Handle:Release()
    local panel = ns.Panel and ns.Panel.frame
    if not panel or InCombatLockdown() then return false end

    panel:StopMovingOrSizing()
    local point, _, rel, x, y = panel:GetPoint()
    ns.db.point = { point, rel, x, y }
    ns.pendingDragStop = false
    return true
end

function Handle:Update()
    if not self.frame then return end

    self:Position()

    -- ☠ DO NOT AND THIS WITH THE PANEL'S IsShown(). The handle is a CHILD of the
    --   panel, so it already disappears with it -- the extra term only ever
    --   latched an explicit hide. Visibility is a state driver now: the panel
    --   can be shown by the secure environment long after the last rebuild, and
    --   nothing calls back here when it does. A handle hidden because the panel
    --   happened to be invisible when you ticked a condition stayed hidden for
    --   good, leaving a panel that could not be dragged.
    self.frame:SetShown(ns.db.showHandle and true or false)
end

-- "Locked" and "no handle" are the same state, so there is one flag and this is
-- the only way to set it. The slash command, the options checkbox, the minimap
-- button and the broker launcher all come through here, which is what stops the
-- grip drifting out of step with the saved value.
function ns.SetLocked(locked)
    ns.db.showHandle = not locked
    ns.Handle:Update()
    return locked
end

function ns.IsLocked()
    return not ns.db.showHandle
end
