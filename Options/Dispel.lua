local addonName, ns = ...
local O = ns.Options

-- Retained as a pure helper for callers/tests which used the original inline
-- layout. The Actions page below uses two independent columns instead.
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

local capture
local function ensureCapture()
    if capture then return capture end
    local f = CreateFrame("Frame", "SalveBindCapture", UIParent)
    f:SetSize(360, 138)
    f:SetPoint("CENTER")
    f:SetFrameStrata("FULLSCREEN_DIALOG")
    f:EnableMouse(true)
    f:EnableKeyboard(true)
    f:Hide()
    local bg = f:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.05, 0.04, 0.03, 0.96)
    for _, edge in ipairs({ { "TOPLEFT", "TOPRIGHT", true }, { "BOTTOMLEFT", "BOTTOMRIGHT", true },
                             { "TOPLEFT", "BOTTOMLEFT", false }, { "TOPRIGHT", "BOTTOMRIGHT", false } }) do
        local t = f:CreateTexture(nil, "OVERLAY")
        t:SetColorTexture(0.58, 0.43, 0.22, 1)
        t:SetPoint(edge[1]); t:SetPoint(edge[2])
        if edge[3] then t:SetHeight(1) else t:SetWidth(1) end
    end
    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.title:SetPoint("TOP", 0, -16)
    f.title:SetTextColor(1, 0.82, 0.26)
    f.body = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.body:SetPoint("TOP", f.title, "BOTTOM", 0, -8)
    f.body:SetWidth(320)
    f.clear = O.Button(f, 82, 20, "danger")
    f.clear:SetPoint("BOTTOMLEFT", 18, 14)
    f.clear:SetText("Unbind")
    f.clear:SetScript("OnClick", function(self)
        local parent = self:GetParent()
        if parent.onClear then parent.onClear() end
        parent:Hide()
    end)
    local cancel = O.Button(f, 82, 20)
    cancel:SetPoint("BOTTOMRIGHT", -18, 14)
    cancel:SetText("Cancel")
    cancel:SetScript("OnClick", function() f:Hide() end)
    f:SetScript("OnMouseDown", function(self, button)
        local key = ns.Bindings:Capture(button)
        if key and self.onCapture then self.onCapture(key) end
        self:Hide()
    end)
    f:SetScript("OnKeyDown", function(self, key)
        if key == "ESCAPE" then self:Hide() end
    end)
    f:SetPropagateKeyboardInput(false)
    capture = f
    return f
end

local function promptForKey(spellName, currentKey, onCapture, onClear)
    local f = ensureCapture()
    f.title:SetText("Bind " .. spellName)
    f.body:SetText((currentKey and "Current: " .. ns.Bindings:Label(currentKey) .. "\n" or "Not currently bound.\n")
        .. "Press a mouse button to assign it. Escape cancels.")
    f.onCapture, f.onClear = onCapture, onClear
    f.clear:SetShown(currentKey and true or false)
    f:Show()
    f:SetPropagateKeyboardInput(false)
end

local function spellIcon(spellID)
    return C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(spellID)
        or "Interface\\Icons\\INV_Misc_QuestionMark"
end

local function findSpell(spellID)
    for _, spell in ipairs(ns.knownDispels or {}) do
        if spell.id == spellID then return spell, "DISPEL" end
    end
    for _, spell in ipairs(ns.knownEscapes or {}) do
        if spell.id == spellID then return spell, "ESCAPE" end
    end
end

local function attachSpellTooltip(row, spell)
    row.salveSpellID = spell.id
    row:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOPRIGHT")
        if GameTooltip.SetSpellByID then
            GameTooltip:SetSpellByID(spell.id)
        else
            GameTooltip:SetText(spell.name)
        end
        if spell.scope == ns.ESCAPE_SELF then
            GameTooltip:AddLine("Self only movement removal.", 0.55, 0.58, 0.64, true)
        elseif spell.scope == ns.ESCAPE_ALLY then
            GameTooltip:AddLine("Can remove movement impairment from a group member.", 0.55, 0.58, 0.64, true)
        elseif spell.scope == ns.ESCAPE_AREA then
            GameTooltip:AddLine("Places a ground-area effect; allies in it can be freed.", 0.55, 0.58, 0.64, true)
        end
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function(self)
        if GameTooltip:IsOwned(self) then GameTooltip:Hide() end
    end)
