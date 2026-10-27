local addonName, ns = ...
local HC = ns.HammerCore
local O = ns.Options

-- Automatic root, snare and slow responses. Movement-spell bindings stay on
-- Actions, which owns every secure click; this page only decides when Salve
-- prompts the player to use one.
HC.Settings:NewPage({
    name = "Movement",
    title = "Movement (beta)",
    group = "main",
    description = "Root, snare and slow alerts.",
}, function(panel, y)
    _, y = O.Header(panel, "Movement (beta)", y)

    local function movementSoundEnabled()
        if ns.db.movementSoundEnabled ~= nil then return ns.db.movementSoundEnabled end
        return ns.db.soundEnabled == true
    end

    _, y = O.Check(panel, "Enable movement alerts (beta)",
        "Master switch for automatic movement text, sounds and the orange player-cell cue. Detection is in beta and may not work correctly. Your movement-spell bindings and dispel alerts still work when this is off.", y,
        function() return ns.db.movementAlertsEnabled end,
        function(value) ns.Set("movementAlertsEnabled", value) end)
    local inferredRow
    inferredRow, y = O.Check(panel, "Include inferred slows (beta)",
        "Also alert when your run speed drops sharply without a reported root or snare. Shows movement text and the orange cue on your cell, pointing at your movement-spell mouse binding. Salve can't tell whether an inferred slow is removable, so this may not work correctly. Inferred slows never play a sound.", y,
        function() return ns.db.inferredSlowAlertsEnabled end,
        function(value) ns.Set("inferredSlowAlertsEnabled", value) end)
    local movementRow
    movementRow, y = O.Check(panel, "Play snare-removal alert sound",
        "Play a sound only for a reviewed root or snare with a matching enabled remedy. Uses the sound channel on Alerts.", y,
        movementSoundEnabled,
        function(value) ns.Set("movementSoundEnabled", value) end)
    local textRow
    textRow, y = O.Check(panel, "Show personal Freedom movement text",
        "Show a notification when you are rooted or snared and a matching movement spell is enabled in Actions.", y,
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
    local chatTabY = y
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
    preview:SetPoint("TOPLEFT", 16, previewY)
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

    local testMovement = O.Button(movementRow, 42, 20)
    testMovement:SetPoint("LEFT", movementRow.hcCheckbox.Text, "RIGHT", 8, 0)
    testMovement:SetText("Test")
    O.AttachHint(testMovement, "Test snare-removal sound", "Play the snare-removal alert.")
    testMovement:SetScript("OnClick", function() ns.Sound:TestMovement() end)

    -- Everything below the preview moves with the optional chat-tab row.
    local footer = CreateFrame("Frame", nil, panel)
    footer:SetSize(560, 1)
    footer.hcRefresh = panel.hcRefresh
    footer.hcRefreshAll = panel.hcRefreshAll
    footer.hcHeaderOwner = panel.hcHeaderOwner or panel
    local footerY = -4
    _, footerY = O.Header(footer, "Movement spells", footerY)
    _, footerY = O.Text(footer, "Choose movement spells and their mouse buttons on Actions.", footerY)
    _, footerY = O.PageLink(footer, footerY, "Open Actions", "Actions")
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
            row.hcCheckbox.Text:ClearAllPoints()
            row.hcCheckbox.Text:SetPoint("LEFT", row.hcCheckbox, "RIGHT", 8, 0)
        end
        local usesChat = (ns.db.movementTextOutput or "SCREEN") ~= "SCREEN"
        if not usesChat and chatTabRow.hcCloseMenu then chatTabRow.hcCloseMenu() end
        chatTabRow:SetShown(usesChat)
        local adjustedPreviewY = usesChat and previewY or chatTabY
        preview:ClearAllPoints()
        preview:SetPoint("TOPLEFT", 16, adjustedPreviewY)
        local y0 = adjustedPreviewY - 40
        footer:ClearAllPoints()
        footer:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, y0)
        pageBottom = y0 - footerHeight - 8
        panel.hcSetBottom(pageBottom)
    end

    panel.hcRefresh[#panel.hcRefresh + 1] = reflow
    reflow()
    return pageBottom
end)
