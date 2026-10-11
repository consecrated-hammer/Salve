local addonName, ns = ...
local HC = ns.HammerCore
local O, T = ns.Options, HC.Theme

local function section(parent)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(560, 1)
    frame.hcRefresh = parent.hcRefresh
    frame.hcRefreshAll = parent.hcRefreshAll
    frame.hcHeaderOwner = parent.hcHeaderOwner or parent
    return frame
end

local function smallLabel(parent, text, x, y)
    local label = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    label:SetPoint("TOPLEFT", x, y)
    label:SetText(text)
    return label
end

local TEXT_POSITIONS = {
    "LEFT:TOP", "CENTER:TOP", "RIGHT:TOP",
    "LEFT:MIDDLE", "CENTER:MIDDLE", "RIGHT:MIDDLE",
    "LEFT:BOTTOM", "CENTER:BOTTOM", "RIGHT:BOTTOM",
}
local TEXT_POSITION_LABELS = {
    "Top left", "Top centre", "Top right",
    "Middle left", "Centre", "Middle right",
    "Bottom left", "Bottom centre", "Bottom right",
}

-- Keep the existing two saved keys so older builds can read these choices.
local function textPosition(parent, label, hint, y, prefix)
    return O.Dropdown(parent, label, hint, y, TEXT_POSITIONS, TEXT_POSITION_LABELS,
        function() return ns.db[prefix .. "JustifyH"] .. ":" .. ns.db[prefix .. "JustifyV"] end,
        function(value)
            local horizontal, vertical = value:match("^([^:]+):([^:]+)$")
            ns.Set(prefix .. "JustifyH", horizontal)
            ns.Set(prefix .. "JustifyV", vertical)
        end, 560, 150, 180)
end

