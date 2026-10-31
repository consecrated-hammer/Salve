local addonName, ns = ...
local HC = ns.HammerCore
local O = ns.Options

local function section(parent, width)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(width or 264, 1)
    frame.hcRefresh = parent.hcRefresh
    frame.hcRefreshAll = parent.hcRefreshAll
    return frame
end

-- Only loaded hosts are offered, plus the saved choice if its addon is
-- missing, so the dropdown never silently shows a different value.
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
    name = "Attach",
    title = "Attach",
    group = "main",
    description = "Line Salve up with DandersFrames or EllesmereUI group frames.",
}, function(panel, y)
    local db = ns.db
    local controls = section(panel, 264)
    controls:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)

    _, y = O.Header(controls, "Attach", y)
    _, y = O.Dropdown(controls, "Attach to",
        "Follow another addon's party and raid frames. Salve uses its saved position whenever those frames aren't on screen.", y,
        function() return (hostChoices()) end,
        function() return select(2, hostChoices()) end,
        function() return db.attachTo end,
        function(value) ns.Set("attachTo", value) end,
        264, 90)
    _, y = O.Dropdown(controls, "Position",
        "Left and Right line each cell up with its member's frame, in the host's order. Top and Bottom keep Salve's grid together.", y,
        { "LEFT", "RIGHT", "TOP", "BOTTOM" }, { "Left", "Right", "Top", "Bottom" },
        function() return db.attachSide end,
        function(value) ns.Set("attachSide", value) end,
        264, 90)
    _, y = O.Slider(controls, "Gap", "Distance from the host frames, in pixels.", y,
        0, 50, 1,
        function() return db.attachGap end,
        function(value) ns.Set("attachGap", value) end,
        nil, 264)
    _, y = O.Dropdown(controls, "Align",
        "Left and Right only. Which edge of each member's frame its cell lines up with.", y,
        { "TOP", "CENTER", "BOTTOM" }, { "Top", "Centre", "Bottom" },
        function() return db.attachAlign end,
        function(value) ns.Set("attachAlign", value) end,
        264, 90)
    _, y = O.Slider(controls, "Up / down", "Left and Right only. Moves every cell up or down, in pixels.", y,
        -50, 50, 1,
        function() return db.attachOffsetY end,
        function(value) ns.Set("attachOffsetY", value) end,
        nil, 264)

    local status
    status, y = O.Text(controls, "", y - 4)
    local function refreshStatus() status:SetText(ns.Attach:StatusText()) end
    controls.hcRefresh[#controls.hcRefresh + 1] = refreshStatus
    O.RefreshAttachStatus = refreshStatus
    refreshStatus()
    _, y = O.Text(controls, "Moves with the host. A mid-fight reshuffle re-aligns after combat.", y)

    _, y = O.PageReset(controls, y - 4, function()
        for _, key in ipairs({ "attachTo", "attachSide", "attachGap", "attachAlign", "attachOffsetY" }) do
            ns.Set(key, ns.defaults[key])
        end
    end, "Reset Attach")

    return y - 8
end)
