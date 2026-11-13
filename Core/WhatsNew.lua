local addonName, ns = ...

-- Highlights for HammerCore's What's new window, newest first. Every
-- CurseForge release gets an entry, fixes included (Kevin, 2026-11-09);
-- HammerCore's tools/whatsnew_check.py fails the release without one. Keep
-- the lines short and player-facing; details stay in CHANGELOG.md. A `page`
-- adds a button that opens that settings page.
ns.WHATS_NEW = {
    { version = "1.14.0", date = "2026-11-13", items = {
        { title = "Clearer settings", text = "Related controls share tabs, search finds hidden options, and a larger profile icon shows which settings belong to this profile.", page = "Salve" },
        { title = "One cure per binding", text = "The unreliable combined dispel is removed. Bind Cure Poison and Remove Curse separately; existing individual bindings stay.", page = "Key Bindings" },
        { title = "Preview docking", text = "Drag the live preview near a settings edge to attach it, or away to let it float. Preview and real panel positions stay separate.", page = "Visibility" },
        { title = "Welcome to Salve", text = "A clearer welcome window includes the Salve icon. Each page reset asks before changing its own settings.", page = "Salve" },
    } },
    { version = "1.13.0", date = "2026-11-12", items = {
        { title = "Mouseover dispels", text = "Bind a key to cleanse a friendly mouseover. Forever also has a combined key for both dispels.", page = "Key Bindings" },
        { title = "Extra target cell", text = "A friendly target outside your group gets a cell beside the grid. Choose Target, Focus or Off on Panel > Members.", page = "Salve", tab = "Members" },
        { title = "Role and marker icons", text = "Cells can show a raid marker, with the role when no marker is set. Configure them on Panel > Names and icons.", page = "Salve", tab = "Names and icons" },
    } },
    { version = "1.12.0", date = "2026-11-11", items = {
        { title = "Debuff tooltips", text = "Hover a lit cell to see what the debuff is, straight from Blizzard. Switch it off on Tooltips.",
            page = "Tooltips" },
        { title = "Out of range fading", text = "Cells fade when someone's out of dispel range, so you don't waste a click. Change how faded a cell is on the Panel page, under Cells.",
            page = "Salve", tab = "Cells" },
    } },
    { version = "1.11.0", date = "2026-11-10", items = {
        { title = "Hide on flights", text = "The panel and movement text hide on a flight path and come back when you land. Switch it off on Visibility.",
            page = "Visibility" },
        { title = "Find a setting", text = "Type in the search box at the top of settings to jump straight to any setting." },
        { title = "One right-click menu", text = "The minimap button and drag handle open the same menu: settings, Profiles, the drag handle toggle and your profiles. Minimap right-click on Visibility can open settings instead.",
            kind = "improved", page = "Visibility" },
    } },
    { version = "1.10.1", date = "2026-11-10", items = {
        { title = "Simpler profiles", text = "A profile saves your whole layout. No more picking which bits count. Sections marked Saved per profile follow the profile you're on; shared settings apply across profiles.",
            kind = "improved", page = "Profiles" },
        { title = "Right-click options moved", text = "Minimap right-click is on Visibility. Drag handle right-click is on Position.",
            kind = "improved", page = "Visibility" },
        { title = "Poison first", text = "When you're rooted and poisoned, the rooted badge stays a small corner marker so the poison is what you see. The live preview shows both on your own cell when Rooted and Dispellable debuff are on.",
            kind = "improved", page = "Salve" },
        { title = "Show on screen too", text = "The live preview's At panel position switch has a clearer name.",
            kind = "improved", page = "Salve" },
    } },
    { version = "1.10.0", items = {
        { title = "Profiles", text = "Keep a separate position and grid layout for Party, Raid 20 and Raid 40. Switch from the Panel page, the minimap or drag handle right-click menu, or /salve profile.",
            page = "Profiles" },
        { title = "Auto-switch", text = "Salve can change profile, or ask you first, when your group or instance changes. It's off until you turn it on, and the rules are yours to edit.",
            page = "Profiles" },
        { title = "Start corner", text = "Grow the grid from any corner. Bottom left keeps new rows above your action bars instead of on top of them.",
            page = "Salve" },
        { title = "A fresh coat of paint", text = "Settings got a new look: tabs, two columns, switches, and this What's new page with every release since 1.0.0. And knobs. So many knobs. All the knobs and all the widgets, polished and lined up for twiddling.",
            kind = "improved" },
        { title = "Live preview", text = "Show live preview opens your panel in its own window, at actual size. Drag it anywhere, keep it open while you change settings, and switch on sample states like a dispellable debuff, your dispel on cooldown, a root or a lockout.",
            kind = "improved", page = "Salve" },
        { title = "Key bindings", text = "Pick a spell from your spellbook, click a mouse button, done. Bound spells sit in one tidy list.",
            kind = "improved", page = "Key Bindings" },
        { title = "Support links", text = "CurseForge, Discord and Buy me a coffee sit at the bottom of the settings window. Hide them on Visibility.",
            kind = "improved", page = "Visibility" },
        { text = "Handle positions other than the four corners no longer reset to Top left on every reload.",
            kind = "fix" },
    } },
    { version = "1.9.0", date = "2026-11-08", items = {
        { title = "Movement alerts", text = "When you're rooted or snared, your cell shows a small badge with the spell that frees you, such as Blessing of Freedom, instead of turning orange. Dispels and Freedom share the cell. Still in beta.",
            page = "Alerts" },
    } },
    { version = "1.8.2", date = "2026-11-01", items = {
        { title = "Lockouts", client = "forever", text = "Forbearance now lasts its full minute and follows every spell that causes it.",
            page = "Cooldowns" },
    } },
    { version = "1.8.0", date = "2026-11-01", items = {
        { title = "Cooldown icons", text = "With names on, your dispel's cooldown now shows as a small spell icon on each cell instead of sweeping the whole cell. Change it with Sweep style.",
            page = "Cooldowns" },
        { title = "Cooldown bar", text = "Icons beside the grid for the spells bound on Key Bindings, shown while they're on cooldown. Off by default.",
            page = "Cooldowns" },
        { title = "Lockouts", text = "See Forbearance on the cooldown bar, with the name of whoever you just cast Blessing of Protection on, so you don't waste a click. Off by default.",
            page = "Cooldowns" },
        { title = "What's new", text = "This window, shown once after an update that adds something worth knowing, with news from any other Consecrated Hammer addons you use. Reopen it with /salve whatsnew or from About, or turn it off on Visibility.",
            page = "Visibility" },
    } },
    { version = "1.7.0", date = "2026-10-31", items = {
        { title = "Sorting", text = "Order cells by role or name, and pin your own cell first or last.",
            page = "Salve", tab = "Members" },
        { title = "Attach", text = "Line Salve up with DandersFrames or EllesmereUI group frames.",
            page = "Position" },
    } },
    -- History: highlights written after the fact for releases from before
    -- What's new existed. Listed under Earlier releases on the What's new page.
    { version = "1.6.5", date = "2026-10-27", history = true, items = {
        { title = "Movement (beta)", text = "Root, snare and slow alerts got their own page, with one switch to turn them all off.",
            page = "Alerts" },
    } },
    { version = "1.6.4", date = "2026-10-18", history = true, items = {
        { text = "Learning chat messages can be muted without stopping learning.", page = "Alerts" },
        { client = "forever", text = "Orc Shatter Curse works as a personal dispel on your own cell.", page = "Key Bindings" },
    } },
    { version = "1.6.3", date = "2026-10-14", history = true, items = {
        "Support for Retail 12.1.5.",
    } },
    { version = "1.6.0", date = "2026-09-26", history = true, items = {
        "A lore quiz: the quest marker on the About page, or /salve quiz. Five questions, one smug verdict.",
        "The same core commands and settings layout as every Consecrated Hammer addon.",
    } },
    { version = "1.5.0", date = "2026-08-27", history = true, items = {
        { text = "Roots and snares got their own alert sound and colour, and a sweep shows when your Freedom-style spell is on cooldown.",
            page = "Alerts" },
    } },
    { version = "1.4.0", date = "2026-08-22", history = true, items = {
        "/salve debug copy builds a report you can paste into a bug report.",
        { text = "Alert sounds for newly catalogued dispellable debuffs when they land on your group.", page = "Alerts" },
    } },
    { version = "1.3.0", date = "2026-08-17", history = true, items = {
        { text = "Roots and snares (alpha): cells get an outline for movement-impairing effects, and you pick which of your spells remove them.",
            page = "Key Bindings" },
    } },
    { version = "1.2.0", date = "2026-08-17", history = true, items = {
        { text = "Hover tooltips on every cell: who it is and what each mouse button casts.", page = "Tooltips" },
    } },
    { version = "1.1.0", date = "2026-08-16", history = true, items = {
        { text = "Alert sounds for all eight Season 2 Mythic+ dungeons.", page = "Alerts" },
    } },
    { version = "1.0.0", date = "2026-08-16", history = true, items = {
        "First stable release: one box per group member that lights up when you can dispel them, with cooldown sweeps and alert sounds.",
    } },
}
