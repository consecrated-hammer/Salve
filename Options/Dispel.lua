local addonName, ns = ...
local O = ns.Options

-- Pure layout calculation shared by the live page and regression tests. Rows
-- are counted from current game state, never from a guessed maximum.
function O.DispelLayout(knownTop, dispelCount, escapeCount)
    local knownRows = math.max(1, dispelCount or 0)
    local escapeRows = math.max(1, escapeCount or 0)
    local layout = {}
    layout.knownNoteY = knownTop - knownRows * 32 - 2
    layout.paletteY = layout.knownNoteY - 20
    layout.escapeHeaderY = knownTop - knownRows * 32 - 48
    layout.escapeNoteY = layout.escapeHeaderY - 28
    layout.escapeTop = layout.escapeHeaderY - 52
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
    title = "Dispels",
    group = "CORE",
    description = "Choose what each click casts.",
}, function(panel, y)
    _, y = O.Header(panel, "Dispel spells", y)

    local knownTop = y
    local knownRows = {}
    local knownNote = panel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    knownNote:SetText("Detected for your current specialisation.")

    local palette = CreateFrame("Frame", nil, panel)
    palette:SetSize(540, 18)
    local paletteTitle = palette:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    paletteTitle:SetPoint("LEFT", 0, 0)
    paletteTitle:SetText("Blizzard dispel colours:")
    local paletteX = 126
    for _, spec in ipairs({
        { key = "Magic", fallback = { 0.20, 0.60, 1.00 } },
        { key = "Curse", fallback = { 0.60, 0.00, 1.00 } },
        { key = "Disease", fallback = { 0.60, 0.40, 0.00 } },
        { key = "Poison", fallback = { 0.00, 0.80, 0.00 } },
    }) do
        local swatch = palette:CreateTexture(nil, "ARTWORK")
        swatch:SetSize(12, 12)
        swatch:SetPoint("LEFT", palette, "LEFT", paletteX, 0)
        local colour = DebuffTypeColor and DebuffTypeColor[spec.key]
        swatch:SetColorTexture((colour and colour.r) or spec.fallback[1],
            (colour and colour.g) or spec.fallback[2],
            (colour and colour.b) or spec.fallback[3], 1)
        local label = palette:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
        label:SetPoint("LEFT", swatch, "RIGHT", 4, 0)
        label:SetText(spec.key)
        paletteX = paletteX + 12 + 4 + ({ Magic = 34, Curse = 34, Disease = 46, Poison = 40 })[spec.key]
    end

    local escapeHeader
    escapeHeader, y = O.Header(panel, "Snare removals", y)
    O.AttachHint(escapeHeader, "Snare removals",
        "Enable spells Salve should treat as a root or snare removal. Party-wide spells light any cell; personal spells light only yours.")

    local escapeNote = panel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    escapeNote:SetWidth(520)
    escapeNote:SetJustifyH("LEFT")
    escapeNote:SetText("Enable the movement-removal spells you want Salve to show.")
    local escapeRows = {}
    local escapeEmpty = panel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    local escapeTop = y
    local reflow
    local redrawAll
    local pageBottom

    local restore = O.Button(panel, 180, 22, "danger")
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
        row.text:SetWidth(hasCheckbox and 270 or 306)
        row.text:SetJustifyH("LEFT")

        row.bind = O.Button(row, 124, 22)
        row.bind:SetPoint("RIGHT", row, "RIGHT", -34, 0)
        if hasCheckbox then
            row.colour = O.Button(row, 24, 22)
            row.colour:SetPoint("RIGHT", row.bind, "LEFT", -6, 0)
            row.colour:SetText("")
            row.colour.swatch = row.colour:CreateTexture(nil, "ARTWORK")
            row.colour.swatch:SetSize(14, 14)
            row.colour.swatch:SetPoint("CENTER")
            O.AttachHint(row.colour, "Snare-removal colour",
                "Choose the colour shown for enabled snare removals.")
        end
        row.clear = O.Button(row, 24, 22)
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
        if row.colour then
            local colour = ns.db.movementColour or ns.defaults.movementColour
            row.colour.swatch:SetColorTexture(colour.r, colour.g, colour.b, colour.a)
            row.colour:SetShown(enabled)
            row.colour:SetScript("OnClick", function()
                O.ShowColourPicker(ns.db.movementColour or ns.defaults.movementColour,
                    function(selected)
                        ns.Set("movementColour", selected)
                        row.colour.swatch:SetColorTexture(selected.r, selected.g,
                            selected.b, selected.a)
                    end)
            end)
        end

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
                local active = not self:GetChecked()
                self:SetChecked(active)
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

    local resetFrame = CreateFrame("Frame", nil, panel)
    resetFrame:SetSize(560, 1)
    resetFrame.salveRefresh = panel.salveRefresh
    resetFrame.salveRefreshAll = panel.salveRefreshAll
    local _, resetY = O.PageReset(resetFrame, -4, function()
        ns.db.bindings = {}
        ns.db.bindingsCustom = false
        ns.RequestRebuildSoon(0.05)
        ns.Set("escapes", {})
        redrawAll()
    end, "Reset Dispels")
    local resetHeight = -resetY

    function reflow()  -- luacheck: ignore (declared local above)
        local layout = O.DispelLayout(knownTop, #(ns.knownDispels or {}),
            #(ns.knownEscapes or {}))

        knownNote:ClearAllPoints()
        knownNote:SetPoint("TOPLEFT", panel, "TOPLEFT", 16,
            layout.knownNoteY)
        palette:ClearAllPoints()
        palette:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, layout.paletteY)

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
        resetFrame:ClearAllPoints()
        resetFrame:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, bottom - 30)
        pageBottom = bottom - 30 - resetHeight
        if panel.salveSetBottom then panel.salveSetBottom(pageBottom) end
    end

    redrawAll()

    panel.salveRefresh[#panel.salveRefresh + 1] = redrawAll
    ns.Options.RefreshDispel = redrawAll
    return pageBottom
end)
