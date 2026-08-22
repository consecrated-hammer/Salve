local addonName, ns = ...
local O = ns.Options

local function section(parent)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(560, 1)
    frame.salveRefresh = parent.salveRefresh
    frame.salveRefreshAll = parent.salveRefreshAll
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
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width, 22)
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
    title = "Appearance",
    description = "How the grid looks — layout, size, and what each cell shows.",
}, function(panel)
    local db = ns.db
    local previewCount = 5
    local previewCellState = "DISPELLABLE"
    local previewCooldownState = "COOLDOWN"
    local sections = {}

    local function add(frame, height, visible)
        sections[#sections + 1] = {
            frame = frame,
            height = height,
            visible = visible,
        }
    end

    local preview = section(panel)
    local py = -8
    _, py = O.Header(preview, "Preview", py)

    local previewButton = CreateFrame("Button", nil, preview, "UIPanelButtonTemplate")
    previewButton:SetSize(150, 22)
    previewButton:SetPoint("TOPLEFT", 16, py - 16)
    O.AttachHint(previewButton, "Live panel preview",
        "Show a full-size, non-clickable test panel at Salve's saved position. It closes with this page and when combat starts.")

    local unitsLabel = smallLabel(preview, "Units", 182, py)
    local minus = CreateFrame("Button", nil, preview, "UIPanelButtonTemplate")
    minus:SetSize(24, 22)
    minus:SetPoint("TOPLEFT", 182, py - 16)
    minus:SetText("-")
    local countText = preview:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    countText:SetPoint("LEFT", minus, "RIGHT", 8, 0)
    countText:SetWidth(22)
    countText:SetJustifyH("CENTER")
    local plus = CreateFrame("Button", nil, preview, "UIPanelButtonTemplate")
    plus:SetSize(24, 22)
    plus:SetPoint("LEFT", countText, "RIGHT", 8, 0)
    plus:SetText("+")

    local stateLabel = smallLabel(preview, "State", 284, py)
    local cooldownLabel = smallLabel(preview, "Cooldown", 416, py)

    local previewDetails = {
        unitsLabel, minus, countText, plus, stateLabel, cooldownLabel,
    }

    local function applyPreviewSettings()
        ns.Preview.count = previewCount
        ns.Preview.cellState = previewCellState
        ns.Preview.cooldownState = previewCooldownState
        if ns.Preview.active then ns.Preview:Refresh() end
    end

    local function refreshPreview()
        countText:SetText(tostring(previewCount))
        previewButton:SetText(ns.Preview.active and "Hide preview" or "Show preview")
        for _, control in ipairs(previewDetails) do
            control:SetShown(ns.Preview.active and true or false)
        end
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
    previewButton:SetScript("OnClick", function()
        applyPreviewSettings()
        ns.Preview:Toggle()
        refreshPreview()
    end)

    local stateButton = toolbarCycle(preview, 284, py - 16, 116, "Preview state",
        "Show a clean group or one with one or two dispellable cells.",
        { "CLEAR", "DISPELLABLE" }, { "Clear", "Needs dispel" },
        function() return previewCellState end,
        function(value) previewCellState = value; applyPreviewSettings() end)
    local cooldownButton = toolbarCycle(preview, 416, py - 16, 112, "Preview cooldown",
        "Show the dispel spell ready or on cooldown.",
        { "READY", "COOLDOWN" }, { "Ready", "On cooldown" },
        function() return previewCooldownState end,
        function(value) previewCooldownState = value; applyPreviewSettings() end)

    previewDetails[#previewDetails + 1] = stateButton
    previewDetails[#previewDetails + 1] = cooldownButton

    preview.salveRefresh[#preview.salveRefresh + 1] = refreshPreview
    O.RefreshPreviewControls = refreshPreview
    refreshPreview()
    py = py - 48
    add(preview, -py)

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
        "Use about 58 or more if you show unit names.", sy,
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
        "Names work best with cells about 58 pixels wide or more.", cy,
        function() return db.showNames end,
        function(value) ns.Set("showNames", value) end)
    _, cy = O.Check(contents, "Show stack counts",
        "The game hides the number when there is only one stack.", cy,
        function() return db.showStacks end,
        function(value) ns.Set("showStacks", value) end)
    add(contents, -cy + 4)

    local names = section(panel)
    local ny = -8
    _, ny = O.Header(names, "Unit names", ny)
    _, _, ny = O.CyclePair(names, "Alignment", ny,
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
    _, _, dy = O.CyclePair(cooldown, "Alignment", dy,
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
    local paletteNote = cooldown:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    paletteNote:SetPoint("TOPLEFT", 16, dy + 2)
    paletteNote:SetWidth(520)
    paletteNote:SetJustifyH("LEFT")
    paletteNote:SetText("Debuff colours come from the game's dispel palette. Colourblind settings apply automatically.")
    dy = dy - 28
    add(cooldown, -dy + 4)

    local reset = section(panel)
    local _, ry = O.PageReset(reset, -4, function()
        for _, key in ipairs({
            "orientation", "horizontalGrowth", "verticalGrowth", "columns",
            "spacing", "scale", "boxWidth", "boxHeight",
            "showTooltip", "showNames", "nameJustifyH", "nameJustifyV", "nameFontSize",
            "cooldownJustifyH", "cooldownJustifyV", "cooldownFontSize", "showStacks",
        }) do
            ns.Set(key, ns.defaults[key])
        end
        previewCount = 5
        previewCellState = "DISPELLABLE"
        previewCooldownState = "COOLDOWN"
        applyPreviewSettings()
    end)
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
