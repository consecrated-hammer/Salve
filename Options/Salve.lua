local addonName, ns = ...
local O = ns.Options

local PREVIEW_NAMES = {
    "Silverhammer", "Beaststalker", "Stormtotemic", "Nightstalker", "Spiritmender",
}
local PREVIEW_CLASSES = { "PALADIN", "HUNTER", "SHAMAN", "ROGUE", "PRIEST" }
local FALLBACK_CLASS_COLOURS = {
    PALADIN = { r = 0.96, g = 0.55, b = 0.73 },
    HUNTER = { r = 0.67, g = 0.83, b = 0.45 },
    SHAMAN = { r = 0.00, g = 0.44, b = 0.87 },
    ROGUE = { r = 1.00, g = 0.96, b = 0.41 },
    PRIEST = { r = 1.00, g = 1.00, b = 1.00 },
}

local PREVIEW_DISPEL_COLOURS = {
    { 0.18, 0.55, 0.95 }, -- Magic
    { 0.72, 0.30, 0.88 }, -- Curse
    { 0.88, 0.62, 0.18 }, -- Disease
    { 0.20, 0.72, 0.30 }, -- Poison
}

local function currentGroupSize()
    local count = GetNumGroupMembers and GetNumGroupMembers() or 0
    return math.max(1, math.min(40, count))
end

local function placePreviewText(text, cell, horizontal, vertical)
    horizontal = horizontal or "LEFT"
    vertical = vertical or "MIDDLE"

    -- Do not rely on FontString justification here. Retail can retain the old
    -- glyph layout after a bounded FontString changes alignment, even after its
    -- anchors move. Measure the one-line text and position its rectangle in
    -- pixels instead; each of the nine combinations then has one exact result.
    local cellWidth, cellHeight = cell:GetWidth(), cell:GetHeight()
    local availableWidth = math.max(1, cellWidth - 6)
    local availableHeight = math.max(1, cellHeight - 2)
    local measuredWidth = text.GetUnboundedStringWidth
        and text:GetUnboundedStringWidth() or text:GetStringWidth()
    local _, fontSize = text:GetFont()
    local width = math.min(availableWidth, math.max(1, math.ceil(measuredWidth + 1)))
    local height = math.min(availableHeight,
        math.max(1, math.ceil((tonumber(fontSize) or 10) + 2)))

    local x
    if horizontal == "RIGHT" then
        x = cellWidth - 3 - width
    elseif horizontal == "CENTER" then
        x = (cellWidth - width) / 2
    else
        x = 3
    end

    local y
    if vertical == "BOTTOM" then
        y = cellHeight - 1 - height
    elseif vertical == "MIDDLE" then
        y = (cellHeight - height) / 2
    else
        y = 1
    end

    text:ClearAllPoints()
    text:SetSize(width, height)
    text:SetPoint("TOPLEFT", cell, "TOPLEFT", x, -y)
    text:SetJustifyH("LEFT")
    text:SetJustifyV("TOP")
end

local function stylePreviewFont(text, template, size, outline)
    local fontPath
    if template and template.GetFont then fontPath = template:GetFont() end
    fontPath = fontPath or STANDARD_TEXT_FONT
    if fontPath then text:SetFont(fontPath, math.max(6, size), outline or "") end
end

function O.PreviewLayout(count, db, maxWidth, maxHeight)
    count = math.max(1, math.min(40, count))
    local perLine = math.max(1, db.columns)
    local across, down
    if db.orientation == "VERTICAL" then
        across, down = math.ceil(count / perLine), math.min(count, perLine)
    else
        across, down = math.min(count, perLine), math.ceil(count / perLine)
    end

    local naturalW = across * db.boxWidth + math.max(0, across - 1) * db.spacing
    local naturalH = down * db.boxHeight + math.max(0, down - 1) * db.spacing
    local scale = math.min(db.scale, maxWidth / math.max(1, naturalW),
        maxHeight / math.max(1, naturalH))
    local width = db.boxWidth * scale
    local height = db.boxHeight * scale
    local gap = db.spacing * scale

    return {
        count = count,
        perLine = perLine,
        across = across,
        down = down,
        scale = scale,
        width = width,
        height = height,
        gap = gap,
        gridWidth = across * width + math.max(0, across - 1) * gap,
        gridHeight = down * height + math.max(0, down - 1) * gap,
    }
