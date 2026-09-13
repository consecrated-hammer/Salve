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
local THEME = {
    outer = { 0.043, 0.051, 0.063, 0.98 },
    rail = { 0.071, 0.082, 0.102, 1 },
    content = { 0.086, 0.098, 0.118, 1 },
    raised = { 0.110, 0.125, 0.153, 1 },
    edge = { 0.169, 0.192, 0.227, 1 },
    menuEdge = { 0.337, 0.416, 0.522, 1 },
    menuActive = { 0.075, 0.125, 0.190, 1 },
    accent = { 0.298, 0.604, 0.478, 1 },
    selected = { 0.247, 0.604, 0.925, 1 },
    muted = { 0.553, 0.584, 0.639, 1 },
    section = { 0.82, 0.85, 0.90, 1 },
    danger = { 0.788, 0.337, 0.306, 1 },
}

Options.theme = THEME

-- ── Widgets ────────────────────────────────────────────────────────────────

-- Hints live in a tooltip rather than as a second line of grey text under every
-- control: at this many settings the inline version turns the page into a wall.
local function attachHint(control, title, hint)
    if not hint then return end
    control.salveHintTitle = title
    control.salveHint = hint
    control:HookScript("OnEnter", function(self)
        -- Settings hints must not cover a page's live preview. Cursor anchoring
        -- keeps the explanation beside the option the player is inspecting.
        GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
        -- Some labels change with the current layout. Resolve them at hover
        -- time: Retail's tooltip rejects a function passed straight to SetText.
        local titleText = self.salveHintTitle
        if type(titleText) == "function" then titleText = titleText() end
        GameTooltip:SetText(type(titleText) == "string" and titleText or "Salve",
            unpack(THEME.accent))
        GameTooltip:AddLine(self.salveHint, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    control:HookScript("OnLeave", function(self)
        if GameTooltip:IsOwned(self) then GameTooltip:Hide() end
    end)
end

Options.AttachHint = attachHint

-- Retail changed the colour-picker entry point, so keep that compatibility
-- work in one place. Callers supply their saved colour and receive a plain
-- { r, g, b, a } table whenever the player changes or cancels it.
function Options.ShowColourPicker(initial, onChange)
    if not ColorPickerFrame then return end
    initial = initial or {}
    local colour = {
        r = tonumber(initial.r) or 1,
        g = tonumber(initial.g) or 1,
        b = tonumber(initial.b) or 1,
        a = tonumber(initial.a) or 1,
    }
    local function applyFromPicker()
        local r, g, b = ColorPickerFrame:GetColorRGB()
        onChange({ r = r, g = g, b = b, a = ColorPickerFrame:GetColorAlpha() })
    end
    local function restore(previous)
        previous = previous or {}
        onChange({
            r = previous.r or colour.r,
            g = previous.g or colour.g,
            b = previous.b or colour.b,
            a = previous.opacity or previous.a or colour.a,
        })
    end
    if ColorPickerFrame.SetupColorPickerAndShow then
        ColorPickerFrame:SetupColorPickerAndShow({
            r = colour.r, g = colour.g, b = colour.b, opacity = colour.a,
            hasOpacity = true, swatchFunc = applyFromPicker,
            opacityFunc = applyFromPicker, cancelFunc = restore,
        })
        return
    end
    ColorPickerFrame.func = applyFromPicker
    ColorPickerFrame.opacityFunc = applyFromPicker
    ColorPickerFrame.cancelFunc = restore
    ColorPickerFrame.hasOpacity = true
    ColorPickerFrame.opacity = colour.a
    ColorPickerFrame:SetColorRGB(colour.r, colour.g, colour.b)
    ColorPickerFrame:Show()
end

local function attachTitleHint(parent, fontString, title, hint)
    if not hint then return end
    local region = CreateFrame("Frame", nil, parent)
    region:SetPoint("TOPLEFT", fontString, "TOPLEFT", -2, 2)
    region:SetPoint("BOTTOMRIGHT", fontString, "BOTTOMRIGHT", 2, -2)
    region:EnableMouse(true)
    attachHint(region, title, hint)
    return region
end

Options.AttachTitleHint = attachTitleHint

local function refreshAll(panel)
    if panel.salveRefreshAll then panel.salveRefreshAll() end
end

function Options.CheckButton(parent)
    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetSize(18, 18)
    btn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    btn:SetBackdropColor(unpack(THEME.rail))
    btn:SetBackdropBorderColor(unpack(THEME.edge))
    btn.check = btn:CreateTexture(nil, "ARTWORK")
    btn.check:SetPoint("TOPLEFT", 2, -2)
    btn.check:SetPoint("BOTTOMRIGHT", -2, 2)
    btn.check:SetColorTexture(unpack(THEME.selected))
    btn.Text = btn:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    btn.Text:SetPoint("LEFT", btn, "RIGHT", 8, 0)
    btn.Text:SetJustifyH("LEFT")
    btn.SetChecked = function(self, checked)
        self.checked = checked and true or false
        self.check:SetShown(self.checked)
        if self.SetBackdropBorderColor then
            self:SetBackdropBorderColor(unpack(self.checked and THEME.selected or THEME.edge))
        end
    end
    btn.GetChecked = function(self) return self.checked end
    btn:SetChecked(false)
    return btn
end

function Options.Row(parent, y, height, title, hint, width)
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(width or 540, height or 38)
    row:SetPoint("TOPLEFT", PAD_L, y)
    if title ~= nil then
        row.Title = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        row.Title:SetPoint("LEFT", 0, 0)
        row.Title:SetTextColor(1, 1, 1)
        row.salveRefreshTitle = function()
            local text = type(title) == "function" and title() or title
            -- Retail FontString:SetText rejects nil. Several labels intentionally
            -- change with grid direction, so resolve them before passing text to
            -- the widget rather than handing it the label function itself.
            row.Title:SetText(text or "")
        end
        row.salveRefreshTitle()
    end
    row:EnableMouse(true)
    attachHint(row, title or "Salve", hint)
    return row
end

-- Rows stay bare, but buttons retain a quiet surface so actions are visibly
-- clickable without turning every setting into a container card.
function Options.Button(parent, width, height, variant)
    local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
    button:SetSize(width or 160, height or 22)
    button:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    button:SetBackdropColor(unpack(THEME.raised))
    if variant == "danger" then
        button:SetBackdropBorderColor(unpack(THEME.danger))
    elseif variant == "primary" then
        button:SetBackdropBorderColor(unpack(THEME.accent))
    else
        button:SetBackdropBorderColor(unpack(THEME.edge))
    end
    button.Text = button:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    button.Text:SetAllPoints()
    button.Text:SetJustifyH("CENTER")
    button.Text:SetTextColor(variant == "danger" and THEME.danger[1] or 1,
        variant == "danger" and THEME.danger[2] or 1,
        variant == "danger" and THEME.danger[3] or 1)
    button.SetText = function(self, text)
        self.Text:SetText(text)
        self.text = text
    end
    return button
end

-- A select is the exception to the bare-control rule: it is a value field,
-- so a subtle 1px boundary makes its current value readable at a glance.
function Options.SelectButton(parent, width, height)
    local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
    button:SetSize(width or 160, height or 30)
    button:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    button:SetBackdropColor(unpack(THEME.rail))
    button:SetBackdropBorderColor(unpack(THEME.edge))
    button.Text = button:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    button.Text:SetAllPoints()
    button.Text:SetJustifyH("CENTER")
    button.Text:SetTextColor(1, 1, 1)
    button.SetText = function(self, text)
        self.Text:SetText(text)
        self.text = text
    end
    return button
end

-- Returns the control and the y for the next row, so pages read as a straight
-- run of assignments instead of tracking offsets by hand.
function Options.Check(panel, label, hint, y, get, set, width)
    local row = Options.Row(panel, y, 28, nil, hint, width)
    local btn = Options.CheckButton(row)
    btn:SetPoint("LEFT", 12, 0)
    row.salveCheckbox = btn
    btn.Text:SetText(label)
    btn.Text:SetTextColor(1, 1, 1)
    btn:SetChecked(get() and true or false)
    local function toggle(self)
        self:SetChecked(not self:GetChecked())
        set(self:GetChecked() and true or false)
        refreshAll(panel)
    end
    btn:SetScript("OnClick", toggle)
    row:SetScript("OnMouseUp", function(_, button)
        if button == "LeftButton" then toggle(btn) end
    end)

    panel.salveRefresh[#panel.salveRefresh + 1] = function()
        btn:SetChecked(get() and true or false)
    end

    return row, y - 32
end

function Options.Slider(panel, label, hint, y, minV, maxV, step, get, set, fmt, width)
    local row = Options.Row(panel, y, 28, label, hint, width)
    local sliderWidth = math.max(80, math.min(180, (width or 540) - 150))
    local s = CreateFrame("Slider", nil, row)
    s:SetOrientation("HORIZONTAL")
    s:SetSize(sliderWidth, 16)
    s:SetPoint("LEFT", row, "LEFT", 150, 0)
    s:SetMinMaxValues(minV, maxV)
    s:SetValueStep(step)
    s:SetObeyStepOnDrag(true)
    local track = s:CreateTexture(nil, "BACKGROUND")
    track:SetPoint("LEFT", 4, 0)
    track:SetPoint("RIGHT", -4, 0)
    track:SetHeight(4)
    track:SetColorTexture(unpack(THEME.rail))
    local fill = s:CreateTexture(nil, "ARTWORK")
    fill:SetPoint("LEFT", 4, 0)
    fill:SetHeight(4)
    fill:SetColorTexture(unpack(THEME.selected))
    local thumb = s:CreateTexture(nil, "OVERLAY")
    thumb:SetSize(10, 10)
    thumb:SetColorTexture(unpack(THEME.selected))
    if s.SetThumbTexture then s:SetThumbTexture(thumb) end

    local value = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    value:SetPoint("LEFT", s, "RIGHT", 14, 0)
    value:SetTextColor(unpack(THEME.muted))

    local function labelText()
        return type(label) == "function" and label() or label
    end

    local titleHint
    local function render(v)
        local shownLabel = labelText()
        if row.salveRefreshTitle then row.salveRefreshTitle() end
        value:SetText(fmt and fmt(v) or tostring(v))
        s.salveHintTitle = shownLabel
        local ratio = (v - minV) / math.max(1, maxV - minV)
        fill:SetWidth(math.max(0, (sliderWidth - 8) * ratio))
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
    attachHint(s, labelText(), hint)

    panel.salveRefresh[#panel.salveRefresh + 1] = function()
        s:SetValue(get())
        render(get())
    end

    return row, y - 34
end

-- A cycling button rather than a dropdown: the dropdown API churned hard in
-- 12.0, and a three-option control does not need a menu to be usable.
function Options.Cycle(panel, label, hint, y, values, labels, get, set)
    local row = Options.Row(panel, y, 28, label, hint)
    local btn = Options.Button(row, 160, 22)
    btn:SetPoint("RIGHT", row, "RIGHT", -8, 0)

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
    attachHint(btn, label, hint)

    panel.salveRefresh[#panel.salveRefresh + 1] = render
    return row, y - 34
end

-- Two short choices under one heading. Alignment reads much faster as a pair:
-- Horizontal and Vertical belong together, not as two full-width sections.
function Options.CyclePair(panel, heading, y, left, right)
    local groupTitle = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    groupTitle:SetPoint("TOPLEFT", PAD_L, y)
    groupTitle:SetText(heading)
    groupTitle:SetTextColor(unpack(THEME.accent))

    local function makeChoice(x, spec)
        local title = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        title:SetPoint("TOPLEFT", x, y - 20)
        title:SetText(spec.label)

        local btn = Options.SelectButton(panel, 150, 20)
        btn:SetPoint("TOPLEFT", x, y - 35)
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
    return leftButton, rightButton, y - 72
end

-- Two compact menu-backed selects under one heading. Each closed control is a
-- complete field in its own right: label, then select. Do not wrap it in a
-- second card; that double surface makes a two-column row feel cramped.
function Options.DropdownPair(panel, heading, y, left, right)
    local groupTitle = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    groupTitle:SetPoint("TOPLEFT", PAD_L, y)
    groupTitle:SetText(heading)
    groupTitle:SetTextColor(unpack(THEME.accent))

    local function makeChoice(x, spec)
        local title = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        title:SetPoint("TOPLEFT", x, y - 20)
        title:SetText(spec.label)
        title:SetTextColor(unpack(THEME.muted))

        local btn = Options.SelectButton(panel, 150, 30)
        btn:SetPoint("TOPLEFT", x, y - 35)
        btn.Text:ClearAllPoints()
        btn.Text:SetPoint("LEFT", 10, 0)
        btn.Text:SetPoint("RIGHT", -26, 0)
        btn.Text:SetJustifyH("LEFT")
        btn.salveTitle = title
        -- Two texture strokes, rather than a unicode glyph, render a reliable
        -- chevron in every WoW font and make this read as a dropdown at a glance.
        local arrowLeft = btn:CreateTexture(nil, "OVERLAY")
        arrowLeft:SetSize(7, 1)
        arrowLeft:SetPoint("RIGHT", -13, 2)
        arrowLeft:SetColorTexture(unpack(THEME.muted))
        if arrowLeft.SetRotation then arrowLeft:SetRotation(-0.75) end
        local arrowRight = btn:CreateTexture(nil, "OVERLAY")
        arrowRight:SetSize(7, 1)
        arrowRight:SetPoint("RIGHT", -8, 2)
        arrowRight:SetColorTexture(unpack(THEME.muted))
        if arrowRight.SetRotation then arrowRight:SetRotation(0.75) end

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
            btn:SetText(text)
        end

        local function select(value)
            spec.set(value)
            render()
            refreshAll(panel)
        end
        local menu
        local function ensureMenu()
            if menu then return end
            menu = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
            menu:SetFrameStrata("FULLSCREEN_DIALOG")
            menu:SetFrameLevel(200)
            menu:SetClampedToScreen(true)
            menu:SetBackdrop({
                bgFile = "Interface\\Buttons\\WHITE8X8",
                edgeFile = "Interface\\Buttons\\WHITE8X8",
                edgeSize = 1,
            })
            menu:SetBackdropColor(0.020, 0.027, 0.039, 1)
            menu:SetBackdropBorderColor(unpack(THEME.menuEdge))
            local values, labels = choices()
            menu:SetSize(144, #values * 26 + 10)
            local items = {}
            local function paint(item, active, hovered)
                item:SetBackdropColor(unpack((active or hovered)
                    and THEME.menuActive or THEME.rail))
                item:SetBackdropBorderColor(0, 0, 0, 0)
                item.activeBar:SetShown(active)
                item.label:SetTextColor(active and 1 or THEME.muted[1],
                    active and 1 or THEME.muted[2], active and 1 or THEME.muted[3])
            end
            local function refreshItems()
                for _, item in ipairs(items) do
                    paint(item, spec.get() == item.value, false)
                end
            end
            for i, value in ipairs(values) do
                local item = CreateFrame("Button", nil, menu, "BackdropTemplate")
                item:SetSize(134, 24)
                item:SetPoint("TOPLEFT", 5, -5 - (i - 1) * 26)
                item:SetBackdrop({
                    bgFile = "Interface\\Buttons\\WHITE8X8",
                    edgeFile = "Interface\\Buttons\\WHITE8X8",
                    edgeSize = 1,
                })
                item.activeBar = item:CreateTexture(nil, "ARTWORK")
                item.activeBar:SetPoint("TOPLEFT")
                item.activeBar:SetPoint("BOTTOMLEFT")
                item.activeBar:SetWidth(3)
                item.activeBar:SetColorTexture(unpack(THEME.selected))
                item.label = item:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
                item.label:SetPoint("LEFT", 10, 0)
                item.label:SetPoint("RIGHT", -8, 0)
                item.label:SetJustifyH("LEFT")
                item.label:SetText(labels[i])
                item.value = value
                item:HookScript("OnEnter", function(self)
                    paint(self, spec.get() == self.value, true)
                end)
                item:HookScript("OnLeave", function(self)
                    paint(self, spec.get() == self.value, false)
                end)
                item:SetScript("OnClick", function()
                    select(value)
                    menu:Hide()
                end)
                items[#items + 1] = item
            end
            menu.refreshItems = refreshItems
            menu:SetScript("OnUpdate", function(self)
                if not self:IsMouseOver() and not btn:IsMouseOver()
                    and IsMouseButtonDown and IsMouseButtonDown("LeftButton") then
                    self:Hide()
                end
            end)
            menu:Hide()
        end
        btn:SetScript("OnClick", function(self)
            ensureMenu()
            if menu:IsShown() then
                menu:Hide()
                return
            end
            menu:ClearAllPoints()
            menu:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 0, -5)
            menu:refreshItems()
            menu:Show()
        end)

        attachHint(btn, heading .. " — " .. spec.label, spec.hint)
        attachTitleHint(panel, title, heading .. " — " .. spec.label, spec.hint)
        panel.salveRefresh[#panel.salveRefresh + 1] = render
        render()
        return btn
    end

    local leftButton = makeChoice(PAD_L, left)
    local rightButton = makeChoice(206, right)
    return leftButton, rightButton, y - 76
end

-- A one-field counterpart to DropdownPair. The full-screen click catcher is
-- deliberate: a popup must close when the player clicks elsewhere, without
-- relying on mouse-state polling that misses some UI clicks.
function Options.Dropdown(panel, label, hint, y, values, labels, get, set, width, offset)
    local row = Options.Row(panel, y, 30, label, hint, width)
    local buttonWidth = 156
    local button = Options.SelectButton(row, buttonWidth, 30)
    button:SetPoint("LEFT", row, "LEFT", offset or 80, 0)
    button.Text:ClearAllPoints()
    button.Text:SetPoint("LEFT", 10, 0)
    button.Text:SetPoint("RIGHT", -26, 0)
    button.Text:SetJustifyH("LEFT")
    button.salveDropdown = true

    for _, spec in ipairs({ { -13, 2, -0.75 }, { -8, 2, 0.75 } }) do
        local arrow = button:CreateTexture(nil, "OVERLAY")
        arrow:SetSize(7, 1)
        arrow:SetPoint("RIGHT", spec[1], spec[2])
        arrow:SetColorTexture(unpack(THEME.muted))
        if arrow.SetRotation then arrow:SetRotation(spec[3]) end
    end

    local function render()
        local current = get()
        for index, value in ipairs(values) do
            if current == value then button:SetText(labels[index]); return end
        end
        button:SetText(labels[1])
    end

    local menu, dismiss
    local function createMenu()
        if menu then return end
        dismiss = CreateFrame("Button", nil, UIParent)
        dismiss:SetFrameStrata("FULLSCREEN_DIALOG")
        dismiss:SetFrameLevel(199)
        dismiss:SetAllPoints(UIParent)
        dismiss:EnableMouse(true)
        menu = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
        menu:SetFrameStrata("FULLSCREEN_DIALOG")
        menu:SetFrameLevel(200)
        menu:SetClampedToScreen(true)
        menu:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
        })
        menu:SetBackdropColor(0.020, 0.027, 0.039, 1)
        menu:SetBackdropBorderColor(unpack(THEME.menuEdge))
        menu:SetSize(buttonWidth, #values * 26 + 10)
        local items = {}
        local function paint(item, active, hovered)
            item:SetBackdropColor(unpack((active or hovered)
                and THEME.menuActive or THEME.rail))
            item:SetBackdropBorderColor(0, 0, 0, 0)
            item.activeBar:SetShown(active)
            item.label:SetTextColor(active and 1 or THEME.muted[1],
                active and 1 or THEME.muted[2], active and 1 or THEME.muted[3])
        end
        local function refreshItems()
            for _, item in ipairs(items) do paint(item, get() == item.value, false) end
        end
        for index, value in ipairs(values) do
            local item = CreateFrame("Button", nil, menu, "BackdropTemplate")
            item:SetSize(buttonWidth - 10, 24)
            item:SetPoint("TOPLEFT", 5, -5 - (index - 1) * 26)
            item:SetBackdrop({
                bgFile = "Interface\\Buttons\\WHITE8X8",
                edgeFile = "Interface\\Buttons\\WHITE8X8",
                edgeSize = 1,
            })
            item.activeBar = item:CreateTexture(nil, "ARTWORK")
            item.activeBar:SetPoint("TOPLEFT")
            item.activeBar:SetPoint("BOTTOMLEFT")
            item.activeBar:SetWidth(3)
            item.activeBar:SetColorTexture(unpack(THEME.selected))
            item.label = item:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
            item.label:SetPoint("LEFT", 10, 0)
            item.label:SetPoint("RIGHT", -8, 0)
            item.label:SetJustifyH("LEFT")
            item.label:SetText(labels[index])
            item.value = value
            item:HookScript("OnEnter", function(self) paint(self, get() == self.value, true) end)
            item:HookScript("OnLeave", function(self) paint(self, get() == self.value, false) end)
            item:SetScript("OnClick", function()
                set(value)
                render()
                refreshAll(panel)
                menu:Hide()
            end)
            items[#items + 1] = item
        end
        menu:SetScript("OnShow", refreshItems)
        menu:SetScript("OnHide", function() dismiss:Hide() end)
        dismiss:SetScript("OnClick", function() menu:Hide() end)
        menu:Hide()
    end
    button:SetScript("OnClick", function(self)
        createMenu()
        if menu:IsShown() then menu:Hide(); return end
        menu:ClearAllPoints()
        menu:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 0, -5)
        dismiss:Show()
        menu:Show()
    end)
    attachHint(button, label, hint)
    panel.salveRefresh[#panel.salveRefresh + 1] = render
    render()
    return row, y - 34
end

-- A dropdown whose choices can change after the page is built. Chat windows and
-- known spells are session state, so cycling a button is both hard to discover
-- and too easy to overshoot.
function Options.DynamicDropdown(panel, label, hint, y, optionsFn, get, set)
    local row = Options.Row(panel, y, 28, label, hint)
    local btn = Options.SelectButton(row, 190, 22)
    btn:SetPoint("RIGHT", row, "RIGHT", -8, 0)
    btn.Text:ClearAllPoints()
    btn.Text:SetPoint("LEFT", 10, 0)
    btn.Text:SetPoint("RIGHT", -26, 0)
    btn.Text:SetJustifyH("LEFT")

    for _, spec in ipairs({ { -13, 2, -0.75 }, { -8, 2, 0.75 } }) do
        local arrow = btn:CreateTexture(nil, "OVERLAY")
        arrow:SetSize(7, 1)
        arrow:SetPoint("RIGHT", spec[1], spec[2])
        arrow:SetColorTexture(unpack(THEME.muted))
        if arrow.SetRotation then arrow:SetRotation(spec[3]) end
    end

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

    local menu, dismiss, items = nil, nil, {}
    local function ensureMenu()
        if menu then return end
        dismiss = CreateFrame("Button", nil, UIParent)
        dismiss:SetFrameStrata("FULLSCREEN_DIALOG")
        dismiss:SetFrameLevel(199)
        dismiss:SetAllPoints(UIParent)
        dismiss:EnableMouse(true)
        menu = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
        menu:SetFrameStrata("FULLSCREEN_DIALOG")
        menu:SetFrameLevel(200)
        menu:SetClampedToScreen(true)
        menu:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
        })
        menu:SetBackdropColor(0.020, 0.027, 0.039, 1)
        menu:SetBackdropBorderColor(unpack(THEME.menuEdge))
        menu:SetScript("OnHide", function() dismiss:Hide() end)
        dismiss:SetScript("OnClick", function() menu:Hide() end)
    end

    local function refreshMenu()
        local values, labels = optionsFn()
        menu:SetSize(190, math.max(1, #values) * 26 + 10)
        for index, value in ipairs(values) do
            local item = items[index]
            if not item then
                item = CreateFrame("Button", nil, menu, "BackdropTemplate")
                item:SetSize(180, 24)
                item:SetPoint("TOPLEFT", 5, -5 - (index - 1) * 26)
                item:SetBackdrop({
                    bgFile = "Interface\\Buttons\\WHITE8X8",
                    edgeFile = "Interface\\Buttons\\WHITE8X8",
                    edgeSize = 1,
                })
                item.activeBar = item:CreateTexture(nil, "ARTWORK")
                item.activeBar:SetPoint("TOPLEFT")
                item.activeBar:SetPoint("BOTTOMLEFT")
                item.activeBar:SetWidth(3)
                item.activeBar:SetColorTexture(unpack(THEME.selected))
                item.label = item:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
                item.label:SetPoint("LEFT", 10, 0)
                item.label:SetPoint("RIGHT", -8, 0)
                item.label:SetJustifyH("LEFT")
                item:SetScript("OnClick", function(self)
                    set(self.value)
                    render()
                    refreshAll(panel)
                    menu:Hide()
                end)
                items[index] = item
            end
            item.value = value
            item.label:SetText(labels[index] or "—")
            item.activeBar:SetShown(get() == value)
            item:SetShown(true)
        end
        for index = #values + 1, #items do items[index]:Hide() end
    end

    btn:SetScript("OnClick", function()
        ensureMenu()
        if menu:IsShown() then menu:Hide(); return end
        refreshMenu()
        menu:ClearAllPoints()
        menu:SetPoint("TOPLEFT", btn, "BOTTOMLEFT", 0, -5)
        dismiss:Show()
        menu:Show()
    end)

    attachHint(btn, label, hint)

    panel.salveRefresh[#panel.salveRefresh + 1] = render
    render()

    return row, y - 34
end

-- A compact custom menu that can mix mutually exclusive base modes with
-- combinable conditions. Visibility is the one place this is needed; keeping
-- it in Salve's own surfaces avoids one remaining patch of Blizzard chrome.
function Options.MultiSelect(panel, label, hint, y, spec, width)
    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    title:SetPoint("TOPLEFT", PAD_L, y)
    title:SetText(label)
    title:SetTextColor(unpack(THEME.muted))
    local btn = Options.SelectButton(panel, width or 240, 30)
    btn:SetPoint("TOPLEFT", PAD_L, y - 15)
    btn.Text:ClearAllPoints()
    btn.Text:SetPoint("LEFT", 10, 0)
    btn.Text:SetPoint("RIGHT", -26, 0)
    btn.Text:SetJustifyH("LEFT")
    local arrowLeft = btn:CreateTexture(nil, "OVERLAY")
    arrowLeft:SetSize(7, 1)
    arrowLeft:SetPoint("RIGHT", -13, 2)
    arrowLeft:SetColorTexture(unpack(THEME.muted))
    if arrowLeft.SetRotation then arrowLeft:SetRotation(-0.75) end
    local arrowRight = btn:CreateTexture(nil, "OVERLAY")
    arrowRight:SetSize(7, 1)
    arrowRight:SetPoint("RIGHT", -8, 2)
    arrowRight:SetColorTexture(unpack(THEME.muted))
    if arrowRight.SetRotation then arrowRight:SetRotation(0.75) end

    local function render()
        local text = spec.summary()
        btn:SetText(text)
    end

    local menu
    local function ensureMenu()
        if menu then return end
        menu = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
        menu:SetFrameStrata("FULLSCREEN_DIALOG")
        menu:SetFrameLevel(200)
        menu:SetClampedToScreen(true)
        menu:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
        })
        menu:SetBackdropColor(0.020, 0.027, 0.039, 1)
        menu:SetBackdropBorderColor(unpack(THEME.menuEdge))
        local menuWidth = btn:GetWidth()
        local menuHeight = 10
        for _, item in ipairs(spec.items) do
            if item.heading then
                menuHeight = menuHeight + 24
            else
                menuHeight = menuHeight + 28
            end
        end
        menu:SetSize(menuWidth, menuHeight)
        local cursorY = -5
        local controls = {}
        for _, item in ipairs(spec.items) do
            if item.heading then
                local heading = menu:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
                heading:SetPoint("TOPLEFT", 10, cursorY - 3)
                heading:SetText(item.label)
                heading:SetTextColor(unpack(THEME.muted))
                cursorY = cursorY - 24
            else
                local choice = CreateFrame("Button", nil, menu, "BackdropTemplate")
                choice:SetSize(menuWidth - 10, 26)
                choice:SetPoint("TOPLEFT", 5, cursorY)
                choice:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
                choice:SetBackdropColor(unpack(THEME.rail))
                choice.check = Options.CheckButton(choice)
                choice.check:SetPoint("LEFT", 8, 0)
                choice.check:SetSize(item.radio and 14 or 18, item.radio and 14 or 18)
                choice.check.check:SetPoint("TOPLEFT", 2, -2)
                choice.check.check:SetPoint("BOTTOMRIGHT", -2, 2)
                choice.check.Text:SetText(item.label)
                choice.check.Text:SetTextColor(1, 1, 1)
                choice.item = item
                choice:SetScript("OnClick", function(self)
                    if self.item.radio then self.item.set(true)
                    else self.item.set(not self.item.get()) end
                    refreshAll(panel)
                    render()
                    for _, control in ipairs(controls) do
                        control.check:SetChecked(control.item.get() and true or false)
                    end
                end)
                choice:HookScript("OnEnter", function(self)
                    self:SetBackdropColor(unpack(THEME.menuActive))
                end)
                choice:HookScript("OnLeave", function(self)
                    self:SetBackdropColor(unpack(THEME.rail))
                end)
                controls[#controls + 1] = choice
                cursorY = cursorY - 28
            end
        end
        menu.refresh = function()
            for _, control in ipairs(controls) do
                control.check:SetChecked(control.item.get() and true or false)
            end
        end
        menu:SetScript("OnUpdate", function(self)
            if not self:IsMouseOver() and not btn:IsMouseOver()
                and IsMouseButtonDown and IsMouseButtonDown("LeftButton") then
                self:Hide()
            end
        end)
        menu:Hide()
    end
    btn:SetScript("OnClick", function(self)
        ensureMenu()
        if menu:IsShown() then menu:Hide() return end
        menu:ClearAllPoints()
        menu:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 0, -5)
        menu:refresh()
        menu:Show()
    end)

    attachHint(btn, label, hint)
    attachTitleHint(panel, title, label, hint)

    panel.salveRefresh[#panel.salveRefresh + 1] = render
    render()

    return btn, y - 54
end

function Options.Header(panel, text, y)
    local fs = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    fs:SetPoint("TOPLEFT", PAD_L, y)
    fs:SetText(text)
    fs:SetTextColor(unpack(THEME.section))

    local divider = panel:CreateTexture(nil, "ARTWORK")
    divider:SetHeight(1)
    divider:SetPoint("LEFT", fs, "RIGHT", 10, 0)
    divider:SetPoint("RIGHT", panel.salveHeaderOwner or panel, "RIGHT", -20, 0)
    divider:SetColorTexture(unpack(THEME.edge))
    fs.salveDivider = divider

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

function Options.PageReset(panel, y, reset, label)
    local button = Options.Button(panel, 180, 22, "danger")
    button:SetPoint("TOPLEFT", 16, y - 4)
    button:SetText(label or "Reset page")
    attachHint(button, label or "Reset page", "Restore settings on this page.")
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

-- ADDON_LOADED is the normal construction point, after saved variables exist.
-- If another addon or the client interrupts that pass, retry once when the
-- player explicitly opens Salve rather than leaving the slash command as a
-- dead end. Keep the error so it can be reported without requiring Lua errors
-- to be enabled just to learn why the window did not appear.
function Options.EnsureBuilt()
    if Options.window then return true end
    local ok, err = pcall(Options.BuildAll)
    if ok and Options.window then
        Options.buildError = nil
        return true
    end
    Options.buildError = tostring(err or "settings window was not created")
    return false
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
    title:SetTextColor(1, 1, 1)

    local contentTop = -48
    if spec.description then
        local description = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        description:SetPoint("TOPLEFT", PAD_L, -42)
        description:SetWidth(540)
        description:SetJustifyH("LEFT")
        description:SetTextColor(unpack(THEME.muted))
        description:SetText(spec.description)
        contentTop = -68
    end

    local scroll = CreateFrame("ScrollFrame", nil, panel)
    local scrollbar = CreateFrame("Slider", nil, panel)
    scrollbar:SetOrientation("VERTICAL")
    scrollbar:SetWidth(6)
    local scrollTrack = scrollbar:CreateTexture(nil, "BACKGROUND")
    scrollTrack:SetAllPoints()
    scrollTrack:SetColorTexture(unpack(THEME.rail))
    local scrollThumb = scrollbar:CreateTexture(nil, "ARTWORK")
    scrollThumb:SetSize(6, 28)
    scrollThumb:SetColorTexture(unpack(THEME.selected))
    if scrollbar.SetThumbTexture then scrollbar:SetThumbTexture(scrollThumb) end
    local function setScrollBounds(top)
        scroll:ClearAllPoints()
        scroll:SetPoint("TOPLEFT", 0, top)
        scroll:SetPoint("BOTTOMRIGHT", -16, 10)
        scrollbar:ClearAllPoints()
        scrollbar:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -7, top)
        scrollbar:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -7, 10)
    end
    setScrollBounds(contentTop)

    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(560, 1)
    scroll:SetScrollChild(content)
    content.salveOwner = panel
    content.salveHeaderOwner = panel
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(self, delta)
        local range = self:GetVerticalScrollRange() or 0
        local nextValue = self:GetVerticalScroll() - delta * 40
        self:SetVerticalScroll(math.max(0, math.min(range, nextValue)))
    end)
    local updatingScroll = false
    local function updateScrollbar()
        local range = scroll:GetVerticalScrollRange() or 0
        scrollbar:Show()
        local maxRange = math.max(1, range)
        scrollbar:SetMinMaxValues(0, maxRange)
        updatingScroll = true
        scrollbar:SetValue(math.min(maxRange, scroll:GetVerticalScroll() or 0))
        updatingScroll = false
    end
    scroll:SetScript("OnVerticalScroll", updateScrollbar)
    scrollbar:SetScript("OnValueChanged", function(_, value)
        if updatingScroll then return end
        local range = scroll:GetVerticalScrollRange() or 0
        scroll:SetVerticalScroll(math.max(0, math.min(range, value)))
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
        updateScrollbar()
    end
    content.salveCreatePinned = function(height, width)
        height = math.max(1, height or 1)
        width = math.max(1, width or 560)
        setScrollBounds(contentTop - height)

        local pinned = CreateFrame("Frame", nil, panel)
        pinned:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, contentTop)
        pinned:SetSize(width, height)
        pinned.salveRefresh = panel.salveRefresh
        pinned.salveRefreshAll = panel.salveRefreshAll
        return pinned
    end

    local bottomY = build(content, -8)
    content.salveSetBottom(bottomY or -600)
    content:HookScript("OnSizeChanged", updateScrollbar)

    -- Pull saved values back in on every page visit. Values may also change
    -- through slash commands, the minimap menu or another page.
    panel:SetScript("OnShow", function(self)
        self.salveRefreshAll()
        updateScrollbar()
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
        if button then
            local active = pageName == name
            button:SetEnabled(not active)
            button.activeBar:SetShown(active)
            button.activeBg:SetShown(active)
            button.Text:SetTextColor(active and 1 or THEME.muted[1],
                active and 1 or THEME.muted[2], active and 1 or THEME.muted[3])
        end
    end
end

function Options.CreateWindow()
    if Options.window then return Options.window end

    local frame = CreateFrame("Frame", "SalveSettingsFrame", UIParent,
        "BackdropTemplate")
    frame:SetSize(920, 760)
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    frame:SetBackdropColor(unpack(THEME.outer))
    frame:SetBackdropBorderColor(unpack(THEME.edge))

    local saved = ns.db.settingsPoint or { "CENTER", "CENTER", 0, 0 }
    frame:SetPoint(saved[1], UIParent, saved[2], saved[3], saved[4])

    local titleBar = CreateFrame("Button", nil, frame)
    titleBar:SetPoint("TOPLEFT", 8, -6)
    titleBar:SetPoint("TOPRIGHT", -38, -6)
    titleBar:SetHeight(36)
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
    icon:SetSize(26, 26)
    icon:SetPoint("LEFT", 8, 0)
    icon:SetTexture("Interface\\AddOns\\Salve\\Textures\\SalveTransparent")
    local title = titleBar:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("LEFT", icon, "RIGHT", 8, 0)
    title:SetText("Salve")

    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -5, -5)
    close:SetScript("OnClick", function() frame:Hide() end)
    local version = titleBar:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    version:SetPoint("RIGHT", close, "LEFT", -8, 0)
    version:SetText(tostring(ns.VERSION or ""))
    version:SetTextColor(unpack(THEME.muted))

    local divider = frame:CreateTexture(nil, "ARTWORK")
    -- BackdropTemplate is required in Retail before SetBackdrop is available.
    -- Without it, settings construction stops here after drawing only the
    -- outer shell and title bar.
    local rail = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    rail:SetPoint("TOPLEFT", 1, -42)
    rail:SetPoint("BOTTOMLEFT", 1, 1)
    rail:SetWidth(178)
    rail:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
    rail:SetBackdropColor(unpack(THEME.rail))

    divider:SetColorTexture(unpack(THEME.edge))
    divider:SetPoint("TOPLEFT", 179, -42)
    divider:SetPoint("BOTTOMLEFT", 179, 1)
    divider:SetWidth(1)

    local host = CreateFrame("Frame", nil, frame)
    host:SetPoint("TOPLEFT", 180, -42)
    host:SetPoint("BOTTOMRIGHT", -10, 10)
    local contentBg = host:CreateTexture(nil, "BACKGROUND")
    contentBg:SetAllPoints()
    contentBg:SetColorTexture(unpack(THEME.content))

    Options.window = frame
    Options.host = host
    Options.pages = {}
    Options.pageButtons = {}

    local railY = -56
    local previousGroup
    -- Finish the navigation before constructing any page. A page may use a
    -- template Blizzard has changed; that must not turn the entire window into
    -- a featureless black box.
    for _, spec in ipairs(Options.queue) do
        local group = spec.group or "REFERENCE"
        if group ~= previousGroup then
            if previousGroup then
                local groupDivider = rail:CreateTexture(nil, "ARTWORK")
                groupDivider:SetPoint("TOPLEFT", 16, railY - 8)
                groupDivider:SetPoint("TOPRIGHT", -16, railY - 8)
                groupDivider:SetHeight(1)
                groupDivider:SetColorTexture(unpack(THEME.edge))
                railY = railY - 24
            end
            local heading = rail:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
            heading:SetPoint("TOPLEFT", 16, railY)
            heading:SetText(group)
            heading:SetTextColor(unpack(THEME.muted))
            railY = railY - 24
            previousGroup = group
        end

        local button = CreateFrame("Button", nil, rail)
        button:SetSize(178, 30)
        button:SetPoint("TOPLEFT", 0, railY)
        button.Text = button:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        button.Text:SetPoint("LEFT", 18, 0)
        button.Text:SetText(spec.title or spec.name)
        button.activeBg = button:CreateTexture(nil, "BACKGROUND")
        button.activeBg:SetAllPoints()
        button.activeBg:SetColorTexture(unpack(THEME.raised))
        button.activeBg:Hide()
        button.activeBar = button:CreateTexture(nil, "ARTWORK")
        button.activeBar:SetPoint("TOPLEFT")
        button.activeBar:SetPoint("BOTTOMLEFT")
        button.activeBar:SetWidth(3)
        button.activeBar:SetColorTexture(unpack(THEME.accent))
        button.activeBar:Hide()
        local pageName = spec.name
        button:SetScript("OnClick", function() Options.ShowPage(pageName) end)
        Options.pageButtons[spec.name] = button
        railY = railY - 30
    end

    Options.pageErrors = {}
    for _, spec in ipairs(Options.queue) do
        local ok, pageOrError = xpcall(function()
            return Options.CreatePage(spec, host)
        end, function(err)
            return tostring(err)
        end)
        if ok then
            Options.pages[spec.name] = pageOrError
        else
            Options.pageErrors[spec.name] = pageOrError
            local page = CreateFrame("Frame", nil, host)
            page:SetAllPoints(host)
            page:Hide()
            local heading = page:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
            heading:SetPoint("TOPLEFT", PAD_L, -16)
            heading:SetText(spec.title or spec.name)
            heading:SetTextColor(unpack(THEME.danger))
            local message = page:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
            message:SetPoint("TOPLEFT", PAD_L, -52)
            message:SetWidth(500)
            message:SetJustifyH("LEFT")
            message:SetJustifyV("TOP")
            message:SetText("This settings page did not build.\n\n" .. pageOrError
                .. "\n\nPlease send this text to the developer. Be honest - you've seen worse errors.")
            Options.pages[spec.name] = page
        end
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
    if not ns.Options.EnsureBuilt() then
        ns.Print("settings could not be built: "
            .. tostring(ns.Options.buildError or "unknown error"))
        return
    end
    if SettingsPanel and SettingsPanel.IsShown and SettingsPanel:IsShown() then
        if HideUIPanel then HideUIPanel(SettingsPanel) else SettingsPanel:Hide() end
    end
    ns.Options.ShowPage(pageName)
    ns.Options.window:Show()
    ns.Options.window:Raise()
end
