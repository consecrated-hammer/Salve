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

O.NewPage("Dispel", function(panel, y)
    _, y = O.Header(panel, "Detected dispels", y)

    local known = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    known:SetPoint("TOPLEFT", 16, y)
    known:SetWidth(520)
    known:SetJustifyH("LEFT")
    y = y - 40

    _, y = O.Header(panel, "Click bindings", y)

    local rowsTop = y
    local rows = {}

    -- Rebuilt on every open and after every edit: both the binding list and the
    -- spells it resolves to can change underneath this page.
    local function redraw()
        local names = {}
        for _, s in ipairs(ns.knownDispels or {}) do
            names[#names + 1] = s.name .. " (" .. ns.CuresText(s.cures) .. ")"
        end
        known:SetText(#names > 0 and table.concat(names, "\n")
            or "|cffff4444No dispel on this specialisation.|r")

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

                rows[i] = row
            end

            row:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, rowsTop - (i - 1) * 32)
            row:Show()

            local what, icon = ns.Bindings:Describe(entry)
            row.icon:SetTexture(icon or "Interface\\Icons\\INV_Misc_QuestionMark")
            row.spell:SetText(what)
            row.bind:SetText(ns.Bindings:Label(entry.key))

            row.bind:SetScript("OnClick", function()
                promptForKey(function(key)
                    -- Materialise the defaults before editing, or the first edit
                    -- would be written into the shared default table.
                    if not ns.db.bindings or #ns.db.bindings == 0 then
                        ns.db.bindings = CopyTable(ns.Bindings:List())
                    end
                    ns.db.bindings[i].key = key
                    ns.RequestRebuildSoon(0.05)
                    redraw()
                end)
            end)

            row.remove:SetScript("OnClick", function()
                if not ns.db.bindings or #ns.db.bindings == 0 then
                    ns.db.bindings = CopyTable(ns.Bindings:List())
                end
                table.remove(ns.db.bindings, i)
                ns.RequestRebuildSoon(0.05)
                redraw()
            end)
        end
    end

    local add = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    add:SetSize(150, 22)
    add:SetPoint("TOPLEFT", 16, rowsTop - 5 * 32 - 8)
    add:SetText("Add a binding")
    add:SetScript("OnClick", function()
        promptForKey(function(key)
            if not ns.db.bindings or #ns.db.bindings == 0 then
                ns.db.bindings = CopyTable(ns.Bindings:List())
            end
            ns.db.bindings[#ns.db.bindings + 1] =
                { key = key, role = ns.ROLE_PRIMARY }
            ns.RequestRebuildSoon(0.05)
            redraw()
        end)
    end)

    y = rowsTop - 5 * 32 - 44

    _, y = O.Header(panel, "Diagnostics", y)

    local probe = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    probe:SetSize(150, 22)
    probe:SetPoint("TOPLEFT", 16, y)
    probe:SetText("Run engine probe")
    probe:SetScript("OnClick", function() ns.Binding:Report() end)

    panel.salveRefresh[#panel.salveRefresh + 1] = redraw
end)
