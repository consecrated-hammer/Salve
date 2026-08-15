local addonName, ns = ...
local O = ns.Options

-- The panel AS A WHOLE: where it sits, how the grid is arranged, when it
-- appears. Anything about an individual box lives on the Boxes page.
--
-- First page registered, so this becomes the parent category in the
-- Options > AddOns tree and the others hang beneath it.

O.NewPage("Panel", function(panel, y)
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
    y = y - 40

    _, y = O.Header(panel, "Grid", y)

    _, y = O.Cycle(panel, "Direction",
        "Horizontal fills a row and then wraps to the next row.\n\n"
        .. "Vertical fills a column and then wraps to the next column — useful "
        .. "down the side of the screen rather than across it.", y,
        { "HORIZONTAL", "VERTICAL" },
        { "Horizontal", "Vertical" },
        function() return db.orientation end,
        function(v) ns.Set("orientation", v) end)

    _, y = O.Slider(panel, "Boxes per line",
        "How many boxes before wrapping — per row when horizontal, per column when vertical.", y,
        1, 10, 1,
        function() return db.columns end,
        function(v) ns.Set("columns", v) end)

    _, y = O.Slider(panel, "Spacing",
        "Gap between boxes, in pixels.", y,
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
