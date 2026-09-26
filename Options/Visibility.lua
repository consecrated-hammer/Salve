local addonName, ns = ...
local HC = ns.HammerCore
local O = ns.Options

-- HammerCore's Visibility page supplies "Other" (minimap button, startup
-- message); this adds when the panel shows and where its handle sits.

local HANDLE_VALUES = { "LEFT", "TOPLEFT", "TOP", "TOPRIGHT", "RIGHT", "BOTTOMRIGHT", "BOTTOM", "BOTTOMLEFT" }
local HANDLE_LABELS = { "Left", "Top left", "Top centre", "Top right", "Right", "Bottom right", "Bottom centre", "Bottom left" }

HC.Settings:AddVisibility()

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
    _, y = O.Check(panel, "Show drag handle", "Drag the gold handle to move Salve. Right-click it for settings.", y,
        function() return db.showHandle end,
        function(value) ns.Set("showHandle", value) end)
    _, y = O.Dropdown(panel, "Handle position", "Which edge of the grid holds the handle.", y,
        HANDLE_VALUES, HANDLE_LABELS,
        function() return db.handlePosition end,
        function(value) ns.Set("handlePosition", value) end)
    local resetPosition = O.Button(panel, 160, 22)
    resetPosition:SetPoint("TOPLEFT", 16, y - 4)
    resetPosition:SetText("Reset frame position")
    O.AttachHint(resetPosition, "Reset frame position", "Move Salve back to the centre of the screen.")
    resetPosition:SetScript("OnClick", function() HC.Commands:Dispatch("reset position") end)
    y = y - 38

    _, y = O.PageReset(panel, y, function()
        db.visibilityMode = ns.defaults.visibilityMode
        db.visibility = {}
        ns.Set("showHandle", ns.defaults.showHandle)
        ns.Set("handlePosition", ns.defaults.handlePosition)
        db.point = { ns.defaults.point[1], ns.defaults.point[2], ns.defaults.point[3], ns.defaults.point[4] }
        local state = HC.State()
        state.minimap, state.startupMessage, state.minimapAngle = true, true, 225
        HC.Minimap:Update()
        ns.Panel:ApplyPosition()
        ns.RequestRebuildSoon(0.05)
    end, "Reset visibility")
    return y
end
