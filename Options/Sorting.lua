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

local ROLE_NAMES = { TANK = "Tank", HEALER = "Healer", DAMAGER = "DPS" }

HC.Settings:NewPage({
    name = "Sorting",
    title = "Sorting",
    group = "main",
    description = "Which member gets which cell. The Panel preview shows the result.",
}, function(panel, y)
    local db = ns.db
    local controls = section(panel, 264)
    controls:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)

    local roleLabels = {}
    for index, value in ipairs(ns.SORT_ROLE_ORDERS) do
        local names = {}
        for role in value:gmatch("[^,]+") do names[#names + 1] = ROLE_NAMES[role] end
        roleLabels[index] = table.concat(names, ", ")
    end

    _, y = O.Header(controls, "Order", y)
    _, y = O.Dropdown(controls, "Sort by",
        "Group order matches the game. Cells re-sort out of combat; a roster change mid-fight waits until combat ends. Attached left or right, the host's order wins.", y,
        { "GROUP", "ROLE", "NAME" }, { "Group order", "Role", "Name" },
        function() return db.sortMode end,
        function(value) ns.Set("sortMode", value) end,
        264, 90)
    _, y = O.Dropdown(controls, "Role order",
        "Used when sorting by role. Members with no role go last.", y,
        ns.SORT_ROLE_ORDERS, roleLabels,
        function() return db.sortRoleOrder end,
        function(value) ns.Set("sortRoleOrder", value) end,
        264, 90)
    _, y = O.Check(controls, "Reverse order",
        "Flip the sorted order. A pinned cell stays where it is.", y,
        function() return db.sortReverse end,
        function(value) ns.Set("sortReverse", value) end, 264)

    _, y = O.Header(controls, "Your cell", y)
    _, y = O.Dropdown(controls, "Position",
        "Pin your own cell first or last, or sort it with everyone else.", y,
        { "SORTED", "FIRST", "LAST" }, { "Sorted", "First", "Last" },
        function() return db.sortSelf end,
        function(value) ns.Set("sortSelf", value) end,
        264, 90)

    _, y = O.PageReset(controls, y - 4, function()
        for _, key in ipairs({ "sortMode", "sortRoleOrder", "sortReverse", "sortSelf" }) do
            ns.Set(key, ns.defaults[key])
        end
    end, "Reset Sorting")

    return y - 8
end)
