local addonName, ns = ...

-- Full-size, out-in-the-world test panel. Danders-style test frames are safer
-- than borrowing Salve's secure action buttons: the preview can disappear at
-- combat start without leaving clicks, units or AuraContainers in a fake state.
-- Appearance and geometry are still shared with the live panel through Box and
-- Panel, so changing Salve changes both rather than creating another imitation.

ns.Preview = {}
local Preview = ns.Preview

local MAX_BOXES = 40
local NAMES = {
    "Silverhammer", "Beaststalker", "Stormtotemic", "Nightstalker", "Spiritmender",
}
local CLASSES = { "PALADIN", "HUNTER", "SHAMAN", "ROGUE", "PRIEST" }
local FALLBACK_DISPEL_COLOURS = {
    Magic = { r = 0.20, g = 0.60, b = 1.00 },
    Curse = { r = 0.72, g = 0.28, b = 1.00 },
    Disease = { r = 1.00, g = 0.72, b = 0.08 },
    Poison = { r = 0.38, g = 1.00, b = 0.04 },
}

Preview.count = 5
Preview.cellState = "DISPELLABLE"
Preview.cooldownState = "COOLDOWN"

local function knownDispelTypes()
    local known, list = {}, {}
    for _, spell in ipairs(ns.knownDispels or {}) do
        for _, dispelType in ipairs(ns.DISPEL_TYPES or {}) do
            if spell.cures and spell.cures[dispelType] then known[dispelType] = true end
        end
    end
    for _, dispelType in ipairs(ns.DISPEL_TYPES or {}) do
        if known[dispelType] then list[#list + 1] = dispelType end
    end
    if #list == 0 then list[1] = "Poison" end
    return list
end

local function dispelColour(dispelType)
    local palette = _G.DebuffTypeColor
    local colour = palette and palette[dispelType]
    return colour or FALLBACK_DISPEL_COLOURS[dispelType]
        or FALLBACK_DISPEL_COLOURS.Poison
end

function Preview:NeedsDispel(index, count)
    if count <= 2 then return index == count end
    return index == 2 or index == math.min(count, 4)
end

function Preview:Create()
    if self.frame then return end

    local frame = CreateFrame("Frame", "SalvePreviewFrame", UIParent)
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:SetFrameStrata("DIALOG")
    frame:EnableMouse(true)
    frame:Hide()
    self.frame = frame
    self.boxes = {}

    for i = 1, MAX_BOXES do
        local box = ns.Box.CreatePreview(frame)
        box:Hide()
        self.boxes[i] = box
    end

    local blocker = CreateFrame("Frame", nil, UIParent)
    blocker:SetFrameStrata("DIALOG")
    blocker:SetFrameLevel(math.max(0, frame:GetFrameLevel() - 1))
    blocker:EnableMouse(true)
    blocker:Hide()
    self.blocker = blocker

    local handle = CreateFrame("Button", nil, frame)
    handle:SetSize(10, 10)
    handle:SetFrameLevel(frame:GetFrameLevel() + 20)
    handle:RegisterForDrag("LeftButton")
    handle:EnableMouse(true)
    local tex = handle:CreateTexture(nil, "ARTWORK")
    tex:SetAllPoints()
    tex:SetColorTexture(0.58, 0.43, 0.22, 0.85)
    local edge = handle:CreateTexture(nil, "BACKGROUND")
    edge:SetPoint("TOPLEFT", -1, 1)
    edge:SetPoint("BOTTOMRIGHT", 1, -1)
    edge:SetColorTexture(0, 0, 0, 0.9)
    handle:SetScript("OnDragStart", function()
        if not InCombatLockdown() then frame:StartMoving() end
    end)
    handle:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
        if ns.Panel and ns.Panel.SavePositionFromFrame then
            ns.Panel:SavePositionFromFrame(frame)
        else
            local point, _, relativePoint, x, y = frame:GetPoint()
            ns.db.point = { point, relativePoint, x, y }
        end
        if ns.Panel then ns.Panel:ApplyPosition() end
    end)
    self.handle = handle

    frame:SetScript("OnUpdate", function(_, elapsed)
        if not Preview.active or Preview.cooldownState ~= "COOLDOWN" then return end
        Preview.elapsed = (Preview.elapsed or 0) + elapsed
        if Preview.elapsed < 0.1 then return end
        Preview.elapsed = 0
        if not Preview.cooldownStart or GetTime() - Preview.cooldownStart >= 8 then
            Preview.cooldownStart = GetTime()
            for _, box in ipairs(Preview.boxes) do
                if box:IsShown() then
                    box.dispelCooldown:SetCooldown(Preview.cooldownStart, 8)
                end
            end
        end
    end)
