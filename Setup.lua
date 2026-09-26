local addonName, ns = ...
local HC = ns.HammerCore

-- Declares Salve to HammerCore: commands, the shared verbs, the minimap
-- right-click, status, diagnostics, Troubleshooting extras and About.
-- Salve's own settings helpers live on ns.Options, which falls back to
-- HammerCore's controls, so pages call O.Check, O.Header and so on.

ns.Print = HC.Print
ns.Options = setmetatable({}, { __index = HC.UI })

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
        rightClick = function() setLocked(not ns.IsLocked()) end,
        rightClickLabel = "show or hide the drag handle",
    },
    onSettingsHidden = function() if ns.Preview then ns.Preview:Stop() end end,
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
HC.Commands:AddAction({ section = "Panel", usage = "Drag the gold handle", help = "Move the panel; right-click it for settings" })
HC.Commands:Add({ name = "forever", section = "Diagnostics", help = "Copy a Forever cure and spellbook report",
    run = function() ns.Options.ShowForeverSpellReport() end })
HC.Commands:Add({ name = "snares", section = "Diagnostics", help = "List captured root and snare spell IDs",
    run = function() ns.Escape:DumpCaptured() end })
HC.Commands:Add({ name = "learned", section = "Learning", help = "List recorded auras",
    run = function() ns.Sound:DumpLearned() end })
HC.Commands:Add({ name = "learned clear", section = "Learning", help = "Clear recorded auras",
    run = function() ns.Sound:ClearLearned() end })
