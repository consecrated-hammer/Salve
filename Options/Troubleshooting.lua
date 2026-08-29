local addonName, ns = ...
local O = ns.Options

local function yesNo(value)
    return value and "yes" or "no"
end

local function moduleStatus()
    if not ns.Sound:NeedsData() then return "off" end
    return ns.Sound.activeModule or "built-in catalogue unavailable"
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
    local dispelSound = ns.db.dispelSoundEnabled
    if dispelSound == nil then dispelSound = ns.db.soundEnabled end
    local movementSound = ns.db.movementSoundEnabled
    if movementSound == nil then movementSound = ns.db.soundEnabled end
    local lines = {
        "Salve diagnostics",
        "Version: " .. tostring(ns.VERSION or "unknown"),
        "Revision: " .. tostring(ns.REVISION or "unknown"),
        "Zone: " .. tostring(ns.Sound.activeScopeName or "World")
            .. " (" .. tostring(ns.Sound.activeScopeKey or "world:0") .. ")",
        "Instance: " .. tostring(ns.Sound.activeInstanceName or "World")
            .. " (" .. tostring(ns.Sound.activeInstanceID or 0) .. ")",
        "Data: " .. moduleStatus(),
        "Dispel sound: " .. yesNo(dispelSound),
        "Snare-removal sound: " .. yesNo(movementSound),
        "Aura learning: always on",
        "Cell-click audit: " .. yesNo(ns.db.clickAuditEnabled)
            .. " (" .. tostring(ns.ClickLog and ns.ClickLog:Count() or 0) .. " entries)",
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
local function showCopyText(titleText, content)
    if not copyFrame then
        local frame = CreateFrame("Frame", "SalveCopyReport", UIParent, "BackdropTemplate")
        frame:SetSize(640, 360)
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
        frame.title = title

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
        edit:SetWidth(565)
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

    copyFrame.title:SetText(titleText)
    copyFrame.edit:SetText(content)
    copyFrame:Show()
    copyFrame.edit:SetFocus()
    copyFrame.edit:HighlightText()
end

local function showCopyReport()
    showCopyText("Copy Salve report", buildReport())
end

local function showCopyClickLog()
    local content = ns.ClickLog and ns.ClickLog:Export()
        or "Salve cell-click audit\nno click-log storage is available"
    showCopyText("Copy Salve click log", content)
end

O.ShowDiagnosticReport = showCopyReport

O.NewPage({
    name = "Troubleshooting",
    title = "Troubleshooting",
    group = "REFERENCE",
    description = "Check Salve status.",
}, function(panel, y)
    _, y = O.Header(panel, "Status", y)

    local card = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    card:SetPoint("TOPLEFT", 16, y)
    card:SetSize(520, 112)
    card:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    card:SetBackdropColor(unpack(O.theme.rail))
    card:SetBackdropBorderColor(unpack(O.theme.edge))

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

    local probe = O.Button(panel, 150, 22)
    probe:SetPoint("TOPLEFT", 16, y)
    probe:SetText("Run diagnostics")
    O.AttachHint(probe, "Run diagnostics",
        "Check the aura engine, clicks, spell data and sound registrations.")
    probe:SetScript("OnClick", function()
        ns.Binding:Report()
        ns.Sound:Report()
        refreshStatus()
    end)

    local copy = O.Button(panel, 120, 22)
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
    note:SetText("Records readable dispellable auras and Blizzard-reported roots or snares. Private auras cannot be recorded.")
    y = y - 42

    _, y = O.Header(panel, "Debug logging", y)
    _, y = O.Check(panel, "Record armed Salve-cell clicks",
        "Off by default. Saves timestamp, unit token, mouse binding and the selected Salve action to SalveClickLog. It cannot record a private aura's name.",
        y, function() return ns.db.clickAuditEnabled end,
        function(value) ns.Set("clickAuditEnabled", value) end)

    local clear = O.Button(panel, 120, 22)
    clear:SetPoint("TOPLEFT", 16, y)
    clear:SetText("Clear click log")
    O.AttachHint(clear, "Clear click log", "Remove saved Salve-cell click history.")
    clear:SetScript("OnClick", function()
        if ns.ClickLog then ns.ClickLog:Clear() end
        refreshStatus()
    end)
    local copyLog = O.Button(panel, 120, 22)
    copyLog:SetPoint("LEFT", clear, "RIGHT", 8, 0)
    copyLog:SetText("Copy click log")
    O.AttachHint(copyLog, "Copy click log",
        "Open a timestamped, copy-ready export of recorded Salve-cell clicks.")
    copyLog:SetScript("OnClick", showCopyClickLog)
    y = y - 38
    return y
end)
