local addonName, ns = ...

-- ============================================================
-- Options plumbing
-- ============================================================
-- Blizzard's Options > AddOns tree holds a small Salve launcher. The actual
-- pages live in Salve's movable window so it can sit beside the frames being
-- configured without inheriting Blizzard Settings' fixed position and width.
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
            local values = type(spec.values) == "function"
                and spec.values() or spec.values
            local labels = type(spec.labels) == "function"
                and spec.labels() or spec.labels
            local current = spec.get()
            for i, value in ipairs(values) do
                if value == current then
                    btn:SetText(labels[i])
                    return
                end
            end
            btn:SetText(labels[1])
        end

        btn:SetScript("OnClick", function()
            local values = type(spec.values) == "function"
                and spec.values() or spec.values
            local current = spec.get()
            for i, value in ipairs(values) do
                if value == current then
                    spec.set(values[(i % #values) + 1])
                    render()
                    refreshAll(panel)
                    return
                end
            end
            spec.set(values[1])
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

-- Two compact Blizzard dropdowns under one heading. Use this where the choice
-- describes direction or mode rather than a simple on/off-style cycle: the
-- standard chevron makes it obvious that the current word is selectable, and
-- avoids relying on arrow glyphs that are absent from some WoW fonts.
function Options.DropdownPair(panel, heading, y, left, right)
    local groupTitle = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    groupTitle:SetPoint("TOPLEFT", PAD_L, y)
    groupTitle:SetText(heading)

    local function makeChoice(x, spec)
        local title = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        title:SetPoint("TOPLEFT", x, y - 20)
        title:SetText(spec.label)

        local btn = CreateFrame("DropdownButton", nil, panel,
            "WowStyle1DropdownTemplate")
        btn:SetSize(150, 22)
        btn:SetPoint("TOPLEFT", x, y - 34)
        btn.salveTitle = title

        local function choices()
            local values = type(spec.values) == "function"
                and spec.values() or spec.values
            local labels = type(spec.labels) == "function"
                and spec.labels() or spec.labels
            return values, labels
        end

        local function render()
            local values, labels = choices()
            local current = spec.get()
            local text = labels[1] or "—"
            for i, value in ipairs(values) do
                if value == current then
                    text = labels[i]
                    break
                end
            end
            if btn.SetDefaultText then btn:SetDefaultText(text) end
            if btn.SetText then btn:SetText(text) end
        end

        btn:SetupMenu(function(_, rootDescription)
            local values, labels = choices()
            for i, value in ipairs(values) do
                rootDescription:CreateRadio(labels[i], function()
                    return spec.get() == value
                end, function()
                    spec.set(value)
                    render()
                    refreshAll(panel)
                end)
            end
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
    render()

    return btn, y - (ROW_GAP + 18)
end

-- A native Blizzard dropdown that can mix mutually exclusive base modes with
-- combinable conditions. Retail's current MenuDescription API supports both,
-- so there is no reason for Salve to imitate the menu or draw its own chevron.
function Options.MultiSelect(panel, label, hint, y, spec)
    local btn = CreateFrame("DropdownButton", nil, panel, "WowStyle1DropdownTemplate")
    btn:SetSize(210, 22)
    btn:SetPoint("TOPLEFT", 16, y - 16)

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    title:SetPoint("BOTTOMLEFT", btn, "TOPLEFT", 2, 2)
    title:SetText(label)

    local function render()
        local text = spec.summary()
        if btn.SetDefaultText then btn:SetDefaultText(text) end
        if btn.SetText then btn:SetText(text) end
    end

    btn:SetupMenu(function(_, rootDescription)
        for _, item in ipairs(spec.items) do
            if item.heading then
                rootDescription:CreateDivider()
                rootDescription:CreateTitle(item.label)
            elseif item.radio then
                rootDescription:CreateRadio(item.label, item.get, function()
                    item.set(true)
                    refreshAll(panel)
                    render()
                end)
            else
                rootDescription:CreateCheckbox(item.label, item.get, function()
                    item.set(not item.get())
                    refreshAll(panel)
                    render()
                end)
            end
        end
    end)

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
    Options.CreateWindow()
    Options.CreateLauncher()
    Options.queue = {}
end

-- Builds one content page inside Salve's movable window. Blizzard Settings
-- remains only as a familiar launcher; owning the actual window lets Salve be
-- positioned beside the frames it is configuring.
function Options.CreatePage(spec, parent)
    local name, build = spec.name, spec.build
    local panel = CreateFrame("Frame", "SalveOptions" .. name:gsub("%s", ""), parent)
    panel:SetAllPoints(parent)
    panel:Hide()
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
    content.salveOwner = panel
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

    -- Pull saved values back in on every page visit. Values may also change
    -- through slash commands, the minimap menu or another page.
    panel:SetScript("OnShow", function(self)
        self.salveRefreshAll()
    end)

    return panel
end

function Options.ShowPage(name)
    if not Options.window then return end
    name = name or Options.selectedPage or "Salve"
    if not Options.pages[name] then name = "Salve" end
    Options.selectedPage = name
    for pageName, page in pairs(Options.pages) do
        page:SetShown(pageName == name)
        local button = Options.pageButtons[pageName]
        if button then button:SetEnabled(pageName ~= name) end
    end
end

function Options.CreateWindow()
    if Options.window then return Options.window end

    local frame = CreateFrame("Frame", "SalveSettingsFrame", UIParent,
        "BackdropTemplate")
    frame:SetSize(790, 620)
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12,
    })
    frame:SetBackdropColor(0.035, 0.035, 0.04, 0.98)
    frame:SetBackdropBorderColor(0.58, 0.43, 0.22, 1)

    local saved = ns.db.settingsPoint or { "CENTER", "CENTER", 0, 0 }
    frame:SetPoint(saved[1], UIParent, saved[2], saved[3], saved[4])

    local titleBar = CreateFrame("Button", nil, frame)
    titleBar:SetPoint("TOPLEFT", 8, -8)
    titleBar:SetPoint("TOPRIGHT", -34, -8)
    titleBar:SetHeight(30)
    titleBar:RegisterForDrag("LeftButton")
    titleBar:SetScript("OnDragStart", function()
        frame:StartMoving()
    end)
    titleBar:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
        local point, _, relativePoint, x, y = frame:GetPoint()
        ns.db.settingsPoint = { point, relativePoint, x, y }
    end)

    local icon = titleBar:CreateTexture(nil, "ARTWORK")
    icon:SetSize(28, 28)
    icon:SetPoint("LEFT", 8, 0)
    icon:SetTexture("Interface\\AddOns\\Salve\\Textures\\SalveTransparent")
    local title = titleBar:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("LEFT", icon, "RIGHT", 8, 0)
    title:SetText("Salve settings")

    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -5, -5)
    close:SetScript("OnClick", function() frame:Hide() end)

    local divider = frame:CreateTexture(nil, "ARTWORK")
    divider:SetColorTexture(0.3, 0.3, 0.33, 0.8)
    divider:SetPoint("TOPLEFT", 160, -44)
    divider:SetPoint("BOTTOMLEFT", 160, 12)
    divider:SetWidth(1)

    local host = CreateFrame("Frame", nil, frame)
    host:SetPoint("TOPLEFT", 170, -44)
    host:SetPoint("BOTTOMRIGHT", -10, 10)

    Options.window = frame
    Options.host = host
    Options.pages = {}
    Options.pageButtons = {}

    for index, spec in ipairs(Options.queue) do
        local page = Options.CreatePage(spec, host)
        Options.pages[spec.name] = page

        local button = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        button:SetSize(136, 28)
        button:SetPoint("TOPLEFT", 14, -50 - (index - 1) * 34)
        button:SetText(spec.title or spec.name)
        button:SetScript("OnClick", function() Options.ShowPage(spec.name) end)
        Options.pageButtons[spec.name] = button
    end

    frame:SetScript("OnShow", function()
        Options.ShowPage(Options.selectedPage)
    end)
    frame:SetScript("OnHide", function()
        if ns.Preview then ns.Preview:Stop() end
    end)
    frame:Hide()

    if UISpecialFrames then
        UISpecialFrames[#UISpecialFrames + 1] = "SalveSettingsFrame"
    end
    return frame
end

function Options.CreateLauncher()
    if Options.rootCategory then return end
    local panel = CreateFrame("Frame", "SalveOptionsLauncher")
    panel.name = "Salve"

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Salve")

    local open = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    open:SetSize(210, 28)
    open:SetPoint("TOPLEFT", 16, -54)
    open:SetText("Open Salve settings")
    open:SetScript("OnClick", function() ns.OpenOptions() end)

    local build = panel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    build:SetPoint("TOPLEFT", 16, -98)
    build:SetText("Version " .. tostring(ns.VERSION or "unknown")
        .. "  •  " .. tostring(ns.REVISION or "unknown"))

    if Settings and Settings.RegisterCanvasLayoutCategory then
        local category = Settings.RegisterCanvasLayoutCategory(panel, "Salve", "Salve")
        category.ID = category.ID or "Salve"
        Settings.RegisterAddOnCategory(category)
        Options.rootCategory = category
        Options.rootID = category:GetID() or category.ID
    elseif InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(panel)
        Options.rootCategory = panel
    end
end

function ns.OpenOptions(pageName)
    if not ns.Options.window then
        ns.Print("settings are not ready yet")
        return
    end
    if SettingsPanel and SettingsPanel.IsShown and SettingsPanel:IsShown() then
        if HideUIPanel then HideUIPanel(SettingsPanel) else SettingsPanel:Hide() end
    end
    ns.Options.ShowPage(pageName)
    ns.Options.window:Show()
    ns.Options.window:Raise()
end
