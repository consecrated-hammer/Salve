local addonName, ns = ...
local O = ns.Options

local function section(parent)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(560, 1)
    frame.salveRefresh = parent.salveRefresh
    frame.salveRefreshAll = parent.salveRefreshAll
    frame.salveHeaderOwner = parent.salveHeaderOwner or parent
    return frame
end

local function smallLabel(parent, text, x, y)
    local label = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    label:SetPoint("TOPLEFT", x, y)
    label:SetText(text)
    return label
end

local function toolbarCycle(parent, x, y, width, hintTitle, hint,
        values, labels, get, set)
    local button = O.Button(parent, width, 22)
    button:SetPoint("TOPLEFT", x, y)
    O.AttachHint(button, hintTitle, hint)

    local function render()
        local current = get()
        for index, value in ipairs(values) do
            if value == current then
                button:SetText(labels[index])
                return
            end
        end
        button:SetText(labels[1])
    end

    button:SetScript("OnClick", function()
        local current = get()
        for index, value in ipairs(values) do
            if value == current then
                set(values[(index % #values) + 1])
                render()
                return
            end
        end
        set(values[1])
        render()
    end)
    parent.salveRefresh[#parent.salveRefresh + 1] = render
    render()
    return button
end

O.NewPage({
    name = "Salve",
    title = "Panel",
    group = "CORE",
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

    local preview = panel.salveCreatePinned(290, 720)
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
    stage:SetBackdropColor(unpack(O.theme.rail))
    stage:SetBackdropBorderColor(unpack(O.theme.edge))
    stage.salveRefresh = preview.salveRefresh
    stage.salveRefreshAll = preview.salveRefreshAll

    local stageLabel = stage:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    stageLabel:SetPoint("TOPLEFT", 10, -8)
    stageLabel:SetText("LIVE PREVIEW")
    stageLabel:SetTextColor(unpack(O.theme.muted))

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
    simulatedLabel:SetTextColor(unpack(O.theme.muted))
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

    preview.salveRefresh[#preview.salveRefresh + 1] = refreshPreview
    O.RefreshPreviewControls = refreshPreview
    refreshPreview()
    local presets = section(panel)
    local presetY = -8
    _, presetY = O.Header(presets, "Presets", presetY)
    local presetSpecs = {
        { label = "Compact", note = "20px cells, no names", width = 20, height = 20, columns = 5, spacing = 1, names = false, previewUnits = 5 },
        { label = "Named", note = "95px cells, names on", width = 95, height = 20, columns = 5, spacing = 1, names = true, previewUnits = 5 },
        { label = "Raid wall", note = "Tight 10-cell wall, no names", width = 20, height = 20, columns = 10, spacing = 0, names = false, previewUnits = 40 },
    }
    for index, spec in ipairs(presetSpecs) do
        local button = O.SelectButton(presets, 168, 46)
        button:SetPoint("TOPLEFT", 16 + (index - 1) * 176, presetY - 4)
        button:SetText(spec.label)
        button.Text:ClearAllPoints()
        button.Text:SetPoint("TOPLEFT", 10, -7)
        button.Text:SetPoint("RIGHT", -10, 0)
        button.Text:SetJustifyH("LEFT")
        local note = button:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
        note:SetPoint("TOPLEFT", button.Text, "BOTTOMLEFT", 0, -2)
        note:SetText(spec.note)
        note:SetTextColor(unpack(O.theme.muted))
        O.AttachHint(button, spec.label, "Apply this panel shape.")
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
            if presets.salveRefreshAll then presets.salveRefreshAll() end
        end)
    end
    add(presets, -presetY + 58)

    local grid = section(panel)
    local gy = -8
    _, gy = O.Header(grid, "Grid", gy)
    _, _, gy = O.DropdownPair(grid, "Grid flow", gy,
        {
            label = "Fill",
            hint = "Rows fill across before wrapping. Columns fill down before wrapping.",
            values = { "HORIZONTAL", "VERTICAL" },
            labels = { "Rows", "Columns" },
            get = function() return db.orientation end,
            set = function(value) ns.Set("orientation", value) end,
        },
        {
            label = "Frames grow from",
            hint = "The selected edge stays fixed as group members are added.",
            values = function()
                return db.orientation == "VERTICAL"
                    and { "DOWN", "UP" } or { "RIGHT", "LEFT" }
            end,
            labels = function()
                return db.orientation == "VERTICAL"
                    and { "Top", "Bottom" }
                    or { "Left", "Right" }
            end,
            get = function()
                return db.orientation == "VERTICAL"
                    and db.verticalGrowth or db.horizontalGrowth
            end,
            set = function(value)
                ns.Set(db.orientation == "VERTICAL"
                    and "verticalGrowth" or "horizontalGrowth", value)
            end,
        })
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
        10, 300, 1,
        function() return db.boxWidth end,
        function(value) ns.Set("boxWidth", value) end)
    _, sy = O.Slider(size, "Height", nil, sy,
        10, 150, 1,
        function() return db.boxHeight end,
        function(value) ns.Set("boxHeight", value) end)
    _, sy = O.Slider(size, "UI scale",
        "Scales the entire Salve frame, including text and borders.", sy,
        0.5, 2, 0.05,
        function() return db.scale end,
        function(value) ns.Set("scale", value) end,
        function(value) return string.format("%.2f", value) end)
    add(size, -sy + 4)

    local contents = section(panel)
    local cy = -8
    _, cy = O.Header(contents, "Cell contents", cy)
    _, cy = O.Check(contents, "Tooltip on hover",
        "Shows who you are pointing at and what each mouse button will cast on them.", cy,
        function() return db.showTooltip end,
        function(value) ns.Set("showTooltip", value) end)
    _, cy = O.Check(contents, "Unit names",
        "Use cells at least 95 pixels wide for the twelve-character preview names.", cy,
        function() return db.showNames end,
        function(value) ns.Set("showNames", value) end)
    _, cy = O.Check(contents, "Show stack counts",
        "The game hides the number when there is only one stack.", cy,
        function() return db.showStacks end,
        function(value) ns.Set("showStacks", value) end)
    _, cy = O.Check(contents, "Use class colours",
        "Dispellable debuffs still use Blizzard's dispel colours.", cy,
        function() return db.useClassColours end,
        function(value) ns.Set("useClassColours", value) end)
    add(contents, -cy + 4)

    local dispelIcon = section(panel)
    local diy = -8
    _, diy = O.Header(dispelIcon, "Dispel icon", diy)
    _, diy = O.Check(dispelIcon, "Show dispel-type icon",
        "Show Blizzard's Magic, Curse, Disease or Poison icon on a dispellable cell.", diy,
        function() return db.showDispelTypeIcon end,
        function(value) ns.Set("showDispelTypeIcon", value) end)
    _, diy = O.Slider(dispelIcon, "Icon size",
        "Size in pixels before UI scale. Large icons can cover names or cooldown numbers.", diy,
        8, 64, 1,
        function() return db.dispelTypeIconSize end,
        function(value) ns.Set("dispelTypeIconSize", value) end)
    _, diy = O.Dropdown(dispelIcon, "Position",
        "Choose which part of the cell holds the Blizzard dispel-type icon.", diy,
        { "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT", "CENTER" },
        { "Top left", "Top right", "Bottom left", "Bottom right", "Centre" },
        function() return db.dispelTypeIconPosition end,
        function(value) ns.Set("dispelTypeIconPosition", value) end,
        560, 78)
    add(dispelIcon, -diy + 4)

    local inactive = section(panel)
    local iy = -8
    _, iy = O.Header(inactive, "Inactive units", iy)
    _, iy = O.Check(inactive, "Show units with nothing to dispel",
        "Off makes inactive cells transparent. Their click areas stay in place during combat.", iy,
        function() return db.showWhenClean end,
        function(value) ns.Set("showWhenClean", value) end)
    _, iy = O.Slider(inactive, "Opacity",
        "How visible inactive cells are when shown.", iy,
        0, 1, 0.05,
        function() return db.cleanAlpha end,
        function(value) ns.Set("cleanAlpha", value) end,
        function(value) return string.format("%d%%", math.floor(value * 100 + 0.5)) end)
    add(inactive, -iy + 4)

    local names = section(panel)
    local ny = -8
    _, ny = O.Header(names, "Unit names", ny)
    _, _, ny = O.DropdownPair(names, "Alignment", ny,
        {
            label = "Horizontal",
            hint = "Place names against the left edge, centre or right edge.",
            values = { "LEFT", "CENTER", "RIGHT" },
            labels = { "Left", "Centre", "Right" },
            get = function() return db.nameJustifyH end,
            set = function(value) ns.Set("nameJustifyH", value) end,
        },
        {
            label = "Vertical",
            hint = "Place names at the top, middle or bottom of each cell.",
            values = { "TOP", "MIDDLE", "BOTTOM" },
            labels = { "Top", "Middle", "Bottom" },
            get = function() return db.nameJustifyV end,
            set = function(value) ns.Set("nameJustifyV", value) end,
        })
    _, ny = O.Slider(names, "Text size", "Size before UI scale is applied.", ny,
        6, 32, 1,
        function() return db.nameFontSize end,
        function(value) ns.Set("nameFontSize", value) end)
    add(names, -ny + 4, function() return db.showNames end)

    local cooldown = section(panel)
    local dy = -8
    _, dy = O.Header(cooldown, "Cooldown", dy)
    _, _, dy = O.DropdownPair(cooldown, "Alignment", dy,
        {
            label = "Horizontal",
            hint = "Place the cooldown number on the left, centre or right.",
            values = { "LEFT", "CENTER", "RIGHT" },
            labels = { "Left", "Centre", "Right" },
            get = function() return db.cooldownJustifyH end,
            set = function(value) ns.Set("cooldownJustifyH", value) end,
        },
        {
            label = "Vertical",
            hint = "Place the cooldown number at the top, middle or bottom.",
            values = { "TOP", "MIDDLE", "BOTTOM" },
            labels = { "Top", "Middle", "Bottom" },
            get = function() return db.cooldownJustifyV end,
            set = function(value) ns.Set("cooldownJustifyV", value) end,
        })
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
            "showTooltip", "showNames", "nameJustifyH", "nameJustifyV", "nameFontSize",
            "cooldownJustifyH", "cooldownJustifyV", "cooldownFontSize", "showStacks",
            "showWhenClean", "cleanAlpha", "useClassColours",
            "showDispelTypeIcon", "dispelTypeIconSize", "dispelTypeIconPosition",
        }) do
            ns.Set(key, ns.defaults[key])
        end
        previewCount = 5
        previewCellState = "DISPELLABLE"
        previewCooldownState = "COOLDOWN"
        applyPreviewSettings()
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
        panel.salveSetBottom(pageBottom)
    end

    panel.salveRefresh[#panel.salveRefresh + 1] = reflow
    reflow()
    return pageBottom
end)
