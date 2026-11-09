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
-- Sample roles so the sort settings visibly reorder the test panel. The first
-- cell stands in for the player.
local ROLES = { "TANK", "DAMAGER", "DAMAGER", "DAMAGER", "HEALER" }
local FALLBACK_DISPEL_COLOURS = {
    Magic = { r = 0.20, g = 0.60, b = 1.00 },
    Curse = { r = 0.72, g = 0.28, b = 1.00 },
    Disease = { r = 1.00, g = 0.72, b = 0.08 },
    Poison = { r = 0.38, g = 1.00, b = 0.04 },
}

Preview.count = 5
-- Sample states. Each is independent, so any mix the player can meet in game
-- can be previewed: a dispellable debuff while the dispel is cooling down, a
-- root alongside a lockout, and so on. Dispellable with the dispel ready is
-- the default, since that's what shows the debuff colour and type icon best.
Preview.cellState = "DISPELLABLE"
Preview.cooldownState = "READY"
Preview.movementSweepState = false
Preview.lockoutState = true
Preview.rootedState = false

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

-- The lockout the player can actually meet: the first one their bindings
-- trigger. Nil when the setting is off or nothing bound causes one.
function Preview:SampleLockout()
    if not (self.lockoutState and ns.Lockouts and ns.Lockouts:Enabled()) then return nil end
    local debuff = ns.Lockouts:Relevant()[1]
    if not debuff then return nil end
    local now = GetTime()
    if not self.lockoutStart or now - self.lockoutStart >= debuff.duration then
        self.lockoutStart = now
    end
    return { spellID = debuff.id, start = self.lockoutStart, duration = debuff.duration }
end

-- The spell the rooted badge points at: the first bound movement spell.
function Preview:SampleRootedSpell()
    if not self.rootedState or (ns.db and ns.db.movementAlertsEnabled == false) then return nil end
    for _, id in ipairs(ns.Cooldowns and ns.Cooldowns:BoundSpells() or {}) do
        if ns.Escape and ns.Escape:IsEnabledSpell(id) then return id end
    end
    return nil
end

-- With Rooted on, your own cell (the first) carries the debuff too, so a
-- poison that roots you shows the fill, the stacks and the rooted badge
-- together.
function Preview:NeedsDispel(index, count)
    if index == 1 and self.rootedState then return true end
    if count <= 2 then return index == count end
    return index == 2 or index == math.min(count, 4)
end

