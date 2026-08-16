local addonName, ns = ...
local O = ns.Options

-- ── Key capture prompt ─────────────────────────────────────────────────────
-- Click a binding's button, then press whatever you want it to be. Built once
-- and reused; shared by every row.

local capture
local function ensureCapture()
    if capture then return capture end

    local f = CreateFrame("Frame", "SalveBindCapture", UIParent)
    f:SetSize(340, 110)
    f:SetPoint("CENTER")
    f:SetFrameStrata("FULLSCREEN_DIALOG")
    f:EnableMouse(true)
    -- ☠ Without this the frame never receives OnKeyDown, so the advertised
    --   Escape-to-cancel silently does nothing and the prompt can only be
    --   dismissed by binding something.
    f:EnableKeyboard(true)
    f:Hide()

    local bg = f:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.05, 0.04, 0.03, 0.96)
    for _, e in ipairs({ { "TOPLEFT", "TOPRIGHT", true }, { "BOTTOMLEFT", "BOTTOMRIGHT", true },
                         { "TOPLEFT", "BOTTOMLEFT", false }, { "TOPRIGHT", "BOTTOMRIGHT", false } }) do
        local t = f:CreateTexture(nil, "OVERLAY")
        t:SetColorTexture(0.58, 0.43, 0.22, 1)
        t:SetPoint(e[1]); t:SetPoint(e[2])
        if e[3] then t:SetHeight(1) else t:SetWidth(1) end
    end

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", 0, -16)
    title:SetText("Press a mouse button")
    title:SetTextColor(1, 0.82, 0.26)

    local body = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    body:SetPoint("TOP", title, "BOTTOM", 0, -8)
    body:SetWidth(300)
    body:SetText("Hold Shift, Ctrl or Alt to include it.\nEscape cancels.")

    -- ☠ Mouse buttons only. A secure action button is driven by attributes
    --   keyed per mouse button; a keyboard key cannot be aimed at "the box
    --   under the cursor" without a mouseover macro, which is a different
    --   mechanism and not this panel's to own.
    f:SetScript("OnMouseDown", function(self, button)
        local key = ns.Bindings:Capture(button)
        if key and self.onCapture then self.onCapture(key) end
        self:Hide()
    end)

    f:SetScript("OnKeyDown", function(self, key)
        if key == "ESCAPE" then self:Hide() return end
        ns.Print("mouse buttons only — a keyboard key cannot target the box under your cursor")
    end)

    f:SetPropagateKeyboardInput(false)
    capture = f
    return f
end

local function promptForKey(onCapture)
    local f = ensureCapture()
    f.onCapture = onCapture
    f:Show()
    f:SetPropagateKeyboardInput(false)
end

-- ── Page ───────────────────────────────────────────────────────────────────

