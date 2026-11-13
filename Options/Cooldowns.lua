local addonName, ns = ...
local HC, O = ns.HammerCore, ns.Options

local POSITIONS = { "LEFT", "RIGHT", "CENTER", "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT" }
local POSITION_LABELS = { "Left", "Right", "Centre", "Top left", "Top right", "Bottom left", "Bottom right" }
local TEXT_POSITIONS = { "LEFT:TOP", "CENTER:TOP", "RIGHT:TOP", "LEFT:MIDDLE", "CENTER:MIDDLE", "RIGHT:MIDDLE", "LEFT:BOTTOM", "CENTER:BOTTOM", "RIGHT:BOTTOM" }
local TEXT_LABELS = { "Top left", "Top centre", "Top right", "Middle left", "Centre", "Middle right", "Bottom left", "Bottom centre", "Bottom right" }

local TAB_KEYS = {
    Cells = { "cooldownStyle", "cooldownIconSize", "cooldownIconPosition", "cooldownJustifyH", "cooldownJustifyV", "cooldownFontSize", "movementSweepSpellIDs", "movementSweepColours" },
    Bar = { "cooldownBar", "cooldownBarShowReady", "cooldownBarSide", "cooldownBarGap", "cooldownBarIconSize", "cooldownBarSpacing", "cooldownBarOrientation", "cooldownBarMatchPanel", "cooldownBarHidden" },
    Lockouts = { "lockoutIcons", "lockoutPlacement", "lockoutIconSize", "lockoutIconPosition" },
}
local function refreshPreview()
    if ns.Preview and ns.Preview.active then ns.Preview:Refresh() end
    if ns.Preview and ns.Preview.RefreshSettingsPreview then ns.Preview:RefreshSettingsPreview() end
end
local function reset(name)
    return function()
        for _, key in ipairs(TAB_KEYS[name]) do ns.Set(key, ns.defaults[key]) end
        if name == "Cells" and ns.Binding then ns.Binding:RefreshMovementCooldowns("movement sweeps reset") end
        ns.Cooldowns:Request()
        refreshPreview()
    end
end
local function addSection(panel, add, title, fill, visible, parentRow, columns)
    local frame = O.Section(panel, columns or 2, parentRow)
    local y = -4
    if title then _, y = O.Header(frame, title, y) end
    local result
    y, result = fill(frame, y)
    y = O.Flush(frame, y)
    add(frame, -y + 4, visible, parentRow)
    return result
end
local function dropdown(frame, label, hint, y, key, values, labels)
    return O.Dropdown(frame, label, hint, y, values, labels,
        function() return ns.db[key] end, function(value) ns.Set(key, value) end, 264, 90)
end
local function slider(frame, label, hint, y, key, minimum, maximum)
    return O.Slider(frame, label, hint, y, minimum, maximum, 1,
        function() return ns.db[key] end, function(value) ns.Set(key, value) end, nil, 264)
end

