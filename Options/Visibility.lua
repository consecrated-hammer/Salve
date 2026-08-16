local addonName, ns = ...
local O = ns.Options

O.NewPage({
    name = "Visibility",
    description = "When Salve is on screen, and how units with nothing to dispel look.",
}, function(panel, y)
    local db = ns.db

    _, y = O.Header(panel, "Show the frame", y)

    local function hasConditions()
        for _, condition in ipairs(ns.VIS_CONDITIONS) do
            if db.visibility[condition.key] then return true end
        end
        return false
    end

    local function setBaseMode(mode)
        db.visibilityMode = mode
        for _, condition in ipairs(ns.VIS_CONDITIONS) do
            db.visibility[condition.key] = nil
        end
        ns.RequestRebuildSoon(0.05)
    end

    local items = {
        { label = "Always",
          get = function() return db.visibilityMode ~= "NEVER" and not hasConditions() end,
          set = function() setBaseMode("ALWAYS") end },
        { label = "Never", get = function() return db.visibilityMode == "NEVER" end,
          set = function() setBaseMode("NEVER") end },
        { label = "Show when any of these match", heading = true },
    }

    for _, condition in ipairs(ns.VIS_CONDITIONS) do
        local key = condition.key
        items[#items + 1] = {
            label = condition.label,
            get = function()
                return db.visibilityMode ~= "NEVER" and db.visibility[key]
            end,
            set = function(v)
                db.visibilityMode = "ALWAYS"
                db.visibility[key] = v or nil
                ns.RequestRebuildSoon(0.05)
            end,
        }
    end

    _, y = O.MultiSelect(panel, "Show Salve",
        "Tick more than one rule and any match will show Salve.", y,
        { items = items, summary = function() return ns.Visibility:Summary() end })

    _, y = O.Header(panel, "Units with nothing to dispel", y)

    _, y = O.Check(panel, "Keep their cells on screen",
        "Off hides empty cells. Their click areas stay in place during combat.", y,
        function() return db.showWhenClean end,
        function(v) ns.Set("showWhenClean", v) end)

    local faded
    faded, y = O.Slider(panel, "Clear cell opacity",
        "How visible a cell is when there is nothing to dispel.", y,
        0, 1, 0.05,
        function() return db.cleanAlpha end,
        function(v) ns.Set("cleanAlpha", v) end,
        function(v) return string.format("%d%%", math.floor(v * 100 + 0.5)) end)

    local fadeNote = panel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    fadeNote:SetPoint("TOPLEFT", 16, y + 6)
    fadeNote:SetText("100% looks the same as a unit you can dispel.")
    y = y - 18

    panel.salveRefresh[#panel.salveRefresh + 1] = function()
        O.SetEnabled(faded, db.showWhenClean)
        fadeNote:SetTextColor(db.showWhenClean and 0.5 or 0.35,
            db.showWhenClean and 0.5 or 0.35,
            db.showWhenClean and 0.5 or 0.35)
    end

    _, y = O.Header(panel, "Moving and access", y)

    local showHandle
    showHandle, y = O.Check(panel, "Show drag handle",
        "Drag the gold handle to move Salve. Right-click it for settings.", y,
        function() return db.showHandle end,
        function(v) ns.Set("showHandle", v) end)

    local handlePosition
    handlePosition, y = O.Cycle(panel, "Drag handle anchor",
        "Choose which edge of the grid holds the handle.", y,
        { "LEFT", "TOPLEFT", "TOP", "TOPRIGHT", "RIGHT", "BOTTOMRIGHT", "BOTTOM", "BOTTOMLEFT" },
        { "Left", "Top left", "Top centre", "Top right", "Right", "Bottom right", "Bottom centre", "Bottom left" },
        function() return db.handlePosition end,
        function(v) ns.Set("handlePosition", v) end)

    panel.salveRefresh[#panel.salveRefresh + 1] = function()
        O.SetEnabled(handlePosition, db.showHandle)
    end

    _, y = O.Check(panel, "Show minimap button",
        "Left-click opens settings. Drag it around the minimap to move it.", y,
        function() return db.showMinimap end,
        function(v) ns.Set("showMinimap", v) end)

    _, y = O.Check(panel, "Show startup message",
        "Print Salve's version in chat after login or /reload.", y,
        function() return db.showStartupMessage end,
        function(v) ns.Set("showStartupMessage", v) end)

    local reset = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    reset:SetSize(160, 22)
    reset:SetPoint("TOPLEFT", 16, y - 4)
    reset:SetText("Reset frame position")
    O.AttachHint(reset, "Reset frame position", "Move Salve back to the centre of the screen.")
    reset:SetScript("OnClick", function()
        ns.db.point = { "CENTER", "CENTER", 0, -140 }
        ns.Panel:ApplyPosition()
    end)
    y = y - 40

    _, y = O.PageReset(panel, y, function()
        db.visibilityMode = ns.defaults.visibilityMode
        db.visibility = {}
        ns.Set("showWhenClean", ns.defaults.showWhenClean)
        ns.Set("cleanAlpha", ns.defaults.cleanAlpha)
        ns.Set("showHandle", ns.defaults.showHandle)
        ns.Set("handlePosition", ns.defaults.handlePosition)
        ns.Set("showMinimap", ns.defaults.showMinimap)
        ns.Set("showStartupMessage", ns.defaults.showStartupMessage)
        db.minimapAngle = ns.defaults.minimapAngle
        db.point = {
            ns.defaults.point[1], ns.defaults.point[2], ns.defaults.point[3],
            ns.defaults.point[4],
        }
        ns.Panel:ApplyPosition()
        ns.RequestRebuildSoon(0.05)
        if ns.Minimap then ns.Minimap:Update() end
    end)
    return y
end)