O.NewPage({
    name = "Dispels",
    description = "What each click does, and when Salve makes a sound.",
}, function(panel, y)
    _, y = O.Header(panel, "Your dispels", y)

    local knownTop = y
    local knownRows = {}
    local knownNote = panel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    knownNote:SetPoint("TOPLEFT", 16, knownTop - 86)
    knownNote:SetText("Detected from your current specialisation.")
    y = y - 110

    _, y = O.Header(panel, "Click bindings", y)

    local rowsTop = y
    local rows = {}
    local pageBottom

    -- Forward declaration: redraw calls this, and it needs the controls that are
    -- created below the list.
    local reflow

    -- Rebuilt on every open and after every edit: both the binding list and the
    -- spells it resolves to can change underneath this page.
    local function redraw()
        for _, row in ipairs(knownRows) do row:Hide() end
        for i, spell in ipairs(ns.knownDispels or {}) do
            local row = knownRows[i]
            if not row then
                row = CreateFrame("Frame", nil, panel)
                row:SetSize(500, 26)
                row.icon = row:CreateTexture(nil, "ARTWORK")
                row.icon:SetSize(22, 22)
                row.icon:SetPoint("LEFT", 16, 0)
                row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
                row.text = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
                row.text:SetPoint("LEFT", row.icon, "RIGHT", 8, 0)
                row.text:SetJustifyH("LEFT")
                knownRows[i] = row
            end
            row:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, knownTop - (i - 1) * 28)
            row.icon:SetTexture(C_Spell and C_Spell.GetSpellTexture
                and C_Spell.GetSpellTexture(spell.id)
                or "Interface\\Icons\\INV_Misc_QuestionMark")
            row.icon:Show()
            row.text:ClearAllPoints()
            row.text:SetPoint("LEFT", row.icon, "RIGHT", 8, 0)
            row.text:SetText(spell.name .. "  |cff999999"
                .. ns.CuresText(spell.cures) .. "|r")
            row:Show()
        end
        if #(ns.knownDispels or {}) == 0 then
            local row = knownRows[1]
            if not row then
                row = CreateFrame("Frame", nil, panel)
                row:SetSize(500, 26)
                row.icon = row:CreateTexture(nil, "ARTWORK")
                row.icon:SetSize(22, 22)
                row.icon:SetPoint("LEFT", 16, 0)
                row.text = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
                row.text:SetPoint("LEFT", row.icon, "RIGHT", 8, 0)
                knownRows[1] = row
            end
            row:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, knownTop)
            row.icon:Hide()
            row.text:ClearAllPoints()
            row.text:SetPoint("LEFT", 16, 0)
            row.text:SetText("|cffff4444No dispel on this specialisation.|r")
            row:Show()
        end

        for _, r in ipairs(rows) do r:Hide() end

        local list = ns.Bindings:List()
        for i, entry in ipairs(list) do
            local row = rows[i]
            if not row then
                row = CreateFrame("Frame", nil, panel)
                row:SetSize(500, 30)

                row.icon = row:CreateTexture(nil, "ARTWORK")
                row.icon:SetSize(24, 24)
                row.icon:SetPoint("LEFT", 16, 0)
                row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

                row.spell = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
                row.spell:SetPoint("LEFT", row.icon, "RIGHT", 8, 0)
                row.spell:SetWidth(210)
                row.spell:SetJustifyH("LEFT")

                row.bind = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
                row.bind:SetSize(150, 22)
                row.bind:SetPoint("LEFT", row.spell, "RIGHT", 8, 0)

                row.remove = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
                row.remove:SetSize(24, 22)
                row.remove:SetPoint("LEFT", row.bind, "RIGHT", 6, 0)
                row.remove:SetText("x")
                O.AttachHint(row.bind, "Change binding",
                    "Press a mouse button. Hold Shift, Ctrl or Alt to include it.")
                O.AttachHint(row.remove, "Remove binding", "Remove this mouse binding.")

                rows[i] = row
            end

            row:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, rowsTop - (i - 1) * 32)
            row:Show()

            local what, icon = ns.Bindings:Describe(entry)
            row.icon:SetTexture(icon or "Interface\\Icons\\INV_Misc_QuestionMark")
            row.spell:SetText(what:gsub(" %(automatic%)$", " |cff888888— automatic|r"))
            row.bind:SetText(ns.Bindings:Label(entry.key))

            row.bind:SetScript("OnClick", function()
                promptForKey(function(key)
                    -- Materialise the defaults before editing, or the first edit
                    -- would be written into the shared default table.
                    local list = ns.Bindings:Materialise()
                    for otherIndex, entry in ipairs(list) do
                        if otherIndex ~= i and entry.key == key then
                            ns.Print(ns.Bindings:Label(key) .. " is already assigned")
                            return
                        end
                    end
                    list[i].key = key
                    ns.RequestRebuildSoon(0.05)
                    redraw()
                end)
            end)
            row.remove:SetScript("OnClick", function()
                table.remove(ns.Bindings:Materialise(), i)
                ns.RequestRebuildSoon(0.05)
                redraw()
            end)
        end

        -- Push the Add button and diagnostics below however many rows there are.
        if reflow then reflow(#list) end
    end

    local add = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    add:SetSize(150, 22)
    add:SetText("Add a binding")
    O.AttachHint(add, "Add a binding", "Add another mouse click.")
    add:SetScript("OnClick", function()
        promptForKey(function(key)
            local list = ns.Bindings:Materialise()
            for _, entry in ipairs(list) do
                if entry.key == key then
                    ns.Print(ns.Bindings:Label(key) .. " is already assigned")
                    return
                end
            end
            list[#list + 1] = { key = key, role = ns.ROLE_PRIMARY }
            ns.RequestRebuildSoon(0.05)
            redraw()
        end)
    end)

    local restore = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    restore:SetSize(150, 22)
    restore:SetText("Restore defaults")
    O.AttachHint(restore, "Restore defaults",
        "Put the best detected dispel on left click, plus right click when needed.")
    restore:SetScript("OnClick", function()
        ns.db.bindings = {}
        ns.RequestRebuildSoon(0.05)
        redraw()
    end)

    -- Everything below the binding list lives in one footer, so an arbitrarily
    -- long custom binding list moves the complete alert section.
    local footer = CreateFrame("Frame", nil, panel)
    footer:SetSize(560, 205)
    footer.salveRefresh = panel.salveRefresh
    footer.salveRefreshAll = panel.salveRefreshAll

    local fy = -4
    _, fy = O.Header(footer, "Alerts", fy)

    _, fy = O.Check(footer, "Play a sound when something you can dispel appears",
        "Uses only the spell list for your current zone, dungeon or raid.", fy,
        function() return ns.db.soundEnabled end,
        function(v) ns.Set("soundEnabled", v) end)

    local channel
    channel, fy = O.Cycle(footer, "Sound channel",
        "Master is audible even when game sound effects are muted.", fy,
        { "Master", "SFX", "Dialog" },
        { "Master", "Sound effects", "Dialog" },
        function() return ns.db.soundChannel end,
        function(v) ns.Set("soundChannel", v) end)

    local test = CreateFrame("Button", nil, footer, "UIPanelButtonTemplate")
    test:SetSize(70, 22)
    test:SetPoint("LEFT", channel, "RIGHT", 18, 0)
    test:SetText("Test")
    O.AttachHint(test, "Test sound", "Play the selected alert now.")
    test:SetScript("OnClick", function() ns.Sound:Test() end)

    _, fy = O.PageReset(footer, fy - 8, function()
        ns.Set("bindings", {})
        ns.Set("soundEnabled", ns.defaults.soundEnabled)
        ns.Set("soundChannel", ns.defaults.soundChannel)
        ns.Set("soundFile", ns.defaults.soundFile)
        redraw()
    end)

    function reflow(rowCount)  -- luacheck: ignore (declared local above)
        local bottom = rowsTop - rowCount * 32 - 8
        add:ClearAllPoints()
        add:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, bottom)
        restore:ClearAllPoints()
        restore:SetPoint("LEFT", add, "RIGHT", 8, 0)

        footer:ClearAllPoints()
        footer:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, bottom - 40)
        pageBottom = bottom - 255
        if panel.salveSetBottom then panel.salveSetBottom(pageBottom) end
    end

    redraw()

    panel.salveRefresh[#panel.salveRefresh + 1] = redraw
    ns.Options.RefreshDispel = redraw
    return pageBottom
end)
