local addonName, ns = ...
local HC = ns.HammerCore
local O, T = ns.Options, HC.Theme

local section = O.Section

local TEXT_POSITIONS = {
    "LEFT:TOP", "CENTER:TOP", "RIGHT:TOP",
    "LEFT:MIDDLE", "CENTER:MIDDLE", "RIGHT:MIDDLE",
    "LEFT:BOTTOM", "CENTER:BOTTOM", "RIGHT:BOTTOM",
}
local TEXT_POSITION_LABELS = {
    "Top left", "Top centre", "Top right",
    "Middle left", "Centre", "Middle right",
    "Bottom left", "Bottom centre", "Bottom right",
}

-- Keep the existing two saved keys so older builds can read these choices.
local function textPosition(parent, label, hint, y, prefix)
    return O.Dropdown(parent, label, hint, y, TEXT_POSITIONS, TEXT_POSITION_LABELS,
        function() return ns.db[prefix .. "JustifyH"] .. ":" .. ns.db[prefix .. "JustifyV"] end,
        function(value)
            local horizontal, vertical = value:match("^([^:]+):([^:]+)$")
            ns.Set(prefix .. "JustifyH", horizontal)
            ns.Set(prefix .. "JustifyV", vertical)
        end, 560, 150, 180)
end

-- Refreshes the floating live preview (UI/Preview.lua) and its controls
-- after a change here.  The sample states live on ns.Preview.
local function refreshPreview()
    ns.Preview.count = ns.db.previewUnits
    ns.Preview:RefreshSettingsPreview()
    if ns.Preview.active then ns.Preview:Refresh() end
    ns.Preview:RefreshWindowControls()
end

-- Each tab's reset restores only the settings on that tab.
local TAB_KEYS = {
    Layout = { "orientation", "horizontalGrowth", "verticalGrowth", "columns",
        "spacing", "scale", "boxWidth", "boxHeight", "previewUnits" },
    Cells = { "showBorders", "showStacks", "showDispelTypeIcon", "dispelTypeIconSize",
        "dispelTypeIconPosition", "showWhenClean", "useClassColours", "cleanAlpha", "outOfRangeAlpha" },
    ["Names and icons"] = { "showNames", "nameJustifyH", "nameJustifyV", "nameFontSize",
        "roleIcon", "roleIconRoles", "roleIconPosition", "roleIconPlacement", "roleIconSize" },
    Members = { "sortMode", "sortRoleOrder", "sortReverse", "sortSelf", "extraCell", "extraCellSkipGroup" },
}

local function tab(name, fill)
    return O.Tab(name, fill, function()
        for _, key in ipairs(TAB_KEYS[name]) do ns.Set(key, ns.defaults[key]) end
        refreshPreview()
    end)
end

