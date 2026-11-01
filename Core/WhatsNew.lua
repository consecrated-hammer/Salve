local addonName, ns = ...

-- Highlights for HammerCore's What's new window, newest first. Short,
-- player-facing lines for releases worth announcing; routine fixes stay in
-- CHANGELOG.md. A `page` adds a button that opens that settings page.
ns.WHATS_NEW = {
    { version = "1.8.0", items = {
        { text = "Cooldown icons: with names on, your dispel's cooldown now shows as a small spell icon on each cell instead of sweeping the whole cell. Change it with Sweep style.",
            page = "Cooldowns" },
        { text = "Cooldown bar: icons beside the grid for the spells bound on Actions, shown while they're on cooldown. Off by default.",
            page = "Cooldowns" },
        { text = "Lockouts: see Forbearance on the cooldown bar, with the name of whoever you just cast Blessing of Protection on, so you don't waste a click. Off by default.",
            page = "Cooldowns" },
        { text = "What's new: this window, shown once after an update that adds something worth knowing, with news from any other Consecrated Hammer addons you use. Reopen it with /salve whatsnew or from About, or turn it off on Visibility.",
            page = "Visibility" },
    } },
    { version = "1.7.0", items = {
        { text = "Sorting: order cells by role or name, and pin your own cell first or last.",
            page = "Sorting" },
        { text = "Attach: line Salve up with DandersFrames or EllesmereUI group frames.",
            page = "Attach" },
    } },
}
