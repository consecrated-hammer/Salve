local addonName, ns = ...
local O = ns.Options

O.NewPage({
    name = "Alerts",
    title = "Alerts",
    group = "CORE",
    description = "Sound and movement alerts.",
}, function(panel, y)
    _, y = O.Header(panel, "Alerts", y)

    local function dispelSoundEnabled()
        if ns.db.dispelSoundEnabled ~= nil then return ns.db.dispelSoundEnabled end
        return ns.db.soundEnabled == true
    end
    local function movementSoundEnabled()
        if ns.db.movementSoundEnabled ~= nil then return ns.db.movementSoundEnabled end
        return ns.db.soundEnabled == true
    end

    local dispelRow
    dispelRow, y = O.Check(panel, "Play dispel alert sound",
        "Play a sound when Salve detects a dispellable aura.", y,
        dispelSoundEnabled,
        function(value) ns.Set("dispelSoundEnabled", value) end)
    local movementRow
    movementRow, y = O.Check(panel, "Play snare-removal alert sound",
        "Play a sound for a reviewed root or snare, or any root or snare Blessing of Freedom can remove.", y,
        movementSoundEnabled,
        function(value) ns.Set("movementSoundEnabled", value) end)
    _, y = O.Check(panel, "Show personal Freedom movement text",
        "Show a notification when you are rooted or snared and Blessing of Freedom is enabled in Actions.", y,
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
    panel.salveRefresh[#panel.salveRefresh + 1] = function()
        preview:SetText(previewLabel())
    end
    y = y - 32
    local selfDispelRow
    selfDispelRow, y = O.Check(panel, "Show self-dispel combat text",
        "Show an instruction when a reviewed scripted dispel reaches you. It never marks a party member or a Salve cell.", y,
        function() return ns.db.selfDispelNotification end,
        function(value) ns.Set("selfDispelNotification", value) end)

    local function testButton(row, title, hint, play)
        local button = O.Button(row, 42, 20)
        button:SetPoint("LEFT", row.salveCheckbox.Text, "RIGHT", 8, 0)
        button:SetText("Test")
        O.AttachHint(button, title, hint)
        button:SetScript("OnClick", play)
        return button
    end

    local testDispel = testButton(dispelRow, "Test dispel sound",
        "Play the dispel alert.", function() ns.Sound:Test() end)
    local testMovement = testButton(movementRow, "Test snare-removal sound",
        "Play the snare-removal alert.", function() ns.Sound:TestMovement() end)

    local soundDetails = CreateFrame("Frame", nil, panel)
    soundDetails:SetSize(560, 1)
    soundDetails.salveRefresh = panel.salveRefresh
    soundDetails.salveRefreshAll = panel.salveRefreshAll
    soundDetails.salveHeaderOwner = panel.salveHeaderOwner or panel

    local soundY = -4
    local channelItems = {
        { label = "Master", radio = true,
            get = function() return ns.db.soundChannel == "Master" end,
            set = function() ns.Set("soundChannel", "Master") end },
        { label = "Sound effects", radio = true,
            get = function() return ns.db.soundChannel == "SFX" end,
            set = function() ns.Set("soundChannel", "SFX") end },
        { label = "Dialog", radio = true,
            get = function() return ns.db.soundChannel == "Dialog" end,
            set = function() ns.Set("soundChannel", "Dialog") end },
    }
    _, soundY = O.MultiSelect(soundDetails, "Sound channel",
        "Choose where the alert sound plays.", soundY,
        { items = channelItems, summary = function()
            for _, item in ipairs(channelItems) do
                if item.get() then return item.label end
            end
            return "Master"
        end }, 264)

    local soundDetailsHeight = -soundY + 4

    local reset = CreateFrame("Frame", nil, panel)
    reset:SetSize(560, 1)
    reset.salveRefresh = panel.salveRefresh
    reset.salveRefreshAll = panel.salveRefreshAll
    local _, resetY = O.PageReset(reset, -4, function()
        ns.Set("soundEnabled", ns.defaults.soundEnabled)
        ns.Set("dispelSoundEnabled", ns.defaults.dispelSoundEnabled)
        ns.Set("movementSoundEnabled", ns.defaults.movementSoundEnabled)
        ns.Set("movementTextNotification", ns.defaults.movementTextNotification)
        ns.Set("movementTextOutput", ns.defaults.movementTextOutput)
        ns.Set("movementChatWindow", ns.defaults.movementChatWindow)
        ns.db.movementTextX, ns.db.movementTextY = 0, 160
        if ns.MovementAlert then ns.MovementAlert:Position() end
        ns.Set("selfDispelNotification", ns.defaults.selfDispelNotification)
        ns.Set("soundChannel", ns.defaults.soundChannel)
        ns.Set("soundFile", ns.defaults.soundFile)
    end, "Reset Alerts")
    local resetHeight = -resetY
    local pageBottom
    local function reflow()
        local anySoundEnabled = dispelSoundEnabled() or movementSoundEnabled()
        soundDetails:SetShown(anySoundEnabled)
        testDispel:SetShown(dispelSoundEnabled())
        testMovement:SetShown(movementSoundEnabled())
        local function placeLabel(row)
            row.salveCheckbox.Text:ClearAllPoints()
            row.salveCheckbox.Text:SetPoint("LEFT", row.salveCheckbox, "RIGHT", 8, 0)
        end
        placeLabel(dispelRow)
        placeLabel(movementRow)
        local usesChat = (ns.db.movementTextOutput or "SCREEN") ~= "SCREEN"
        if not usesChat and chatTabRow.salveCloseMenu then chatTabRow.salveCloseMenu() end
        chatTabRow:SetShown(usesChat)
        local adjustedPreviewY = usesChat and previewY or chatTabY
        preview:ClearAllPoints()
        preview:SetPoint("TOPLEFT", 16, adjustedPreviewY)
        selfDispelRow:ClearAllPoints()
        selfDispelRow:SetPoint("TOPLEFT", 16, adjustedPreviewY - 32)
        local y0 = adjustedPreviewY - 66
        soundDetails:ClearAllPoints()
        soundDetails:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, y0)
        if anySoundEnabled then y0 = y0 - soundDetailsHeight end
        reset:ClearAllPoints()
        reset:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, y0)
        pageBottom = y0 - resetHeight - 8
        panel.salveSetBottom(pageBottom)
    end

    panel.salveRefresh[#panel.salveRefresh + 1] = reflow
    reflow()
    return pageBottom
end)
