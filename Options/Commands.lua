local addonName, ns = ...
local O = ns.Options

local commands = {
    { section = "GENERAL" },
    { "/salve or /salve options", "Open settings; config and opt also work" },
    { "/salve help", "Print this command list in chat" },
    { "/salve version", "Print the loaded version and revision" },
    { section = "PANEL" },
    { "/salve lock", "Hide the drag handle" },
    { "/salve reset", "Move Salve back to the centre" },
    { "/salve unlock", "Show the drag handle; handle also works" },
    { section = "DIAGNOSTICS" },
    { "/salve debug", "Print a diagnostic report; probe also works" },
    { "/salve debug copy", "Open a selectable diagnostic report for copy/paste" },
    { "/salve snares", "List auto-captured root and snare spell IDs for sharing" },
    { section = "LEARNING" },
    { "/salve learned", "List recorded auras" },
    { "/salve learned clear", "Clear recorded auras" },
}

O.NewPage({
    name = "Commands",
    title = "Commands",
    group = "REFERENCE",
    description = "Every /salve command.",
}, function(panel, y)
    local rowY = y
    local firstSection = true
    for _, row in ipairs(commands) do
        if row.section then
            if not firstSection then rowY = rowY - 10 end
            firstSection = false
            local heading = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
            heading:SetPoint("TOPLEFT", 16, rowY)
            heading:SetText(row.section)
            heading:SetTextColor(unpack(O.theme.accent))
            rowY = rowY - 20
        else
            local commandRow = CreateFrame("Frame", nil, panel, "BackdropTemplate")
            commandRow:SetPoint("TOPLEFT", 16, rowY)
            commandRow:SetSize(540, 28)
            commandRow:SetBackdrop({
                bgFile = "Interface\\Buttons\\WHITE8X8",
                edgeFile = "Interface\\Buttons\\WHITE8X8",
                edgeSize = 1,
            })
            commandRow:SetBackdropColor(unpack(O.theme.raised))
            commandRow:SetBackdropBorderColor(unpack(O.theme.edge))
            local command = commandRow:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
            command:SetPoint("LEFT", 12, 0)
            command:SetWidth(220)
            command:SetJustifyH("LEFT")
            command:SetText("|cff4c9a7a" .. row[1] .. "|r")

            local does = commandRow:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
            does:SetPoint("LEFT", 240, 0)
            does:SetWidth(285)
            does:SetJustifyH("LEFT")
            does:SetText(row[2])
            rowY = rowY - 30
        end
    end
    return rowY - 8
end)