HC.Settings:NewPage({
    name = "Salve",
    title = "Panel",
    group = "main",
}, function(panel)
    local db = ns.db
    local previewCount = 5
    local previewCellState = "DISPELLABLE"
    local previewCooldownState = "COOLDOWN"
    local previewMovementSweep = false
    local sections = {}

    local function add(frame, height, visible)
        sections[#sections + 1] = {
            frame = frame,
            height = height,
            visible = visible,
        }
    end

    local preview = panel.hcCreatePinned(290, 720)
    local py = -8
    _, py = O.Header(preview, "Preview", py)

    local stage = CreateFrame("Frame", nil, preview, "BackdropTemplate")
    stage:SetPoint("TOPLEFT", 16, py)
    stage:SetSize(688, 246)
    stage:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    stage:SetBackdropColor(unpack(T.Colour("rail")))
    stage:SetBackdropBorderColor(unpack(T.Colour("edge")))
    stage.hcRefresh = preview.hcRefresh
    stage.hcRefreshAll = preview.hcRefreshAll

    local stageLabel = stage:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    stageLabel:SetPoint("TOPLEFT", 10, -8)
    stageLabel:SetText("LIVE PREVIEW")
    stageLabel:SetTextColor(unpack(T.Colour("muted")))

    -- The rendered grid owns the wide centre of the stage. This leaves a full
    -- five 95px-name row intact and lets every layout grow around the centre.
    if ns.Preview.CreateSettingsPreview then
        ns.Preview:CreateSettingsPreview(stage, -10, 10, 668, 160)
    end

    local previewToggle = O.CheckButton(stage)
    previewToggle:SetPoint("TOPLEFT", 10, -198)
    previewToggle.Text:SetText("Preview settings on screen")
    O.AttachHint(previewToggle, "On-screen preview",
        "Show the same non-clickable test panel at Salve's saved screen position. It closes with settings and when combat starts.")

    local unitsLabel = smallLabel(stage, "Units", 10, -38)
    local minus = O.SelectButton(stage, 24, 22)
    minus:SetPoint("TOPLEFT", 50, -32)
    minus:SetText("-")
    local count = stage:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    count:SetPoint("LEFT", minus, "RIGHT", 8, 0)
    count:SetWidth(22)
    count:SetJustifyH("CENTER")
    local plus = O.SelectButton(stage, 24, 22)
    plus:SetPoint("LEFT", count, "RIGHT", 8, 0)
    plus:SetText("+")

    local simulatedLabel = smallLabel(stage, "PREVIEW OPTIONS", 10, -178)
    simulatedLabel:SetTextColor(unpack(T.Colour("muted")))
    local stateToggle = O.CheckButton(stage)
    stateToggle:SetPoint("TOPLEFT", 250, -198)
    stateToggle.Text:SetText("Preview dispellable")
    O.AttachHint(stateToggle, "Preview dispellable",
        "Show one or two cells with a dispellable effect.")
    local cooldownToggle = O.CheckButton(stage)
    cooldownToggle:SetPoint("TOPLEFT", 480, -198)
    cooldownToggle.Text:SetText("Preview on cooldown")
    O.AttachHint(cooldownToggle, "Preview on cooldown",
        "Draw a cooldown over the preview cells.")
    local movementSweepToggle = O.CheckButton(stage)
    movementSweepToggle:SetPoint("TOPLEFT", 10, -222)
    movementSweepToggle.Text:SetText("Preview movement sweep")
    O.AttachHint(movementSweepToggle, "Preview movement sweep",
        "Show the chosen movement actions' coloured clock-hand cooldowns on the first preview cell.")

    local function applyPreviewSettings()
        ns.Preview.count = previewCount
        ns.Preview.cellState = previewCellState
        ns.Preview.cooldownState = previewCooldownState
        ns.Preview.movementSweepState = previewMovementSweep
        if ns.Preview.RefreshSettingsPreview then ns.Preview:RefreshSettingsPreview() end
        if ns.Preview.active then ns.Preview:Refresh() end
    end

    local function refreshPreview()
        count:SetText(tostring(previewCount))
        previewToggle:SetChecked(ns.Preview.active and true or false)
        stateToggle:SetChecked(previewCellState == "DISPELLABLE")
        cooldownToggle:SetChecked(previewCooldownState == "COOLDOWN")
        movementSweepToggle:SetChecked(previewMovementSweep)
        applyPreviewSettings()
    end

    minus:SetScript("OnClick", function()
        previewCount = math.max(1, previewCount - 1)
        applyPreviewSettings()
        refreshPreview()
    end)
    plus:SetScript("OnClick", function()
        previewCount = math.min(40, previewCount + 1)
        applyPreviewSettings()
        refreshPreview()
    end)
    previewToggle:SetScript("OnClick", function()
        applyPreviewSettings()
        ns.Preview:Toggle()
        refreshPreview()
    end)
    stateToggle:SetScript("OnClick", function(self)
        self:SetChecked(not self:GetChecked())
        previewCellState = self:GetChecked() and "DISPELLABLE" or "CLEAR"
        applyPreviewSettings()
    end)
    cooldownToggle:SetScript("OnClick", function(self)
        self:SetChecked(not self:GetChecked())
        previewCooldownState = self:GetChecked() and "COOLDOWN" or "READY"
        applyPreviewSettings()
    end)
    movementSweepToggle:SetScript("OnClick", function(self)
        self:SetChecked(not self:GetChecked())
        previewMovementSweep = self:GetChecked() and true or false
        applyPreviewSettings()
    end)

    preview.hcRefresh[#preview.hcRefresh + 1] = refreshPreview
    O.RefreshPreviewControls = refreshPreview
    refreshPreview()
    local presets = section(panel)
    local presetY = -8
    _, presetY = O.Header(presets, "Layout presets", presetY)
    local presetSpecs = {
        { label = "Compact", note = "20px cells, no names", width = 20, height = 20, columns = 5, spacing = 1, names = false, previewUnits = 5 },
        { label = "Named", note = "95px cells, names on", width = 95, height = 20, columns = 5, spacing = 1, names = true, previewUnits = 5 },
        { label = "Raid wall", note = "Tight 10-cell wall, no names", width = 20, height = 20, columns = 10, spacing = 0, names = false, previewUnits = 40 },
    }
    for index, spec in ipairs(presetSpecs) do
        local button = O.Button(presets, 168, 46)
        button:SetPoint("TOPLEFT", 16 + (index - 1) * 176, presetY - 4)
        button:SetText(spec.label)
        button.Text:ClearAllPoints()
        button.Text:SetPoint("TOPLEFT", 10, -7)
        button.Text:SetPoint("RIGHT", -10, 0)
        button.Text:SetJustifyH("LEFT")
        local note = button:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
        note:SetPoint("TOPLEFT", button.Text, "BOTTOMLEFT", 0, -2)
        note:SetText(spec.note)
        note:SetTextColor(unpack(T.Colour("muted")))
        O.AttachHint(button, spec.label, "Sets cell width, height, wrapping, spacing and names. Keeps grid direction and panel scale.")
        button:SetScript("OnClick", function()
            ns.Set("boxWidth", spec.width)
            ns.Set("boxHeight", spec.height)
            ns.Set("columns", spec.columns)
            ns.Set("spacing", spec.spacing)
            ns.Set("showNames", spec.names)
            if spec.previewUnits then
                previewCount = spec.previewUnits
                refreshPreview()
            end
            if presets.hcRefreshAll then presets.hcRefreshAll() end
        end)
    end
    add(presets, -presetY + 58)

    local grid = section(panel)
    local gy = -8
    _, gy = O.Header(grid, "Grid", gy)
    _, gy = O.Dropdown(grid, "Grid direction",
        "Rows fill across then down. Columns fill down or up then right. The starting edge stays fixed as the group grows.", gy,
        { "HORIZONTAL:RIGHT", "HORIZONTAL:LEFT", "VERTICAL:DOWN", "VERTICAL:UP" },
        { "Rows from left", "Rows from right", "Columns from top", "Columns from bottom" },
        function()
            return db.orientation .. ":" .. (db.orientation == "VERTICAL"
                and db.verticalGrowth or db.horizontalGrowth)
        end,
        function(value)
            local orientation, growth = value:match("^([^:]+):([^:]+)$")
            ns.Set("orientation", orientation)
            ns.Set(orientation == "VERTICAL" and "verticalGrowth" or "horizontalGrowth", growth)
        end, 560, 150, 200)
    _, gy = O.Slider(grid,
        function() return db.orientation == "VERTICAL"
            and "Cells per column" or "Cells per row" end,
        "How many cells appear before the next line starts.", gy,
        1, 10, 1,
        function() return db.columns end,
        function(value) ns.Set("columns", value) end)
    _, gy = O.Slider(grid, "Spacing", "Gap between cells, in pixels.", gy,
        0, 12, 1,
        function() return db.spacing end,
        function(value) ns.Set("spacing", value) end)
    add(grid, -gy + 4)

    local size = section(panel)
    local sy = -8
    _, sy = O.Header(size, "Cell size", sy)
    _, sy = O.Slider(size, "Width",
        "Use 95 or more to show the twelve-character preview names.", sy,
        10, 200, 1,
        function() return db.boxWidth end,
        function(value) ns.Set("boxWidth", value) end)
    _, sy = O.Slider(size, "Height", nil, sy,
        10, 150, 1,
        function() return db.boxHeight end,
        function(value) ns.Set("boxHeight", value) end)
    _, sy = O.Slider(size, "Panel scale",
        "Scales the entire Salve frame, including text and borders.", sy,
        0.5, 2, 0.05,
        function() return db.scale end,
        function(value) ns.Set("scale", value) end,
        function(value) return string.format("%.2f", value) end)
    add(size, -sy + 4)

    local contents = section(panel)
    local cy = -8
    _, cy = O.Header(contents, "Cell contents", cy)
    _, cy = O.Check(contents, "Show box borders",
        "Show an outline around every cell, independently of idle backgrounds and names.", cy,
        function() return db.showBorders end,
        function(value) ns.Set("showBorders", value) end)
    _, cy = O.Check(contents, "Show stack counts",
        "The game hides the number at one stack. Dispelling previews simulate two stacks.", cy,
        function() return db.showStacks end,
        function(value) ns.Set("showStacks", value) end)
    add(contents, -cy + 4)

    local dispelIcon = section(panel)
    local diy = -8
    _, diy = O.Header(dispelIcon, "Dispel icon", diy)
    _, diy = O.Check(dispelIcon, "Show dispel-type icon",
        "Show Blizzard's Magic, Curse, Disease or Poison icon on a dispellable cell.", diy,
        function() return db.showDispelTypeIcon end,
        function(value) ns.Set("showDispelTypeIcon", value) end)
    add(dispelIcon, -diy + 4)
    local iconDetails = section(panel)
    diy = -4
    _, diy = O.Slider(iconDetails, "Icon size",
        "Size in pixels before UI scale. Large icons can cover names or cooldown numbers.", diy,
        8, 64, 1,
        function() return db.dispelTypeIconSize end,
        function(value) ns.Set("dispelTypeIconSize", value) end)
    _, diy = O.Dropdown(iconDetails, "Icon position",
        "Choose which part of the cell holds the Blizzard dispel-type icon.", diy,
        { "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT", "CENTER" },
        { "Top left", "Top right", "Bottom left", "Bottom right", "Centre" },
        function() return db.dispelTypeIconPosition end,
        function(value) ns.Set("dispelTypeIconPosition", value) end,
        560, 150, 180)
    add(iconDetails, -diy + 4, function() return db.showDispelTypeIcon end)

    local inactive = section(panel)
    local iy = -8
    _, iy = O.Header(inactive, "Idle backgrounds", iy)
    _, iy = O.Check(inactive, "Show idle backgrounds",
        "Off hides idle backgrounds. Borders and unit names have separate settings; click areas stay in place during combat.", iy,
        function() return db.showWhenClean end,
        function(value) ns.Set("showWhenClean", value) end)
    add(inactive, -iy + 4)
    local idleDetails = section(panel)
    iy = -4
    _, iy = O.Check(idleDetails, "Class-coloured backgrounds",
        "Colour idle backgrounds by class. Names always use class colours; debuff colours are chosen by the game.", iy,
        function() return db.useClassColours end,
        function(value) ns.Set("useClassColours", value) end)
    _, iy = O.Slider(idleDetails, "Idle opacity",
        "How visible inactive cells are when shown.", iy,
        0, 1, 0.05,
        function() return db.cleanAlpha end,
        function(value) ns.Set("cleanAlpha", value) end,
        function(value) return string.format("%d%%", math.floor(value * 100 + 0.5)) end)
    add(idleDetails, -iy + 4, function() return db.showWhenClean end)

    local names = section(panel)
    local ny = -8
    _, ny = O.Header(names, "Unit names", ny)
    _, ny = O.Check(names, "Show unit names",
        "Use cells at least 95 pixels wide for the twelve-character preview names.", ny,
        function() return db.showNames end,
        function(value) ns.Set("showNames", value) end)
    add(names, -ny + 4)
    local nameDetails = section(panel)
    ny = -4
    _, ny = textPosition(nameDetails, "Name position", "Place names within each cell.", ny, "name")
    _, ny = O.Slider(nameDetails, "Text size", "Size before UI scale is applied.", ny,
        6, 32, 1,
        function() return db.nameFontSize end,
        function(value) ns.Set("nameFontSize", value) end)
    add(nameDetails, -ny + 4, function() return db.showNames end)

    local cooldown = section(panel)
    local dy = -8
    _, dy = O.Header(cooldown, "Cooldown numbers", dy)
    _, dy = textPosition(cooldown, "Number position", "Place cooldown numbers within each cell.", dy, "cooldown")
    _, dy = O.Slider(cooldown, "Text size", "Size before UI scale is applied.", dy,
        6, 40, 1,
        function() return db.cooldownFontSize end,
        function(value) ns.Set("cooldownFontSize", value) end)
    add(cooldown, -dy + 4)

    local reset = section(panel)
    local _, ry = O.PageReset(reset, -4, function()
        for _, key in ipairs({
            "orientation", "horizontalGrowth", "verticalGrowth", "columns",
            "spacing", "scale", "boxWidth", "boxHeight",
            "showNames", "nameJustifyH", "nameJustifyV", "nameFontSize",
            "cooldownJustifyH", "cooldownJustifyV", "cooldownFontSize", "showStacks",
            "showWhenClean", "cleanAlpha", "useClassColours", "showBorders",
            "showDispelTypeIcon", "dispelTypeIconSize", "dispelTypeIconPosition",
        }) do
            ns.Set(key, ns.defaults[key])
        end
        previewCount = 5
        previewCellState = "DISPELLABLE"
        previewCooldownState = "COOLDOWN"
        previewMovementSweep = false
        refreshPreview()
    end, "Reset Panel")
    add(reset, -ry)

    local pageBottom
    local function reflow()
        local y = -8
        for _, entry in ipairs(sections) do
            local shown = not entry.visible or entry.visible()
            entry.frame:SetShown(shown)
            if shown then
                entry.frame:ClearAllPoints()
                entry.frame:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, y)
                entry.frame:SetHeight(entry.height)
                y = y - entry.height
            end
        end
        pageBottom = y - 8
        panel.hcSetBottom(pageBottom)
    end

    panel.hcRefresh[#panel.hcRefresh + 1] = reflow
    reflow()
    return pageBottom
end)
