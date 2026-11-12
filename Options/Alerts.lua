local addonName, ns = ...
local HC, O = ns.HammerCore, ns.Options

HC.Settings:NewPage({
    name = "Alerts", title = "Alerts", group = "main", profileScope = false,
    description = "Dispel and movement alerts, sound and chat messages.",
    headerAction = O.LivePreviewAction,
}, function(panel)
    local db = ns.db
    local flow = O.Flow(panel)
    local function section(title, fill, visible, parentRow, columns)
        local frame = O.Section(panel, columns or 2, parentRow)
        local y = -4
        if title then _, y = O.Header(frame, title, y) end
        local result
        y, result = fill(frame, y)
        flow:Add(frame, -O.Flush(frame, y) + 4, visible, parentRow)
        return result
    end
    local function soundEnabled(key)
        if db[key] ~= nil then return db[key] end
        return db.soundEnabled == true
    end
    local dispel = section("Dispel alerts", function(frame, y)
        local row
        row, y = O.Check(frame, "Play dispel alert sound",
            "Play a sound for built-in catalogue auras in this zone whose dispel school matches a known cure. Learned-only auras do not trigger sounds.", y,
            function() return soundEnabled("dispelSoundEnabled") end,
            function(value) ns.Set("dispelSoundEnabled", value) end)
        local test = O.CellAction(row, "Test", 52, "Play the dispel alert.")
        test:SetScript("OnClick", function() ns.Sound:Test() end)
        panel.hcRefresh[#panel.hcRefresh + 1] = function() test:SetShown(soundEnabled("dispelSoundEnabled")) end
        _, y = O.Check(frame, "Show self-dispel combat text",
            "Show an instruction when a reviewed scripted dispel reaches you. It never marks a party member or a Salve cell.", y,
            function() return db.selfDispelNotification end,
            function(value) ns.Set("selfDispelNotification", value) end)
        return y, row
    end)
    local master = section("Movement alerts (beta)", function(frame, y)
        local row
        row, y = O.Check(frame, "Enable movement alerts (beta)",
            "Master switch for movement text, sounds and the movement badge. Detection is in beta and may not work correctly. Movement-spell bindings and dispel alerts still work when this is off.", y,
            function() return db.movementAlertsEnabled end,
            function(value) ns.Set("movementAlertsEnabled", value) end)
        return y, row
    end)
    local function movementEnabled() return db.movementAlertsEnabled ~= false end
    local text = section(nil, function(frame, y)
        _, y = O.Check(frame, "Include inferred slows (beta)",
            "Also alert when run speed drops sharply without a reported root or snare. Salve cannot tell whether an inferred slow is removable. Inferred slows never play a sound.", y,
            function() return db.inferredSlowAlertsEnabled end,
            function(value) ns.Set("inferredSlowAlertsEnabled", value) end)
        local sound
        sound, y = O.Check(frame, "Play movement alert sound",
            "Play a sound for a reviewed root or snare with a matching enabled remedy. Uses the sound channel below.", y,
            function() return soundEnabled("movementSoundEnabled") end,
            function(value) ns.Set("movementSoundEnabled", value) end)
        local test = O.CellAction(sound, "Test", 52, "Play the movement alert.")
        test:SetScript("OnClick", function() ns.Sound:TestMovement() end)
        panel.hcRefresh[#panel.hcRefresh + 1] = function() test:SetShown(soundEnabled("movementSoundEnabled")) end
        local row
        row, y = O.Check(frame, "Show movement text",
            "Show a notification when rooted or snared with a matching movement spell bound on Key Bindings.", y,
            function() return db.movementTextNotification end,
            function(value) ns.Set("movementTextNotification", value) end)
        return y, row
    end, movementEnabled, master)
    local function textEnabled() return movementEnabled() and db.movementTextNotification end
    local destination = section(nil, function(frame, y)
        local row
        row, y = O.Dropdown(frame, "Movement text destination",
            "Messages are visible only to you. Chat window prints locally and never sends to a party, raid or channel.", y,
            { "SCREEN", "CHAT", "BOTH" }, { "On-screen text", "Chat window", "Both" },
            function() return db.movementTextOutput or "SCREEN" end,
            function(value)
                ns.Set("movementTextOutput", value)
                if ns.MovementAlert then ns.MovementAlert:StopPreview() end
            end, 264, 90)
        return y, row
    end, textEnabled, text)
    section(nil, function(frame, y)
        _, y = O.DynamicDropdown(frame, "Movement chat tab",
            "Choose the chat tab for Chat window or Both. A closed tab falls back to the default window.", y,
            function()
                if ns.MovementAlert then return ns.MovementAlert:ChatWindows() end
                return { 0 }, { "Default chat window" }
            end,
            function() return tonumber(db.movementChatWindow) or 0 end,
            function(value) ns.Set("movementChatWindow", value) end)
        return y
    end, function() return textEnabled() and (db.movementTextOutput or "SCREEN") ~= "SCREEN" end, destination)
    section(nil, function(frame, y)
        local button
        button, y = O.ActionButton(frame, y, "Preview / move movement text",
            function() ns.MovementAlert:TogglePreview() end,
            "Preview movement text, or drag its on-screen position.", nil, 260)
        O.RegisterRow(frame, button, "Preview / move movement text")
        return y
    end, textEnabled, text, 1)
    panel:HookScript("OnHide", function()
        if ns.MovementAlert then ns.MovementAlert:StopPreview() end
    end)
    panel.hcRefresh[#panel.hcRefresh + 1] = function()
        if not textEnabled() and ns.MovementAlert then ns.MovementAlert:StopPreview() end
    end
    section(nil, function(frame, y)
        _, y = O.PageLink(frame, y, "Open Key Bindings", "Key Bindings")
        return y
    end, nil, nil, 1)
    section("Sound", function(frame, y)
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
    _, y = O.MultiSelect(frame, "Sound channel",
        "Choose where dispel and movement alert sounds play.", y,
        { items = channelItems, summary = function()
            for _, item in ipairs(channelItems) do
                if item.get() then return item.label end
            end
            return "Master"
        end }, 264)


        return y
    end, function() return soundEnabled("dispelSoundEnabled") or (movementEnabled() and soundEnabled("movementSoundEnabled")) end, dispel)
    section("Chat messages", function(frame, y)
        _, y = O.Check(frame, "Show learning scope changes",
            "Print when learning moves to another zone or instance. Turning this off keeps learning active.", y,
            function() return db.learningScopeMessages end,
            function(value) ns.Set("learningScopeMessages", value) end)
        _, y = O.Check(frame, "Show newly learned spells",
            "Print when Salve records a new dispellable aura, root or snare. Turning this off still records the spell.", y,
            function() return db.learningDiscoveryMessages end,
            function(value) ns.Set("learningDiscoveryMessages", value) end)
        return y
    end)
    section(nil, function(frame, y)
        _, y = O.PageReset(frame, y, function()
            for _, key in ipairs({ "soundEnabled", "dispelSoundEnabled", "selfDispelNotification", "learningScopeMessages",
                "learningDiscoveryMessages", "soundChannel", "soundFile", "movementAlertsEnabled", "inferredSlowAlertsEnabled",
                "movementSoundEnabled", "movementTextNotification", "movementTextOutput", "movementChatWindow", "movementTextX", "movementTextY" }) do
                ns.Set(key, ns.defaults[key])
            end
            if ns.MovementAlert then ns.MovementAlert:Position() end
        end, "Reset Alerts")
        return y
    end, nil, nil, 1)
    return flow:Layout()
end)
