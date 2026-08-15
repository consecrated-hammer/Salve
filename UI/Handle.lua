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

function Handle:Create(parent)
    if self.frame then return self.frame end

    local h = CreateFrame("Button", "SalveHandle", parent)
    h:SetSize(SIZE, SIZE)
    h:SetPoint("BOTTOMRIGHT", parent, "TOPLEFT", -1, 1)
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

    h:SetScript("OnDragStart", function()
        if InCombatLockdown() then
            ns.Print("can't move the panel in combat")
            return
        end
        parent:StartMoving()
    end)

    h:SetScript("OnDragStop", function()
        parent:StopMovingOrSizing()
        local point, _, rel, x, y = parent:GetPoint()
        ns.db.point = { point, rel, x, y }
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
    return h
end

function Handle:Update()
    if not self.frame then return end

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
