local addonName, ns = ...
local HC = ns.HammerCore
local O = ns.Options

local HANDLE_VALUES = { "CORNER", "LEFT", "TOPLEFT", "TOP", "TOPRIGHT", "RIGHT", "BOTTOMRIGHT", "BOTTOM", "BOTTOMLEFT" }
local HANDLE_LABELS = { "Start corner", "Left", "Top left", "Top centre", "Top right", "Right", "Bottom right", "Bottom centre", "Bottom left" }

-- Keep an unloaded saved host available instead of silently choosing None.
local function hostChoices()
    local values, labels = { "NONE" }, { "None" }
    for _, key in ipairs(ns.Attach.HOST_ORDER) do
        local loaded = ns.Attach:IsLoaded(key)
        if loaded or ns.db.attachTo == key then
            values[#values + 1] = key
            labels[#labels + 1] = ns.Attach.HOSTS[key].label .. (loaded and "" or " (not loaded)")
        end
    end
    return values, labels
end

HC.Settings:NewPage({
    name = "Position",
    title = "Position",
    group = "main",
    profileScope = false,
    description = "Move the panel or line it up with your group frames.",
    headerAction = O.LivePreviewAction,
}, O.Tab("Position", function(panel, add, db)
    local attachToggle
    local handle = O.Section(panel, 2)
    local y = -8
    _, y = O.Header(handle, "Drag handle", y)
    y = O.ProfileScope(handle, y, true)
    local handleToggle
    handleToggle, y = O.Check(handle, "Show drag handle", "Drag the gold handle to move Salve.", y,
        function() return db.showHandle end,
        function(value) ns.Set("showHandle", value) end)
    y = O.Flush(handle, y)
    add(handle, -y + 4)

    local position = O.Section(panel, 2, handleToggle)
    y = -4
    y = O.ProfileScope(position, y)
    _, y = O.Dropdown(position, "Handle position",
        "Saved per profile. Which edge of the grid holds the handle. Start corner follows the grid's fixed corner (Panel > Layout).", y,
        HANDLE_VALUES, HANDLE_LABELS,
        function() return db.handlePosition end,
        function(value) ns.Set("handlePosition", value) end)
    y = O.Flush(position, y)
    add(position, -y + 4, function()
        position.hcParentRow = db.attachTo ~= "NONE" and attachToggle or handleToggle
        return db.showHandle and db.attachTo == "NONE"
    end)

    local handleActions = O.Section(panel, 2)
    y = -4
    y = O.ProfileScope(handleActions, y, true)
    _, y = O.Dropdown(handleActions, "Handle right-click",
        "Menu matches the minimap button's: settings, the drag handle and your profiles. Open settings goes straight there.", y,
        { "PROFILES", "SETTINGS" }, { "Menu", "Open settings" },
        function() return db.handleRightClick end,
        function(value) ns.Set("handleRightClick", value) end,
        nil, 150, 130)
    y = O.Flush(handleActions, y)
    add(handleActions, -y + 4)
    local panelPosition = O.Section(panel, 1)
    y = -4
    _, y = O.Header(panelPosition, "Panel position", y)
    y = O.ProfileScope(panelPosition, y)
    local resetPosition
    resetPosition, y = O.ActionButton(panelPosition, y, "Re-centre panel",
        function() HC.Commands:Dispatch("reset position") end,
        "Move Salve back to the centre of the screen. Saved per profile.")
    O.RegisterRow(panelPosition, resetPosition, "Re-centre panel")
    add(panelPosition, -y + 4)

    local attach = O.Section(panel, 2)
    y = -8
    _, y = O.Header(attach, "Attach to group frames", y)
    y = O.ProfileScope(attach, y)
    attachToggle, y = O.Dropdown(attach, "Attach to",
        "Follow another addon's party and raid frames. Salve uses its saved position whenever those frames aren't on screen.", y,
        function() return (hostChoices()) end,
        function() return select(2, hostChoices()) end,
        function() return db.attachTo end,
        function(value) ns.Set("attachTo", value) end, 560, 150, 180)
    y = O.Flush(attach, y)
    add(attach, -y + 4)

    local attachDetails = O.Section(panel, 2, attachToggle)
    y = -4
    local sideToggle
    sideToggle, y = O.Dropdown(attachDetails, "Attach side",
        "Left and Right line each cell up with its member's frame, in the host's order. Top and Bottom keep Salve's grid together.", y,
        { "LEFT", "RIGHT", "TOP", "BOTTOM" }, { "Left", "Right", "Top", "Bottom" },
        function() return db.attachSide end,
        function(value) ns.Set("attachSide", value) end, 560, 150, 180)
    _, y = O.Slider(attachDetails, "Attach gap", "Distance from the host frames, in pixels.", y,
        0, 50, 1,
        function() return db.attachGap end,
        function(value) ns.Set("attachGap", value) end)
    y = O.Flush(attachDetails, y)
    add(attachDetails, -y + 4, function() return db.attachTo ~= "NONE" end)

    local alignment = O.Section(panel, 2, sideToggle)
    y = -4
    _, y = O.Dropdown(alignment, "Align",
        "Which edge of each member's frame its cell lines up with.", y,
        { "TOP", "CENTER", "BOTTOM" }, { "Top", "Centre", "Bottom" },
        function() return db.attachAlign end,
        function(value) ns.Set("attachAlign", value) end, 560, 150, 180)
    _, y = O.Slider(alignment, "Up / down", "Moves every cell up or down, in pixels.", y,
        -50, 50, 1,
        function() return db.attachOffsetY end,
        function(value) ns.Set("attachOffsetY", value) end)
    y = O.Flush(alignment, y)
    add(alignment, -y + 4, function()
        return db.attachTo ~= "NONE" and (db.attachSide == "LEFT" or db.attachSide == "RIGHT")
    end)

    local statusSection = O.Section(panel, 1, attachToggle)
    local status
    status, y = O.Text(statusSection, "", -4)
    local function refreshStatus() status:SetText(ns.Attach:StatusText()) end
    statusSection.hcRefresh[#statusSection.hcRefresh + 1] = refreshStatus
    O.RefreshAttachStatus = refreshStatus
    refreshStatus()
    _, y = O.Text(statusSection, "Moves with the host. A mid-fight reshuffle re-aligns after combat.", y)
    add(statusSection, -y + 4, function() return db.attachTo ~= "NONE" end)
end, function()
    for _, key in ipairs({ "showHandle", "handlePosition", "handleRightClick",
        "attachTo", "attachSide", "attachGap", "attachAlign", "attachOffsetY" }) do
        ns.Set(key, ns.defaults[key])
    end
    ns.Set("point", { unpack(ns.defaults.point) })
    ns.Panel:ApplyPosition()
    ns.RequestRebuildSoon(0.05)end, "Reset handle and attach", "drag handle, panel position and frame attachment"))
