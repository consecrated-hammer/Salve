local addonName, ns = ...
local O = ns.Options

local function section(parent, width)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(width or 264, 1)
    frame.salveRefresh = parent.salveRefresh
    frame.salveRefreshAll = parent.salveRefreshAll
    return frame
end

O.NewPage({
    name = "Tooltips",
    title = "Tooltips",
    group = "CORE",
    description = "Choose what a Salve cell says when you hover it.",
}, function(panel, y)
    local db = ns.db
    local controls = section(panel, 264)
    controls:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)

    _, y = O.Header(controls, "Cell tooltip", y)
    _, y = O.Check(controls, "Show cell tooltips",
        "Show a tooltip when hovering a Salve cell.", y,
        function() return db.showTooltip end,
        function(value) ns.Set("showTooltip", value) end, 264)
    _, y = O.Check(controls, "Show default tooltips",
        "Include Blizzard's normal unit tooltip: name, class, level and other standard unit details.", y,
        function() return db.tooltipUnitInfo end,
        function(value) ns.Set("tooltipUnitInfo", value) end, 264)

    _, y = O.Header(controls, "Content", y)
    _, y = O.Check(controls, "Show Salve actions",
        "List the currently bound clicks and what each one casts.", y,
        function() return db.tooltipActions end,
        function(value) ns.Set("tooltipActions", value) end, 264)
    _, y = O.Check(controls, "Show spell descriptions",
        "Add Blizzard's static description for each bound spell. This can make the tooltip much taller.", y,
        function() return db.tooltipSpellDescriptions end,
        function(value) ns.Set("tooltipSpellDescriptions", value) end, 264)

    _, y = O.Header(controls, "Position", y)
    _, y = O.Dropdown(controls, "Anchor",
        "Choose where the tooltip opens relative to a Salve cell.", y,
        { "RIGHT", "LEFT", "CURSOR" },
        { "Right of cell", "Left of cell", "At cursor" },
        function() return db.tooltipAnchor end,
        function(value) ns.Set("tooltipAnchor", value) end,
        264, 72)

    _, y = O.PageReset(controls, y - 4, function()
        ns.Set("showTooltip", ns.defaults.showTooltip)
        ns.Set("tooltipUnitInfo", ns.defaults.tooltipUnitInfo)
        ns.Set("tooltipActions", ns.defaults.tooltipActions)
        ns.Set("tooltipSpellDescriptions", ns.defaults.tooltipSpellDescriptions)
        ns.Set("tooltipAnchor", ns.defaults.tooltipAnchor)
    end, "Reset Tooltips")

    return y - 8
end)
