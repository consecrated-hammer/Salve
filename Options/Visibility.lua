local addonName, ns = ...
local HC = ns.HammerCore
local O = ns.Options

-- Panel show rules followed by HammerCore's minimap, update and window options.
HC.Settings:AddVisibility()
HC.Pages.visibility.profileScope = true

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

    _, y = O.Header(panel, "Panel", y)
    _, y = O.MultiSelect(panel, "Show panel",
        "Choose Always or Never, or tick several rules; any matching rule will show Salve.",
        y, { items = items, summary = function() return ns.Visibility:Summary() end }, 264)
    _, y = O.Check(panel, "Hide on flights", "Hide the panel and movement text on a flight path.", y,
        function() return db.hideOnFlights end,
        function(value) ns.Set("hideOnFlights", value) end)

    _, y = O.PageReset(panel, y + 12, function()
        db.visibilityMode = ns.defaults.visibilityMode
        db.visibility = {}
        ns.Set("hideOnFlights", ns.defaults.hideOnFlights)
        local state = HC.State()
        state.minimap, state.startupMessage, state.minimapAngle = true, true, 225
        state.minimapRightClick = nil
        HC.Minimap:Update()
        ns.RequestRebuildSoon(0.05)
    end, "Reset visibility")
    return y
end
