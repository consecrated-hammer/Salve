local addonName, ns = ...
local O = ns.Options

O.NewPage("Dispel", function(panel, y)
    local db = ns.db

    _, y = O.Header(panel, "Spell", y)

    local spell = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    spell:SetPoint("TOPLEFT", 16, y)
    spell:SetWidth(520)
    spell:SetJustifyH("LEFT")
    y = y - 46

    -- Refreshed on every open: the spells change with spec, and this is a likely
    -- place to look right after respeccing.
    panel.salveRefresh[#panel.salveRefresh + 1] = function()
        if not ns.spellName then
            spell:SetText("|cffff4444No dispel on this specialisation.|r")
            return
        end
        local text = "Left click: |cffffd100" .. ns.spellName .. "|r  ("
            .. ns.CuresText(ns.primaryCures) .. ")"
        if ns.secondaryName then
            text = text .. "\nRight click: |cffffd100" .. ns.secondaryName .. "|r  ("
                .. ns.CuresText(ns.secondaryCures) .. ")"
        end
        spell:SetText(text)
    end

    _, y = O.Header(panel, "Clicks", y)

    _, y = O.Cycle(panel, "Right click",
        "Automatic uses your second dispel where your specialisation has one, so "
        .. "the two buttons together cover everything the panel can light up.\n\n"
        .. "Set it to Dispel to make both buttons cast the same spell.", y,
        { "AUTO", "DISPEL", "TARGET", "NONE" },
        { "Automatic", "Same as left", "Target unit", "Do nothing" },
        function() return db.rightClick end,
        function(v) ns.Set("rightClick", v) end)

    _, y = O.Header(panel, "Alert sound", y)

    _, y = O.Check(panel, "Play a sound when something dispellable lands",
        "Decursive's AfflictionAlert.\n\n"
        .. "EXPERIMENTAL: the game's own sound API is keyed per spell ID, which "
        .. "Salve deliberately never knows. This uses the engine's show event on "
        .. "the box instead, which is unverified. Run the engine probe below to "
        .. "see whether it has actually fired.", y,
        function() return db.soundEnabled end,
        function(v) ns.Set("soundEnabled", v) end)

    _, y = O.Slider(panel, "Minimum gap between sounds",
        "Stops a raid-wide debuff turning into a machine gun.", y,
        0.5, 10, 0.5,
        function() return db.soundThrottle end,
        function(v) ns.Set("soundThrottle", v) end,
        function(v) return string.format("%.1fs", v) end)

    local test = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    test:SetSize(150, 22)
    test:SetPoint("TOPLEFT", 16, y - 4)
    test:SetText("Play test sound")
    test:SetScript("OnClick", function() ns.Sound:Test() end)
    y = y - 34

    _, y = O.Header(panel, "Diagnostics", y)

    local probe = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    probe:SetSize(150, 22)
    probe:SetPoint("TOPLEFT", 16, y)
    probe:SetText("Run engine probe")
    probe:SetScript("OnClick", function() ns.Binding:Report() end)

    local hint = panel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    hint:SetPoint("TOPLEFT", 16, y - 30)
    hint:SetWidth(520)
    hint:SetJustifyH("LEFT")
    hint:SetText("Prints which parts of the game's aura-binding API this client offers, "
        .. "and whether the sound hook has fired. Worth running once after a patch: "
        .. "these are new interfaces and Blizzard has renamed them before.")
end)
