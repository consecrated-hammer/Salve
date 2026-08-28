local addonName, ns = ...
local O = ns.Options

local function section(parent)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(560, 1)
    frame.salveRefresh = parent.salveRefresh
    frame.salveRefreshAll = parent.salveRefreshAll
    frame.salveHeaderOwner = parent.salveHeaderOwner or parent
    return frame
end

O.NewPage({
    name = "Visibility",
    title = "Visibility",
    group = "CORE",
    description = "Choose when the panel is visible.",
}, function(panel)
    local db = ns.db

    local display = section(panel)
    display:SetWidth(264)
    local dy = -8
    _, dy = O.Header(display, "Display", dy)

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
        {
            label = "Always",
            radio = true,
            get = function()
                return db.visibilityMode ~= "NEVER" and not hasConditions()
            end,
            set = function() setBaseMode("ALWAYS") end,
        },
        {
            label = "Never",
            radio = true,
            get = function() return db.visibilityMode == "NEVER" end,
            set = function() setBaseMode("NEVER") end,
        },
        { label = "Show when any of these match", heading = true },
    }

    for _, condition in ipairs(ns.VIS_CONDITIONS) do
        local key = condition.key
        items[#items + 1] = {
            label = condition.label,
            get = function()
                return db.visibilityMode ~= "NEVER" and db.visibility[key]
            end,
            set = function(value)
                db.visibilityMode = "ALWAYS"
                db.visibility[key] = value or nil
                ns.RequestRebuildSoon(0.05)
            end,
        }
    end

    _, dy = O.MultiSelect(display, "Show",
        "Choose Always or Never, or tick several rules; any matching rule will show Salve.",
        dy, { items = items, summary = function() return ns.Visibility:Summary() end }, 264)
    local displayHeight = -dy + 4

    local position = section(panel)
    local py = -8
    _, py = O.Header(position, "Position", py)
    _, py = O.Check(position, "Show drag handle",
        "Drag the gold handle to move Salve. Right-click it for settings.", py,
        function() return db.showHandle end,
        function(value) ns.Set("showHandle", value) end)

    local handleDetails = section(position)
    handleDetails:SetPoint("TOPLEFT", position, "TOPLEFT", 0, py)
    local hdy = 0
    local handleItems = {}
    for index, value in ipairs({ "LEFT", "TOPLEFT", "TOP", "TOPRIGHT", "RIGHT", "BOTTOMRIGHT", "BOTTOM", "BOTTOMLEFT" }) do
        local position = value
        local labels = { "Left", "Top left", "Top centre", "Top right", "Right", "Bottom right", "Bottom centre", "Bottom left" }
        handleItems[#handleItems + 1] = {
            label = labels[index], radio = true,
            get = function() return db.handlePosition == position end,
            set = function() ns.Set("handlePosition", position) end,
        }
    end
    _, hdy = O.MultiSelect(handleDetails, "Handle position",
        "Choose which edge of the grid holds the handle.", hdy,
        { items = handleItems, summary = function()
            for _, item in ipairs(handleItems) do
                if item.get() then return item.label end
            end
            return "Top left"
        end }, 264)
    local positionBaseHeight = -py
    local handleDetailsHeight = -hdy

    local resetPosition = O.Button(position, 160, 22)
    resetPosition:SetText("Reset frame position")
    O.AttachHint(resetPosition, "Reset frame position",
        "Move Salve back to the centre of the screen.")
    resetPosition:SetScript("OnClick", function()
        db.point = { "CENTER", "CENTER", 0, -140 }
        ns.Panel:ApplyPosition()
    end)

    local other = section(panel)
    local oy = -8
    _, oy = O.Header(other, "Other", oy)
    _, oy = O.Check(other, "Show minimap button",
        "Left-click opens settings. Drag it around the minimap to move it.", oy,
        function() return db.showMinimap end,
        function(value) ns.Set("showMinimap", value) end)
    _, oy = O.Check(other, "Show startup message",
        "Print Salve's version in chat after login or /reload.", oy,
        function() return db.showStartupMessage end,
        function(value) ns.Set("showStartupMessage", value) end)
    local otherHeight = -oy + 4

    local reset = section(panel)
    local _, ry = O.PageReset(reset, -4, function()
        db.visibilityMode = ns.defaults.visibilityMode
        db.visibility = {}
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
    end, "Reset Visibility")
    local resetHeight = -ry

    local pageBottom
    local function reflow()
        handleDetails:SetShown(db.showHandle)
        local resetY = -positionBaseHeight
            - (db.showHandle and handleDetailsHeight or 0) - 4
        resetPosition:ClearAllPoints()
        resetPosition:SetPoint("TOPLEFT", position, "TOPLEFT", 16, resetY)
        local positionHeight = -resetY + 36
        position:SetHeight(positionHeight)

        local y = -8
        display:ClearAllPoints()
        display:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, y)
        display:SetHeight(displayHeight)
        y = y - displayHeight - 8
        position:ClearAllPoints()
        position:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, y)
        position:SetHeight(positionHeight)
        y = y - positionHeight
        other:ClearAllPoints()
        other:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, y)
        other:SetHeight(otherHeight)
        y = y - otherHeight
        reset:ClearAllPoints()
        reset:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, y)
        reset:SetHeight(resetHeight)
        y = y - resetHeight
        pageBottom = y - 8
        panel.salveSetBottom(pageBottom)
    end

    panel.salveRefresh[#panel.salveRefresh + 1] = reflow
    reflow()
    return pageBottom
end)