HC.Settings:NewPage({
    name = "Salve",
    -- Names, grid and member order are profile-owned; cell styling is shared.
    profileScope = function(tabName) return tabName ~= "Cells" end,
    title = "Panel",
    group = "main",
    headerAction = O.LivePreviewAction,
    tabs = {
        { name = "Layout", build = tab("Layout", function(panel, add, db)
            -- Which layout profile this page is editing, with Save as new beside it.
            local profile = section(panel)
            local _, profileY = O.Header(profile, "Profile", -8)
            _, profileY = HC.Profiles:Selector(profile, profileY,
                "The layout profile these settings belong to. Changes save to it straight away; manage profiles on the Profiles page.")
            add(profile, -profileY + 4)

            local presets = section(panel)
            local presetY = -8
            _, presetY = O.Header(presets, "Layout presets", presetY)
            local presetSpecs = {
                { label = "Compact", note = "20px cells, no names", width = 20, height = 20, columns = 5, spacing = 1, names = false, previewUnits = 5 },
                { label = "Named", note = "95px cells, names on", width = 95, height = 20, columns = 5, spacing = 1, names = true, previewUnits = 5 },
                { label = "Raid wall", note = "Tight 10-cell wall, no names", width = 20, height = 20, columns = 10, spacing = 0, names = false, previewUnits = 40 },
            }
            for index, spec in ipairs(presetSpecs) do
                local button = O.Button(presets, 168, 46)
                button:SetPoint("TOPLEFT", O.PAD + (index - 1) * 176, presetY - 4)
                button:SetText(spec.label)
                button.Text:ClearAllPoints()
                button.Text:SetPoint("TOPLEFT", 10, -7)
                button.Text:SetPoint("RIGHT", -10, 0)
                button.Text:SetJustifyH("LEFT")
                local note = button:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
                note:SetPoint("TOPLEFT", button.Text, "BOTTOMLEFT", 0, -2)
                note:SetText(spec.note)
                note:SetTextColor(unpack(T.Colour("muted")))
                O.AttachHint(button, spec.label, "Layout preset: sets cell width, height, wrapping, spacing and names. Keeps grid direction and panel scale.")
                O.RegisterRow(presets, button, spec.label .. " layout preset")
                button:SetScript("OnClick", function()
                    ns.Set("boxWidth", spec.width)
                    ns.Set("boxHeight", spec.height)
                    ns.Set("columns", spec.columns)
                    ns.Set("spacing", spec.spacing)
                    ns.Set("showNames", spec.names)
                    if spec.previewUnits then
                        ns.Set("previewUnits", spec.previewUnits)
                        refreshPreview()
                    end
                    if presets.hcRefreshAll then presets.hcRefreshAll() end
                end)
            end
            add(presets, -presetY + 58)

            local grid = section(panel, 2)
            local gy = -8
            _, gy = O.Header(grid, "Grid", gy)
            gy = O.ProfileScope(grid, gy)
            _, gy = O.Dropdown(grid, "Fill",
                "Rows fill a whole row before starting the next. Columns fill a whole column first.", gy,
                { "HORIZONTAL", "VERTICAL" }, { "Rows", "Columns" },
                function() return db.orientation end,
                function(value) ns.Set("orientation", value) end, 560, 150, 200)
            _, gy = O.Dropdown(grid, "Start corner",
                "Where the first cell goes. This corner stays put as the group grows, so Bottom left keeps new rows above your action bars.", gy,
                { "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT" },
                { "Top left", "Top right", "Bottom left", "Bottom right" },
                function() return ns.Panel:GrowthAnchor() end,
                function(value)
                    ns.Set("verticalGrowth", value:find("BOTTOM", 1, true) and "UP" or "DOWN")
                    ns.Set("horizontalGrowth", value:find("RIGHT", 1, true) and "LEFT" or "RIGHT")
                end, 560, 150, 200)
            _, gy = O.Slider(grid,
                function() return db.orientation == "VERTICAL"
                    and "Cells per column" or "Cells per row" end,
                "How many cells appear before the next line starts.", gy,
                1, 10, 1,
                function() return db.columns end,
                function(value) ns.Set("columns", value) end)
            _, gy = O.Slider(grid, "Spacing", "Gap between cells, in pixels.", gy,
                0, 12, 1,
                function() return db.spacing end,
                function(value) ns.Set("spacing", value) end)
            gy = O.Flush(grid, gy)
            add(grid, -gy + 4)

            local size = section(panel, 2)
            local sy = -8
            _, sy = O.Header(size, "Cell size", sy)
            sy = O.ProfileScope(size, sy)
            _, sy = O.Slider(size, "Width",
                "Use 95 or more to show the twelve-character preview names.", sy,
                10, 200, 1,
                function() return db.boxWidth end,
                function(value) ns.Set("boxWidth", value) end)
            _, sy = O.Slider(size, "Height", nil, sy,
                10, 150, 1,
                function() return db.boxHeight end,
                function(value) ns.Set("boxHeight", value) end)
            _, sy = O.Slider(size, "Panel scale",
                "Scales the entire Salve frame, including text and borders.", sy,
                0.5, 2, 0.05,
                function() return db.scale end,
                function(value) ns.Set("scale", value) end,
                function(value) return string.format("%.2f", value) end)
            sy = O.Flush(size, sy)
            add(size, -sy + 4)


        end) },
        { name = "Cells", build = tab("Cells", function(panel, add, db)
            local contents = section(panel, 2)
            local cy = -8
            _, cy = O.Header(contents, "Cell contents", cy)
            _, cy = O.Check(contents, "Show cell borders",
                "Show an outline around every cell, independently of idle backgrounds and names.", cy,
                function() return db.showBorders end,
                function(value) ns.Set("showBorders", value) end)
            _, cy = O.Check(contents, "Show stack counts",
                "The game hides the number at one stack. Dispelling previews simulate two stacks.", cy,
                function() return db.showStacks end,
                function(value) ns.Set("showStacks", value) end)
            cy = O.Flush(contents, cy)
            add(contents, -cy + 4)

            local dispelIcon = section(panel, 2)
            local diy = -8
            _, diy = O.Header(dispelIcon, "Dispel icon", diy)
            local dispelToggle
            dispelToggle, diy = O.Check(dispelIcon, "Show dispel-type icon",
                "Show Blizzard's Magic, Curse, Disease or Poison icon on a dispellable cell.", diy,
                function() return db.showDispelTypeIcon end,
                function(value) ns.Set("showDispelTypeIcon", value) end)
            diy = O.Flush(dispelIcon, diy)
            add(dispelIcon, -diy + 4)
            local iconDetails = section(panel, 2, dispelToggle)
            diy = -4
            _, diy = O.Slider(iconDetails, "Dispel icon size",
                "Size in pixels before UI scale. Large icons can cover names or cooldown numbers.", diy,
                8, 64, 1,
                function() return db.dispelTypeIconSize end,
                function(value) ns.Set("dispelTypeIconSize", value) end)
            _, diy = O.Dropdown(iconDetails, "Dispel icon position",
                "Choose which part of the cell holds the Blizzard dispel-type icon.", diy,
                { "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT", "CENTER" },
                { "Top left", "Top right", "Bottom left", "Bottom right", "Centre" },
                function() return db.dispelTypeIconPosition end,
                function(value) ns.Set("dispelTypeIconPosition", value) end,
                560, 150, 180)
            diy = O.Flush(iconDetails, diy)
            add(iconDetails, -diy + 4, function() return db.showDispelTypeIcon end)

            local inactive = section(panel, 2)
            local iy = -8
            _, iy = O.Header(inactive, "Idle backgrounds", iy)
            local idleToggle
            idleToggle, iy = O.Check(inactive, "Show idle backgrounds",
                "Off hides idle backgrounds. Borders and unit names have separate settings; click areas stay in place during combat.", iy,
                function() return db.showWhenClean end,
                function(value) ns.Set("showWhenClean", value) end)
            iy = O.Flush(inactive, iy)
            add(inactive, -iy + 4)
            local idleDetails = section(panel, 2, idleToggle)
            iy = -4
            _, iy = O.Check(idleDetails, "Class-coloured backgrounds",
                "Colour idle backgrounds by class. Names always use class colours; debuff colours are chosen by the game.", iy,
                function() return db.useClassColours end,
                function(value) ns.Set("useClassColours", value) end)
            _, iy = O.Slider(idleDetails, "Idle opacity",
                "How visible inactive cells are when shown.", iy,
                0, 1, 0.05,
                function() return db.cleanAlpha end,
                function(value) ns.Set("cleanAlpha", value) end,
                function(value) return string.format("%d%%", math.floor(value * 100 + 0.5)) end)
            iy = O.Flush(idleDetails, iy)
            add(idleDetails, -iy + 4, function() return db.showWhenClean end)

            local range = section(panel, 2)
            local ry = -8
            _, ry = O.Header(range, "Range", ry)
            _, ry = O.Slider(range, "Out of range opacity",
                "Cells fade for group members out of dispel range. 100% turns it off.", ry,
                0, 1, 0.05,
                function() return db.outOfRangeAlpha end,
                function(value) ns.Set("outOfRangeAlpha", value) end,
                function(value) return string.format("%d%%", math.floor(value * 100 + 0.5)) end)
            ry = O.Flush(range, ry)
            add(range, -ry + 4)

        end) },
        { name = "Names and icons", build = tab("Names and icons", function(panel, add, db)
            local names = section(panel, 2)
            local ny = -8
            _, ny = O.Header(names, "Unit names", ny)
            ny = O.ProfileScope(names, ny)
            local namesToggle
            namesToggle, ny = O.Check(names, "Show unit names",
                "Use cells at least 95 pixels wide for the twelve-character preview names.", ny,
                function() return db.showNames end,
                function(value) ns.Set("showNames", value) end)
            ny = O.Flush(names, ny)
            add(names, -ny + 4)
            local nameDetails = section(panel, 2, namesToggle)
            ny = -4
            _, ny = textPosition(nameDetails, "Name position", "Place names within each cell.", ny, "name")
            _, ny = O.Slider(nameDetails, "Name text size", "Size before UI scale is applied.", ny,
                6, 32, 1,
                function() return db.nameFontSize end,
                function(value) ns.Set("nameFontSize", value) end)
            ny = O.Flush(nameDetails, ny)
            add(nameDetails, -ny + 4, function() return db.showNames end)


            local roleIcon = section(panel, 2)
            local riy = -8
            _, riy = O.Header(roleIcon, "Role icon", riy)
            local roleToggle
            roleToggle, riy = O.Dropdown(roleIcon, "Role and marker icon",
                "Role, raid marker, or the marker when set and the role otherwise.", riy,
                { "OFF", "ROLE", "MARKER", "BOTH" },
                { "Off", "Role", "Raid marker", "Marker, else role" },
                function() return db.roleIcon end,
                function(value) ns.Set("roleIcon", value) end,
                560, 150, 180)
            riy = O.Flush(roleIcon, riy)
            add(roleIcon, -riy + 4)
            local roleFilter = section(panel, 2, roleToggle)
            riy = -4
            _, riy = O.Dropdown(roleFilter, "Roles shown", nil, riy,
                { "TANKHEALER", "ALL" }, { "Tank and healer", "All" },
                function() return db.roleIconRoles end,
                function(value) ns.Set("roleIconRoles", value) end,
                560, 150, 180)
            riy = O.Flush(roleFilter, riy)
            add(roleFilter, -riy + 4, function() return db.roleIcon == "ROLE" or db.roleIcon == "BOTH" end)
            local roleDetails = section(panel, 2, roleToggle)
            riy = -4
            _, riy = O.Dropdown(roleDetails, "Role icon corner", nil, riy,
                { "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT" },
                { "Top left", "Top right", "Bottom left", "Bottom right" },
                function() return db.roleIconPosition end,
                function(value) ns.Set("roleIconPosition", value) end,
                560, 150, 180)
            _, riy = O.Dropdown(roleDetails, "Role icon placement",
                "On edge straddles the border; on corner centres on the corner point.", riy,
                { "INSIDE", "EDGE", "CORNER" }, { "Inside", "On edge", "On corner" },
                function() return db.roleIconPlacement end,
                function(value) ns.Set("roleIconPlacement", value) end,
                560, 150, 180)
            _, riy = O.Slider(roleDetails, "Role icon size", nil, riy,
                6, 32, 1,
                function() return db.roleIconSize end,
                function(value) ns.Set("roleIconSize", value) end)
            riy = O.Flush(roleDetails, riy)
            add(roleDetails, -riy + 4, function() return db.roleIcon ~= "OFF" end)

        end) },
        { name = "Members", build = tab("Members", function(panel, add, db)
            local roleNames = { TANK = "Tank", HEALER = "Healer", DAMAGER = "DPS" }
            local roleLabels = {}
            for index, value in ipairs(ns.SORT_ROLE_ORDERS) do
                local names = {}
                for role in value:gmatch("[^,]+") do names[#names + 1] = roleNames[role] end
                roleLabels[index] = table.concat(names, ", ")
            end
            local order = section(panel, 2)
            local y = -8
            _, y = O.Header(order, "Order", y)
            y = O.ProfileScope(order, y)
            local sortToggle
            sortToggle, y = O.Dropdown(order, "Sort by",
                "Group order matches the game. Cells re-sort out of combat; a roster change mid-fight waits until combat ends. Attached left or right, the host's order wins.", y,
                { "GROUP", "ROLE", "NAME" }, { "Group order", "Role", "Name" },
                function() return db.sortMode end,
                function(value) ns.Set("sortMode", value) end, 560, 150, 180)
            y = O.Flush(order, y)
            add(order, -y + 4)
            local roleOrder = section(panel, 2, sortToggle)
            y = -4
            _, y = O.Dropdown(roleOrder, "Role order",
                "Used when sorting by role. Members with no role go last.", y,
                ns.SORT_ROLE_ORDERS, roleLabels,
                function() return db.sortRoleOrder end,
                function(value) ns.Set("sortRoleOrder", value) end, 560, 150, 180)
            y = O.Flush(roleOrder, y)
            add(roleOrder, -y + 4, function() return db.sortMode == "ROLE" end)
            local memberOrder = section(panel, 2)
            y = -4
            _, y = O.Check(memberOrder, "Reverse order",
                "Flip the sorted order. A pinned cell stays where it is.", y,
                function() return db.sortReverse end,
                function(value) ns.Set("sortReverse", value) end)
            _, y = O.Dropdown(memberOrder, "Your cell",
                "Pin your own cell first or last, or sort it with everyone else.", y,
                { "SORTED", "FIRST", "LAST" }, { "Sorted", "First", "Last" },
                function() return db.sortSelf end,
                function(value) ns.Set("sortSelf", value) end, 560, 150, 180)
            y = O.Flush(memberOrder, y)
            add(memberOrder, -y + 4)

            local extra = section(panel, 2)
            local ey = -8
            _, ey = O.Header(extra, "Extra cell", ey)
            local extraToggle
            extraToggle, ey = O.Dropdown(extra, "Extra cell",
                "One more cell after your group for a friendly target or focus outside it.", ey,
                { "OFF", "TARGET", "FOCUS" }, { "Off", "Target", "Focus" },
                function() return db.extraCell end,
                function(value) ns.Set("extraCell", value) end, 560, 150, 200)
            ey = O.Flush(extra, ey)
            add(extra, -ey + 4)
            local extraDetails = section(panel, 2, extraToggle)
            ey = -4
            _, ey = O.Check(extraDetails, "Hide for group members",
                "Your group already has cells.", ey,
                function() return db.extraCellSkipGroup end,
                function(value) ns.Set("extraCellSkipGroup", value) end)
            ey = O.Flush(extraDetails, ey)
            add(extraDetails, -ey + 4, function() return db.extraCell ~= "OFF" end)

        end) },
    },
})
