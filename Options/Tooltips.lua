local addonName, ns = ...
local O = ns.Options

local function section(parent, width)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(width or 264, 1)
    frame.salveRefresh = parent.salveRefresh
    frame.salveRefreshAll = parent.salveRefreshAll
    return frame
end

-- This follows the menu-backed select used by the Panel page. Tooltips has
-- one compact field, while those pages use paired fields.
local function anchorDropdown(parent, y, get, set)
    local row = O.Row(parent, y, 30, "Anchor",
        "Choose where the tooltip opens relative to a Salve cell.", 264)
    local values = { "RIGHT", "LEFT", "CURSOR" }
    local labels = { "Right of cell", "Left of cell", "At cursor" }
    local button = O.SelectButton(row, 156, 30)
    button:SetPoint("LEFT", row, "LEFT", 72, 0)
    button.Text:ClearAllPoints()
    button.Text:SetPoint("LEFT", 10, 0)
    button.Text:SetPoint("RIGHT", -26, 0)
    button.Text:SetJustifyH("LEFT")

    for _, spec in ipairs({
        { -13, 2, -0.75 }, { -8, 2, 0.75 },
    }) do
        local arrow = button:CreateTexture(nil, "OVERLAY")
        arrow:SetSize(7, 1)
        arrow:SetPoint("RIGHT", spec[1], spec[2])
        arrow:SetColorTexture(unpack(O.theme.muted))
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
        menu:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
        })
        menu:SetBackdropColor(0.020, 0.027, 0.039, 1)
        menu:SetBackdropBorderColor(unpack(O.theme.menuEdge))
        menu:SetSize(156, #values * 26 + 10)
        local items = {}
        local function paint(item, active, hovered)
            item:SetBackdropColor(unpack((active or hovered)
                and O.theme.menuActive or O.theme.rail))
            item:SetBackdropBorderColor(0, 0, 0, 0)
            item.activeBar:SetShown(active)
            item.label:SetTextColor(active and 1 or O.theme.muted[1],
                active and 1 or O.theme.muted[2], active and 1 or O.theme.muted[3])
        end
        local function refreshItems()
            for _, item in ipairs(items) do
                paint(item, get() == item.value, false)
            end
        end
        for index, value in ipairs(values) do
            local item = CreateFrame("Button", nil, menu, "BackdropTemplate")
            item:SetSize(146, 24)
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
            item.activeBar:SetColorTexture(unpack(O.theme.selected))
            item.label = item:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
            item.label:SetPoint("LEFT", 10, 0)
            item.label:SetPoint("RIGHT", -8, 0)
            item.label:SetJustifyH("LEFT")
            item.label:SetText(labels[index])
            item.value = value
            item:HookScript("OnEnter", function(self)
                paint(self, get() == self.value, true)
            end)
            item:HookScript("OnLeave", function(self)
                paint(self, get() == self.value, false)
            end)
            item:SetScript("OnClick", function()
                set(value)
                render()
                parent.salveRefreshAll()
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
    O.AttachHint(button, "Anchor", "Choose where the tooltip opens relative to a Salve cell.")
    parent.salveRefresh[#parent.salveRefresh + 1] = render
    render()
    return row, y - 34
end

O.NewPage({
    name = "Tooltips",
    title = "Tooltips",
    group = "CORE",
    description = "Choose what a Salve cell says when you hover it.",
}, function(panel, y)
    local db = ns.db
    local controls = section(panel, 264)
    controls:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)

    _, y = O.Header(controls, "Cell tooltip", y)
    _, y = O.Check(controls, "Show cell tooltips",
        "Show a tooltip when hovering a Salve cell.", y,
        function() return db.showTooltip end,
        function(value) ns.Set("showTooltip", value) end, 264)
    _, y = O.Check(controls, "Show default tooltips",
        "Include Blizzard's normal unit tooltip: name, class, level and other standard unit details.", y,
        function() return db.tooltipUnitInfo end,
        function(value) ns.Set("tooltipUnitInfo", value) end, 264)

    _, y = O.Header(controls, "Content", y)
    _, y = O.Check(controls, "Show Salve actions",
        "List the currently bound clicks and what each one casts.", y,
        function() return db.tooltipActions end,
        function(value) ns.Set("tooltipActions", value) end, 264)
    _, y = O.Check(controls, "Show spell descriptions",
        "Add Blizzard's static description for each bound spell. This can make the tooltip much taller.", y,
        function() return db.tooltipSpellDescriptions end,
        function(value) ns.Set("tooltipSpellDescriptions", value) end, 264)

    _, y = O.Header(controls, "Position", y)
    _, y = anchorDropdown(controls, y,
        function() return db.tooltipAnchor end,
        function(value) ns.Set("tooltipAnchor", value) end)

    _, y = O.PageReset(controls, y - 4, function()
        ns.Set("showTooltip", ns.defaults.showTooltip)
        ns.Set("tooltipUnitInfo", ns.defaults.tooltipUnitInfo)
        ns.Set("tooltipActions", ns.defaults.tooltipActions)
        ns.Set("tooltipSpellDescriptions", ns.defaults.tooltipSpellDescriptions)
        ns.Set("tooltipAnchor", ns.defaults.tooltipAnchor)
    end, "Reset Tooltips")

    return y - 8
end)
