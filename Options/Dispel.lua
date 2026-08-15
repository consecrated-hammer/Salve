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
    -- Shows what is ACTUALLY bound right now, after any overrides below --
    -- otherwise the page could describe a setup you had already changed.
    panel.salveRefresh[#panel.salveRefresh + 1] = function()
        if not ns.spellName then
            spell:SetText("|cffff4444No dispel on this specialisation.|r")
            return
        end
        local left, rightType, right = ns.ResolveClicks()
        local text = "Left click: |cffffd100" .. tostring(left) .. "|r"
        if rightType == "spell" then
            text = text .. "\nRight click: |cffffd100" .. tostring(right) .. "|r"
        elseif rightType == "target" then
            text = text .. "\nRight click: |cffffd100targets the unit|r"
        else
            text = text .. "\nRight click: |cff999999nothing|r"
        end
        spell:SetText(text)
    end

    _, y = O.Header(panel, "Clicks", y)

    -- Built from the spells you actually know, refreshed on every open, because
    -- that list changes with your specialisation.
    local function spellChoices(extra)
        local values, labels = { ns.CLICK_AUTO }, { "Automatic" }
        for _, s in ipairs(ns.knownDispels or {}) do
            values[#values + 1] = s.id
            labels[#labels + 1] = s.name .. " (" .. ns.CuresText(s.cures) .. ")"
        end
        if extra then
            for i, v in ipairs(extra.values) do
                values[#values + 1] = v
                labels[#labels + 1] = extra.labels[i]
            end
        end
        return values, labels
    end

    _, y = O.DynamicCycle(panel, "Left click",
        "Which spell the left button casts. Automatic picks the broadest dispel "
        .. "you can cast repeatedly, keeping cooldown-limited ones off the button "
        .. "you press most.", y,
        function() return spellChoices() end,
        function() return db.leftSpell end,
        function(v) ns.Set("leftSpell", v) end)

    _, y = O.DynamicCycle(panel, "Right click",
        "Automatic uses your second dispel where your specialisation has one, so "
        .. "the two buttons together cover every school the panel can light up.", y,
        function()
            return spellChoices({
                values = { ns.CLICK_TARGET, ns.CLICK_NONE },
                labels = { "Target the unit", "Do nothing" },
            })
        end,
        function() return db.rightSpell end,
        function(v) ns.Set("rightSpell", v) end)

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
