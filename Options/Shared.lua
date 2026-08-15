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
local function attachHint(control, hint)
    if not hint then return end
    control.salveHint = hint
    control:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(self.salveHint, 1, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    control:HookScript("OnLeave", function(self)
        if GameTooltip:IsOwned(self) then GameTooltip:Hide() end
    end)
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
    end)
    attachHint(btn, hint)

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

    local function render(v)
        title:SetText(label .. ": |cffffd100" .. (fmt and fmt(v) or tostring(v)) .. "|r")
    end

    s:SetValue(get())
    render(get())

    s:SetScript("OnValueChanged", function(_, v)
        -- Snap before storing: OnValueChanged fires with unsnapped values while
        -- dragging on some clients, which would write 19.9997 into saved vars.
        v = math.floor(v / step + 0.5) * step
        render(v)
        set(v)
    end)
    attachHint(s, hint)

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
            if v == cur then set(values[(i % #values) + 1]) render() return end
        end
        set(values[1])
        render()
    end)
    attachHint(btn, hint)

    panel.salveRefresh[#panel.salveRefresh + 1] = render
    return btn, y - (ROW_GAP + 18)
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

    if hint then
        btn:HookScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(hint, 1, 1, 1, 1, true)
            GameTooltip:Show()
        end)
        btn:HookScript("OnLeave", function(self)
            if GameTooltip:IsOwned(self) then GameTooltip:Hide() end
        end)
    end

    panel.salveRefresh[#panel.salveRefresh + 1] = render
    render()

    return btn, y - (ROW_GAP + 18)
end

function Options.Header(panel, text, y)
    local fs = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    fs:SetPoint("TOPLEFT", PAD_L, y)
    fs:SetText(text)
    return fs, y - 24
end

-- ── Page construction ──────────────────────────────────────────────────────

-- ☠ PAGES ARE QUEUED HERE, NOT BUILT. Option files run while the TOC loads,
--   which is BEFORE ADDON_LOADED and therefore before ns.InitConfig() has made
--   ns.db exist. Building at file scope meant every page captured a nil db and
--   the first getter call took the whole options system down with it -- no
--   pages registered at all. Core/Events.lua calls BuildAll() once the saved
--   variables are real.
Options.queue = {}

function Options.NewPage(name, build)
    Options.queue[#Options.queue + 1] = { name = name, build = build }
end

function Options.BuildAll()
    for _, page in ipairs(Options.queue) do
        Options.CreatePage(page.name, page.build)
    end
    Options.queue = {}
end

-- Builds a canvas panel and registers it. The FIRST page registered becomes the
-- parent category; the rest become subcategories under it.
function Options.CreatePage(name, build)
    local panel = CreateFrame("Frame", "SalveOptions" .. name:gsub("%s", ""))
    panel.name = name
    panel.salveRefresh = {}

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", PAD_L, -16)
    title:SetText("Salve — " .. name)

    build(panel, -48)

    -- Blizzard shows a canvas panel without telling it to refresh, so pull the
    -- saved values back in on every open. Otherwise a value changed by a slash
    -- command shows stale here.
    panel:SetScript("OnShow", function(self)
        for _, fn in ipairs(self.salveRefresh) do fn() end
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
