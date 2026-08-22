local addonName, ns = ...
local O = ns.Options

local function section(parent)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(560, 1)
    frame.salveRefresh = parent.salveRefresh
    frame.salveRefreshAll = parent.salveRefreshAll
    return frame
end

O.NewPage({
    name = "Visibility",
    description = "When Salve is on screen, and how inactive units look.",
}, function(panel)
    local db = ns.db
    local sections = {}

    local function add(frame, height)
        sections[#sections + 1] = { frame = frame, height = height }
    end

    local display = section(panel)
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

    _, dy = O.MultiSelect(display, "Show Salve",
        "Choose Always or Never, or tick several rules; any matching rule will show Salve.",
        dy, { items = items, summary = function() return ns.Visibility:Summary() end })
    add(display, -dy + 4)

    local inactive = section(panel)
    local iy = -8
    _, iy = O.Header(inactive, "Inactive units", iy)
    _, iy = O.Check(inactive, "Show units with nothing to dispel",
        "Off makes inactive cells transparent. Their click areas stay in place during combat.",
        iy,
        function() return db.showWhenClean end,
        function(value) ns.Set("showWhenClean", value) end)

    local inactiveDetails = section(inactive)
    inactiveDetails:SetPoint("TOPLEFT", inactive, "TOPLEFT", 0, iy)
    local idy = 0
    _, idy = O.Slider(inactiveDetails, "Opacity",
        "Higher values make inactive cells more prominent.", idy,
        0, 1, 0.05,
        function() return db.cleanAlpha end,
        function(value) ns.Set("cleanAlpha", value) end,
        function(value) return string.format("%d%%", math.floor(value * 100 + 0.5)) end)
    _, idy = O.Check(inactiveDetails, "Use class colours",
        "Dispellable debuffs still use Blizzard's dispel colours.", idy,
        function() return db.useClassColours end,
        function(value) ns.Set("useClassColours", value) end)
    local inactiveBaseHeight = -iy + 4
    local inactiveDetailsHeight = -idy

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
    _, hdy = O.Cycle(handleDetails, "Handle position",
        "Choose which edge of the grid holds the handle.", hdy,
        { "LEFT", "TOPLEFT", "TOP", "TOPRIGHT", "RIGHT", "BOTTOMRIGHT", "BOTTOM", "BOTTOMLEFT" },
        { "Left", "Top left", "Top centre", "Top right", "Right", "Bottom right", "Bottom centre", "Bottom left" },
        function() return db.handlePosition end,
        function(value) ns.Set("handlePosition", value) end)
    local positionBaseHeight = -py
    local handleDetailsHeight = -hdy

    local resetPosition = CreateFrame("Button", nil, position, "UIPanelButtonTemplate")
    resetPosition:SetSize(160, 22)
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
    add(other, -oy + 4)

    local reset = section(panel)
    local _, ry = O.PageReset(reset, -4, function()
        db.visibilityMode = ns.defaults.visibilityMode
        db.visibility = {}
        ns.Set("showWhenClean", ns.defaults.showWhenClean)
        ns.Set("cleanAlpha", ns.defaults.cleanAlpha)
        ns.Set("useClassColours", ns.defaults.useClassColours)
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
    add(reset, -ry)

    local pageBottom
    local function reflow()
        inactiveDetails:SetShown(db.showWhenClean)
        local inactiveHeight = inactiveBaseHeight
            + (db.showWhenClean and inactiveDetailsHeight or 0)
        inactive:SetHeight(inactiveHeight)

        handleDetails:SetShown(db.showHandle)
        local resetY = -positionBaseHeight
            - (db.showHandle and handleDetailsHeight or 0) - 4
        resetPosition:ClearAllPoints()
        resetPosition:SetPoint("TOPLEFT", position, "TOPLEFT", 16, resetY)
        local positionHeight = -resetY + 36
        position:SetHeight(positionHeight)

        sections[2] = { frame = inactive, height = inactiveHeight }
        sections[3] = { frame = position, height = positionHeight }

        local y = -8
        for _, entry in ipairs(sections) do
            entry.frame:ClearAllPoints()
            entry.frame:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, y)
            entry.frame:SetHeight(entry.height)
            y = y - entry.height
        end
        pageBottom = y - 8
        panel.salveSetBottom(pageBottom)
    end

    -- Insert the two dynamic sections between Display and Other.
    table.insert(sections, 2, { frame = inactive, height = inactiveBaseHeight })
    table.insert(sections, 3, { frame = position, height = positionBaseHeight + 36 })
    panel.salveRefresh[#panel.salveRefresh + 1] = reflow
    reflow()
    return pageBottom
end)