end

O.NewPage({
    name = "Salve",
    description = "How the grid looks — layout, size, and what each cell shows.",
}, function(panel, y)
    local db = ns.db
    local previewCount = currentGroupSize()
    local previewInitialised = false
    local previewCellState = "DISPELLABLE"
    local previewCooldownState = "COOLDOWN"
    local previewCooldownStart
    local previewUpdateElapsed = 0

    -- The preview stays pinned below the page heading. Only the controls below
    -- it scroll, so changes remain visible on long option pages.
    local pinned = panel.salveCreatePinned(150)
    local previewY
    _, previewY = O.Header(pinned, "Preview", -8)

    local preview = CreateFrame("Frame", nil, pinned, "BackdropTemplate")
    preview:SetPoint("TOPLEFT", 16, previewY)
    preview:SetSize(520, 100)
    preview:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 8,
    })
    preview:SetBackdropColor(0.035, 0.035, 0.04, 0.9)
    preview:SetBackdropBorderColor(0.35, 0.35, 0.38, 0.8)
    if preview.SetClipsChildren then preview:SetClipsChildren(true) end

    local cells = {}

    for i = 1, 40 do
        local cell = CreateFrame("Frame", nil, preview, "BackdropTemplate")
        if cell.SetClipsChildren then cell:SetClipsChildren(true) end
        cell:SetBackdrop({
            bgFile = "Interface\\TargetingFrame\\UI-StatusBar",
        })

        cell.cooldown = CreateFrame("Cooldown", nil, cell, "CooldownFrameTemplate")
        cell.cooldown:SetAllPoints(cell)
        cell.cooldown:SetFrameLevel(cell:GetFrameLevel() + 5)
        if cell.cooldown.SetDrawSwipe then cell.cooldown:SetDrawSwipe(true) end
        if cell.cooldown.SetDrawEdge then cell.cooldown:SetDrawEdge(false) end
        if cell.cooldown.SetDrawBling then cell.cooldown:SetDrawBling(false) end
        if cell.cooldown.SetSwipeColor then
            cell.cooldown:SetSwipeColor(0, 0, 0, 0.72)
        end
        if cell.cooldown.SetHideCountdownNumbers then
            -- The real frame supplies the sweep and dimming. A preview-owned
            -- FontString below supplies stable whole numbers and positioning;
            -- Blizzard otherwise re-anchors its countdown during updates.
            cell.cooldown:SetHideCountdownNumbers(true)
        end
        if cell.cooldown.SetMinimumCountdownDuration then
            cell.cooldown:SetMinimumCountdownDuration(0)
        end
        if cell.cooldown.EnableMouse then cell.cooldown:EnableMouse(false) end

        cell.textLayer = CreateFrame("Frame", nil, cell)
        cell.textLayer:SetAllPoints(cell)
        cell.textLayer:SetFrameLevel(cell:GetFrameLevel() + 10)

        cell.name = cell.textLayer:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        if cell.name.SetWordWrap then cell.name:SetWordWrap(false) end

        cell.cooldownText = cell.textLayer:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        cell.cooldownText:SetTextColor(1, 0.86, 0.18, 1)
        if cell.cooldownText.SetShadowColor then
            cell.cooldownText:SetShadowColor(0, 0, 0, 1)
        end
        if cell.cooldownText.SetShadowOffset then
            cell.cooldownText:SetShadowOffset(1, -1)
        end

        cell.stack = cell.textLayer:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
        cell.stack:SetPoint("BOTTOMRIGHT", -2, 1)

        cell.border = CreateFrame("Frame", nil, cell, "BackdropTemplate")
        cell.border:SetPoint("TOPLEFT", cell, "TOPLEFT", -1, 1)
        cell.border:SetPoint("BOTTOMRIGHT", cell, "BOTTOMRIGHT", 1, -1)
        cell.border:SetFrameLevel(cell:GetFrameLevel() + 12)
        cell.border:SetBackdrop({
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 6,
        })
        cell.border:SetBackdropBorderColor(0.62, 0.62, 0.65, 0.9)
        cell.border:EnableMouse(false)
        cells[i] = cell
    end

    local fitNote = pinned:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    fitNote:SetPoint("TOPRIGHT", preview, "BOTTOMRIGHT", 0, -2)
    fitNote:SetText("Preview shrinks to fit.")

    local function redrawPreview()
        if not previewInitialised then
            previewCount = currentGroupSize()
            previewInitialised = true
        end
        local layout = O.PreviewLayout(previewCount, db, 500, 80)
        local startX = math.max(10, (520 - layout.gridWidth) / 2)
        local startY = -math.max(10, (100 - layout.gridHeight) / 2)

        for i, cell in ipairs(cells) do
            if i <= layout.count then
                local n0, col, row = i - 1
                if db.orientation == "VERTICAL" then
                    col, row = math.floor(n0 / layout.perLine), n0 % layout.perLine
                else
                    col, row = n0 % layout.perLine, math.floor(n0 / layout.perLine)
                end

                cell:ClearAllPoints()
                cell:SetPoint("TOPLEFT", preview, "TOPLEFT",
                    startX + col * (layout.width + layout.gap),
                    startY - row * (layout.height + layout.gap))
                cell:SetSize(layout.width, layout.height)

                local dispellable = previewCellState == "DISPELLABLE"
                if dispellable then
                    local c = PREVIEW_DISPEL_COLOURS[((i - 1) % #PREVIEW_DISPEL_COLOURS) + 1]
                    cell:SetBackdropColor(c[1], c[2], c[3], 0.95)
                else
                    local classKey = PREVIEW_CLASSES[((i - 1) % #PREVIEW_CLASSES) + 1]
                    local classColour = RAID_CLASS_COLORS and RAID_CLASS_COLORS[classKey]
                        or FALLBACK_CLASS_COLOURS[classKey]
                    if db.useClassColours and classColour then
                        cell:SetBackdropColor(classColour.r, classColour.g, classColour.b,
                            db.showWhenClean and db.cleanAlpha or 0)
                    else
                        cell:SetBackdropColor(0.18, 0.18, 0.18,
                            db.showWhenClean and db.cleanAlpha or 0)
                    end
                end
                cell:SetAlpha(1)

                local classKey = PREVIEW_CLASSES[((i - 1) % #PREVIEW_CLASSES) + 1]
                local nameColour = RAID_CLASS_COLORS and RAID_CLASS_COLORS[classKey]
                    or FALLBACK_CLASS_COLOURS[classKey]
                cell.name:SetTextColor(nameColour.r, nameColour.g, nameColour.b)
                stylePreviewFont(cell.name, GameFontHighlightSmall,
                    db.nameFontSize * layout.scale)
                cell.name:SetText(db.showNames
                    and PREVIEW_NAMES[((i - 1) % #PREVIEW_NAMES) + 1] or "")
                placePreviewText(cell.name, cell, db.nameJustifyH, db.nameJustifyV)

                cell.stack:SetText(db.showStacks and dispellable and i % 3 == 0 and "3" or "")
                stylePreviewFont(cell.stack, NumberFontNormalSmall,
                    11 * layout.scale, "OUTLINE")

                stylePreviewFont(cell.cooldownText, GameFontNormal,
                    db.cooldownFontSize * layout.scale, "THICKOUTLINE")
                if previewCooldownState == "COOLDOWN" then
                    local now = GetTime()
                    if not previewCooldownStart or now - previewCooldownStart >= 8 then
                        previewCooldownStart = now
                    end
                    cell.cooldown:SetCooldown(previewCooldownStart, 8)
                    cell.cooldown:Show()
                    local remaining = math.max(1,
                        math.ceil(8 - (now - previewCooldownStart)))
                    cell.cooldownText:SetText(remaining)
                    placePreviewText(cell.cooldownText, cell,
                        db.cooldownJustifyH, db.cooldownJustifyV)
                else
                    if cell.cooldown.Clear then cell.cooldown:Clear() end
                    cell.cooldown:Hide()
                    cell.cooldownText:SetText("")
                end
                cell:Show()
            else
                cell:Hide()
            end
        end
    end

    preview:SetScript("OnUpdate", function(_, elapsed)
        if previewCooldownState ~= "COOLDOWN" or not previewCooldownStart then return end
        previewUpdateElapsed = previewUpdateElapsed + elapsed
        if previewUpdateElapsed < 0.05 then return end
        previewUpdateElapsed = 0

        local now = GetTime()
        if now - previewCooldownStart >= 8 then
            previewCooldownStart = now
            for _, cell in ipairs(cells) do
                if cell:IsShown() then cell.cooldown:SetCooldown(now, 8) end
            end
        end
        local remaining = math.max(1, math.ceil(8 - (now - previewCooldownStart)))
        for _, cell in ipairs(cells) do
            if cell:IsShown() then
                cell.cooldownText:SetText(remaining)
                placePreviewText(cell.cooldownText, cell,
                    db.cooldownJustifyH, db.cooldownJustifyV)
            end
        end
    end)

    panel.salveRefresh[#panel.salveRefresh + 1] = redrawPreview

    _, y = O.Slider(panel, "Preview group size", nil, y,
        1, 40, 1,
        function() return previewCount end,
        function(v) previewCount = v end)

    _, y = O.Cycle(panel, "Preview cell state",
        "Show cells with nothing to dispel or cells that need your dispel.", y,
        { "CLEAR", "DISPELLABLE" }, { "Nothing to dispel", "Needs dispel" },
        function() return previewCellState end,
        function(v) previewCellState = v end)

    _, y = O.Cycle(panel, "Preview dispel cooldown",
        "Show the dispel spell ready or on cooldown.", y,
        { "READY", "COOLDOWN" }, { "Ready", "On cooldown" },
        function() return previewCooldownState end,
        function(v)
            previewCooldownState = v
            previewCooldownStart = v == "COOLDOWN" and GetTime() or nil
        end)

    _, y = O.Header(panel, "Layout", y)

    _, y = O.Cycle(panel, "Fill direction",
        "Horizontal fills rows. Vertical fills columns.", y,
        { "HORIZONTAL", "VERTICAL" }, { "Horizontal", "Vertical" },
        function() return db.orientation end,
        function(v) ns.Set("orientation", v) end)

    _, y = O.Slider(panel,
        function() return db.orientation == "VERTICAL"
            and "Cells per column" or "Cells per row" end,
        "How many cells appear before the next line starts.", y,
        1, 10, 1,
        function() return db.columns end,
        function(v) ns.Set("columns", v) end)

    _, y = O.Slider(panel, "Spacing", "Gap between cells, in pixels.", y,
        0, 12, 1,
        function() return db.spacing end,
        function(v) ns.Set("spacing", v) end)

    _, y = O.Slider(panel, "Overall scale", nil, y,
        0.5, 2, 0.05,
        function() return db.scale end,
        function(v) ns.Set("scale", v) end,
        function(v) return string.format("%.2f", v) end)

    _, y = O.Header(panel, "Cell size", y)

    _, y = O.Slider(panel, "Width",
        "Use about 58 or more if you show unit names.", y,
        10, 300, 1,
        function() return db.boxWidth end,
        function(v) ns.Set("boxWidth", v) end)

    _, y = O.Slider(panel, "Height", nil, y,
        10, 150, 1,
        function() return db.boxHeight end,
        function(v) ns.Set("boxHeight", v) end)

    _, y = O.Header(panel, "Inside each cell", y)

    local showNames
    showNames, y = O.Check(panel, "Show unit names",
        "Names work best with cells about 58 pixels wide or more.", y,
        function() return db.showNames end,
        function(v) ns.Set("showNames", v) end)

    local nameHorizontal, nameVertical
    nameHorizontal, nameVertical, y = O.CyclePair(panel, "Name alignment", y,
        {
            label = "Horizontal",
            hint = "Place names against the left edge, centre or right edge.",
            values = { "LEFT", "CENTER", "RIGHT" },
            labels = { "Left", "Centre", "Right" },
            get = function() return db.nameJustifyH end,
            set = function(v) ns.Set("nameJustifyH", v) end,
        },
        {
            label = "Vertical",
            hint = "Place names at the top, middle or bottom of each cell.",
            values = { "TOP", "MIDDLE", "BOTTOM" },
            labels = { "Top", "Middle", "Bottom" },
            get = function() return db.nameJustifyV end,
            set = function(v) ns.Set("nameJustifyV", v) end,
        })

    local nameSize
    panel.salveRefresh[#panel.salveRefresh + 1] = function()
        O.SetEnabled(nameHorizontal, db.showNames)
        O.SetEnabled(nameVertical, db.showNames)
        O.SetEnabled(nameSize, db.showNames)
    end

    nameSize, y = O.Slider(panel, "Name text size", "Size before Overall scale is applied.", y,
        6, 32, 1,
        function() return db.nameFontSize end,
        function(v) ns.Set("nameFontSize", v) end)

    _, _, y = O.CyclePair(panel, "Cooldown alignment", y,
        {
            label = "Horizontal",
            hint = "Place the cooldown number on the left, centre or right.",
            values = { "LEFT", "CENTER", "RIGHT" },
            labels = { "Left", "Centre", "Right" },
            get = function() return db.cooldownJustifyH end,
            set = function(v) ns.Set("cooldownJustifyH", v) end,
        },
        {
            label = "Vertical",
            hint = "Place the cooldown number at the top, middle or bottom.",
            values = { "TOP", "MIDDLE", "BOTTOM" },
            labels = { "Top", "Middle", "Bottom" },
            get = function() return db.cooldownJustifyV end,
            set = function(v) ns.Set("cooldownJustifyV", v) end,
        })

    _, y = O.Slider(panel, "Cooldown text size", "Size before Overall scale is applied.", y,
        6, 40, 1,
        function() return db.cooldownFontSize end,
        function(v) ns.Set("cooldownFontSize", v) end)

    _, y = O.Check(panel, "Show stack counts",
        "The game hides the number when there is only one stack.", y,
        function() return db.showStacks end,
        function(v) ns.Set("showStacks", v) end)

    _, y = O.Check(panel, "Use class colours when clear",
        "A dispellable debuff still uses Blizzard's dispel colour.", y,
        function() return db.useClassColours end,
        function(v) ns.Set("useClassColours", v) end)

    local note = panel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    note:SetPoint("TOPLEFT", 16, y - 2)
    note:SetWidth(520)
    note:SetJustifyH("LEFT")
    note:SetText("Debuff colours come from the game's dispel palette. Colourblind settings apply automatically.")
    y = y - 34

    _, y = O.PageReset(panel, y, function()
        for _, key in ipairs({
            "orientation", "columns", "spacing", "scale", "boxWidth", "boxHeight",
            "showNames", "nameJustifyH", "nameJustifyV", "nameFontSize",
            "cooldownJustifyH", "cooldownJustifyV", "cooldownFontSize",
            "showStacks", "useClassColours",
        }) do
            ns.Set(key, ns.defaults[key])
        end
        previewCount = currentGroupSize()
        previewCellState = "DISPELLABLE"
        previewCooldownState = "COOLDOWN"
        previewCooldownStart = GetTime()
    end)
    return y
end)
