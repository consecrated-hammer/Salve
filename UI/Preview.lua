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
    -- Each is twelve characters: the Named preset needs to prove it can carry
    -- a realistic player name rather than flattering itself with short labels.
    "Ravenstriker", "Nyxmoonblade", "Thornwhisper", "Shadowmender", "Stormwardenx",
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
Preview.movementSweepState = false

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

local function previewSweepSpellIDs()
    local ids = {}
    for id, enabled in pairs((ns.db and ns.db.movementSweepSpellIDs) or {}) do
        if enabled and type(id) == "number" then ids[#ids + 1] = id end
    end
    table.sort(ids)
    if #ids == 0 and ns.db and type(ns.db.movementSweepSpellID) == "number" then
        ids[1] = ns.db.movementSweepSpellID
    end
    return ids
end

function Preview:NeedsDispel(index, count)
    if count <= 2 then return index == count end
    return index == 2 or index == math.min(count, 4)
end

-- Both preview hosts use the same non-secure boxes, layout calculation and
-- restyling as Salve's live panel. The Settings host is clipped and scales down
-- only when the configured grid cannot fit its preview stage.
local function renderBoxes(boxes, frame, count, layout, state, cooldownState,
        cooldownStart, movementSweepState, movementSweepStart)
    local types = knownDispelTypes()
    for i, box in ipairs(boxes) do
        if i <= count then
            ns.Panel:PlaceBox(box, i, layout)
            ns.Box.RestylePreview(box,
                NAMES[((i - 1) % #NAMES) + 1],
                CLASSES[((i - 1) % #CLASSES) + 1])

            if state == "DISPELLABLE" and Preview:NeedsDispel(i, count) then
                local colour = dispelColour(types[((i - 1) % #types) + 1])
                box.previewFill:SetColorTexture(colour.r, colour.g, colour.b, 1)
                box.previewFill:Show()
                box.previewStack:SetText(ns.db.showStacks and i == 4 and "2" or "")
            else
                box.previewFill:Hide()
                box.previewStack:SetText("")
            end

            if cooldownState == "COOLDOWN" then
                box.dispelCooldown:SetCooldown(cooldownStart, 8)
                box.dispelCooldown:Show()
            else
                if box.dispelCooldown.Clear then box.dispelCooldown:Clear() end
                box.dispelCooldown:Hide()
            end
            local sweeps = movementSweepState and i == 1 and previewSweepSpellIDs() or {}
            local cooldowns = box.movementCooldowns or { box.movementCooldown }
            while #cooldowns < #sweeps and ns.Box and ns.Box.CreateMovementCooldown do
                cooldowns[#cooldowns + 1] = ns.Box.CreateMovementCooldown(box, #cooldowns + 1)
            end
            for index, cooldown in ipairs(cooldowns) do
                local spellID = sweeps[index]
                if spellID then
                    local r, g, b, a = ns.Binding:GetMovementSweepColour(spellID)
                    if cooldown.SetDrawSwipe then cooldown:SetDrawSwipe(false) end
                    if cooldown.SetDrawEdge then cooldown:SetDrawEdge(true) end
                    if cooldown.SetEdgeColor then cooldown:SetEdgeColor(r, g, b, a) end
                    cooldown:SetCooldown(movementSweepStart - (index - 1) * 5, 25)
                    cooldown:Show()
                else
                    if cooldown.Clear then cooldown:Clear() end
                    cooldown:Hide()
                end
            end
            box:Show()
        else
            box:Hide()
        end
    end
end

function Preview:CreateSettingsPreview(parent, top, left, width, height)
    if self.settingsPreview and self.settingsPreview.parent == parent then return end

    width = width or 508
    height = height or 100
    local viewport = CreateFrame("Frame", nil, parent)
    viewport:SetPoint("TOPLEFT", left or 10, top or -24)
    viewport:SetSize(width, height)
    if viewport.SetClipsChildren then viewport:SetClipsChildren(true) end

    local frame = CreateFrame("Frame", nil, viewport)
    frame:EnableMouse(false)
    local boxes = {}
    for i = 1, MAX_BOXES do
        local box = ns.Box.CreatePreview(frame)
        box:Hide()
        boxes[i] = box
    end
    self.settingsPreview = {
        parent = parent, viewport = viewport, frame = frame, boxes = boxes,
        width = width, height = height,
    }
    viewport:SetScript("OnUpdate", function(_, elapsed)
        if not Preview.settingsPreview
            or (Preview.cooldownState ~= "COOLDOWN" and not Preview.movementSweepState) then return end
        Preview.settingsElapsed = (Preview.settingsElapsed or 0) + elapsed
        if Preview.settingsElapsed < 0.1 then return end
        Preview.settingsElapsed = 0
        local now, changed = GetTime(), false
        if Preview.cooldownState == "COOLDOWN"
            and (not Preview.cooldownStart or now - Preview.cooldownStart >= 8) then
            Preview.cooldownStart = now
            changed = true
        end
        if Preview.movementSweepState
            and (not Preview.movementSweepStart or now - Preview.movementSweepStart >= 25) then
            Preview.movementSweepStart = now - 8
            changed = true
        end
        if changed then
            Preview:RefreshSettingsPreview()
        end
    end)
end

function Preview:RefreshSettingsPreview()
    local preview = self.settingsPreview
    if not preview then return end

    local count = math.max(1, math.min(MAX_BOXES, tonumber(self.count) or 5))
    local layout = ns.Panel:Layout(count)
    local fit = math.min(1, preview.width / math.max(1, layout.frameWidth),
        preview.height / math.max(1, layout.frameHeight))
    preview.frame:ClearAllPoints()
    preview.frame:SetPoint("CENTER", preview.viewport, "CENTER")
    preview.frame:SetScale(layout.scale * fit)
    preview.frame:SetSize(layout.frameWidth, layout.frameHeight)
    self.cooldownStart = self.cooldownStart or GetTime()
    self.movementSweepStart = self.movementSweepStart or (GetTime() - 8)
    renderBoxes(preview.boxes, preview.frame, count, layout, self.cellState,
        self.cooldownState, self.cooldownStart, self.movementSweepState, self.movementSweepStart)
    preview.frame:Show()
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
        if not Preview.active
            or (Preview.cooldownState ~= "COOLDOWN" and not Preview.movementSweepState) then return end
        Preview.elapsed = (Preview.elapsed or 0) + elapsed
        if Preview.elapsed < 0.1 then return end
        Preview.elapsed = 0
        local now = GetTime()
        if Preview.cooldownState == "COOLDOWN"
            and (not Preview.cooldownStart or now - Preview.cooldownStart >= 8) then
            Preview.cooldownStart = now
            for _, box in ipairs(Preview.boxes) do
                if box:IsShown() then
                    box.dispelCooldown:SetCooldown(Preview.cooldownStart, 8)
                end
            end
        end
        if Preview.movementSweepState
            and (not Preview.movementSweepStart or now - Preview.movementSweepStart >= 25) then
            Preview.movementSweepStart = now - 8
            for index, box in ipairs(Preview.boxes) do
                if index == 1 and box:IsShown() then
                    for sweepIndex, cooldown in ipairs(box.movementCooldowns or { box.movementCooldown }) do
                        cooldown:SetCooldown(Preview.movementSweepStart - (sweepIndex - 1) * 5, 25)
                    end
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

    local now = GetTime()
    if self.cooldownState == "COOLDOWN"
        and (not self.cooldownStart or now - self.cooldownStart >= 8) then
        self.cooldownStart = now
    end
    if self.movementSweepState
        and (not self.movementSweepStart or now - self.movementSweepStart >= 25) then
        self.movementSweepStart = now - 8
    end

    renderBoxes(self.boxes, frame, count, layout, self.cellState,
        self.cooldownState, self.cooldownStart, self.movementSweepState, self.movementSweepStart)

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
