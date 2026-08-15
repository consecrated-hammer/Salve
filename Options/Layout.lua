local addonName, ns = ...
local O = ns.Options

-- First page registered, so this one becomes the parent category in the
-- Options > AddOns tree and the others hang beneath it.

O.NewPage("Layout", function(panel, y)
    local db = ns.db

    _, y = O.Header(panel, "Position", y)

    _, y = O.Check(panel, "Show drag handle",
        "A small grip beside the panel. Drag it to move Salve, right-click it for options.\n\n"
        .. "The panel cannot be dragged by its own surface: the boxes are buttons and cover every pixel of it.",
        y,
        function() return db.showHandle end,
        function(v) ns.Set("showHandle", v) end)

    _, y = O.Check(panel, "Show minimap button", nil, y,
        function() return db.showMinimap end,
        function(v) ns.Set("showMinimap", v) end)

    local reset = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    reset:SetSize(150, 22)
    reset:SetPoint("TOPLEFT", 16, y - 4)
    reset:SetText("Reset panel position")
    reset:SetScript("OnClick", function()
        ns.db.point = { "CENTER", "CENTER", 0, -140 }
        ns.Panel:ApplyPosition()
    end)
    y = y - 36

    _, y = O.Header(panel, "Size", y)

    _, y = O.Slider(panel, "Columns",
        "How many boxes per row before wrapping.", y,
        1, 10, 1,
        function() return db.columns end,
        function(v) ns.Set("columns", v) end)

    _, y = O.Slider(panel, "Box width",
        "Decursive's own boxes were 20 x 20. Names need roughly 58 to be readable.", y,
        10, 120, 1,
        function() return db.boxWidth end,
        function(v) ns.Set("boxWidth", v) end)

    _, y = O.Slider(panel, "Box height", nil, y,
        10, 60, 1,
        function() return db.boxHeight end,
        function(v) ns.Set("boxHeight", v) end)

    _, y = O.Slider(panel, "Spacing", nil, y,
        0, 12, 1,
        function() return db.spacing end,
        function(v) ns.Set("spacing", v) end)

    _, y = O.Slider(panel, "Scale", nil, y,
        0.5, 2.0, 0.05,
        function() return db.scale end,
        function(v) ns.Set("scale", v) end,
        function(v) return string.format("%.2f", v) end)

    _, y = O.Header(panel, "Where it shows", y)

    _, y = O.Check(panel, "Solo",
        "Keeps a single box for yourself when ungrouped. Self-dispel still matters.", y,
        function() return db.showInSolo end,
        function(v) ns.Set("showInSolo", v) end)

    _, y = O.Check(panel, "Party", nil, y,
        function() return db.showInParty end,
        function(v) ns.Set("showInParty", v) end)

    _, y = O.Check(panel, "Raid", nil, y,
        function() return db.showInRaid end,
        function(v) ns.Set("showInRaid", v) end)
end)
