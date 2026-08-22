local addonName, ns = ...
local O = ns.Options

local function yesNo(value)
    return value and "yes" or "no"
end

local function moduleStatus()
    if not ns.Sound:NeedsData() then return "off" end
    return ns.Sound.activeModule or "no matching data"
end

local function statusText()
    return table.concat({
        "Zone: " .. tostring(ns.Sound.activeScopeName or "World")
            .. " (" .. tostring(ns.Sound.activeScopeKey or "world:0") .. ")",
        "Sound data: " .. moduleStatus(),
        "Spell IDs: " .. tostring(#ns.Sound:ActiveRecords()),
        "Sound registrations: " .. tostring(ns.Sound.registered)
            .. "/" .. tostring(ns.Sound.expected),
        "Build: " .. tostring(ns.REVISION or ns.VERSION or "unknown"),
    }, "\n")
end

local function buildReport()
    local lines = {
        "Salve diagnostics",
        "Version: " .. tostring(ns.VERSION or "unknown"),
        "Revision: " .. tostring(ns.REVISION or "unknown"),
        "Zone: " .. tostring(ns.Sound.activeScopeName or "World")
            .. " (" .. tostring(ns.Sound.activeScopeKey or "world:0") .. ")",
        "Instance: " .. tostring(ns.Sound.activeInstanceName or "World")
            .. " (" .. tostring(ns.Sound.activeInstanceID or 0) .. ")",
        "Data: " .. moduleStatus(),
        "Sound enabled: " .. yesNo(ns.db.soundEnabled),
        "Aura learning: always on",
        "Cures: " .. ns.CuresText(ns.Sound:CurrentCures()),
        "Spell IDs: " .. tostring(#ns.Sound:ActiveRecords()),
        "Sound registrations: " .. tostring(ns.Sound.registered)
            .. "/" .. tostring(ns.Sound.expected),
        "Aura filter: " .. tostring(ns.DISPELLABLE_FILTER),
    }

    local caps = ns.Binding:Probe()
    if caps.deferred then
        lines[#lines + 1] = "Aura engine: not checked in combat"
    else
        lines[#lines + 1] = "Aura engine: " .. (caps.usable and "ready" or "not ready")
        for _, method in ipairs({ "SetUnit", "AddAuraSlot", "SetEnabled", "UpdateAllAuras" }) do
            lines[#lines + 1] = "  " .. method .. ": " .. yesNo(caps.methods[method])
        end
    end

    lines[#lines + 1] = "Buttons initialised: " .. tostring(ns.Binding.boundCount or 0)
    lines[#lines + 1] = "Containers built: " .. tostring(ns.Binding.containersBuilt or 0)
    if ns.Binding.CooldownDiagnosticLines then
        for _, line in ipairs(ns.Binding:CooldownDiagnosticLines()) do
            lines[#lines + 1] = line
        end
    end
    if ns.Binding.lastFailure then
        lines[#lines + 1] = "Last binding failure: " .. tostring(ns.Binding.lastFailure)
    end
    if ns.Binding.lastCooldownFailure then
        lines[#lines + 1] = "Last cooldown failure: "
            .. tostring(ns.Binding.lastCooldownFailure)
    end
    if ns.Sound.lastFailure then
        lines[#lines + 1] = "Last sound failure: " .. tostring(ns.Sound.lastFailure)
    end

    lines[#lines + 1] = "Bindings:"
    for _, entry in ipairs(ns.Bindings:List()) do
        local what = ns.Bindings:Describe(entry)
        lines[#lines + 1] = "  " .. ns.Bindings:Label(entry.key)
            .. ": " .. tostring(what)
    end

    lines[#lines + 1] = "Detected dispels:"
    if #(ns.knownDispels or {}) == 0 then
        lines[#lines + 1] = "  none"
    else
        for _, spell in ipairs(ns.knownDispels) do
            lines[#lines + 1] = "  " .. spell.name .. ": " .. ns.CuresText(spell.cures)
        end
    end

    return table.concat(lines, "\n")
end

O.BuildDiagnosticReport = buildReport

local copyFrame
local function showCopyReport()
    if not copyFrame then
        local frame = CreateFrame("Frame", "SalveCopyReport", UIParent, "BackdropTemplate")
        frame:SetSize(560, 360)
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
        title:SetText("Copy Salve report")

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
        edit:SetWidth(485)
        edit:SetHeight(800)
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

O.ShowDiagnosticReport = showCopyReport

O.NewPage({
    name = "Troubleshooting",
    description = "Use this when a debuff is missing or Salve looks wrong.",
}, function(panel, y)
    _, y = O.Header(panel, "Status", y)

    local card = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    card:SetPoint("TOPLEFT", 16, y)
    card:SetSize(520, 112)
    card:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 8,
    })
    card:SetBackdropColor(0.045, 0.045, 0.05, 0.9)
    card:SetBackdropBorderColor(0.3, 0.3, 0.33, 0.9)

    local status = card:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    status:SetPoint("TOPLEFT", 14, -12)
    status:SetPoint("BOTTOMRIGHT", -14, 12)
    status:SetJustifyH("LEFT")
    status:SetJustifyV("TOP")

    local function refreshStatus()
        status:SetText(statusText())
    end
    panel.salveRefresh[#panel.salveRefresh + 1] = refreshStatus
    O.RefreshTroubleshooting = refreshStatus
    y = y - 126

    local probe = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    probe:SetSize(150, 22)
    probe:SetPoint("TOPLEFT", 16, y)
    probe:SetText("Run diagnostics")
    O.AttachHint(probe, "Run diagnostics",
        "Check the aura engine, clicks, spell data and sound registrations.")
    probe:SetScript("OnClick", function()
        ns.Binding:Report()
        ns.Sound:Report()
        refreshStatus()
    end)

    local copy = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    copy:SetSize(120, 22)
    copy:SetPoint("LEFT", probe, "RIGHT", 8, 0)
    copy:SetText("Copy report")
    O.AttachHint(copy, "Copy report", "Open a report you can paste into a bug report.")
    copy:SetScript("OnClick", showCopyReport)
    y = y - 48

    _, y = O.Header(panel, "Aura learning", y)

    local note = panel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    note:SetPoint("TOPLEFT", 16, y)
    note:SetWidth(520)
    note:SetJustifyH("LEFT")
    note:SetText("Salve always records readable dispellable aura names, IDs and schools from your group in the separate SalveLearnedDB saved-data block, scoped to each location. It also captures Blizzard-reported roots and snares automatically. Private auras cannot be learned. Use /salve learned clear to remove the recorded catalogue.")
    y = y - 82
    return y
end)