function Preview:Roster(count)
    local entries = {}
    for i = 1, count do
        local sample = ((i - 1) % #NAMES) + 1
        entries[i] = {
            index = i, isPlayer = i == 1, name = NAMES[sample],
            class = CLASSES[sample], role = ROLES[sample],
        }
    end
    if ns.Panel and ns.Panel.SortEntries then return ns.Panel:SortEntries(entries) end
    return entries
end

-- Both preview hosts use the same non-secure boxes, layout calculation and
-- restyling as Salve's live panel. The Settings host is clipped and scales down
-- only when the configured grid cannot fit its preview stage.
local function renderBoxes(boxes, frame, count, layout, state, cooldownState,
        cooldownStart, movementSweepState, movementSweepStart, cells)
    local types = knownDispelTypes()
    local roster = Preview:Roster(count)
    -- The sample lockout goes on the second cell (the only one when solo).
    local lockoutCell = math.min(2, count)
    Preview.lockoutName = roster[lockoutCell] and roster[lockoutCell].name or nil
    local lockoutSample = Preview:SampleLockout()
    local rootedSpell = Preview:SampleRootedSpell()
    for i, box in ipairs(boxes) do
        if i <= count then
            if cells then
                ns.Panel:PlaceBoxAt(box, cells[i], layout)
            else
                ns.Panel:PlaceBox(box, i, layout)
            end
            ns.Box.RestylePreview(box, roster[i].name, roster[i].class)

            if state == "DISPELLABLE" and Preview:NeedsDispel(i, count) then
                local dispelType = types[((i - 1) % #types) + 1]
                local colour = dispelColour(dispelType)
                box.previewFill:SetColorTexture(colour.r, colour.g, colour.b, 1)
                box.previewFill:Show()
                box.previewStack:SetText(ns.db.showStacks and "2" or "")
                if ns.db.showDispelTypeIcon ~= false then
                    local icon = box.previewDispelIcon
                    icon:ClearAllPoints()
                    local point = ns.db.dispelTypeIconPosition or "BOTTOMLEFT"
                    icon:SetPoint(point, box, point, 0, 0)
                    local size = math.max(8, math.min(64, tonumber(ns.db.dispelTypeIconSize) or 20))
                    icon:SetSize(size, size)
                    -- Static sample art, never a read of live aura data.
                    local atlas = "RaidFrame-Icon-Debuff" .. dispelType
                    local available = C_Texture and C_Texture.GetAtlasInfo
                        and C_Texture.GetAtlasInfo(atlas)
                    if available then
                        icon:SetAtlas(atlas)
                    else
                        icon:SetTexture(134400)
                    end
                    icon:Show()
                else
                    box.previewDispelIcon:Hide()
                end
            else
                box.previewFill:Hide()
                box.previewStack:SetText("")
                box.previewDispelIcon:Hide()
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
            -- Icon mode: the same sweeps, moved onto spell icons. Each spell's
            -- state is the test panel's, not the client's.
            local entries = {}
            if ns.spellID then
                entries[1] = { spellID = ns.spellID, cooldown = box.dispelCooldown,
                    state = cooldownState == "COOLDOWN" and "ACTIVE" or "READY" }
            end
            for index, spellID in ipairs(sweeps) do
                if cooldowns[index] then
                    entries[#entries + 1] = { spellID = spellID, cooldown = cooldowns[index],
                        movement = true, state = "ACTIVE" }
                end
            end
            ns.Box.UpdateCooldownIcons(box, nil, entries)
            ns.Box.UpdateLockoutIcon(box, lockoutSample and ns.Lockouts:OnCells()
                and i == lockoutCell and lockoutSample or nil)
            -- The rooted badge goes on the player's cell, as in game.
            ns.Box.SetMovementPrompt(box, rootedSpell ~= nil and roster[i].isPlayer, rootedSpell)
            box:Show()
        else
            box:Hide()
        end
    end
    if ns.CooldownBar then
        ns.CooldownBar:RenderPreview(frame, {
            cooldownState = cooldownState, cooldownStart = cooldownStart,
            movementSweepState = movementSweepState, movementSweepStart = movementSweepStart,
            lockoutName = Preview.lockoutName, lockout = lockoutSample,
        })
    end
end

-- ── Live preview window ────────────────────────────────────────────────────
-- A floating, draggable window opened from settings.  It is parented to the
-- screen, not to the settings window, and draws the grid at the panel's own
-- scale, so a cell here is the size it will be in game.  It only shrinks
-- when the layout wouldn't fit on screen, and says so.

local WINDOW_MIN_WIDTH, WINDOW_PAD, WINDOW_HEADER, WINDOW_CONTROLS = 480, 16, 40, 208
local HANDLE_ROOM = 14

local function windowSwitch(parent, label, hint)
    local HC = ns.HammerCore
    local switch = HC.UI.Switch(parent)
    switch:SetSize(210, 26)
    switch.Text:SetText(label)
    HC.UI.AttachHint(switch, label, hint)
    return switch
end

-- Why a ticked state draws nothing, so the preview never just looks broken.
function Preview:MissingStates()
    local db, out = ns.db, {}
    if self.lockoutState and not self:SampleLockout() then
        if not db.lockoutIcons then
            out[#out + 1] = "Lockout: Show lockout debuffs is off (Cooldowns)."
        else
            out[#out + 1] = "Lockout: nothing you've bound causes one."
        end
    end
    if self.rootedState and not self:SampleRootedSpell() then
        if db.movementAlertsEnabled == false then
            out[#out + 1] = "Rooted: movement alerts are off (Movement)."
        else
            out[#out + 1] = "Rooted: no movement spell is bound."
        end
    end
    if self.movementSweepState and #previewSweepSpellIDs() == 0 then
        out[#out + 1] = "Movement sweep: none picked (Movement)."
    end
    return #out > 0 and table.concat(out, " ") or nil
end

function Preview:CreateSettingsPreview()
    if self.window then return self.window end
    local HC = ns.HammerCore
    local UI, T = HC.UI, HC.Theme

    local win = CreateFrame("Frame", "SalveLivePreview", UIParent, "BackdropTemplate")
    win:SetFrameStrata("DIALOG")
    win:SetToplevel(true)
    win:SetClampedToScreen(true)
    win:SetMovable(true)
    win:EnableMouse(true)
    win:SetScale(1)
    T.Surface(win, "outer", "edge")
    win:Hide()
    local point = ns.db.previewWindowPoint
    if type(point) == "table" and point[1] then
        win:SetPoint(point[1], UIParent, point[2], point[3], point[4])
    else
        win:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 40, -120)
    end

    local bar = CreateFrame("Frame", nil, win)
    bar:SetPoint("TOPLEFT", 1, -1)
    bar:SetPoint("TOPRIGHT", -1, -1)
    bar:SetHeight(WINDOW_HEADER)
    T.Fill(bar:CreateTexture(nil, "BACKGROUND"), "header"):SetAllPoints()
    bar:EnableMouse(true)
    bar:RegisterForDrag("LeftButton")
    bar:SetScript("OnDragStart", function() win:StartMoving() end)
    bar:SetScript("OnDragStop", function()
        win:StopMovingOrSizing()
        local from, _, to, x, y = win:GetPoint()
        ns.db.previewWindowPoint = { from, to, x, y }
    end)
    local title = T.Font(UI.FontString(bar, "GameFontNormalLarge", "text"), 16)
    title:SetPoint("LEFT", WINDOW_PAD, 0)
    title:SetText("Live preview")
    local close = UI.CloseButton(bar, function() Preview:HideWindow() end, 24)
    close:SetPoint("RIGHT", -8, 0)

    -- Controls: test units and the sample states, two to a line.
    local controls = CreateFrame("Frame", nil, win)
    controls:SetPoint("TOPLEFT", 0, -WINDOW_HEADER)
    controls:SetPoint("TOPRIGHT", 0, -WINDOW_HEADER)
    controls:SetHeight(WINDOW_CONTROLS)
    local function place(control, row, right, drop)
        local y = -8 - (row - 1) * 32 - (drop or 0)
        control:ClearAllPoints()
        if right then
            control:SetPoint("TOPLEFT", controls, "TOP", 4, y)
        else
            control:SetPoint("TOPLEFT", controls, "TOPLEFT", WINDOW_PAD, y)
        end
    end
    local units = CreateFrame("Frame", nil, controls)
    units:SetSize(210, 26)
    place(units, 1)
    local unitsLabel = UI.FontString(units, "GameFontHighlight", "text")
    unitsLabel:SetPoint("LEFT")
    unitsLabel:SetText("Units")
    local minus = UI.Button(units, 26, 24)
    minus:SetPoint("LEFT", unitsLabel, "RIGHT", 12, 0)
    minus:SetText("-")
    local count = UI.FontString(units, "GameFontHighlight", "text")
    count:SetPoint("LEFT", minus, "RIGHT", 6, 0)
    count:SetWidth(26)
    count:SetJustifyH("CENTER")
    local plus = UI.Button(units, 26, 24)
    plus:SetPoint("LEFT", count, "RIGHT", 6, 0)
    plus:SetText("+")
    UI.AttachHint(minus, "Fewer units", "Preview a smaller group. Saved per profile.")
    UI.AttachHint(plus, "More units", "Preview a bigger group. Saved per profile.")

    local openWith = windowSwitch(controls, "Open with settings",
        "Open this window whenever Salve's settings open.")
    place(openWith, 1, true)
    local onScreen = windowSwitch(controls, "Show on screen too",
        "Also show the test panel where Salve sits on your screen, over the real one, at real size. It closes with settings and when combat starts.")
    place(onScreen, 2)
    local inFront = windowSwitch(controls, "Keep in front",
        "Keep this window above the settings window. Off, whichever you click comes to the front.")
    place(inFront, 2, true)

    -- Sample states: mix them freely, as they can mix in game.
    local statesLabel = T.Font(UI.FontString(controls, "GameFontNormal", "accent"), 12)
    statesLabel:SetPoint("TOPLEFT", controls, "TOPLEFT", WINDOW_PAD, -8 - 2 * 32 - 6)
    statesLabel:SetText("Preview options")
    local function placeState(control, row, right) place(control, row, right, 18) end
    local dispellable = windowSwitch(controls, "Dispellable debuff",
        "One or two cells with a debuff you can dispel: colour, type icon and stacks.")
    placeState(dispellable, 3)
    local cooldown = windowSwitch(controls, "Dispel on cooldown",
        "Your dispel cooling down: the sweep and countdown on every cell and the cooldown bar.")
    placeState(cooldown, 3, true)
    local sweep = windowSwitch(controls, "Movement sweep",
        "Your movement spells' coloured sweeps on the first cell and the cooldown bar.")
    placeState(sweep, 4)
    local rooted = windowSwitch(controls, "Rooted",
        "You're rooted: the badge on your own cell shows the spell that frees you. With Dispellable debuff on, you're poisoned too.")
    placeState(rooted, 4, true)
    local lockout = windowSwitch(controls, "Lockout",
        "A lockout debuff such as Forbearance, where Show on puts it: a cell, the cooldown bar or both.")
    placeState(lockout, 5)

    local note = UI.FontString(win, "GameFontHighlightSmall", "muted")
    note:SetPoint("TOPLEFT", WINDOW_PAD, -(WINDOW_HEADER + WINDOW_CONTROLS))
    note:SetPoint("RIGHT", -WINDOW_PAD, 0)
    note:SetJustifyH("LEFT")

    local viewport = CreateFrame("Frame", nil, win)
    viewport:SetPoint("TOPLEFT", WINDOW_PAD, -(WINDOW_HEADER + WINDOW_CONTROLS + 22))
    T.Fill(viewport:CreateTexture(nil, "BACKGROUND"), "rail"):SetAllPoints()
    if viewport.SetClipsChildren then viewport:SetClipsChildren(true) end

    local frame = CreateFrame("Frame", nil, viewport)
    frame:EnableMouse(false)
    local boxes = {}
    for i = 1, MAX_BOXES do
        local box = ns.Box.CreatePreview(frame)
        box:Hide()
        boxes[i] = box
    end
    -- The drag handle, drawn as the panel draws it.
    local handle = CreateFrame("Frame", nil, frame)
    handle:SetSize(10, 10)
    local handleFill = handle:CreateTexture(nil, "ARTWORK")
    handleFill:SetAllPoints()
    handleFill:SetColorTexture(0.58, 0.43, 0.22, 0.85)
    local handleEdge = handle:CreateTexture(nil, "BACKGROUND")
    handleEdge:SetPoint("TOPLEFT", -1, 1)
    handleEdge:SetPoint("BOTTOMRIGHT", 1, -1)
    handleEdge:SetColorTexture(0, 0, 0, 0.9)

    self.window = win
    self.settingsPreview = {
        window = win, viewport = viewport, frame = frame, boxes = boxes, handle = handle,
        note = note, count = count, openWith = openWith, dispellable = dispellable,
        cooldown = cooldown, sweep = sweep, onScreen = onScreen, inFront = inFront,
        rooted = rooted, lockout = lockout,
    }

    local function changed()
        Preview:RefreshSettingsPreview()
        if Preview.active then Preview:Refresh() end
        Preview:RefreshWindowControls()
    end
    minus:SetScript("OnClick", function()
        ns.Set("previewUnits", math.max(1, ns.db.previewUnits - 1))
        Preview.count = ns.db.previewUnits
        changed()
    end)
    plus:SetScript("OnClick", function()
        ns.Set("previewUnits", math.min(MAX_BOXES, ns.db.previewUnits + 1))
        Preview.count = ns.db.previewUnits
        changed()
    end)
    openWith:SetScript("OnClick", function()
        ns.db.previewWindowOpen = not ns.db.previewWindowOpen
        Preview:RefreshWindowControls()
    end)
    dispellable:SetScript("OnClick", function()
        Preview.cellState = Preview.cellState == "DISPELLABLE" and "CLEAR" or "DISPELLABLE"
        changed()
    end)
    cooldown:SetScript("OnClick", function()
        Preview.cooldownState = Preview.cooldownState == "COOLDOWN" and "READY" or "COOLDOWN"
        changed()
    end)
    sweep:SetScript("OnClick", function()
        Preview.movementSweepState = not Preview.movementSweepState
        changed()
    end)
    rooted:SetScript("OnClick", function()
        Preview.rootedState = not Preview.rootedState
        changed()
    end)
    lockout:SetScript("OnClick", function()
        Preview.lockoutState = not Preview.lockoutState
        Preview.lockoutStart = nil
        changed()
    end)
    inFront:SetScript("OnClick", function()
        ns.db.previewWindowOnTop = not ns.db.previewWindowOnTop
        Preview:ApplyWindowLayer()
        Preview:RefreshWindowControls()
    end)
    onScreen:SetScript("OnClick", function()
        Preview.count = ns.db.previewUnits
        Preview:Toggle()
        Preview:RefreshWindowControls()
    end)

    win:SetScript("OnUpdate", function(_, elapsed)
        if Preview.cooldownState ~= "COOLDOWN" and not Preview.movementSweepState
            and not Preview.lockoutStart then return end
        Preview.settingsElapsed = (Preview.settingsElapsed or 0) + elapsed
        if Preview.settingsElapsed < 0.1 then return end
        Preview.settingsElapsed = 0
        local now, restart = GetTime(), false
        if Preview.cooldownState == "COOLDOWN"
            and (not Preview.cooldownStart or now - Preview.cooldownStart >= 8) then
            Preview.cooldownStart = now
            restart = true
        end
        if Preview.movementSweepState
            and (not Preview.movementSweepStart or now - Preview.movementSweepStart >= 25) then
            Preview.movementSweepStart = now - 8
            restart = true
        end
        local lockout = Preview.lockoutStart and Preview:SampleLockout()
        if lockout and lockout.start == now then restart = true end
        if restart then Preview:RefreshSettingsPreview() end
    end)
    return win
end

-- Keep in front: one layer above the settings window (DIALOG), so it always
-- floats over it.  Off, it shares that layer and whichever was clicked last
-- is on top.  HammerCore's menus and dialogs sit higher either way.
function Preview:ApplyWindowLayer()
    if not self.window then return end
    self.window:SetFrameStrata(ns.db.previewWindowOnTop ~= false and "FULLSCREEN" or "DIALOG")
    if self.window.Raise then self.window:Raise() end
end

function Preview:RefreshWindowControls()
    local preview = self.settingsPreview
    if not preview then return end
    preview.count:SetText(tostring(ns.db.previewUnits))
    preview.openWith:SetChecked(ns.db.previewWindowOpen == true)
    preview.dispellable:SetChecked(self.cellState == "DISPELLABLE")
    preview.cooldown:SetChecked(self.cooldownState == "COOLDOWN")
    preview.sweep:SetChecked(self.movementSweepState and true or false)
    preview.rooted:SetChecked(self.rootedState and true or false)
    preview.lockout:SetChecked(self.lockoutState and true or false)
    preview.onScreen:SetChecked(self.active and true or false)
    preview.inFront:SetChecked(ns.db.previewWindowOnTop ~= false)
end

function Preview:IsWindowShown()
    return self.window and self.window:IsShown() or false
end

function Preview:ShowWindow()
    self:CreateSettingsPreview()
    self.count = ns.db.previewUnits
    self.window:Show()
    self:ApplyWindowLayer()
    self:RefreshWindowControls()
    self:RefreshSettingsPreview()
end

function Preview:HideWindow()
    if self.window then self.window:Hide() end
    local HC = ns.HammerCore
    if HC and HC.Settings and HC.Settings.RefreshHeaderAction then HC.Settings:RefreshHeaderAction() end
end

function Preview:ToggleWindow()
    if self:IsWindowShown() then self:HideWindow() else self:ShowWindow() end
end

-- How far the cooldown bar and handle reach past the grid, in grid units:
-- left, top, right, bottom, measured from the grid's top-left corner.
local function extents(frame, layout, handleShown)
    local left, top, right, bottom = 0, 0, layout.frameWidth, layout.frameHeight
    local bar = frame.salveCooldownBar
    if bar and bar.frame:IsShown() then
        local width, height = bar.frame:GetSize()
        local gap = tonumber(ns.db.cooldownBarGap) or 4
        local side = ns.db.cooldownBarSide or "BOTTOM"
        if side == "TOP" then
            top = math.min(top, -(gap + height)); right = math.max(right, width)
        elseif side == "LEFT" then
            left = math.min(left, -(gap + width)); bottom = math.max(bottom, height)
        elseif side == "RIGHT" then
            right = math.max(right, layout.frameWidth + gap + width); bottom = math.max(bottom, height)
        else
            bottom = math.max(bottom, layout.frameHeight + gap + height); right = math.max(right, width)
        end
    end
    if handleShown then
        left, top = left - HANDLE_ROOM, top - HANDLE_ROOM
        right, bottom = right + HANDLE_ROOM, bottom + HANDLE_ROOM
    end
    return left, top, right, bottom
end

function Preview:RefreshSettingsPreview()
    local preview = self.settingsPreview
    if not (preview and preview.window:IsShown()) then return end

    local count = math.max(1, math.min(MAX_BOXES, tonumber(self.count) or 5))
    local layout = ns.Panel:Layout(count)
    preview.frame:SetSize(layout.frameWidth, layout.frameHeight)
    self.cooldownStart = self.cooldownStart or GetTime()
    self.movementSweepStart = self.movementSweepStart or (GetTime() - 8)
    renderBoxes(preview.boxes, preview.frame, count, layout, self.cellState,
        self.cooldownState, self.cooldownStart, self.movementSweepState, self.movementSweepStart)

    local handleShown = ns.db.showHandle and true or false
    preview.handle:SetShown(handleShown)
    if handleShown then ns.Handle:PositionFrame(preview.handle, preview.frame) end

    -- Actual size unless the layout is bigger than most of the screen.
    local left, top, right, bottom = extents(preview.frame, layout, handleShown)
    local naturalWidth = (right - left) * layout.scale
    local naturalHeight = (bottom - top) * layout.scale
    local screenWidth = UIParent.GetWidth and UIParent:GetWidth() or 0
    local screenHeight = UIParent.GetHeight and UIParent:GetHeight() or 0
    local fit = 1
    if screenWidth > 0 and screenHeight > 0 then
        fit = math.min(1, (screenWidth * 0.8) / math.max(1, naturalWidth),
            (screenHeight * 0.7) / math.max(1, naturalHeight))
    end
    local scale = layout.scale * fit
    local contentWidth, contentHeight = (right - left) * scale, (bottom - top) * scale
    local innerWidth = math.max(WINDOW_MIN_WIDTH - WINDOW_PAD * 2, contentWidth + 24)
    local innerHeight = math.max(80, contentHeight + 24)
    preview.viewport:SetSize(innerWidth, innerHeight)
    preview.frame:SetScale(scale)
    preview.frame:ClearAllPoints()
    -- Offsets are in the grid's own units.
    preview.frame:SetPoint("TOPLEFT", preview.viewport, "TOPLEFT",
        ((innerWidth - contentWidth) / 2) / scale - left,
        -(((innerHeight - contentHeight) / 2) / scale - top))
    preview.frame:Show()
    preview.window:SetSize(innerWidth + WINDOW_PAD * 2,
        WINDOW_HEADER + WINDOW_CONTROLS + 22 + innerHeight + WINDOW_PAD)

    -- Attached Left or Right, each cell lines up with its member's frame in
    -- game, which a window can't show; Top and Bottom keep this grid.
    local attachTo = ns.db.attachTo
    local followsHost = attachTo and attachTo ~= "NONE" and ns.Attach and ns.Attach:IsLoaded(attachTo)
        and (ns.db.attachSide == "LEFT" or ns.db.attachSide == "RIGHT")
    local text
    if followsHost then
        text = "Attached Left or Right: in game, cells line up with the host's frames. Show on screen too shows that."
    elseif fit < 1 then
        text = ("Scaled to %d%% to fit your screen."):format(math.floor(fit * 100 + 0.5))
    else
        text = ("Actual size, %d units."):format(count)
    end
    local missing = self:MissingStates()
    if missing then text = text .. " " .. missing end
    preview.note:SetText(text)
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
        local now, restarted = GetTime(), false
        if Preview.cooldownState == "COOLDOWN"
            and (not Preview.cooldownStart or now - Preview.cooldownStart >= 8) then
            Preview.cooldownStart = now
            restarted = true
            for _, box in ipairs(Preview.boxes) do
                if box:IsShown() then
                    box.dispelCooldown:SetCooldown(Preview.cooldownStart, 8)
                end
            end
        end
        if Preview.movementSweepState
            and (not Preview.movementSweepStart or now - Preview.movementSweepStart >= 25) then
            Preview.movementSweepStart = now - 8
            restarted = true
            for index, box in ipairs(Preview.boxes) do
                if index == 1 and box:IsShown() then
                    for sweepIndex, cooldown in ipairs(box.movementCooldowns or { box.movementCooldown }) do
                        cooldown:SetCooldown(Preview.movementSweepStart - (sweepIndex - 1) * 5, 25)
                    end
                end
            end
        end
        if restarted and ns.CooldownBar and frame.salveCooldownBar
            and frame.salveCooldownBar.frame:IsShown() then
            ns.CooldownBar:RenderPreview(frame, Preview)
        end
    end)
end

function Preview:Refresh()
    if not self.active then return end
    self:Create()

    local frame = self.frame
    local count = math.max(1, math.min(MAX_BOXES, tonumber(self.count) or 5))
    local layout = ns.Panel:Layout(count)
    frame:SetScale(layout.scale)

    -- With real host frames on screen, the test cells take their places in
    -- the host's reading order. Otherwise the saved position, as live.
    local plan = ns.Attach and ns.Attach:Plan(count, layout, frame:GetEffectiveScale(), true)
    frame:ClearAllPoints()
    if plan then
        frame:SetPoint(plan.point, plan.anchor, plan.anchorPoint, plan.x, plan.y)
        frame:SetSize(plan.width, plan.height)
    else
        local point = ns.db.point
        frame:SetPoint(point[1], UIParent, point[2], point[3], point[4])
        if ns.Panel.NormalizeGrowthAnchor then ns.Panel:NormalizeGrowthAnchor(frame) end
        frame:SetSize(layout.frameWidth, layout.frameHeight)
    end

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
        self.cooldownState, self.cooldownStart, self.movementSweepState, self.movementSweepStart,
        plan and plan.cells)

    self.handle:SetShown(ns.db.showHandle and not plan and true or false)
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
