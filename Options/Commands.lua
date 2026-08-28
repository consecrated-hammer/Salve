local addonName, ns = ...
local O = ns.Options

local commands = {
    { "/salve or /salve options", "Open settings; config and opt also work" },
    { "/salve lock", "Hide the drag handle" },
    { "/salve unlock", "Show the drag handle; handle also works" },
    { "/salve reset", "Move Salve back to the centre" },
    { "/salve version", "Print the loaded version and revision" },
    { "/salve debug", "Print a diagnostic report; probe also works" },
    { "/salve debug copy", "Open a selectable diagnostic report for copy/paste" },
    { "/salve snares", "List auto-captured root and snare spell IDs for sharing" },
    { "/salve learned", "List recorded auras" },
    { "/salve learned clear", "Clear recorded auras" },
    { "/salve help", "Print this command list in chat" },
}

O.NewPage({
    name = "Commands",
    title = "Commands",
    group = "REFERENCE",
    description = "Every /salve command.",
}, function(panel, y)
    _, y = O.Header(panel, "Commands", y)
    local list = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    list:SetPoint("TOPLEFT", 16, y)
    list:SetSize(540, #commands * 28)
    list:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    list:SetBackdropColor(unpack(O.theme.raised))
    list:SetBackdropBorderColor(unpack(O.theme.edge))
    for index, row in ipairs(commands) do
        local rowY = -8 - (index - 1) * 28
        local command = list:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        command:SetPoint("TOPLEFT", 12, rowY)
        command:SetWidth(220)
        command:SetJustifyH("LEFT")
        command:SetText("|cff4c9a7a" .. row[1] .. "|r")

        local does = list:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        does:SetPoint("TOPLEFT", 240, rowY)
        does:SetWidth(285)
        does:SetJustifyH("LEFT")
        does:SetText(row[2])
        if index < #commands then
            local divider = list:CreateTexture(nil, "ARTWORK")
            divider:SetPoint("TOPLEFT", 1, -index * 28)
            divider:SetPoint("TOPRIGHT", -1, -index * 28)
            divider:SetHeight(1)
            divider:SetColorTexture(unpack(O.theme.edge))
        end
    end
    return y - #commands * 28 - 20
end)
