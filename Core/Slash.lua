local addonName, ns = ...

-- /salve with no argument opens the options panel; everything else is a
-- shortcut for something in it.

SLASH_SALVE1 = "/salve"

SlashCmdList.SALVE = function(msg)
    local cmd, arg = (msg or ""):lower():match("^%s*(%S*)%s*(%S*)")

    -- Bare /salve already opens the panel, but only because it falls through to
    -- the default. Naming it explicitly means /salve options is documented and
    -- discoverable rather than accidental.
    if cmd == "options" or cmd == "config" or cmd == "opt" then
        ns.OpenOptions()

    elseif cmd == "snares" then
        ns.Escape:DumpCaptured()

    elseif cmd == "learn" then
        if arg == "on" then
            ns.Sound:SetLearning(true)
        elseif arg == "off" then
            ns.Sound:SetLearning(false)
        else
            local state = ns.db.learnMode
                and ("ON for " .. tostring(ns.Sound.activeScopeName)
                    .. " (persists across zones and reloads)") or "off"
            ns.Print("learn mode is " .. state
                .. " — use |cffffd100/salve learn on|r or |cffffd100off|r")
        end

    elseif cmd == "learned" then
        if arg == "clear" then ns.Sound:ClearLearned() else ns.Sound:DumpLearned() end

    elseif cmd == "debug" or cmd == "probe" then
        ns.Binding:Report()
        ns.Sound:Report()

    elseif cmd == "unlock" or cmd == "handle" then
        ns.SetLocked(false)
        ns.Print("drag handle shown — grab the small square above the panel")

    elseif cmd == "lock" then
        ns.SetLocked(true)
        ns.Print("drag handle hidden")

    elseif cmd == "reset" then
        ns.db.point = { "CENTER", "CENTER", 0, -140 }
        ns.Panel:ApplyPosition()
        ns.Print("panel position reset")

    elseif cmd == "help" then
        ns.Print("|cffffd100/salve|r or |cffffd100/salve options|r — open the options panel")
        ns.Print("|cffffd100/salve lock|r | |cffffd100unlock|r — hide or show the drag handle")
        ns.Print("|cffffd100/salve reset|r — put the panel back in the middle")
        ns.Print("|cffffd100/salve debug|r — print a diagnostic report")
        ns.Print("|cffffd100/salve learn on|r | |cffffd100off|r | |cffffd100status|r — persistent, opt-in aura logging")
        ns.Print("|cffffd100/salve snares|r — list auto-captured root and snare spell IDs")
        ns.Print("|cffffd100/salve learned|r | |cffffd100learned clear|r — list or clear recorded auras")
        ns.Print("|cffffd100/salve help|r — show this command list")

    else
        ns.OpenOptions()
    end
end
