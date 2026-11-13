local addonName, ns = ...
local HC = ns.HammerCore

-- Rows without `since` are offered only on a fresh install, never an update.
local welcomeRows = {
    { key = "layout", label = "Cell layout", choices = {
        { value = "COMPACT", label = "Compact" }, { value = "NAMED", label = "Named" },
        { value = "RAID", label = "Raid wall" },
    }, get = function() return ns.db.showNames and "NAMED" or (ns.db.columns == 10 and "RAID" or "COMPACT") end,
    set = function(value)
        ns.Set("boxWidth", value == "NAMED" and 95 or 20)
        ns.Set("boxHeight", 20)
        ns.Set("columns", value == "RAID" and 10 or 5)
        ns.Set("spacing", value == "RAID" and 0 or 1)
        ns.Set("showNames", value == "NAMED")
    end },
    { key = "sound", label = "Dispel alert sound", choices = {
        { value = false, label = "Off" }, { value = true, label = "On" },
    }, get = function() return ns.db.dispelSoundEnabled end,
    set = function(value) ns.Set("dispelSoundEnabled", value) end },
}
local attachChoices = { { value = "NONE", label = "None" } }
for _, key in ipairs(ns.Attach.HOST_ORDER) do
    if ns.Attach:IsLoaded(key) then
        attachChoices[#attachChoices + 1] = { value = key, label = ns.Attach.HOSTS[key].label }
    end
end
if #attachChoices > 1 then
    welcomeRows[#welcomeRows + 1] = { key = "attach", label = "Attach to group frames", choices = attachChoices,
        get = function() return ns.db.attachTo end,
        set = function(value) ns.Set("attachTo", value) end }
end
HC.Welcome:Register({ icon = HC.spec.icon,
    intro = "Choose a layout and alert sound, then bind your dispel on Key Bindings.",
    rows = welcomeRows, footer = "You can change these in settings." })

