local addonName, ns = ...
local O = ns.Options

-- An individual BOX: how big it is and what it carries. The grid those boxes
-- are arranged into lives on the Panel page.

O.NewPage("Boxes", function(panel, y)
    local db = ns.db

    _, y = O.Header(panel, "Size", y)

    _, y = O.Slider(panel, "Box width",
        "20 x 20 is the default and is deliberately small. Names need roughly 58 to be readable.", y,
        10, 120, 1,
        function() return db.boxWidth end,
        function(v) ns.Set("boxWidth", v) end)

    _, y = O.Slider(panel, "Box height", nil, y,
        10, 60, 1,
        function() return db.boxHeight end,
        function(v) ns.Set("boxHeight", v) end)

    _, y = O.Header(panel, "Contents", y)

    _, y = O.Check(panel, "Show unit names",
        "Off gives bare colour squares, which is what fits at the default 20 x 20.\n\n"
        .. "Names need a box around 58 wide to be readable.", y,
        function() return db.showNames end,
        function(v) ns.Set("showNames", v) end)

    _, y = O.Check(panel, "Show stack counts",
        "Drawn by the game rather than by Salve, so it follows Blizzard's own rules "
        .. "-- including hiding the number at a single stack.", y,
        function() return db.showStacks end,
        function(v) ns.Set("showStacks", v) end)

    _, y = O.Header(panel, "Clean units", y)

    _, y = O.Check(panel, "Keep clean units visible",
        "Holds the panel's shape so boxes never move mid-fight.\n\n"
        .. "Off empties the panel until something lands. Note that a fully "
        .. "transparent box is still clickable: mouse input cannot be turned off "
        .. "on a protected frame during combat.", y,
        function() return db.showWhenClean end,
        function(v) ns.Set("showWhenClean", v) end)

    _, y = O.Slider(panel, "Clean opacity", nil, y,
        0, 1, 0.05,
        function() return db.cleanAlpha end,
        function(v) ns.Set("cleanAlpha", v) end,
        function(v) return string.format("%d%%", math.floor(v * 100 + 0.5)) end)

    local note = panel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    note:SetPoint("TOPLEFT", 16, y - 8)
    note:SetWidth(520)
    note:SetJustifyH("LEFT")
    note:SetText("Fill colour comes from the game's own dispel palette and cannot be "
        .. "changed here. Salve never reads your debuffs -- it hands each box to the "
        .. "engine and the engine colours it. That also means colourblind settings are "
        .. "picked up automatically.")
end)