HC.Settings:NewPage({
    name = "Cooldowns", title = "Cooldowns", group = "main",
    description = "Cooldown sweeps, movement sweeps, the bar and lockouts.",
    headerAction = O.LivePreviewAction,
    profileScope = function(tab) return tab == "Bar" end,
    tabs = {
        { name = "On cells", build = O.Tab("On cells", function(panel, add, db)
            local style = addSection(panel, add, "Cell sweep", function(frame, y)
                local row
                row, y = dropdown(frame, "Sweep style", "Whole cell sweeps across the cell. Icon shows a spell icon while it is on cooldown. Auto uses Icon when names are on.", y, "cooldownStyle", { "BOX", "ICON", "AUTO" }, { "Whole cell", "Icon", "Auto" })
                return y, row
            end)
            addSection(panel, add, nil, function(frame, y)
                _, y = slider(frame, "Cooldown icon size", "Cell cooldown icon size, in pixels.", y, "cooldownIconSize", 8, 64)
                _, y = dropdown(frame, "Cooldown icon position", "Where cooldown icons sit on the cell.", y, "cooldownIconPosition", POSITIONS, POSITION_LABELS)
                return y
            end, function() return db.cooldownStyle ~= "BOX" end, style)
            addSection(panel, add, "Cooldown numbers", function(frame, y)
                _, y = O.Dropdown(frame, "Number position", "Place cooldown numbers within each cell.", y, TEXT_POSITIONS, TEXT_LABELS,
                    function() return db.cooldownJustifyH .. ":" .. db.cooldownJustifyV end,
                    function(value)
                        local horizontal, vertical = value:match("^([^:]+):([^:]+)$")
                        ns.Set("cooldownJustifyH", horizontal); ns.Set("cooldownJustifyV", vertical)
                    end, 264, 90)
                _, y = slider(frame, "Number text size", "Size before UI scale is applied.", y, "cooldownFontSize", 6, 40)
                return y
            end)
    -- Movement sweeps: one row per bound movement spell, with its colour and
    -- whether the sweep shows.
    local sweeps = O.Section(panel, 1)
    O.RegisterRow(sweeps, sweeps, "Movement sweeps")
    local _, sweepTop = O.Header(sweeps, "Movement sweeps", -4)
    local sweepNote
    sweepNote, sweepTop = O.Text(sweeps, "The coloured countdown on your cell after you cast a bound movement spell.", sweepTop)
    local sweepEmpty = O.FontString(sweeps, "GameFontHighlightSmall", "muted")
    sweepEmpty:SetPoint("TOPLEFT", O.PAD + 2, sweepTop - 4)
    sweepEmpty:SetText("No movement spells bound yet.")
    local sweepRows = {}
    local function sweepRow(index)
        if sweepRows[index] then return sweepRows[index] end
        local row = O.Row(sweeps, sweepTop - (index - 1) * (O.CELL_H + 4), O.CELL_H, "",
            "The sweep's colour, and whether it shows on your cell.")
        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(24, 24)
        row.icon:SetPoint("LEFT", O.CELL_INSET, 0)
        row.Title:ClearAllPoints()
        row.Title:SetPoint("LEFT", row.icon, "RIGHT", 10, 0)
        row.swatch = O.Button(row, 34, 22)
        row.swatch:SetPoint("RIGHT", -O.CELL_INSET, 0)
        row.swatch.fill = row.swatch:CreateTexture(nil, "ARTWORK")
        row.swatch.fill:SetSize(20, 12)
        row.swatch.fill:SetPoint("CENTER")
        O.AttachHint(row.swatch, "Sweep colour", "Pick the colour of this spell's sweep.")
        row.show = O.Switch(row)
        row.show:SetSize(170, O.CELL_H)
        row.show:SetPoint("RIGHT", row.swatch, "LEFT", -12, 0)
        row.show.Text:SetText("Show sweep")
        sweepRows[index] = row
        return row
    end
    local function layoutSweeps()
        local bound = {}
        for _, entry in ipairs(O.BoundSpells and O.BoundSpells() or {}) do
            if entry.kind == "ESCAPE" then bound[#bound + 1] = entry end
        end
        sweepEmpty:SetShown(#bound == 0)
        for index, entry in ipairs(bound) do
            local row, spell = sweepRow(index), entry.spell
            row.icon:SetTexture(O.SpellIcon(spell.id))
            row.Title:SetText(spell.name)
            if row.hcSearchLabel then (panel.hcHeaderOwner or panel).hcRows[row.hcSearchLabel] = nil end
            row.hcSearchLabel = "Movement sweep: " .. spell.name
            O.RegisterRow(sweeps, row, row.hcSearchLabel)
            local r, g, b, a = ns.Binding:GetMovementSweepColour(spell.id)
            row.swatch.fill:SetColorTexture(r, g, b, a)
            row.swatch:SetScript("OnClick", function()
                O.ShowColourPicker({ r = r, g = g, b = b, a = a }, function(colour)
                    local colours = {}
                    for id, value in pairs(ns.db.movementSweepColours or {}) do colours[id] = value end
                    colours[spell.id] = colour
                    ns.Set("movementSweepColours", colours)
                    ns.Binding:RefreshMovementCooldowns("movement sweep colour changed")
                    panel.hcRefreshAll()
                end)
            end)
            row.show:SetChecked(ns.db.movementSweepSpellIDs and ns.db.movementSweepSpellIDs[spell.id])
            row.show:SetScript("OnClick", function()
                local selected = {}
                for id, enabled in pairs(ns.db.movementSweepSpellIDs or {}) do
                    if enabled then selected[id] = true end
                end
                selected[spell.id] = not selected[spell.id] or nil
                ns.Set("movementSweepSpellIDs", selected)
                ns.Binding:RefreshMovementCooldowns("movement sweep selection changed")
                panel.hcRefreshAll()
            end)
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", O.PAD, sweepTop - (index - 1) * (O.CELL_H + 4))
            row:Show()
        end
        for index = #bound + 1, #sweepRows do
            local row = sweepRows[index]
            if row.hcSearchLabel then (panel.hcHeaderOwner or panel).hcRows[row.hcSearchLabel] = nil; row.hcSearchLabel = nil end
            row:Hide()
        end
        local bottom = #bound == 0 and (sweepTop - 28) or (sweepTop - #bound * (O.CELL_H + 4))
        return -bottom + 8
    end


            layoutSweeps()
            add(sweeps, function() return layoutSweeps() end)
            ns.Options.RefreshMovementSweeps = function() panel.hcRefreshAll() end
            addSection(panel, add, nil, function(frame, y)
                _, y = O.PageLink(frame, y, "Open Key Bindings", "Key Bindings")
                return y
            end, nil, nil, 1)
        end, reset("Cells")) },
        { name = "Bar", build = O.Tab("Bar", function(panel, add, db)
            addSection(panel, add, nil, function(frame, y)
                return O.ProfileScope(frame, y)
            end)
            local bar = addSection(panel, add, "Cooldown bar", function(frame, y)
                local row
                row, y = O.Check(frame, "Show cooldown bar", "Icons beside the grid for spells bound on Key Bindings. Moves with Salve.", y,
                    function() return db.cooldownBar end, function(value) ns.Set("cooldownBar", value) end)
                return y, row
            end)
            local function barVisible() return db.cooldownBar or (db.lockoutIcons and db.lockoutPlacement ~= "CELL") end
            addSection(panel, add, nil, function(frame, y)
                _, y = O.Check(frame, "Show when ready", "Keep ready spells on the bar, dimmed.", y,
                    function() return db.cooldownBarShowReady end, function(value) ns.Set("cooldownBarShowReady", value) end)
                return y
            end, function() return db.cooldownBar end, bar)
            local match = addSection(panel, add, "Bar layout", function(frame, y)
                _, y = dropdown(frame, "Bar position", "Which side of the grid the bar sits on.", y, "cooldownBarSide", { "TOP", "BOTTOM", "LEFT", "RIGHT" }, { "Top", "Bottom", "Left", "Right" })
                _, y = dropdown(frame, "Bar layout", "Run icons across or down.", y, "cooldownBarOrientation", { "HORIZONTAL", "VERTICAL" }, { "Horizontal", "Vertical" })
                _, y = slider(frame, "Bar gap", "Distance from the grid, in pixels.", y, "cooldownBarGap", 0, 50)
                local row
                row, y = O.Check(frame, "Match cell size", "Use the Panel page's cell height, spacing and borders, so icons line up with cells.", y,
                    function() return db.cooldownBarMatchPanel end, function(value) ns.Set("cooldownBarMatchPanel", value) end)
                return y, row
            end, barVisible, bar)
            addSection(panel, add, nil, function(frame, y)
                _, y = slider(frame, "Bar icon size", "Bar icon size, in pixels.", y, "cooldownBarIconSize", 12, 64)
                _, y = slider(frame, "Bar spacing", "Space between bar icons, in pixels.", y, "cooldownBarSpacing", 0, 20)
                return y
            end, function() return barVisible() and not db.cooldownBarMatchPanel end, match)

            local spells = O.Section(panel, 1, bar)
            O.RegisterRow(spells, spells, "Bar spells")
            local _, top = O.Header(spells, "Bar spells", -4)
            local empty = O.FontString(spells, "GameFontHighlightSmall", "muted")
            empty:SetPoint("TOPLEFT", O.PAD, top)
            empty:SetText("No spells bound on Key Bindings.")
            local rows = {}
            local function layoutSpells()
                local bound = ns.Cooldowns:BoundSpells()
                empty:SetShown(#bound == 0)
                for index, id in ipairs(bound) do
                    local row = rows[index]
                    if not row then
                        row = O.Check(spells, "", "Show this spell on the bar.", top - (index - 1) * (O.CELL_H + 4),
                            function() local spell = ns.Cooldowns:BoundSpells()[index]; return spell and not db.cooldownBarHidden[spell] end,
                            function(value)
                                local spell = ns.Cooldowns:BoundSpells()[index]
                                if not spell then return end
                                local hidden = {}
                                for spellID, hide in pairs(db.cooldownBarHidden) do hidden[spellID] = hide end
                                hidden[spell] = (not value) or nil
                                ns.Set("cooldownBarHidden", hidden)
                                ns.Cooldowns:Request(); refreshPreview()
                            end)
                        rows[index] = row
                    end
                    if row.hcSearchLabel then (panel.hcHeaderOwner or panel).hcRows[row.hcSearchLabel] = nil end
                    local name = ns.Cooldowns.SpellName(id)
                    row.hcCheckbox.Text:SetText(name)
                    row.hcHintTitle = name
                    row.hcSearchLabel = "Bar spell: " .. name
                    O.RegisterRow(spells, row, row.hcSearchLabel)
                    row:Show()
                end
                for index = #bound + 1, #rows do
                    local row = rows[index]
                    if row.hcSearchLabel then (panel.hcHeaderOwner or panel).hcRows[row.hcSearchLabel] = nil; row.hcSearchLabel = nil end
                    row:Hide()
                end
                return -top + math.max(1, #bound) * (O.CELL_H + 4) + 4
            end
            layoutSpells()
            panel.hcRefresh[#panel.hcRefresh + 1] = function()
                if not db.cooldownBar then layoutSpells() end
            end
            add(spells, layoutSpells, function() return db.cooldownBar end, bar)
        end, reset("Bar")) },
        { name = "Lockouts", build = O.Tab("Lockouts", function(panel, add, db)
            local lockouts = addSection(panel, add, "Lockouts", function(frame, y)
                local row
                row, y = O.Check(frame, "Show lockout debuffs", "Show Forbearance after your own protection casts, until they can be used again. Needs a matching spell bound on Key Bindings.", y,
                    function() return db.lockoutIcons end, function(value) ns.Set("lockoutIcons", value) end)
                return y, row
            end)
            local placement = addSection(panel, add, nil, function(frame, y)
                local row
                row, y = dropdown(frame, "Show on", "Show lockouts on the cooldown bar with member names, on their cells, or both.", y, "lockoutPlacement", { "BAR", "CELL", "BOTH" }, { "Cooldown bar", "Cell", "Both" })
                return y, row
            end, function() return db.lockoutIcons end, lockouts)
            addSection(panel, add, nil, function(frame, y)
                _, y = slider(frame, "Lockout icon size", "Cell lockout icon size, in pixels.", y, "lockoutIconSize", 8, 48)
                _, y = dropdown(frame, "Lockout icon position", "Where the lockout icon sits on the cell.", y, "lockoutIconPosition", POSITIONS, POSITION_LABELS)
                return y
            end, function() return db.lockoutIcons and db.lockoutPlacement ~= "BAR" end, placement)
        end, reset("Lockouts")) },
    },
})
