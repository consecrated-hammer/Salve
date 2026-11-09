local addonName, ns = ...
local HC = ns.HammerCore
local O = ns.Options

-- Cooldown icons on the cells and the optional bar beside the grid. The bar
-- and lockouts are off by default; Auto sweep style only changes cells that
-- show names.

local SPELL_ROWS = 8

local function section(parent, width)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(O.CONTENT_WIDTH + O.PAD * 2, 1)
    frame.hcColumns = 2
    frame.hcRefresh = parent.hcRefresh
    frame.hcRefreshAll = parent.hcRefreshAll
    frame.hcHeaderOwner = parent.hcHeaderOwner or parent
    return frame
end

local function refreshPreview()
    if ns.Preview and ns.Preview.active then ns.Preview:Refresh() end
    if ns.Preview and ns.Preview.RefreshSettingsPreview then ns.Preview:RefreshSettingsPreview() end
end

HC.Settings:NewPage({
    name = "Cooldowns",
    profileGroups = { "cooldownBar" },
    -- Cooldown icons and lockouts are shared by all profiles.
    profilePartial = true,
    title = "Cooldowns",
    group = "main",
    description = "Spell icons for cooldown sweeps, and a cooldown bar.",
    headerAction = ns.Options.LivePreviewAction,
}, function(panel, y)
    local db = ns.db
    local controls = section(panel, 264)
    controls:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)

    _, y = O.Header(controls, "Cell sweep", y)
    _, y = O.Dropdown(controls, "Sweep style",
        "Whole cell sweeps across the cell. Icon shows each spell's icon on the cell, only while it's on cooldown. Auto uses Icon when names are on.", y,
        { "BOX", "ICON", "AUTO" }, { "Whole cell", "Icon", "Auto" },
        function() return db.cooldownStyle end,
        function(value) ns.Set("cooldownStyle", value) end,
        264, 90)
    _, y = O.Slider(controls, "Icon size", "Cell icon size, in pixels.", y,
        8, 64, 1,
        function() return db.cooldownIconSize end,
        function(value) ns.Set("cooldownIconSize", value) end,
        nil, 264)
    _, y = O.Dropdown(controls, "Icon position", "Where the cell icons sit. More than one lines up beside the first.", y,
        { "LEFT", "RIGHT", "CENTER", "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT" },
        { "Left", "Right", "Centre", "Top left", "Top right", "Bottom left", "Bottom right" },
        function() return db.cooldownIconPosition end,
        function(value) ns.Set("cooldownIconPosition", value) end,
        264, 90)

    _, y = O.Header(controls, "Lockouts", y - 4)
    _, y = O.Check(controls, "Show lockout debuffs",
        "Show Forbearance after you cast Blessing of Protection or similar on someone, until you can again. Only your own casts are tracked. Needs one of those spells bound on Key Bindings.", y,
        function() return db.lockoutIcons end,
        function(value) ns.Set("lockoutIcons", value) end, 264)
    _, y = O.Dropdown(controls, "Show on", "Cooldown bar shows it with the member's name, only while it lasts. Cell puts a small icon on their cell.", y,
        { "BAR", "CELL", "BOTH" }, { "Cooldown bar", "Cell", "Both" },
        function() return db.lockoutPlacement end,
        function(value) ns.Set("lockoutPlacement", value) end,
        264, 90)
    local lockoutSizeRow, lockoutPositionRow
    lockoutSizeRow, y = O.Slider(controls, "Icon size", "Cell lockout icon size, in pixels.", y,
        8, 48, 1,
        function() return db.lockoutIconSize end,
        function(value) ns.Set("lockoutIconSize", value) end,
        nil, 264)
    lockoutPositionRow, y = O.Dropdown(controls, "Icon position", "Where the lockout icon sits on the cell.", y,
        { "LEFT", "RIGHT", "CENTER", "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT" },
        { "Left", "Right", "Centre", "Top left", "Top right", "Bottom left", "Bottom right" },
        function() return db.lockoutIconPosition end,
        function(value) ns.Set("lockoutIconPosition", value) end,
        264, 90)

    _, y = O.Header(controls, "Cooldown bar", y - 4)
    _, y = O.Check(controls, "Show cooldown bar",
        "Icons beside the grid for the spells bound on Key Bindings. Moves with Salve.", y,
        function() return db.cooldownBar end,
        function(value) ns.Set("cooldownBar", value) end, 264)
    _, y = O.Check(controls, "Show when ready",
        "Keep ready spells on the bar, dimmed. Off, a spell shows only while it's on cooldown.", y,
        function() return db.cooldownBarShowReady end,
        function(value) ns.Set("cooldownBarShowReady", value) end, 264)
    _, y = O.Dropdown(controls, "Position", "Which side of the grid the bar sits on.", y,
        { "TOP", "BOTTOM", "LEFT", "RIGHT" }, { "Top", "Bottom", "Left", "Right" },
        function() return db.cooldownBarSide end,
        function(value) ns.Set("cooldownBarSide", value) end,
        264, 90)
    _, y = O.Dropdown(controls, "Layout", "Run the icons across or down.", y,
        { "HORIZONTAL", "VERTICAL" }, { "Horizontal", "Vertical" },
        function() return db.cooldownBarOrientation end,
        function(value) ns.Set("cooldownBarOrientation", value) end,
        264, 90)
    _, y = O.Check(controls, "Match Salve panel",
        "Use the cell height, cell spacing and box borders from the Panel page, so icons line up with the cells.", y,
        function() return db.cooldownBarMatchPanel end,
        function(value) ns.Set("cooldownBarMatchPanel", value) end, 264)
    _, y = O.Slider(controls, "Gap", "Distance from the grid, in pixels.", y,
        0, 50, 1,
        function() return db.cooldownBarGap end,
        function(value) ns.Set("cooldownBarGap", value) end,
        nil, 264)
    local sizeRow, spacingRow
    sizeRow, y = O.Slider(controls, "Bar icon size", "Bar icon size, in pixels. Ignored with Match Salve panel.", y,
        12, 64, 1,
        function() return db.cooldownBarIconSize end,
        function(value) ns.Set("cooldownBarIconSize", value) end,
        nil, 264)
    spacingRow, y = O.Slider(controls, "Spacing", "Space between bar icons, in pixels. Ignored with Match Salve panel.", y,
        0, 20, 1,
        function() return db.cooldownBarSpacing end,
        function(value) ns.Set("cooldownBarSpacing", value) end,
        nil, 264)

    _, y = O.Header(controls, "Bar spells", y - 4)
    -- The spell list is one column: rows come and go as bindings change.
    y = O.Columns(controls, 1, y)
    local empty
    empty, y = O.Text(controls, "No spells bound on Key Bindings.", y)
    local rowsY = y
    -- One row per bound spell. The list follows spec and Key Bindings, so the rows
    -- are a fixed pool relabelled on every refresh.
    local rows = {}
    for index = 1, SPELL_ROWS do
        local row
        row, y = O.Check(controls, "", "Show this spell on the bar.", y,
            function()
                local id = ns.Cooldowns:BoundSpells()[index]
                return id and not db.cooldownBarHidden[id]
            end,
            function(value)
                local id = ns.Cooldowns:BoundSpells()[index]
                if not id then return end
                db.cooldownBarHidden[id] = (not value) or nil
                ns.Cooldowns:Request()
                refreshPreview()
            end, 264)
        rows[index] = row
    end

    local footer = section(panel, 264)
    local footerY = -4
    _, footerY = O.PageReset(footer, footerY, function()
        for _, key in ipairs({ "cooldownStyle", "cooldownIconSize", "cooldownIconPosition",
            "lockoutIcons", "lockoutPlacement", "lockoutIconSize", "lockoutIconPosition",
            "cooldownBar", "cooldownBarShowReady", "cooldownBarSide", "cooldownBarGap",
            "cooldownBarIconSize", "cooldownBarSpacing", "cooldownBarOrientation",
            "cooldownBarMatchPanel" }) do
            ns.Set(key, ns.defaults[key])
        end
        db.cooldownBarHidden = {}
        ns.Cooldowns:Request()
        refreshPreview()
    end, "Reset Cooldowns")
    local footerHeight = -footerY

    local pageBottom
    local function reflow()
        local matched = db.cooldownBarMatchPanel and 0.5 or 1
        sizeRow:SetAlpha(matched)
        spacingRow:SetAlpha(matched)
        local onCells = db.lockoutPlacement ~= "BAR" and 1 or 0.5
        lockoutSizeRow:SetAlpha(onCells)
        lockoutPositionRow:SetAlpha(onCells)
        local spells = ns.Cooldowns:BoundSpells()
        empty:SetShown(#spells == 0)
        local rowY = #spells == 0 and rowsY or (rowsY + 24)
        for index, row in ipairs(rows) do
            local id = spells[index]
            row:SetShown(id ~= nil)
            if id then
                row.hcCheckbox.Text:SetText(ns.Cooldowns.SpellName(id))
                row.hcHintTitle = ns.Cooldowns.SpellName(id)
                row:ClearAllPoints()
                row:SetPoint("TOPLEFT", controls, "TOPLEFT", O.PAD or 16, rowY)
                rowY = rowY - O.CELL_H - 4
            end
        end
        footer:ClearAllPoints()
        footer:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, rowY)
        pageBottom = rowY - footerHeight - 8
        if panel.hcSetBottom then panel.hcSetBottom(pageBottom) end
    end
    controls.hcRefresh[#controls.hcRefresh + 1] = reflow
    reflow()
    return pageBottom
end)
