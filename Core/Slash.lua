local addonName, ns = ...

-- /salve with no argument opens the options panel; everything else is a
-- shortcut for something in it.

SLASH_SALVE1 = "/salve"

SlashCmdList.SALVE = function(msg)
    local cmd = (msg or ""):lower():match("^%s*(%S*)")

    -- Bare /salve already opens the panel, but only because it falls through to
    -- the default. Naming it explicitly means /salve options is documented and
    -- discoverable rather than accidental.
    if cmd == "options" or cmd == "config" or cmd == "opt" then
        ns.OpenOptions()

    elseif cmd == "probe" then
        ns.Binding:Report()

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
        ns.Print("|cffffd100/salve probe|r — engine diagnostics")

    else
        ns.OpenOptions()
    end
end
