local addonName, ns = ...
local O = ns.Options

-- This is intentionally a factual, local snapshot: it reports only entries
-- Retail exposes in the player spellbook at the moment it is opened. It does
-- not infer hidden abilities or treat an omitted entry as unlearned.
local function buildReport()
    local lines = {
        "Salve learned-spell export",
        "Character: " .. tostring(UnitName and UnitName("player") or "unknown"),
        "Scope: entries currently exposed in Retail's player spellbook; inactive or hidden abilities may be absent.",
        "",
    }

    if not (C_SpellBook and C_SpellBook.GetNumSpellBookSkillLines
        and C_SpellBook.GetSpellBookSkillLineInfo and C_SpellBook.GetSpellBookItemInfo
        and Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player) then
        lines[#lines + 1] = "Unavailable: this WoW client does not expose the modern spellbook API."
        return table.concat(lines, "\n")
    end

    local ok, lineCount = pcall(C_SpellBook.GetNumSpellBookSkillLines)
    if not ok or type(lineCount) ~= "number" then
        lines[#lines + 1] = "Unavailable: Retail did not return spellbook skill lines."
        return table.concat(lines, "\n")
    end

    local spellType = Enum.SpellBookItemType and Enum.SpellBookItemType.Spell
    local emitted = 0
    for lineIndex = 1, math.min(lineCount, 128) do
        local lineOK, line = pcall(C_SpellBook.GetSpellBookSkillLineInfo, lineIndex)
        local offset = lineOK and line and tonumber(line.itemIndexOffset)
        local count = lineOK and line and tonumber(line.numSpellBookItems)
        local entries = {}
        if offset and count and count > 0 then
            for itemOffset = 1, math.min(count, 1024) do
                local itemOK, item = pcall(C_SpellBook.GetSpellBookItemInfo,
                    offset + itemOffset, Enum.SpellBookSpellBank.Player)
                local spellID = itemOK and item and item.spellID
                local isSpell = type(spellID) == "number"
                    and (spellType == nil or item.itemType == spellType)
                if isSpell then
                    local info = C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(spellID)
                    local flags = {}
                    if item.isOffSpec then flags[#flags + 1] = "off-spec" end
                    if item.isPassive then flags[#flags + 1] = "passive" end
                    entries[#entries + 1] = {
                        id = spellID,
                        name = (info and info.name) or item.name or "Unknown spell",
                        suffix = #flags > 0 and "; " .. table.concat(flags, "; ") or "",
                    }
                end
            end
        end
        if #entries > 0 then
            table.sort(entries, function(a, b)
                if a.name == b.name then return a.id < b.id end
                return a.name < b.name
            end)
            lines[#lines + 1] = "## " .. tostring(line.name or ("Spellbook section " .. lineIndex))
            lines[#lines + 1] = ""
            for _, entry in ipairs(entries) do
                lines[#lines + 1] = "- " .. entry.name .. " (spell ID " .. entry.id .. entry.suffix .. ")"
                emitted = emitted + 1
            end
            lines[#lines + 1] = ""
        end
    end
    if emitted == 0 then lines[#lines + 1] = "No spell entries were exposed by the current spellbook." end
    return table.concat(lines, "\n")
end

O.BuildLearnedSpellReport = buildReport

local copyFrame
local function showCopyReport()
    if not copyFrame then
        local frame = CreateFrame("Frame", "SalveCopyLearnedSpells", UIParent, "BackdropTemplate")
        frame:SetSize(620, 460)
        frame:SetPoint("CENTER")
        frame:SetFrameStrata("FULLSCREEN_DIALOG")
        frame:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 12,
        })
        frame:SetBackdropColor(0.035, 0.035, 0.04, 0.98)
        frame:SetBackdropBorderColor(0.58, 0.43, 0.22, 1)
        frame:EnableMouse(true)
        frame:Hide()

        local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        title:SetPoint("TOPLEFT", 18, -16)
        title:SetText("Copy learned spells")
        local help = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        help:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -5)
        help:SetText("Press Ctrl+C, then Escape.")

        local scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", 18, -66)
        scroll:SetPoint("BOTTOMRIGHT", -38, 44)
        local edit = CreateFrame("EditBox", nil, scroll)
        edit:SetMultiLine(true)
        edit:SetAutoFocus(false)
        edit:SetFontObject(ChatFontNormal)
        edit:SetWidth(545)
        edit:SetHeight(2400)
        edit:SetTextInsets(4, 4, 4, 4)
        edit:SetScript("OnEscapePressed", function() frame:Hide() end)
        scroll:SetScrollChild(edit)
        frame.edit = edit

        local close = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        close:SetSize(90, 22)
        close:SetPoint("BOTTOMRIGHT", -18, 14)
        close:SetText("Close")
        close:SetScript("OnClick", function() frame:Hide() end)
        frame:SetScript("OnHide", function() edit:ClearFocus() end)
        copyFrame = frame
    end
    copyFrame.edit:SetText(buildReport())
    copyFrame:Show()
    copyFrame.edit:SetFocus()
    copyFrame.edit:HighlightText()
end

O.ShowLearnedSpellReport = showCopyReport

O.NewPage({
    name = "Learned Spells",
    description = "Copy the spellbook entries this Retail client currently exposes for your character.",
}, function(panel, y)
    _, y = O.Header(panel, "Export learned spells", y)
    local note = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    note:SetPoint("TOPLEFT", 16, y)
    note:SetWidth(520)
    note:SetJustifyH("LEFT")
    note:SetText("This local plain-text export includes spell names, IDs, spellbook sections, and off-spec/passive markers when the client supplies them.")
    y = y - 52

    local copy = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    copy:SetSize(170, 22)
    copy:SetPoint("TOPLEFT", 16, y)
    copy:SetText("Copy learned spells")
    O.AttachHint(copy, "Copy learned spells", "Open the complete current spellbook list, ready for Ctrl+C.")
    copy:SetScript("OnClick", showCopyReport)
    return y - 42
end)
