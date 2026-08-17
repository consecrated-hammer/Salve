local addonName, ns = ...
local O = ns.Options

local commands = {
    { "/salve or /salve options", "Open settings; config and opt also work" },
    { "/salve lock", "Hide the drag handle" },
    { "/salve unlock", "Show the drag handle; handle also works" },
    { "/salve reset", "Move Salve back to the centre" },
    { "/salve version", "Print the loaded version and revision" },
    { "/salve debug", "Print a diagnostic report; probe also works" },
    { "/salve learn on | off | status", "Control persistent, opt-in aura logging" },
    { "/salve snares", "List auto-captured root and snare spell IDs for sharing" },
    { "/salve learned", "List recorded auras" },
    { "/salve learned clear", "Clear recorded auras" },
    { "/salve help", "Print this command list in chat" },
}

O.NewPage({
    name = "Commands",
    description = "Every /salve command in one place.",
}, function(panel, y)
    _, y = O.Header(panel, "Commands", y)
    for _, row in ipairs(commands) do
        local command = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        command:SetPoint("TOPLEFT", 16, y)
        command:SetWidth(220)
        command:SetJustifyH("LEFT")
        command:SetText("|cffffd100" .. row[1] .. "|r")

        local does = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        does:SetPoint("TOPLEFT", 250, y)
        does:SetWidth(285)
        does:SetJustifyH("LEFT")
        does:SetText(row[2])
        y = y - 22
    end
    return y - 20
end)
