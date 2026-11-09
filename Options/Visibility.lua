local addonName, ns = ...
local HC = ns.HammerCore
local O = ns.Options

-- HammerCore's Visibility page supplies "Other" (minimap button, startup
-- message); this adds when the panel shows and where its handle sits.

local HANDLE_VALUES = { "CORNER", "LEFT", "TOPLEFT", "TOP", "TOPRIGHT", "RIGHT", "BOTTOMRIGHT", "BOTTOM", "BOTTOMLEFT" }
local HANDLE_LABELS = { "Start corner", "Left", "Top left", "Top centre", "Top right", "Right", "Bottom right", "Bottom centre", "Bottom left" }

HC.Settings:AddVisibility()
-- Handle position shows in the live preview.
HC.Pages.visibility.headerAction = ns.Options.LivePreviewAction

-- Right-click on the minimap button sits under Show minimap button.
HC.spec.visibilityMinimap = function(panel, y)
    local db = ns.db
    _, y = O.Dropdown(panel, "Minimap right-click",
        "Profile menu lists your profiles and can show or hide the drag handle. Drag handle toggles it straight away.", y,
        { "PROFILES", "HANDLE" }, { "Profile menu", "Drag handle" },
        function() return db.minimapRightClick end,
        function(value) ns.Set("minimapRightClick", value) end,
        nil, 150, 130)
    return y
end

HC.spec.visibility = function(panel, y)
    local db = ns.db

    local function hasConditions()
        for _, condition in ipairs(ns.VIS_CONDITIONS) do
            if db.visibility[condition.key] then return true end
        end
        return false
    end
    local function setBaseMode(mode)
        db.visibilityMode = mode
        for _, condition in ipairs(ns.VIS_CONDITIONS) do db.visibility[condition.key] = nil end
        ns.RequestRebuildSoon(0.05)
    end
    local items = {
        { label = "Always", radio = true,
          get = function() return db.visibilityMode ~= "NEVER" and not hasConditions() end,
          set = function() setBaseMode("ALWAYS") end },
        { label = "Never", radio = true,
          get = function() return db.visibilityMode == "NEVER" end,
          set = function() setBaseMode("NEVER") end },
        { label = "Show when any of these match", heading = true },
    }
    for _, condition in ipairs(ns.VIS_CONDITIONS) do
        local key = condition.key
        items[#items + 1] = {
            label = condition.label,
            get = function() return db.visibilityMode ~= "NEVER" and db.visibility[key] end,
            set = function(value)
                db.visibilityMode = "ALWAYS"
                db.visibility[key] = value or nil
                ns.RequestRebuildSoon(0.05)
            end,
        }
    end

    _, y = O.Header(panel, "Display", y)
    _, y = O.MultiSelect(panel, "Show",
        "Choose Always or Never, or tick several rules; any matching rule will show Salve.",
        y, { items = items, summary = function() return ns.Visibility:Summary() end }, 264)

    _, y = O.Header(panel, "Position", y)
    _, y = O.Check(panel, "Show drag handle", "Drag the gold handle to move Salve.", y,
        function() return db.showHandle end,
        function(value) ns.Set("showHandle", value) end)
    _, y = O.Dropdown(panel, "Handle position",
        "Which edge of the grid holds the handle. Start corner follows the grid's fixed corner (Panel > Grid).", y,
        HANDLE_VALUES, HANDLE_LABELS,
        function() return db.handlePosition end,
        function(value) ns.Set("handlePosition", value) end)
    _, y = O.Dropdown(panel, "Handle right-click",
        "Profile menu lists your profiles and links to settings. Open settings goes straight there.", y,
        { "PROFILES", "SETTINGS" }, { "Profile menu", "Open settings" },
        function() return db.handleRightClick end,
        function(value) ns.Set("handleRightClick", value) end,
        nil, 150, 130)
    _, y = O.ActionButton(panel, y, "Reset frame position",
        function() HC.Commands:Dispatch("reset position") end,
        "Move Salve back to the centre of the screen.")

    _, y = O.PageReset(panel, y + 12, function()
        db.visibilityMode = ns.defaults.visibilityMode
        db.visibility = {}
        ns.Set("showHandle", ns.defaults.showHandle)
        ns.Set("handlePosition", ns.defaults.handlePosition)
        ns.Set("handleRightClick", ns.defaults.handleRightClick)
        ns.Set("minimapRightClick", ns.defaults.minimapRightClick)
        db.point = { ns.defaults.point[1], ns.defaults.point[2], ns.defaults.point[3], ns.defaults.point[4] }
        local state = HC.State()
        state.minimap, state.startupMessage, state.minimapAngle = true, true, 225
        HC.Minimap:Update()
        ns.Panel:ApplyPosition()
        ns.RequestRebuildSoon(0.05)
    end, "Reset visibility")
    return y
end
