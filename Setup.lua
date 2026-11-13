local addonName, ns = ...
local HC = ns.HammerCore

-- Declares Salve to HammerCore: commands, the shared verbs, the minimap
-- menu, status, diagnostics, Troubleshooting extras and About.
-- Salve's own settings helpers live on ns.Options, which falls back to
-- HammerCore's controls, so pages call O.Check, O.Header and so on.

ns.Print = HC.Print
ns.Options = setmetatable({}, { __index = HC.UI })

-- Sections share their page's refresh list and search index.
function ns.Options.Section(parent, columns, parentRow)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(HC.UI.CONTENT_WIDTH + HC.UI.PAD * 2, 1)
    frame.hcColumns = columns or 2
    frame.hcRefresh, frame.hcRefreshAll = parent.hcRefresh, parent.hcRefreshAll
    frame.hcHeaderOwner = parent.hcHeaderOwner or parent
    frame.hcParentRow = parentRow
    return frame
end

-- Hidden dependent sections leave no gap and keep a searchable parent.
function ns.Options.Flow(panel)
    local flow = { entries = {}, y = -8 }
    function flow:Add(frame, height, visible, parentRow)
        if parentRow then frame.hcParentRow = parentRow end
        self.entries[#self.entries + 1] = { frame = frame, height = height, visible = visible }
    end
    function flow:Layout()
        local y = -8
        for _, entry in ipairs(self.entries) do
            local shown = not entry.visible or entry.visible()
            entry.frame:SetShown(shown)
            if shown then
                entry.frame:ClearAllPoints()
                entry.frame:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, y)
                local height = type(entry.height) == "function" and entry.height() or entry.height
                entry.frame:SetHeight(height)
                y = y - height
            end
        end
        self.y = y - 8
        if panel.hcSetBottom then panel.hcSetBottom(self.y) end
        return self.y
    end
    panel.hcRefresh[#panel.hcRefresh + 1] = function() flow:Layout() end
    return flow
end

function ns.Options.Tab(name, fill, resetFn, resetLabel, resetScope)
    return function(panel)
        local flow = ns.Options.Flow(panel)
        fill(panel, function(...) flow:Add(...) end, ns.db)
        if resetFn then
            local reset = ns.Options.Section(panel)
            HC.UI.SetScope(reset, "shared") -- a tab reset can mix both storage classes
            local _, y = ns.Options.PageReset(reset, -4, resetFn, resetLabel or "Reset " .. name:lower(), resetScope)
            flow:Add(reset, -y)
        end
        return flow:Layout()
    end
end

-- Scope markers describe the existing storage groups; they do not change them.
function ns.Options.ProfileScope(panel, y, shared)
    HC.UI.SetScope(panel, shared and "shared" or "profile")
    return y
end

-- The header button on every page whose settings change how the grid looks.
ns.Options.LivePreviewAction = {
    text = function()
        return ns.Preview and ns.Preview:IsWindowShown() and "Hide live preview" or "Show live preview"
    end,
    onClick = function() ns.Preview:ToggleWindow() end,
    hint = "An actual-size preview of the panel in its own window. Drag it anywhere; it stays open while you change pages.",
}

-- Events refresh Troubleshooting when spells or zones change.
function ns.Options.RefreshTroubleshooting()
    local settings = HC.Settings
    if settings:IsShown() and settings.selected == "Troubleshooting" then settings:Select("Troubleshooting") end
end

local tips = {
    "For external use only. Side effects may include fewer purple swirls.",
    "If it lights up, click it.",
    "Drag the gold handle. The cells have important clicking to do.",
    "Master sound still works when sound effects are muted.",
    "Aura learning quietly fills the gaps. On purpose.",
    "Purple swirl? Salve first, questions later.",
    "A glowing cell is not a suggestion.",
    "One click removes a debuff. Repeated clicks express concern.",
    "A dispel on cooldown is not ignoring you. It is thinking.",
    "Side effects may include suspiciously clean raid frames.",
    "If nothing lights up, congratulations. Or run diagnostics.",
    "Apply directly to affected party members. Avoid eyes and damage meters.",
    "The raid leader said 'dispel'. This is your moment.",
    "If everyone is purple, start with yourself. You are holding the mouse.",
    "Salve contains no aloe. The lawyers insisted.",
    "Not tested on murlocs. They would not sign the consent form.",
    "Keep out of reach of DPS. They will bind it to Heroism.",
    "The gold handle is not loot. Please stop rolling Need.",
    "If the tank asks who dispelled it, look professionally innocent.",
    "The square knows what it did.",
    "Cleanse responsibly. Salve does not judge your mouse-button choices.",
    "Follower NPCs also deserve healthcare. Probably.",
    "Do not use on enrage effects. That is a differently shaped problem.",
    "Eight seconds is plenty of time to decide who gets the next dispel.",
    "Hovering reveals tooltips. Staring intensely does not.",
    "Lua arrays start at 1. Zero did not make the raid roster.",
    "There are two hard problems in addon development: naming things, cache invalidation, and off-by-one errors.",
}

local applicationLines = {
    "You apply Salve. Much better.",
    "You apply Salve. The options feel cleaner already.",
    "You apply Salve. No raid members were harmed.",
    "You apply Salve. The bottle makes a reassuring little noise.",
    "You apply Salve. Somewhere, a purple swirl feels nervous.",
    "You apply Salve. The tooltip recommends another click.",
}

local function setLocked(locked)
    ns.SetLocked(locked)
    HC.Print(locked and "drag handle hidden" or "drag handle shown - grab the small square above the panel")
end

-- Salve's part of HammerCore's minimap menu, which already starts with
-- "Salve settings" and "Profiles": the drag handle toggle, a line, then the
-- profiles. The drag handle and the LDB launcher open the same menu.
function ns.MenuItems()
    local items = { { text = ns.IsLocked() and "Show drag handle" or "Hide drag handle",
        func = function() setLocked(not ns.IsLocked()) end } }
    items[#items + 1] = { separator = true }
    -- HC's own "Profiles" item already sits above, so skip the list's title.
    for _, item in ipairs(HC.Profiles:MenuItems()) do
        if not item.title then items[#items + 1] = item end
    end
    return items
end

-- anchor: the frame to open beneath (the drag handle), or nil for the cursor.
function ns.OpenMenu(anchor)
    return HC.Minimap:OpenMenu(anchor)
end

HC:Init({
    name = "Salve",
    command = "salve",
    savedVariable = "SalveDB",
    db = function() return ns.db end,
    icon = "Interface\\AddOns\\Salve\\Textures\\SalveTransparent",
    window = { width = 920, height = 760 },
    legacy = {
        startupMessage = "showStartupMessage",
        minimap = "showMinimap",
        minimapAngle = "minimapAngle",
        settingsPoint = "settingsPoint",
    },
    clientLabel = function() return ns.isCamelot and "WoW Forever" or "Retail" end,
    minimap = {
        icon = "Interface\\AddOns\\Salve\\Textures\\SalveClean",
        menu = function() return ns.MenuItems() end,
    },
    onSettingsShown = function()
        if ns.Preview and ns.db.previewWindowOpen then ns.Preview:ShowWindow() end
    end,
    onSettingsHidden = function()
        if ns.Preview then
            ns.Preview:Stop()
            ns.Preview:HideWindow()
        end
    end,
    whatsNew = ns.WHATS_NEW,
    -- Takeoff and landing only, for Hide on flights. See Features/Flights.lua.
    flights = { estimates = false },
    toggle = { help = "Show or hide the panel", run = function()
        ns.db.visibilityMode = ns.db.visibilityMode == "NEVER" and "ALWAYS" or "NEVER"
        ns.RequestRebuildSoon(0.05)
        HC.Print("panel " .. (ns.db.visibilityMode == "NEVER" and "hidden" or "shown"))
    end },
    lock = { help = "Hide the drag handle", run = function() setLocked(true) end },
    unlock = { help = "Show the drag handle", run = function() setLocked(false) end },
    resetPosition = function()
        ns.db.point = { "CENTER", "CENTER", 0, -140 }
        ns.Panel:ApplyPosition()
    end,
    status = function() return ns.Options.StatusText() end,
    diagnostics = function() return ns.Options.BuildDiagnosticReport() end,
    troubleshooting = function(panel, y) return ns.Options.TroubleshootingExtras(panel, y) end,
    about = {
        note = "PRACTITIONER'S NOTE",
        tips = tips,
        chat = applicationLines,
        action = "Apply Salve",
        onApply = function() if ns.Sound and ns.Sound.Test then ns.Sound:Test(true) end end,
        credit = "Decursive alert sound by John Wellesz, used under GPL v3-or-later.",
    },
})

HC.Commands:AddAction({ section = "Panel", usage = "Click a lit cell", help = "Use the action bound to that mouse button" })
HC.Commands:AddAction({ section = "Panel", usage = "Drag the gold handle", help = "Move the panel; right-click it for the menu" })
HC.Commands:Add({ name = "forever", section = "Diagnostics", help = "Copy a Forever cure and spellbook report",
    run = function() ns.Options.ShowForeverSpellReport() end })
HC.Commands:Add({ name = "cooldowns", section = "Diagnostics", help = "Show how cooldown icons read each spell; works in combat",
    run = function()
        ns.Print("cooldown icon report")
        ns.Cooldowns:Report()
    end })
HC.Commands:Add({ name = "snares", section = "Diagnostics", help = "List captured root and snare spell IDs",
    run = function() ns.Escape:DumpCaptured() end })
HC.Commands:Add({ name = "trace", section = "Diagnostics", help = "Print your casts and error messages until you run it again",
    run = function() ns.CastTrace:Toggle() end })
HC.Commands:Add({ name = "secrecy", section = "Diagnostics", help = "Show which unit details the game has hidden, by situation",
    run = function() for _, line in ipairs(ns.Secrecy:DiagnosticLines()) do ns.Print(line) end end })
HC.Commands:Add({ name = "secrecy clear", section = "Diagnostics", help = "Clear the unit secrecy log",
    run = function() ns.Secrecy:Clear(); ns.Print("unit secrecy log cleared") end })
HC.Commands:Add({ name = "learned", section = "Learning", help = "List recorded auras",
    run = function() ns.Sound:DumpLearned() end })
HC.Commands:Add({ name = "learned clear", section = "Learning", help = "Clear recorded auras",
    run = function() ns.Sound:ClearLearned() end })

-- ── Layout profiles ────────────────────────────────────────────────────────
-- HammerCore owns the store, auto-switch and the Profiles page; Salve says
-- which settings can belong to a profile and how to redraw after a switch.
-- Every group below is saved per profile; settings outside them are the
-- same in every profile.
HC.Profiles:Setup({
    groups = {
        { key = "position", label = "Position",
            hint = "Where the panel sits and where its drag handle is.",
            keys = { "point", "handlePosition" } },
        { key = "grid", label = "Grid and size",
            hint = "Grid direction, start corner, cells per row, spacing, cell size, scale and preview units.",
            keys = { "orientation", "horizontalGrowth", "verticalGrowth", "columns", "spacing",
                "scale", "boxWidth", "boxHeight", "previewUnits" } },
        { key = "names", label = "Player names",
            hint = "Show names, their position and text size.",
            keys = { "showNames", "nameJustifyH", "nameJustifyV", "nameFontSize" } },
        { key = "sorting", label = "Sorting",
            hint = "Sort order, role order and your own cell.",
            keys = { "sortMode", "sortRoleOrder", "sortReverse", "sortSelf" } },
        { key = "cooldownBar", label = "Cooldown bar",
            hint = "Whether the bar shows, where, its size and hidden spells.",
            keys = { "cooldownBar", "cooldownBarShowReady", "cooldownBarSide", "cooldownBarOrientation",
                "cooldownBarMatchPanel", "cooldownBarGap", "cooldownBarIconSize", "cooldownBarSpacing",
                "cooldownBarHidden" } },
        { key = "visibility", label = "Visibility",
            hint = "When the panel shows.",
            keys = { "visibilityMode", "visibility" } },
        { key = "attach", label = "Attach",
            hint = "Attaching to another addon's frames.",
            keys = { "attachTo", "attachSide", "attachGap", "attachAlign", "attachOffsetY" } },
    },
    defaults = function() return ns.defaults end,
    seed = {
        { name = "Party", values = { previewUnits = 5 } },
        { name = "Raid 20", values = { previewUnits = 20 } },
        { name = "Raid 40", values = { previewUnits = 40 } },
    },
    active = "Party",
    rules = {
        { profile = "Party", group = "ANY", min = 1, max = 5, instance = "ANY", source = "INSTANCE" },
        { profile = "Raid 20", group = "ANY", min = 6, max = 20, instance = "ANY", source = "INSTANCE" },
        { profile = "Raid 40", group = "ANY", min = 21, max = 40, instance = "ANY", source = "INSTANCE" },
    },
    unsafe = function() return ns.StructuralChangesUnsafe() end,
    apply = function()
        local panel = ns.Panel
        if not (panel and panel.frame) then return end
        -- ☠ Position BEFORE the rebuild. Rebuild normalises the anchor from
        --   the frame's current edges; run first, it would save the old
        --   profile's position into the new one.
        panel:ApplyPosition()
        ns.RequestRebuild()
        if ns.Handle then ns.Handle:Update() end
        panel:Restyle()
        if ns.CooldownBar and ns.CooldownBar.Anchor then ns.CooldownBar:Anchor() end
        if ns.Preview and ns.Preview.active then ns.Preview:Refresh() end
        if ns.Preview and ns.Preview.RefreshSettingsPreview then
            ns.Preview.count = ns.db.previewUnits
            ns.Preview:RefreshSettingsPreview()
        end
    end,
})
