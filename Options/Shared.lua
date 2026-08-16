local addonName, ns = ...

-- ============================================================
-- Options plumbing
-- ============================================================
-- Salve registers into Blizzard's own Options > AddOns tree rather than putting
-- up a floating window: one main category and a subcategory per page, so the
-- pages stay separate files without inventing a nav rail of our own.
--
-- Widget creation follows Speedster's defensive shape -- pcall the Blizzard
-- template, fall back to the plain one -- because InterfaceOptionsCheckButton-
-- Template has been renamed more than once and a hard call takes the whole file
-- down with it.

ns.Options = {}
local Options = ns.Options

Options.categories = {}

local PAD_L   = 16
local ROW_GAP = 26

-- ── Widgets ────────────────────────────────────────────────────────────────

-- Hints live in a tooltip rather than as a second line of grey text under every
-- control: at this many settings the inline version turns the page into a wall.
local function attachHint(control, title, hint)
    if not hint then return end
    control.salveHintTitle = title
    control.salveHint = hint
    control:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(self.salveHintTitle or "Salve", 1, 0.82, 0.26)
        GameTooltip:AddLine(self.salveHint, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    control:HookScript("OnLeave", function(self)
        if GameTooltip:IsOwned(self) then GameTooltip:Hide() end
    end)
end

Options.AttachHint = attachHint

local function attachTitleHint(parent, fontString, title, hint)
    if not hint then return end
    local region = CreateFrame("Frame", nil, parent)
    region:SetPoint("TOPLEFT", fontString, "TOPLEFT", -2, 2)
    region:SetPoint("BOTTOMRIGHT", fontString, "BOTTOMRIGHT", 2, -2)
    region:EnableMouse(true)
    attachHint(region, title, hint)
    return region
end

local function refreshAll(panel)
    if panel.salveRefreshAll then panel.salveRefreshAll() end
end

function Options.CheckButton(parent)
    local ok, btn = pcall(CreateFrame, "CheckButton", nil, parent,
        "InterfaceOptionsCheckButtonTemplate")
    if not ok or not btn then
        btn = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    end
    -- The fallback template has no .Text, so give it one that lands in the same
    -- place. Every caller can then treat the two identically.
    if not btn.Text then
        btn.Text = btn:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        btn.Text:SetPoint("LEFT", btn, "RIGHT", 2, 1)
    end
    return btn
end

-- Returns the control and the y for the next row, so pages read as a straight
-- run of assignments instead of tracking offsets by hand.
function Options.Check(panel, label, hint, y, get, set)
    local btn = Options.CheckButton(panel)
    btn:SetPoint("TOPLEFT", PAD_L - 2, y)
    btn.Text:SetText(label)
    btn:SetChecked(get() and true or false)
    btn:SetScript("OnClick", function(self)
        set(self:GetChecked() and true or false)
        refreshAll(panel)
    end)
    if btn.SetHitRectInsets then btn:SetHitRectInsets(0, -460, 0, 0) end
    attachHint(btn, label, hint)

    panel.salveRefresh[#panel.salveRefresh + 1] = function()
        btn:SetChecked(get() and true or false)
    end

    return btn, y - ROW_GAP
end

function Options.Slider(panel, label, hint, y, minV, maxV, step, get, set, fmt)
    local s = CreateFrame("Slider", nil, panel, "UISliderTemplate")
    s:SetOrientation("HORIZONTAL")
    s:SetSize(200, 16)
    s:SetPoint("TOPLEFT", PAD_L, y - 16)
    s:SetMinMaxValues(minV, maxV)
    s:SetValueStep(step)
    s:SetObeyStepOnDrag(true)

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    title:SetPoint("BOTTOMLEFT", s, "TOPLEFT", 0, 2)

    local function labelText()
        return type(label) == "function" and label() or label
    end

    local titleHint
    local function render(v)
        local shownLabel = labelText()
        title:SetText(shownLabel .. ": |cffffd100"
            .. (fmt and fmt(v) or tostring(v)) .. "|r")
        s.salveHintTitle = shownLabel
        if titleHint then titleHint.salveHintTitle = shownLabel end
    end

    s:SetValue(get())
    render(get())

    s:SetScript("OnValueChanged", function(_, v)
        -- Snap before storing: OnValueChanged fires with unsnapped values while
        -- dragging on some clients, which would write 19.9997 into saved vars.
        v = math.floor(v / step + 0.5) * step
        render(v)
        set(v)
        refreshAll(panel)
    end)
    s.salveTitle = title
    attachHint(s, labelText(), hint)
    titleHint = attachTitleHint(panel, title, labelText(), hint)

    panel.salveRefresh[#panel.salveRefresh + 1] = function()
        s:SetValue(get())
        render(get())
    end

    return s, y - (ROW_GAP + 18)
end

-- A cycling button rather than a dropdown: the dropdown API churned hard in
-- 12.0, and a three-option control does not need a menu to be usable.
function Options.Cycle(panel, label, hint, y, values, labels, get, set)
    local btn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    btn:SetSize(160, 22)
    btn:SetPoint("TOPLEFT", PAD_L, y - 16)

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    title:SetPoint("BOTTOMLEFT", btn, "TOPLEFT", 2, 2)
    title:SetText(label)

    local function render()
        local cur = get()
        for i, v in ipairs(values) do
            if v == cur then btn:SetText(labels[i]) return end
        end
        btn:SetText(labels[1])
    end
    render()

    btn:SetScript("OnClick", function()
        local cur = get()
        for i, v in ipairs(values) do
            if v == cur then
                set(values[(i % #values) + 1])
                render()
                refreshAll(panel)
                return
            end
        end
        set(values[1])
        render()
        refreshAll(panel)
    end)
    btn.salveTitle = title
    attachHint(btn, label, hint)
    attachTitleHint(panel, title, label, hint)

    panel.salveRefresh[#panel.salveRefresh + 1] = render
    return btn, y - (ROW_GAP + 18)
end

-- Two short choices under one heading. Alignment reads much faster as a pair:
-- Horizontal and Vertical belong together, not as two full-width sections.
function Options.CyclePair(panel, heading, y, left, right)
    local groupTitle = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    groupTitle:SetPoint("TOPLEFT", PAD_L, y)
    groupTitle:SetText(heading)

    local function makeChoice(x, spec)
        local title = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        title:SetPoint("TOPLEFT", x, y - 20)
        title:SetText(spec.label)

        local btn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
        btn:SetSize(150, 22)
        btn:SetPoint("TOPLEFT", x, y - 34)
        btn.salveTitle = title

        local function render()
            local current = spec.get()
            for i, value in ipairs(spec.values) do
                if value == current then
                    btn:SetText(spec.labels[i])
                    return
                end
            end
            btn:SetText(spec.labels[1])
        end

        btn:SetScript("OnClick", function()
            local current = spec.get()
            for i, value in ipairs(spec.values) do
                if value == current then
                    spec.set(spec.values[(i % #spec.values) + 1])
                    render()
                    refreshAll(panel)
                    return
                end
            end
            spec.set(spec.values[1])
            render()
            refreshAll(panel)
        end)

        attachHint(btn, heading .. " — " .. spec.label, spec.hint)
        attachTitleHint(panel, title, heading .. " — " .. spec.label, spec.hint)
        panel.salveRefresh[#panel.salveRefresh + 1] = render
        render()
        return btn
    end

    local leftButton = makeChoice(PAD_L, left)
    local rightButton = makeChoice(206, right)
    return leftButton, rightButton, y - 66
end

-- Like Cycle, but the option list is rebuilt every time it is drawn or clicked.
-- Needed wherever the choices depend on game state: the pages are built once at
-- ADDON_LOADED, while the spells you know change with every specialisation.
function Options.DynamicCycle(panel, label, hint, y, optionsFn, get, set)
    local btn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    btn:SetSize(190, 22)
    btn:SetPoint("TOPLEFT", 16, y - 16)

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    title:SetPoint("BOTTOMLEFT", btn, "TOPLEFT", 2, 2)
    title:SetText(label)

    local function render()
        local values, labels = optionsFn()
        local cur = get()
        for i, v in ipairs(values) do
            if v == cur then btn:SetText(labels[i]) return end
        end
        -- The stored choice is no longer available -- a spell from the previous
        -- spec, most likely. Show the first option rather than a blank button.
        btn:SetText(labels[1] or "—")
    end

    btn:SetScript("OnClick", function()
        local values = optionsFn()
        if #values == 0 then return end
        local cur = get()
        for i, v in ipairs(values) do
            if v == cur then set(values[(i % #values) + 1]) render() return end
        end
        set(values[1])
        render()
    end)

    btn.salveTitle = title
    attachHint(btn, label, hint)
    attachTitleHint(panel, title, label, hint)

    panel.salveRefresh[#panel.salveRefresh + 1] = render
    render()

    return btn, y - (ROW_GAP + 18)
end

-- A dropdown that opens a panel of checkboxes rather than a single-choice menu:
-- a base mode at the top, then conditions that combine. Hand-built because
-- Blizzard's dropdown API churned in 12.0 and a custom panel is both stabler
-- and the only way to get the two-part layout.
function Options.MultiSelect(panel, label, hint, y, spec)
    local btn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    btn:SetSize(210, 22)
    btn:SetPoint("TOPLEFT", 16, y - 16)

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    title:SetPoint("BOTTOMLEFT", btn, "TOPLEFT", 2, 2)
    title:SetText(label)

    local arrow = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    arrow:SetPoint("RIGHT", -6, 0)
    arrow:SetText("|cffffd100v|r")

    -- The drop-down body. Parented to UIParent at a high strata so it floats
    -- over the settings panel rather than being clipped by it.
    local menu = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    menu:SetFrameStrata("FULLSCREEN_DIALOG")
    menu:SetPoint("TOPLEFT", btn, "BOTTOMLEFT", 0, -2)
    menu:SetWidth(230)
    menu:EnableMouse(true)
    menu:Hide()

    local bg = menu:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.05, 0.05, 0.06, 0.97)
    for _, e in ipairs({ { "TOPLEFT", "TOPRIGHT", true }, { "BOTTOMLEFT", "BOTTOMRIGHT", true },
                         { "TOPLEFT", "BOTTOMLEFT", false }, { "TOPRIGHT", "BOTTOMRIGHT", false } }) do
        local t = menu:CreateTexture(nil, "OVERLAY")
        t:SetColorTexture(0.35, 0.35, 0.38, 1)
        t:SetPoint(e[1]); t:SetPoint(e[2])
        if e[3] then t:SetHeight(1) else t:SetWidth(1) end
    end

    local rows, my = {}, -8

    local function addRow(text, get, set, isHeading)
        if isHeading then
            local h = menu:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
            h:SetPoint("TOPLEFT", 10, my)
            h:SetText(text)
            h:SetTextColor(0.6, 0.6, 0.65)
            my = my - 18
            return
        end

        local row = CreateFrame("Button", nil, menu)
        row:SetPoint("TOPLEFT", 6, my)
        row:SetPoint("TOPRIGHT", -6, my)
        row:SetHeight(22)

        local box = row:CreateTexture(nil, "ARTWORK")
        box:SetSize(14, 14)
        box:SetPoint("LEFT", 6, 0)

        local fs = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        fs:SetPoint("LEFT", box, "RIGHT", 8, 0)
        fs:SetText(text)

        local hl = row:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetColorTexture(1, 1, 1, 0.07)

        row.Render = function()
            if get() then
                box:SetColorTexture(0.28, 0.80, 0.62, 1)
            else
                box:SetColorTexture(0.16, 0.16, 0.18, 1)
            end
        end

        row:SetScript("OnClick", function()
            set(not get())
            for _, r in ipairs(rows) do r.Render() end
            if panel.salveRefreshAll then panel.salveRefreshAll() end
        end)

        rows[#rows + 1] = row
        my = my - 22
    end

    for _, item in ipairs(spec.items) do
        addRow(item.label, item.get, item.set, item.heading)
    end
    menu:SetHeight(-my + 8)

    local function render()
        btn:SetText(spec.summary())
        for _, r in ipairs(rows) do r.Render() end
    end

    btn:SetScript("OnClick", function()
        menu:SetShown(not menu:IsShown())
        render()
    end)

    -- Close when the settings page goes away, or it would float over whatever
    -- the player opens next.
    panel:HookScript("OnHide", function() menu:Hide() end)

    btn.salveTitle = title
    attachHint(btn, label, hint)
    attachTitleHint(panel, title, label, hint)

    panel.salveRefresh[#panel.salveRefresh + 1] = render
    render()

    return btn, y - (ROW_GAP + 18)
end

function Options.Header(panel, text, y)
    local fs = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    fs:SetPoint("TOPLEFT", PAD_L, y)
    fs:SetText(text)

    local divider = panel:CreateTexture(nil, "ARTWORK")
    divider:SetHeight(1)
    divider:SetPoint("LEFT", fs, "RIGHT", 10, 0)
    divider:SetPoint("RIGHT", panel, "RIGHT", -20, 0)
    divider:SetColorTexture(0.38, 0.38, 0.42, 0.7)

    return fs, y - 28
end

function Options.SetEnabled(control, enabled)
    if not control then return end
    if control.SetEnabled then
        control:SetEnabled(enabled)
    elseif enabled and control.Enable then
        control:Enable()
    elseif not enabled and control.Disable then
        control:Disable()
    end
    local colour = enabled and 1 or 0.5
    if control.Text then control.Text:SetTextColor(colour, colour, colour) end
    if control.salveTitle then
        control.salveTitle:SetTextColor(colour, colour, colour)
    end
end

function Options.PageReset(panel, y, reset)
    local button = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    button:SetSize(180, 22)
    button:SetPoint("TOPLEFT", 16, y - 4)
    button:SetText("Reset page to defaults")
    attachHint(button, "Reset page to defaults", "Reset only the settings on this page.")
    button:SetScript("OnClick", function()
        reset()
        if panel.salveRefreshAll then panel.salveRefreshAll() end
    end)
    return button, y - 40
end

-- ── Page construction ──────────────────────────────────────────────────────

-- ☠ PAGES ARE QUEUED HERE, NOT BUILT. Option files run while the TOC loads,
--   which is BEFORE ADDON_LOADED and therefore before ns.InitConfig() has made
--   ns.db exist. Building at file scope meant every page captured a nil db and
--   the first getter call took the whole options system down with it -- no
--   pages registered at all. Core/Events.lua calls BuildAll() once the saved
--   variables are real.
Options.queue = {}

function Options.NewPage(spec, build)
    if type(spec) == "string" then spec = { name = spec } end
    spec.build = build
    Options.queue[#Options.queue + 1] = spec
end

function Options.BuildAll()
    for _, page in ipairs(Options.queue) do
        Options.CreatePage(page)
    end
    Options.queue = {}
end

-- Builds a canvas panel and registers it. The FIRST page registered becomes the
-- parent category; the rest become subcategories under it.
function Options.CreatePage(spec)
    local name, build = spec.name, spec.build
    local panel = CreateFrame("Frame", "SalveOptions" .. name:gsub("%s", ""))
    panel.name = name
    panel.salveRefresh = {}

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", PAD_L, -16)
    title:SetText(spec.title or name)

    local contentTop = -48
    if spec.description then
        local description = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        description:SetPoint("TOPLEFT", PAD_L, -42)
        description:SetWidth(540)
        description:SetJustifyH("LEFT")
        description:SetTextColor(0.72, 0.72, 0.72)
        description:SetText(spec.description)
        contentTop = -68
    end

    local pageIcon = panel:CreateTexture(nil, "ARTWORK")
    pageIcon:SetSize(42, 42)
    pageIcon:SetPoint("TOPRIGHT", -38, -12)
    pageIcon:SetTexture("Interface\\AddOns\\Salve\\Textures\\SalveTransparent")

    local scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 0, contentTop)
    scroll:SetPoint("BOTTOMRIGHT", -30, 10)

    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(560, 1)
    scroll:SetScrollChild(content)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(self, delta)
        local range = self:GetVerticalScrollRange() or 0
        local nextValue = self:GetVerticalScroll() - delta * 40
        self:SetVerticalScroll(math.max(0, math.min(range, nextValue)))
    end)
    content.salveRefresh = panel.salveRefresh

    panel.salveRefreshAll = function()
        if panel.salveRefreshing then return end
        panel.salveRefreshing = true
        for _, fn in ipairs(panel.salveRefresh) do fn() end
        panel.salveRefreshing = false
    end
    content.salveRefreshAll = panel.salveRefreshAll
    content.salveSetBottom = function(bottomY)
        content:SetHeight(math.max(1, -(bottomY or -1) + 16))
    end
    content.salveCreatePinned = function(height)
        height = math.max(1, height or 1)
        scroll:ClearAllPoints()
        scroll:SetPoint("TOPLEFT", 0, contentTop - height)
        scroll:SetPoint("BOTTOMRIGHT", -30, 10)

        local pinned = CreateFrame("Frame", nil, panel)
        pinned:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, contentTop)
        pinned:SetSize(560, height)
        pinned.salveRefresh = panel.salveRefresh
        pinned.salveRefreshAll = panel.salveRefreshAll
        return pinned
    end

    local bottomY = build(content, -8)
    content.salveSetBottom(bottomY or -600)

    -- Blizzard shows a canvas panel without telling it to refresh, so pull the
    -- saved values back in on every open. Otherwise a value changed by a slash
    -- command shows stale here.
    panel:SetScript("OnShow", function(self)
        self.salveRefreshAll()
    end)

    if Settings and Settings.RegisterCanvasLayoutCategory then
        if not Options.rootCategory then
            local cat = Settings.RegisterCanvasLayoutCategory(panel, "Salve", "Salve")
            -- ☠ The ID is what OpenToCategory needs; the category object alone
            --   is not enough on every client build.
            cat.ID = cat.ID or "Salve"
            Settings.RegisterAddOnCategory(cat)
            Options.rootCategory = cat
            Options.rootID = cat:GetID() or cat.ID
        else
            local sub = Settings.RegisterCanvasLayoutSubcategory(
                Options.rootCategory, panel, name)
            Options.categories[name] = sub
        end
    elseif InterfaceOptions_AddCategory then
        -- Pre-Settings clients: flat list, one entry per page.
        if Options.rootCategory then panel.parent = "Salve" end
        InterfaceOptions_AddCategory(panel)
        Options.rootCategory = Options.rootCategory or panel
    end

    return panel
end

function ns.OpenOptions()
    if Settings and Settings.OpenToCategory and ns.Options.rootID then
        -- ☠ Called twice on purpose. A known Blizzard quirk: the first call
        --   opens the panel, the second actually selects the category.
        Settings.OpenToCategory(ns.Options.rootID)
        Settings.OpenToCategory(ns.Options.rootID)
    elseif InterfaceOptionsFrame_OpenToCategory and ns.Options.rootCategory then
        InterfaceOptionsFrame_OpenToCategory(ns.Options.rootCategory)
        InterfaceOptionsFrame_OpenToCategory(ns.Options.rootCategory)
    else
        ns.Print("could not open the options panel on this client")
    end
end
