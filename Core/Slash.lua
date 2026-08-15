local addonName, ns = ...

-- /salve with no argument opens the options panel; everything else is a
-- shortcut for something in it.

SLASH_SALVE1 = "/salve"

SlashCmdList.SALVE = function(msg)
    local cmd = (msg or ""):lower():match("^%s*(%S*)")

    if cmd == "probe" then
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
        ns.Print("/salve — options")
        ns.Print("/salve lock | unlock — hide or show the drag handle")
        ns.Print("/salve reset — put the panel back in the middle")
        ns.Print("/salve probe — engine diagnostics")

    else
        ns.OpenOptions()
    end
end
