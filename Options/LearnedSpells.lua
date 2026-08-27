local addonName, ns = ...
local O = ns.Options

-- This is Salve's learned catalogue, not the character spellbook. Every entry
-- is a positive observation: readable dispellable auras are scoped to where
-- they were seen, while Blizzard's loss-of-control feed supplies roots/snares.
-- Absence is deliberately not a claim that an encounter has no other spells.
local function sortedKeys(tableValue)
    local keys = {}
    for key in pairs(type(tableValue) == "table" and tableValue or {}) do
        keys[#keys + 1] = key
    end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    return keys
end

local function appendAuraCatalogue(lines, learned)
    lines[#lines + 1] = "## Learned dispellable auras"
    local scopeKeys = {}
    for scopeKey, bucket in pairs(type(learned.auras) == "table" and learned.auras or {}) do
        if type(bucket) == "table" and type(bucket.spells) == "table" and next(bucket.spells) then
            scopeKeys[#scopeKeys + 1] = scopeKey
        end
    end
    table.sort(scopeKeys)
    if #scopeKeys == 0 then
        lines[#lines + 1] = "No readable dispellable auras recorded yet."
        lines[#lines + 1] = ""
        return
    end

    for _, scopeKey in ipairs(scopeKeys) do
        local bucket = learned.auras[scopeKey]
        lines[#lines + 1] = "### " .. tostring(bucket.name or "Unknown location")
            .. " (" .. tostring(scopeKey) .. ")"
        lines[#lines + 1] = ""
        for _, spellID in ipairs(sortedKeys(bucket.spells)) do
            local record = bucket.spells[spellID]
            record = type(record) == "table" and record or { name = record }
            local fields = { "spell ID " .. tostring(spellID) }
            if type(record.dispelType) == "string" and record.dispelType ~= "" then
                fields[#fields + 1] = record.dispelType
            end
            if type(record.provenance) == "string" and record.provenance ~= "" then
                fields[#fields + 1] = record.provenance
            end
            lines[#lines + 1] = "- " .. tostring(record.name or "Unknown spell")
                .. " (" .. table.concat(fields, "; ") .. ")"
        end
        lines[#lines + 1] = ""
    end
end

local function appendMovementCatalogue(lines, learned)
    lines[#lines + 1] = "## Learned roots and snares"
    local movement = type(learned.movement) == "table" and learned.movement or {}
    local spellIDs = sortedKeys(movement)
    if #spellIDs == 0 then
        lines[#lines + 1] = "No Blizzard-reported roots or snares recorded yet."
        lines[#lines + 1] = ""
        return
    end

    for _, spellID in ipairs(spellIDs) do
        local name = movement[spellID]
        lines[#lines + 1] = "- " .. tostring(name == true and "Unknown spell" or name)
            .. " (spell ID " .. tostring(spellID) .. "; Blizzard loss-of-control)"
    end
    lines[#lines + 1] = ""
end

local function buildReport()
    local lines = {
        "Salve learned-spell export",
        "Character: " .. tostring(UnitName and UnitName("player") or "unknown"),
        "Scope: Salve's positive observations of readable dispellable auras and Blizzard-reported roots or snares. Missing entries remain unknown.",
        "",
    }
    local learned = type(ns.learned) == "table" and ns.learned or {}
    appendAuraCatalogue(lines, learned)
    appendMovementCatalogue(lines, learned)
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
        title:SetText("Copy Salve-learned spells")
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
    description = "Dispellable auras, roots and snares Salve has recorded while you play.",
}, function(panel, y)
    _, y = O.Header(panel, "Salve's learned spells", y)
    local note = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    note:SetPoint("TOPLEFT", 16, y)
    note:SetWidth(520)
    note:SetJustifyH("LEFT")
    note:SetText("This is Salve's learned catalogue, not your spellbook. It shows only positive observations; missing spells remain unknown.")
    y = y - 46

    local list = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    list:SetPoint("TOPLEFT", 16, y)
    list:SetWidth(520)
    list:SetJustifyH("LEFT")
    list:SetJustifyV("TOP")

    local copy = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    copy:SetSize(170, 22)
    copy:SetText("Copy learned spells")
    O.AttachHint(copy, "Copy learned spells", "Copy the same Salve-learned catalogue, ready for Ctrl+C.")
    copy:SetScript("OnClick", showCopyReport)

    local listHeight = 42
    local function render()
        local report = buildReport()
        list:SetText(report)
        local lineCount = 1
        for _ in report:gmatch("\n") do lineCount = lineCount + 1 end
        listHeight = math.max(42, lineCount * 15)
        list:SetHeight(listHeight)
        copy:ClearAllPoints()
        copy:SetPoint("TOPLEFT", list, "BOTTOMLEFT", 0, -14)
        panel.salveSetBottom(-46 - listHeight - 46)
    end
    panel.salveRefresh[#panel.salveRefresh + 1] = render
    render()
    return -46 - listHeight - 46
end)