end

O.NewPage({
    name = "Actions",
    title = "Actions",
    group = "CORE",
    description = "What each click casts on a lit cell.",
}, function(panel, y)
    local boundRows, paletteRows, sweepColourRows, sweepChoiceRows = {}, {}, {}, {}
    local redrawAll
    local pageBottom = y - 360
    local left = CreateFrame("Frame", nil, panel)
    left:SetSize(278, 620)
    left:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, y)
    local right = CreateFrame("Frame", nil, panel)
    right:SetSize(246, 620)
    right:SetPoint("TOPLEFT", left, "TOPRIGHT", 32, 0)

    local divider = panel:CreateTexture(nil, "ARTWORK")
    divider:SetColorTexture(unpack(O.theme.edge))
    divider:SetWidth(1)
    divider:SetPoint("TOP", left, "TOPRIGHT", 16, 0)
    divider:SetPoint("BOTTOM", left, "BOTTOMRIGHT", 16, 0)
    local leftHeader = left:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    leftHeader:SetPoint("TOPLEFT", 0, 0)
    leftHeader:SetText("KEY BINDINGS")
    leftHeader:SetTextColor(unpack(O.theme.accent))
    local leftHint = left:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    leftHint:SetPoint("TOPLEFT", leftHeader, "BOTTOMLEFT", 0, -4)
    leftHint:SetText("Click a row to reassign.")
    local boundCount = left:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    boundCount:SetPoint("TOPLEFT", leftHint, "BOTTOMLEFT", 0, -16)
    local clearAll = O.Button(left, 62, 20, "danger")
    clearAll:SetPoint("TOPRIGHT", 0, -35)
    clearAll:SetText("Clear all")
    clearAll:SetScript("OnClick", function()
        ns.db.bindings = {}
        ns.db.bindingsCustom = true
        ns.Set("escapes", {})
        ns.Set("movementSweepSpellIDs", {})
        if ns.Binding and ns.Binding.RefreshMovementCooldowns then
            ns.Binding:RefreshMovementCooldowns("all movement actions cleared")
        end
        ns.RequestRebuildSoon(0.05)
        redrawAll()
    end)
    local rightHeader = right:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    rightHeader:SetPoint("TOPLEFT", 0, 0)
    rightHeader:SetText("SPELLS")
    rightHeader:SetTextColor(unpack(O.theme.accent))
    local rightHint = right:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    rightHint:SetPoint("TOPLEFT", rightHeader, "BOTTOMLEFT", 0, -4)
    rightHint:SetText("Click a spell to bind it.")

    local sweepColoursHeader = left:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    sweepColoursHeader:SetText("MOVEMENT SWEEP COLOURS")
    sweepColoursHeader:SetTextColor(unpack(O.theme.section))
    local sweepChoiceHeader = left:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    sweepChoiceHeader:SetText("SHOW SWEEPS")
    sweepChoiceHeader:SetTextColor(unpack(O.theme.section))
    local sweepExplain = left:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    sweepExplain:SetWidth(270)
    sweepExplain:SetJustifyH("LEFT")
    sweepExplain:SetText("A sweep is the coloured clock-hand animation that counts down around a Salve cell after you cast the selected spell.")
    local sweepDivider = left:CreateTexture(nil, "ARTWORK")
    sweepDivider:SetHeight(1)
    sweepDivider:SetColorTexture(unpack(O.theme.edge))

    local function makeBoundRow(index)
        local row = boundRows[index]
        if row then return row end
        row = CreateFrame("Button", nil, left, "BackdropTemplate")
        row:SetSize(278, 42)
        row:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
        row:SetBackdropColor(unpack(O.theme.rail))
        row:SetBackdropBorderColor(unpack(O.theme.edge))
        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(32, 32)
        row.icon:SetPoint("LEFT", 8, 0)
        row.text = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        row.text:SetPoint("LEFT", row.icon, "RIGHT", 8, 0)
        row.text:SetWidth(132)
        row.text:SetJustifyH("LEFT")
        row.key = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        row.key:SetPoint("RIGHT", -31, 0)
        row.key:SetTextColor(unpack(O.theme.accent))
        row.remove = O.Button(row, 20, 20)
        row.remove:SetPoint("RIGHT", -5, 0)
        row.remove:SetText("x")
        boundRows[index] = row
        return row
    end

    local function makePaletteRow(index)
        local row = paletteRows[index]
        if row then return row end
        row = CreateFrame("Button", nil, right, "BackdropTemplate")
        row:SetSize(246, 42)
        row:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
        row:SetBackdropColor(unpack(O.theme.raised))
        row:SetBackdropBorderColor(unpack(O.theme.edge))
        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(32, 32)
        row.icon:SetPoint("LEFT", 8, 0)
        row.text = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        row.text:SetPoint("LEFT", row.icon, "RIGHT", 8, 0)
        row.text:SetWidth(142)
        row.text:SetJustifyH("LEFT")
        row.subtext = row:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
        row.subtext:SetWidth(142)
        row.subtext:SetJustifyH("LEFT")
        row.status = row:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
        row.status:SetPoint("RIGHT", -8, 0)
        paletteRows[index] = row
        return row
    end

    local function makeSweepRow(storage, index, selectable)
        local row = storage[index]
        if row then return row end
        row = CreateFrame("Frame", nil, left, "BackdropTemplate")
        row:SetSize(278, 42)
        row:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
        row:SetBackdropColor(unpack(O.theme.content))
        row:SetBackdropBorderColor(unpack(O.theme.edge))
        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(32, 32)
        row.icon:SetPoint("LEFT", 6, 0)
        row.text = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        row.text:SetPoint("LEFT", row.icon, "RIGHT", 7, 0)
        if selectable then
            row.check = O.CheckButton(row)
            row.check:SetPoint("RIGHT", -8, 0)
            row.check.Text:SetText("Show sweep")
            row.check.Text:ClearAllPoints()
            row.check.Text:SetPoint("RIGHT", row.check, "LEFT", -7, 0)
        else
            row.swatch = O.Button(row, 26, 20)
            row.swatch:SetPoint("RIGHT", -6, 0)
            row.swatch.fill = row.swatch:CreateTexture(nil, "ARTWORK")
            row.swatch.fill:SetSize(14, 14)
            row.swatch.fill:SetPoint("CENTER")
        end
        storage[index] = row
        return row
    end

    local function disableEscape(spellID)
        local escapes = {}
        for id in pairs(ns.db.escapes) do
            if id ~= spellID then escapes[id] = true end
        end
        ns.Set("escapes", escapes)
        if ns.db.movementSweepSpellIDs and ns.db.movementSweepSpellIDs[spellID] then
            local selected = {}
            for id, enabled in pairs(ns.db.movementSweepSpellIDs) do
                if id ~= spellID and enabled then selected[id] = true end
            end
            ns.Set("movementSweepSpellIDs", selected)
            if ns.Binding and ns.Binding.RefreshMovementCooldowns then
                ns.Binding:RefreshMovementCooldowns("movement action disabled")
            end
        end
    end

    local function beginBinding(spell, kind)
        local keys = ns.Bindings:KeysForSpell(spell.id)
        local currentKey = kind == "ESCAPE" and not ns.db.escapes[spell.id]
            and nil or keys[1]
        promptForKey(spell.name, currentKey, function(key)
            -- Selecting a movement spell is its explicit opt-in. Cancelling
            -- leaves the candidate inert.
            if kind == "ESCAPE" then ns.db.escapes[spell.id] = true end
            local ok, message = ns.Bindings:SetSpellBinding(spell.id, key)
            if not ok then ns.Print(message) return end
            ns.RequestRebuildSoon(0.05)
            redrawAll()
        end, function()
            ns.Bindings:ClearSpellBinding(spell.id)
            if kind == "ESCAPE" then disableEscape(spell.id) end
            ns.RequestRebuildSoon(0.05)
            redrawAll()
        end)
    end

    redrawAll = function()
        local bound = {}
        for _, entry in ipairs(ns.Bindings:List()) do
            local spellID = ns.Bindings:SpellID(entry)
            local spell, kind = findSpell(spellID)
            if spell and kind == "ESCAPE" and not ns.db.escapes[spellID] then spell = nil end
            if spell then bound[#bound + 1] = { entry = entry, spell = spell, kind = kind } end
        end
        boundCount:SetText("Bound  " .. #bound)
        clearAll:SetShown(#bound > 0)
        clearAll:ClearAllPoints()
        clearAll:SetPoint("TOPRIGHT", left, "TOPRIGHT", 0, -70 - #bound * 46 - 2)
        for _, row in ipairs(boundRows) do row:Hide() end
        for index, item in ipairs(bound) do
            local row = makeBoundRow(index)
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", left, "TOPLEFT", 0, -70 - (index - 1) * 46)
            row.icon:SetTexture(spellIcon(item.spell.id))
            row.text:SetText(item.spell.name)
            row.key:SetText(ns.Bindings:Label(item.entry.key))
            attachSpellTooltip(row, item.spell)
            row:SetScript("OnClick", function() beginBinding(item.spell, item.kind) end)
            row.remove:SetScript("OnClick", function()
                ns.Bindings:ClearSpellBinding(item.spell.id)
                if item.kind == "ESCAPE" then disableEscape(item.spell.id) end
                ns.RequestRebuildSoon(0.05)
                redrawAll()
            end)
            row.remove:Show()
            row:Show()
        end
        if #bound == 0 then
            local row = makeBoundRow(1)
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", left, "TOPLEFT", 0, -70)
            row.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
            row.text:SetText("No actions bound")
            row.key:SetText("")
            row.remove:Hide()
            row.salveSpellID = nil
            row:SetScript("OnEnter", nil)
            row:SetScript("OnLeave", nil)
            row:SetScript("OnClick", nil)
            row:Show()
        end

        local movementBound = {}
        for _, item in ipairs(bound) do
            if item.kind == "ESCAPE" then movementBound[#movementBound + 1] = item end
        end
        -- Options are constructed at ADDON_LOADED, before PLAYER_LOGIN has
        -- discovered the class spell list. Do not mistake that temporary empty
        -- list for an unbound saved selection and erase it on every reload.
        for _, row in ipairs(sweepColourRows) do row:Hide() end
        for _, row in ipairs(sweepChoiceRows) do row:Hide() end
        sweepColoursHeader:Hide()
        sweepChoiceHeader:Hide()
        sweepExplain:Hide()
        sweepDivider:Hide()
        if #movementBound > 0 then
            local sweepY = -70 - math.max(#bound, 1) * 46 - 52
            sweepDivider:ClearAllPoints()
            sweepDivider:SetPoint("TOPLEFT", left, "TOPLEFT", 0, sweepY + 18)
            sweepDivider:SetPoint("TOPRIGHT", left, "TOPRIGHT", 0, sweepY + 18)
            sweepDivider:Show()
            sweepColoursHeader:ClearAllPoints()
            sweepColoursHeader:SetPoint("TOPLEFT", left, "TOPLEFT", 0, sweepY)
            sweepColoursHeader:Show()
            for index, item in ipairs(movementBound) do
                local row = makeSweepRow(sweepColourRows, index, false)
                row:ClearAllPoints()
                row:SetPoint("TOPLEFT", left, "TOPLEFT", 0, sweepY - 24 - (index - 1) * 46)
                row.icon:SetTexture(spellIcon(item.spell.id))
                row.text:SetText(item.spell.name)
                local r, g, b, a = ns.Binding:GetMovementSweepColour(item.spell.id)
                row.swatch.fill:SetColorTexture(r, g, b, a)
                row.swatch:SetScript("OnClick", function()
                    O.ShowColourPicker({ r = r, g = g, b = b, a = a }, function(colour)
                        local colours = {}
                        for id, value in pairs(ns.db.movementSweepColours or {}) do colours[id] = value end
                        colours[item.spell.id] = colour
                        ns.Set("movementSweepColours", colours)
                        ns.Binding:RefreshMovementCooldowns("movement sweep colour changed")
                        redrawAll()
                    end)
                end)
                row:Show()
            end
            local choiceY = sweepY - 30 - #movementBound * 46
            sweepChoiceHeader:ClearAllPoints()
            sweepChoiceHeader:SetPoint("TOPLEFT", left, "TOPLEFT", 0, choiceY)
            sweepChoiceHeader:Show()
            for index, item in ipairs(movementBound) do
                local row = makeSweepRow(sweepChoiceRows, index, true)
                row:ClearAllPoints()
                row:SetPoint("TOPLEFT", left, "TOPLEFT", 0, choiceY - 24 - (index - 1) * 46)
                row.icon:SetTexture(spellIcon(item.spell.id))
                row.text:SetText(item.spell.name)
                row.check:SetChecked(ns.db.movementSweepSpellIDs and ns.db.movementSweepSpellIDs[item.spell.id])
                row.check:SetScript("OnClick", function()
                    local selected = {}
                    for id, enabled in pairs(ns.db.movementSweepSpellIDs or {}) do
                        if enabled then selected[id] = true end
                    end
                    -- This is Salve's own painted Button, not Blizzard's
                    -- CheckButtonTemplate; it has no automatic checked-state
                    -- toggle. Flip the saved value explicitly before redraw.
                    selected[item.spell.id] = not selected[item.spell.id] or nil
                    ns.Set("movementSweepSpellIDs", selected)
                    ns.Binding:RefreshMovementCooldowns("movement sweep selection changed")
                    redrawAll()
                end)
                row:Show()
            end
            sweepExplain:ClearAllPoints()
            sweepExplain:SetPoint("TOPLEFT", left, "TOPLEFT", 0,
                choiceY - 34 - #movementBound * 46)
            sweepExplain:Show()
        end

        for _, row in ipairs(paletteRows) do row:Hide() end
        local paletteIndex, py = 0, -32
        local function section(label, spells, kind)
            local heading = makePaletteRow(paletteIndex + 1)
            paletteIndex = paletteIndex + 1
            heading:ClearAllPoints()
            heading:SetPoint("TOPLEFT", right, "TOPLEFT", 0, py)
            heading:SetSize(246, 42)
            heading:SetBackdropColor(unpack(O.theme.content))
            heading:SetBackdropBorderColor(unpack(O.theme.content))
            heading.icon:Hide()
            heading.text:ClearAllPoints()
            heading.text:SetPoint("LEFT", 0, 0)
            heading.text:SetText(label)
            heading.text:SetTextColor(unpack(O.theme.section))
            if paletteIndex == 1 then
                -- Both labels use GameFontHighlightSmall.  Tie their left
                -- anchors together so their baselines remain aligned if the
                -- header fonts or hint spacing change.
                boundCount:ClearAllPoints()
                boundCount:SetPoint("LEFT", heading.text, "LEFT", -310, 0)
            end
            heading.status:SetText("")
            heading.subtext:Hide()
            heading.salveSpellID = nil
            heading:SetScript("OnEnter", nil)
            heading:SetScript("OnLeave", nil)
            heading:SetScript("OnClick", nil)
            heading:Show()
            -- Section labels are text-only. Keep their next spell row level
            -- with the first bound action instead of reserving a full row.
            py = py - 38
            if #spells == 0 then
                local row = makePaletteRow(paletteIndex + 1)
                paletteIndex = paletteIndex + 1
                row:ClearAllPoints()
                row:SetPoint("TOPLEFT", right, "TOPLEFT", 0, py)
                row:SetSize(246, 42)
                row.icon:Hide()
                row.text:ClearAllPoints()
                row.text:SetPoint("LEFT", 8, 0)
                row.text:SetText("No spells detected")
                row.text:SetTextColor(unpack(O.theme.muted))
                row.status:SetText("")
                row.subtext:Hide()
                row:SetBackdropColor(unpack(O.theme.content))
                row:SetBackdropBorderColor(unpack(O.theme.edge))
                row.salveSpellID = nil
                row:SetScript("OnEnter", nil)
                row:SetScript("OnLeave", nil)
                row:SetScript("OnClick", nil)
                row:Show()
                py = py - 46
            end
            for _, spell in ipairs(spells) do
                local row = makePaletteRow(paletteIndex + 1)
                paletteIndex = paletteIndex + 1
                row:ClearAllPoints()
                row:SetPoint("TOPLEFT", right, "TOPLEFT", 0, py)
                row.icon:Show()
                row.icon:SetTexture(spellIcon(spell.id))
                row.text:ClearAllPoints()
                row.text:SetPoint("LEFT", row.icon, "RIGHT", 8, 0)
                row.text:SetText(spell.name)
                row.text:SetTextColor(1, 1, 1)
                attachSpellTooltip(row, spell)
                -- A row may have previously been a section heading while the
                -- known-spell list was still empty. Reset its surface on every
                -- draw so all spell choices share the same quiet background.
                row:SetBackdropColor(unpack(O.theme.content))
                local keys = ns.Bindings:KeysForSpell(spell.id)
                local isBound = #keys > 0 and (kind ~= "ESCAPE" or ns.db.escapes[spell.id])
                row.status:SetText(isBound and "bound" or "")
                row:SetBackdropBorderColor(unpack(O.theme.edge))
                row:SetScript("OnClick", function() beginBinding(spell, kind) end)
                if kind == "DISPEL" then
                    row:SetSize(246, 58)
                    row.text:ClearAllPoints()
                    row.text:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 8, -7)
                    row.subtext:ClearAllPoints()
                    row.subtext:SetPoint("TOPLEFT", row.text, "BOTTOMLEFT", 0, -2)
                    row.subtext:SetText("Dispels " .. ns.CuresText(spell.cures))
                    row.subtext:Show()
                    py = py - 62
                else
                    row.subtext:Hide()
                    py = py - 46
                end
                row:Show()
            end
        end
        local allyEscapes, areaEscapes, selfEscapes = {}, {}, {}
        for _, spell in ipairs(ns.knownEscapes or {}) do
            local destination = spell.scope == ns.ESCAPE_ALLY and allyEscapes
                or spell.scope == ns.ESCAPE_AREA and areaEscapes or selfEscapes
            destination[#destination + 1] = spell
        end
        section("Dispels", ns.knownDispels or {}, "DISPEL")
        section("Frees movement", allyEscapes, "ESCAPE")
        section("Area movement", areaEscapes, "ESCAPE")
        section("Self only", selfEscapes, "ESCAPE")
        local leftRows = #bound * 46 + (#movementBound > 0 and (100 + #movementBound * 92) or 0)
        local paletteDepth = paletteIndex * 46 + #(ns.knownDispels or {}) * 16
        pageBottom = y - math.max(leftRows, paletteDepth) - 108
        if panel.salveSetBottom then panel.salveSetBottom(pageBottom) end
    end

    redrawAll()
    panel.salveRefresh[#panel.salveRefresh + 1] = redrawAll
    ns.Options.RefreshDispel = redrawAll
    return pageBottom
end)
