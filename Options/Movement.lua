local addonName, ns = ...
local HC = ns.HammerCore
local O = ns.Options

-- Automatic root, snare and slow responses. Movement-spell bindings stay on
-- Key Bindings, which owns every secure click; this page decides when Salve
-- prompts the player to use one, and how its cooldown sweep looks.
HC.Settings:NewPage({
    name = "Movement",
    title = "Movement (beta)",
    group = "main",
    description = "Root, snare and slow alerts.",
    headerAction = ns.Options.LivePreviewAction,
}, function(panel, y)
    _, y = O.Header(panel, "Movement (beta)", y)

    local function movementSoundEnabled()
        if ns.db.movementSoundEnabled ~= nil then return ns.db.movementSoundEnabled end
        return ns.db.soundEnabled == true
    end

    _, y = O.Check(panel, "Enable movement alerts (beta)",
        "Master switch for automatic movement text, sounds and the movement badge on your cell. Detection is in beta and may not work correctly. Your movement-spell bindings and dispel alerts still work when this is off.", y,
        function() return ns.db.movementAlertsEnabled end,
        function(value) ns.Set("movementAlertsEnabled", value) end)
    local inferredRow
    inferredRow, y = O.Check(panel, "Include inferred slows (beta)",
        "Also alert when your run speed drops sharply without a reported root or snare. Shows movement text and the movement badge on your cell, pointing at your movement-spell mouse binding. Salve can't tell whether an inferred slow is removable, so this may not work correctly. Inferred slows never play a sound.", y,
        function() return ns.db.inferredSlowAlertsEnabled end,
        function(value) ns.Set("inferredSlowAlertsEnabled", value) end)
    local movementRow
    movementRow, y = O.Check(panel, "Play snare-removal alert sound",
        "Play a sound only for a reviewed root or snare with a matching enabled remedy. Uses the sound channel on Alerts.", y,
        movementSoundEnabled,
        function(value) ns.Set("movementSoundEnabled", value) end)
    local textRow
    textRow, y = O.Check(panel, "Show personal Freedom movement text",
        "Show a notification when you are rooted or snared and a matching movement spell is bound on Key Bindings.", y,
        function() return ns.db.movementTextNotification end,
        function(value) ns.Set("movementTextNotification", value) end)
    local destinations = {}
    for _, choice in ipairs({ { "SCREEN", "On-screen text" }, { "CHAT", "Chat window" }, { "BOTH", "Both" } }) do
        local value, label = choice[1], choice[2]
        destinations[#destinations + 1] = {
            label = label, radio = true,
            get = function() return (ns.db.movementTextOutput or "SCREEN") == value end,
            set = function()
                ns.Set("movementTextOutput", value)
                if ns.MovementAlert then ns.MovementAlert:StopPreview() end
            end,
        }
    end
    _, y = O.MultiSelect(panel, "Movement text destination",
        "Messages are visible only to you. Chat window prints locally; it never sends to a party, raid or channel.", y,
        { items = destinations, summary = function()
            for _, item in ipairs(destinations) do if item.get() then return item.label end end
            return "On-screen text"
        end }, 264)
    local chatTabRow
    chatTabRow, y = O.DynamicDropdown(panel, "Movement chat tab",
        "Choose the chat tab used for Chat window or Both. A closed tab falls back to the default window.", y,
        function()
            if ns.MovementAlert then return ns.MovementAlert:ChatWindows() end
            return { 0 }, { "Default chat window" }
        end,
        function() return tonumber(ns.db.movementChatWindow) or 0 end,
        function(value) ns.Set("movementChatWindow", value) end)
    local previewY = y
    local preview = O.Button(panel, 220, 24)
    preview:SetPoint("TOPLEFT", O.PAD, previewY - 8)
    local function previewLabel()
        local destination = ns.db.movementTextOutput or "SCREEN"
        if destination == "CHAT" then return "Preview movement text in chat" end
        if destination == "BOTH" then return "Preview / move text + chat" end
        return "Preview / move movement text"
    end
    preview:SetText(previewLabel())
    preview:SetScript("OnClick", function() ns.MovementAlert:TogglePreview() end)
    panel:HookScript("OnHide", function()
        if ns.MovementAlert then ns.MovementAlert:StopPreview() end
    end)
    panel.hcRefresh[#panel.hcRefresh + 1] = function()
        preview:SetText(previewLabel())
    end

    local testMovement = O.CellAction(movementRow, "Test", 52, "Play the snare-removal alert.")
    testMovement:SetScript("OnClick", function() ns.Sound:TestMovement() end)

    -- Movement sweeps: one row per bound movement spell, with its colour and
    -- whether the sweep shows.
    local sweeps = CreateFrame("Frame", nil, panel)
    sweeps:SetSize(O.CONTENT_WIDTH + O.PAD * 2, 1)
    sweeps.hcRefresh = panel.hcRefresh
    sweeps.hcRefreshAll = panel.hcRefreshAll
    sweeps.hcHeaderOwner = panel.hcHeaderOwner or panel
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
        for index = #bound + 1, #sweepRows do sweepRows[index]:Hide() end
        local bottom = #bound == 0 and (sweepTop - 28) or (sweepTop - #bound * (O.CELL_H + 4))
        return -bottom + 8
    end

    -- Everything below the preview moves with the optional chat-tab row.
    local footer = CreateFrame("Frame", nil, panel)
    footer:SetSize(O.CONTENT_WIDTH + O.PAD * 2, 1)
    footer.hcRefresh = panel.hcRefresh
    footer.hcRefreshAll = panel.hcRefreshAll
    footer.hcHeaderOwner = panel.hcHeaderOwner or panel
    local footerY = -4
    _, footerY = O.Text(footer, "Choose movement spells and their mouse buttons on Key Bindings.", footerY)
    _, footerY = O.PageLink(footer, footerY, "Open Key Bindings", "Key Bindings")
    _, footerY = O.PageReset(footer, footerY - 4, function()
        ns.Set("movementAlertsEnabled", ns.defaults.movementAlertsEnabled)
        ns.Set("inferredSlowAlertsEnabled", ns.defaults.inferredSlowAlertsEnabled)
        ns.Set("movementSoundEnabled", ns.defaults.movementSoundEnabled)
        ns.Set("movementTextNotification", ns.defaults.movementTextNotification)
        ns.Set("movementTextOutput", ns.defaults.movementTextOutput)
        ns.Set("movementChatWindow", ns.defaults.movementChatWindow)
        ns.db.movementTextX, ns.db.movementTextY = 0, 160
        if ns.MovementAlert then ns.MovementAlert:Position() end
    end, "Reset Movement")
    local footerHeight = -footerY

    local pageBottom
    local function reflow()
        local enabled = ns.db.movementAlertsEnabled ~= false
        testMovement:SetShown(enabled and movementSoundEnabled())
        for _, row in ipairs({ inferredRow, movementRow, textRow }) do
            row:SetAlpha(enabled and 1 or 0.5)
        end
        local usesChat = (ns.db.movementTextOutput or "SCREEN") ~= "SCREEN"
        if not usesChat and chatTabRow.hcCloseMenu then chatTabRow.hcCloseMenu() end
        chatTabRow:SetShown(usesChat)
        -- The chat tab is the right-hand cell beside the destination, so
        -- hiding it leaves the rows below where they are.
        local adjustedPreviewY = previewY
        preview:ClearAllPoints()
        preview:SetPoint("TOPLEFT", O.PAD, adjustedPreviewY - 8)
        local y0 = adjustedPreviewY - 48
        sweeps:ClearAllPoints()
        sweeps:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, y0)
        y0 = y0 - layoutSweeps()
        footer:ClearAllPoints()
        footer:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, y0)
        pageBottom = y0 - footerHeight - 8
        panel.hcSetBottom(pageBottom)
    end

    panel.hcRefresh[#panel.hcRefresh + 1] = reflow
    ns.Options.RefreshMovementSweeps = reflow
    reflow()
    return pageBottom
end)
