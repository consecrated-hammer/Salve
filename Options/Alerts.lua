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
        "Play a sound for a verified root or snare you can remove.", y,
        movementSoundEnabled,
        function(value) ns.Set("movementSoundEnabled", value) end)

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
        local y0 = y
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
