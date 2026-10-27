local addonName, ns = ...
local HC = ns.HammerCore
local O, T = ns.Options, HC.Theme

HC.Settings:NewPage({
    name = "Alerts",
    title = "Alerts",
    group = "main",
    description = "Dispel sounds, self-dispel text and learning messages.",
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
    local function movementSoundShown()
        return ns.db.movementAlertsEnabled ~= false and movementSoundEnabled()
    end

    local dispelRow
    dispelRow, y = O.Check(panel, "Play dispel alert sound",
        "Play a sound for built-in catalogue auras in this zone whose dispel school matches a known cure. This spell-ID list cannot exactly mirror the cell's live dispellability filter; learned-only auras do not trigger sounds.", y,
        dispelSoundEnabled,
        function(value) ns.Set("dispelSoundEnabled", value) end)
    local selfDispelY = y
    _, y = O.Check(panel, "Show self-dispel combat text",
        "Show an instruction when a reviewed scripted dispel reaches you. It never marks a party member or a Salve cell.", y,
        function() return ns.db.selfDispelNotification end,
        function(value) ns.Set("selfDispelNotification", value) end)

    local function testButton(row, title, hint, play)
        local button = O.Button(row, 42, 20)
        button:SetPoint("LEFT", row.hcCheckbox.Text, "RIGHT", 8, 0)
        button:SetText("Test")
        O.AttachHint(button, title, hint)
        button:SetScript("OnClick", play)
        return button
    end

    local testDispel = testButton(dispelRow, "Test dispel sound",
        "Play the dispel alert.", function() ns.Sound:Test() end)

    local soundDetails = CreateFrame("Frame", nil, panel)
    soundDetails:SetSize(560, 1)
    soundDetails.hcRefresh = panel.hcRefresh
    soundDetails.hcRefreshAll = panel.hcRefreshAll
    soundDetails.hcHeaderOwner = panel.hcHeaderOwner or panel

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
        "Choose where dispel and movement alert sounds play.", soundY,
        { items = channelItems, summary = function()
            for _, item in ipairs(channelItems) do
                if item.get() then return item.label end
            end
            return "Master"
        end }, 264)

    local soundDetailsHeight = -soundY + 4

    local learningMessages = CreateFrame("Frame", nil, panel)
    learningMessages:SetSize(560, 1)
    learningMessages.hcRefresh = panel.hcRefresh
    learningMessages.hcRefreshAll = panel.hcRefreshAll
    learningMessages.hcHeaderOwner = panel.hcHeaderOwner or panel
    local messageY = -4
    _, messageY = O.Header(learningMessages, "Learning messages", messageY)
    _, messageY = O.Check(learningMessages, "Show learning scope changes",
        "Print a chat message when learning moves to another zone or instance. Turning this off keeps learning active.", messageY,
        function() return ns.db.learningScopeMessages end,
        function(value) ns.Set("learningScopeMessages", value) end)
    _, messageY = O.Check(learningMessages, "Show newly learned spells",
        "Print a chat message when Salve records a new dispellable aura, root or snare. Turning this off still records the spell.", messageY,
        function() return ns.db.learningDiscoveryMessages end,
        function(value) ns.Set("learningDiscoveryMessages", value) end)
    local learningMessagesHeight = -messageY + 8

    local reset = CreateFrame("Frame", nil, panel)
    reset:SetSize(560, 1)
    reset.hcRefresh = panel.hcRefresh
    reset.hcRefreshAll = panel.hcRefreshAll
    local _, resetY = O.PageReset(reset, -4, function()
        ns.Set("soundEnabled", ns.defaults.soundEnabled)
        ns.Set("dispelSoundEnabled", ns.defaults.dispelSoundEnabled)
        ns.Set("selfDispelNotification", ns.defaults.selfDispelNotification)
        ns.Set("learningScopeMessages", ns.defaults.learningScopeMessages)
        ns.Set("learningDiscoveryMessages", ns.defaults.learningDiscoveryMessages)
        ns.Set("soundChannel", ns.defaults.soundChannel)
        ns.Set("soundFile", ns.defaults.soundFile)
    end, "Reset Alerts")
    local resetHeight = -resetY
    local pageBottom
    local function reflow()
        -- Movement sounds share this channel, though their switch is on Movement.
        local anySoundEnabled = dispelSoundEnabled() or movementSoundShown()
        soundDetails:SetShown(anySoundEnabled)
        testDispel:SetShown(dispelSoundEnabled())
        dispelRow.hcCheckbox.Text:ClearAllPoints()
        dispelRow.hcCheckbox.Text:SetPoint("LEFT", dispelRow.hcCheckbox, "RIGHT", 8, 0)
        local y0 = selfDispelY - 34
        soundDetails:ClearAllPoints()
        soundDetails:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, y0)
        if anySoundEnabled then y0 = y0 - soundDetailsHeight end
        learningMessages:ClearAllPoints()
        learningMessages:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, y0)
        y0 = y0 - learningMessagesHeight
        reset:ClearAllPoints()
        reset:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, y0)
        pageBottom = y0 - resetHeight - 8
        panel.hcSetBottom(pageBottom)
    end

    panel.hcRefresh[#panel.hcRefresh + 1] = reflow
    reflow()
    return pageBottom
end)
