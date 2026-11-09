local addonName, ns = ...
local HC = ns.HammerCore
local O = ns.Options

-- HammerCore builds the Profiles page (management, Included in profiles and
-- Auto-switch). Salve adds where the quick profile menu opens from.
HC.Profiles:NewPage({
    description = "Saved layouts for different group sizes. Switch by hand, from the minimap menu, or by group.",
    extra = function(frame, y)
        local db = ns.db
        _, y = O.Header(frame, "Quick switch", y)
        _, y = O.Dropdown(frame, "Minimap right-click",
            "Profiles opens a menu of profiles, which can also show or hide the drag handle. Drag handle toggles it straight away.", y,
            { "PROFILES", "HANDLE" }, { "Profile menu", "Drag handle" },
            function() return db.minimapRightClick end,
            function(value) ns.Set("minimapRightClick", value) end,
            nil, 150, 220)
        _, y = O.Dropdown(frame, "Handle right-click",
            "Profiles opens a menu of profiles, which also links to settings. Open settings goes straight there.", y,
            { "PROFILES", "SETTINGS" }, { "Profile menu", "Open settings" },
            function() return db.handleRightClick end,
            function(value) ns.Set("handleRightClick", value) end,
            nil, 150, 220)
        _, y = O.Text(frame, "Or type /salve profile <name>.", y)
        return y
    end,
})
