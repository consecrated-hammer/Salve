local addonName, ns = ...

-- Minimap button, hand-rolled in the same shape as Speedster's -- no LibDBIcon,
-- no LibDataBroker, nothing embedded. Position is an angle around the minimap,
-- saved so it survives a reload.

ns.Minimap = {}
local Minimap_ = ns.Minimap

local RADIUS    = 80
local ICON      = "Interface\\Icons\\Spell_Holy_Renew"

-- ☠ Salve always owns its own button, even when LibDBIcon happens to be loaded
--   by some other addon. Handing the job over would make the icon's position
--   depend on which addons are enabled. See the note in UI/Broker.lua.
function Minimap_:Create()
    if self.button then return self.button end

    local b = CreateFrame("Button", "SalveMinimapButton", Minimap)
    b:SetSize(31, 31)
    b:SetFrameStrata("MEDIUM")
    b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    b:GetHighlightTexture():SetBlendMode("ADD")

    local bg = b:CreateTexture(nil, "BACKGROUND")
    bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    bg:SetAllPoints()

    local icon = b:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", b, "TOPLEFT", 7, -7)
    icon:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -7, 7)
    icon:SetTexture(ICON)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    b.icon = icon

    local border = b:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetSize(54, 54)
    border:SetPoint("TOPLEFT")

    local function place(angle)
        local r = math.rad(angle or 225)
        b:ClearAllPoints()
        b:SetPoint("CENTER", Minimap, "CENTER",
            math.cos(r) * RADIUS, math.sin(r) * RADIUS)
    end

    -- ☠ atan2, NOT a two-argument math.atan. WoW runs Lua 5.1, where math.atan
    --   is UNARY: the second argument is silently discarded, so the angle ends
    --   up derived from vertical cursor movement alone and the icon cannot be
    --   dragged around the minimap. The two-argument form of math.atan is 5.3+.
    --   Fall back to math.atan only in case a future client drops atan2.
    local atan2 = math.atan2 or math.atan

    local function follow()
        local scale = Minimap:GetEffectiveScale()
        local cx, cy = GetCursorPosition()
        cx, cy = cx / scale, cy / scale
        local mx, my = Minimap:GetCenter()
        if not mx or not my then return end
        local angle = math.deg(atan2(cy - my, cx - mx))
        ns.db.minimapAngle = angle
        place(angle)
    end

    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:RegisterForDrag("LeftButton")

    b:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", follow)
    end)

    b:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
        self._dragged = true
    end)

    b:SetScript("OnClick", function(self, button)
        if self._dragged then self._dragged = nil return end
        -- ☠ ns.IsLocked(), never ns.db.locked. There is no `locked` key: the
        --   handle's visibility IS the lock state. Reading a key nothing writes
        --   made this a one-way switch that could hide the handle but never
        --   bring it back.
        if button == "RightButton" then
            ns.SetLocked(not ns.IsLocked())
        else
            ns.OpenOptions()
        end
    end)

    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("Salve")
        GameTooltip:AddLine("Click: open options", 0.85, 0.85, 0.85)
        GameTooltip:AddLine("Right-click: show or hide the drag handle", 0.85, 0.85, 0.85)
        GameTooltip:AddLine("Drag: move this icon", 0.85, 0.85, 0.85)
        GameTooltip:Show()
    end)

    b:SetScript("OnLeave", function() GameTooltip:Hide() end)

    place(ns.db.minimapAngle or 225)
    self.button = b
    return b
end

function Minimap_:Update()
    if not self.button then return end
    self.button:SetShown(ns.db.showMinimap and true or false)
end
