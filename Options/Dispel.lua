local addonName, ns = ...
local O = ns.Options

-- Pure layout calculation shared by the live page and regression tests. Rows
-- are counted from current game state, never from a guessed maximum.
function O.DispelLayout(knownTop, dispelCount, escapeCount)
    local knownRows = math.max(1, dispelCount or 0)
    local escapeRows = math.max(1, escapeCount or 0)
    local layout = {}
    layout.knownNoteY = knownTop - knownRows * 32 - 2
    layout.escapeHeaderY = knownTop - knownRows * 32 - 28
    layout.escapeNoteY = layout.escapeHeaderY - 28
    layout.escapeTop = layout.escapeHeaderY - 74
    layout.buttonsTop = layout.escapeTop - escapeRows * 32 - 12
    return layout
end

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
    description = "Your dispels, movement-removal bindings, and alerts.",
}, function(panel, y)
    _, y = O.Header(panel, "Your dispels", y)

    local knownTop = y
    local knownRows = {}
    local knownNote = panel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    knownNote:SetText("Detected from your current specialisation. Click a binding to change it.")

    local escapeHeader
    escapeHeader, y = O.Header(panel, "Your snare removals — EXPERIMENTAL", y)

    local escapeNote = panel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    escapeNote:SetWidth(520)
    escapeNote:SetJustifyH("LEFT")
    escapeNote:SetText("Roots and snares carry no dispel school, so the normal filter "
        .. "never sees them. Enable only spells you count as a removal, then bind "
        .. "them here. Party-wide spells light anyone's cell; personal spells light only yours.")
    local escapeRows = {}
    local escapeEmpty = panel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    local escapeTop = y
    local reflow
    local redrawAll
    local pageBottom

    local restore = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    restore:SetSize(180, 22)
    restore:SetText("Restore binding defaults")
    O.AttachHint(restore, "Restore binding defaults",
        "Bind the primary dispel to left click and a distinct secondary dispel to right click.")
    restore:SetScript("OnClick", function()
        ns.db.bindings = {}
        ns.db.bindingsCustom = false
        ns.RequestRebuildSoon(0.05)
        if redrawAll then redrawAll() end
    end)

    local function createActionRow(storage, index, hasCheckbox)
        local row = storage[index]
        if row then return row end
        row = CreateFrame("Frame", nil, panel)
        row:SetSize(540, 30)

        if hasCheckbox then
            row.check = O.CheckButton(row)
            row.check:SetPoint("LEFT", 14, 0)
        end

        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(22, 22)
        row.icon:SetPoint("LEFT", hasCheckbox and row.check or row, hasCheckbox and "RIGHT" or "LEFT",
            hasCheckbox and 4 or 16, 0)
        row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

        row.text = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        row.text:SetPoint("LEFT", row.icon, "RIGHT", 8, 0)
        row.text:SetWidth(hasCheckbox and 292 or 306)
        row.text:SetJustifyH("LEFT")

        row.bind = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        row.bind:SetSize(hasCheckbox and 124 or 140, 22)
        row.bind:SetPoint("RIGHT", row, "RIGHT", -34, 0)
        row.clear = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        row.clear:SetSize(24, 22)
        row.clear:SetPoint("LEFT", row.bind, "RIGHT", 6, 0)
        row.clear:SetText("x")
        O.AttachHint(row.bind, "Change binding",
            "Press a mouse button. Hold Shift, Ctrl or Alt to include it.")
        O.AttachHint(row.clear, "Clear binding", "Leave this spell unbound.")

        storage[index] = row
        return row
    end

    local function configureBinding(row, spellID, enabled)
        local keys = ns.Bindings:KeysForSpell(spellID)
        row.bind:Show()
        if enabled then
            row.bind:SetText(keys[1] and ns.Bindings:Label(keys[1]) or "Unbound")
        else
            row.bind:SetText("Enable first")
        end
        O.SetEnabled(row.bind, enabled)
        row.clear:SetShown(enabled and #keys > 0)

        row.bind:SetScript("OnClick", function()
            if not enabled then return end
            promptForKey(function(key)
                local ok, message = ns.Bindings:SetSpellBinding(spellID, key)
                if not ok then ns.Print(message) return end
                ns.RequestRebuildSoon(0.05)
                redrawAll()
            end)
        end)
        row.clear:SetScript("OnClick", function()
            ns.Bindings:ClearSpellBinding(spellID)
            ns.RequestRebuildSoon(0.05)
            redrawAll()
        end)
    end

    redrawAll = function()
        for _, row in ipairs(knownRows) do row:Hide() end
        local dispels = ns.knownDispels or {}
        for i, spell in ipairs(dispels) do
            local row = createActionRow(knownRows, i, false)
            row:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, knownTop - (i - 1) * 32)
            row.icon:SetTexture(C_Spell and C_Spell.GetSpellTexture
                and C_Spell.GetSpellTexture(spell.id)
                or "Interface\\Icons\\INV_Misc_QuestionMark")
            row.icon:Show()
            row.text:SetText(spell.name .. "  |cff999999" .. ns.CuresText(spell.cures) .. "|r")
            configureBinding(row, spell.id, true)
            row:Show()
        end
        if #dispels == 0 then
            local row = createActionRow(knownRows, 1, false)
            row:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, knownTop)
            row.icon:Hide()
            row.text:SetText("|cffff4444No dispel on this specialisation.|r")
            row.bind:Hide()
            row.clear:Hide()
            row:Show()
        end

        for _, row in ipairs(escapeRows) do row:Hide() end
        escapeEmpty:Hide()
        local escapes = ns.knownEscapes or {}
        for i, spell in ipairs(escapes) do
            local row = createActionRow(escapeRows, i, true)
            local spellID = spell.id
            local enabled = ns.db.escapes[spellID] and true or false
            row:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, escapeTop - (i - 1) * 32)
            row.icon:SetTexture(C_Spell and C_Spell.GetSpellTexture
                and C_Spell.GetSpellTexture(spellID)
                or "Interface\\Icons\\INV_Misc_QuestionMark")
            local scope = spell.scope == ns.ESCAPE_ALLY and "|cff66ddaaparty-wide|r"
                or "|cff888888personal|r"
            row.text:SetText(spell.name .. "  " .. scope)
            O.AttachHint(row, spell.name, spell.note or "Movement-removal candidate.")
            row.check:SetChecked(enabled)
            row.check:SetScript("OnClick", function(self)
                local active = self:GetChecked() and true or false
                ns.db.escapes[spellID] = active and true or nil
                if not active then ns.Bindings:ClearSpellBinding(spellID) end
                if active and ns.Sound then ns.Sound:ActivateCurrentInstance() end
                ns.RequestRebuildSoon(0.05)
                redrawAll()
            end)
            configureBinding(row, spellID, enabled)
            row:Show()
        end
        if #escapes == 0 then
            escapeEmpty:SetText("No known snare removal on this specialisation.")
            escapeEmpty:Show()
        end
        if reflow then reflow() end
    end

    -- Everything below the action rows lives in one footer so detected class
    -- spells move the complete alert section together.
    local footer = CreateFrame("Frame", nil, panel)
    footer:SetSize(560, 1)
    footer.salveRefresh = panel.salveRefresh
    footer.salveRefreshAll = panel.salveRefreshAll

    local fy = -4
    _, fy = O.Header(footer, "Alerts", fy)

    _, fy = O.Check(footer, "Play a sound when something you can dispel appears",
        "Uses only the spell list for your current zone, dungeon or raid.", fy,
        function() return ns.db.soundEnabled end,
        function(v) ns.Set("soundEnabled", v) end)

    local alertDetails = CreateFrame("Frame", nil, footer)
    alertDetails:SetSize(560, 1)
    alertDetails:SetPoint("TOPLEFT", footer, "TOPLEFT", 0, fy)
    alertDetails.salveRefresh = panel.salveRefresh
    alertDetails.salveRefreshAll = panel.salveRefreshAll

    local channel
    local alertY = 0
    channel, alertY = O.Cycle(alertDetails, "Sound channel",
        "Master is audible even when game sound effects are muted.", alertY,
        { "Master", "SFX", "Dialog" },
        { "Master", "Sound effects", "Dialog" },
        function() return ns.db.soundChannel end,
        function(v) ns.Set("soundChannel", v) end)

    local test = CreateFrame("Button", nil, alertDetails, "UIPanelButtonTemplate")
    test:SetSize(70, 22)
    test:SetPoint("LEFT", channel, "RIGHT", 18, 0)
    test:SetText("Test")
    O.AttachHint(test, "Test sound", "Play the selected alert now.")
    test:SetScript("OnClick", function() ns.Sound:Test() end)

    local alertDetailsHeight = -alertY
    local resetFrame = CreateFrame("Frame", nil, footer)
    resetFrame:SetSize(560, 1)
    resetFrame.salveRefresh = panel.salveRefresh
    resetFrame.salveRefreshAll = panel.salveRefreshAll
    local _, resetY = O.PageReset(resetFrame, -4, function()
        ns.db.bindings = {}
        ns.db.bindingsCustom = false
        ns.RequestRebuildSoon(0.05)
        ns.Set("escapes", {})
        ns.Set("soundEnabled", ns.defaults.soundEnabled)
        ns.Set("soundChannel", ns.defaults.soundChannel)
        ns.Set("soundFile", ns.defaults.soundFile)
        redrawAll()
    end)
    local resetHeight = -resetY

    function reflow()  -- luacheck: ignore (declared local above)
        local layout = O.DispelLayout(knownTop, #(ns.knownDispels or {}),
            #(ns.knownEscapes or {}))

        knownNote:ClearAllPoints()
        knownNote:SetPoint("TOPLEFT", panel, "TOPLEFT", 16,
            layout.knownNoteY)

        escapeHeader:ClearAllPoints()
        escapeHeader:SetPoint("TOPLEFT", panel, "TOPLEFT", 16,
            layout.escapeHeaderY)
        escapeNote:ClearAllPoints()
        escapeNote:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, layout.escapeNoteY)
        escapeTop = layout.escapeTop

        for index, row in ipairs(escapeRows) do
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", panel, "TOPLEFT", 0,
                escapeTop - (index - 1) * 32)
        end
        escapeEmpty:ClearAllPoints()
        escapeEmpty:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, escapeTop)

        local bottom = layout.buttonsTop
        restore:ClearAllPoints()
        restore:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, bottom)

        footer:ClearAllPoints()
        footer:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, bottom - 40)
        alertDetails:SetShown(ns.db.soundEnabled)
        local footerY = fy
        if ns.db.soundEnabled then footerY = footerY - alertDetailsHeight end
        resetFrame:ClearAllPoints()
        resetFrame:SetPoint("TOPLEFT", footer, "TOPLEFT", 0, footerY - 8)
        local footerHeight = -footerY + 8 + resetHeight
        footer:SetHeight(footerHeight)
        pageBottom = bottom - 40 - footerHeight
        if panel.salveSetBottom then panel.salveSetBottom(pageBottom) end
    end

    redrawAll()

    panel.salveRefresh[#panel.salveRefresh + 1] = redrawAll
    ns.Options.RefreshDispel = redrawAll
    return pageBottom
end)
