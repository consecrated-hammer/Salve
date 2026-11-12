local addonName, ns = ...
local HC, O = ns.HammerCore, ns.Options

HC.Settings:NewPage({
    name = "Tooltips", title = "Tooltips", group = "main", profileScope = false,
    description = "Choose what a Salve cell says when you hover it.",
}, function(panel)
    local db = ns.db
    local flow = O.Flow(panel)
    local function section(title, fill, visible, parentRow)
        local frame = O.Section(panel, 2, parentRow)
        local y = -4
        if title then _, y = O.Header(frame, title, y) end
        local result
        y, result = fill(frame, y)
        flow:Add(frame, -O.Flush(frame, y) + 4, visible, parentRow)
        return result
    end
    local master = section("Cell tooltip", function(frame, y)
        local row
        row, y = O.Check(frame, "Show cell tooltips", "Show a tooltip when hovering a Salve cell.", y,
            function() return db.showTooltip end,
            function(value) ns.Set("showTooltip", value) end)
        return y, row
    end)
    local actions = section("Content", function(frame, y)
        _, y = O.Check(frame, "Show default tooltips", "Include Blizzard's normal unit details.", y,
            function() return db.tooltipUnitInfo end,
            function(value) ns.Set("tooltipUnitInfo", value) end)
        _, y = O.Check(frame, "Show Blizzard debuff tooltip", "Show Blizzard's tooltip for the debuff on a lit cell. Needs a reload.", y,
            function() return db.tooltipDebuff end,
            function(value) ns.Set("tooltipDebuff", value) end)
        local row
        row, y = O.Check(frame, "Show Salve actions", "List the currently bound clicks and what each one casts.", y,
            function() return db.tooltipActions end,
            function(value) ns.Set("tooltipActions", value) end)
        return y, row
    end, function() return db.showTooltip end, master)
    section(nil, function(frame, y)
        _, y = O.Check(frame, "Show spell descriptions", "Add Blizzard's description for each bound spell. This can make the tooltip much taller.", y,
            function() return db.tooltipSpellDescriptions end,
            function(value) ns.Set("tooltipSpellDescriptions", value) end)
        return y
    end, function() return db.showTooltip and db.tooltipActions end, actions)
    section("Position", function(frame, y)
        _, y = O.Dropdown(frame, "Anchor", "Choose where the tooltip opens relative to a Salve cell.", y,
            { "RIGHT", "LEFT", "CURSOR" }, { "Right of cell", "Left of cell", "At cursor" },
            function() return db.tooltipAnchor end,
            function(value) ns.Set("tooltipAnchor", value) end, 264, 90)
        return y
    end, function() return db.showTooltip end, master)
    section(nil, function(frame, y)
        _, y = O.PageReset(frame, y, function()
            for _, key in ipairs({ "showTooltip", "tooltipUnitInfo", "tooltipDebuff", "tooltipActions", "tooltipSpellDescriptions", "tooltipAnchor" }) do
                ns.Set(key, ns.defaults[key])
            end
        end, "Reset Tooltips")
        return y
    end)
    return flow:Layout()
end)
