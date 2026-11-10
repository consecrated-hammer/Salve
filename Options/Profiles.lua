local addonName, ns = ...
local HC = ns.HammerCore
local O = ns.Options

-- HammerCore builds the Profiles page. Salve says what a profile saves and
-- where the quick-switch clicks are set (Visibility).
HC.Profiles:NewPage({
    description = "Saved layouts for different group sizes. Switch by hand, from the minimap or by group.",
    extra = function(frame, y)
        _, y = O.Header(frame, "What a profile saves", y)
        _, y = O.Text(frame, "Position, grid and size, unit names, sorting, cooldown bar, when Salve shows and attach.", y)
        _, y = O.Text(frame, "Alerts, movement, tooltips and key bindings are the same in every profile.", y)
        _, y = O.Header(frame, "Switching", y)
        _, y = O.Text(frame, "Right-click the minimap button or drag handle for a menu with your profiles, or type /salve profile <name>.", y)
        _, y = O.SettingLink(frame, y, "Right-click options", "Visibility", "Minimap right-click")
        return y
    end,
})