end

function Preview:Refresh()
    if not self.active then return end
    self:Create()

    local frame = self.frame
    local point = ns.db.point
    frame:ClearAllPoints()
    frame:SetPoint(point[1], UIParent, point[2], point[3], point[4])
    if ns.Panel.NormalizeGrowthAnchor then ns.Panel:NormalizeGrowthAnchor(frame) end

    local count = math.max(1, math.min(MAX_BOXES, tonumber(self.count) or 5))
    local layout = ns.Panel:Layout(count)
    frame:SetScale(layout.scale)
    frame:SetSize(layout.frameWidth, layout.frameHeight)

    local types = knownDispelTypes()
    local now = GetTime()
    if self.cooldownState == "COOLDOWN"
        and (not self.cooldownStart or now - self.cooldownStart >= 8) then
        self.cooldownStart = now
    end

    for i, box in ipairs(self.boxes) do
        if i <= count then
            ns.Panel:PlaceBox(box, i, layout)
            ns.Box.RestylePreview(box,
                NAMES[((i - 1) % #NAMES) + 1],
                CLASSES[((i - 1) % #CLASSES) + 1])

            if self.cellState == "DISPELLABLE" and self:NeedsDispel(i, count) then
                local dispelType = types[((i - 1) % #types) + 1]
                local colour = dispelColour(dispelType)
                box.previewFill:SetColorTexture(colour.r, colour.g, colour.b, 1)
                box.previewFill:Show()
                box.previewStack:SetText(ns.db.showStacks and i == 4 and "2" or "")
            else
                box.previewFill:Hide()
                box.previewStack:SetText("")
            end

            if self.cooldownState == "COOLDOWN" then
                box.dispelCooldown:SetCooldown(self.cooldownStart, 8)
                box.dispelCooldown:Show()
            else
                if box.dispelCooldown.Clear then box.dispelCooldown:Clear() end
                box.dispelCooldown:Hide()
            end
            box:Show()
        else
            box:Hide()
        end
    end

    self.handle:SetShown(ns.db.showHandle and true or false)
    ns.Handle:PositionFrame(self.handle, frame)
    if ns.Panel and ns.Panel.frame then
        self.blocker:ClearAllPoints()
        self.blocker:SetPoint("TOPLEFT", ns.Panel.frame, "TOPLEFT")
        self.blocker:SetPoint("BOTTOMRIGHT", ns.Panel.frame, "BOTTOMRIGHT")
        self.blocker:Show()
    end
    frame:Show()
end

function Preview:Start()
    if InCombatLockdown() then
        ns.Print("panel preview is unavailable in combat")
        return false
    end
    if self.active then
        self:Refresh()
        return true
    end
    self:Create()
    self.active = true
    self.cooldownStart = GetTime()
    if ns.Panel and ns.Panel.frame then
        self.liveAlpha = ns.Panel.frame:GetAlpha()
        ns.Panel.frame:SetAlpha(0)
    end
    self:Refresh()
    return true
end

function Preview:Stop()
    if not self.active then return end
    self.active = false
    if self.frame then self.frame:Hide() end
    if self.blocker then self.blocker:Hide() end
    if ns.Panel and ns.Panel.frame then
        ns.Panel.frame:SetAlpha(self.liveAlpha or 1)
    end
    self.liveAlpha = nil
    if ns.Options and ns.Options.RefreshPreviewControls then
        ns.Options.RefreshPreviewControls()
    end
end

function Preview:Toggle()
    if self.active then
        self:Stop()
        return false
    end
    return self:Start()
end
