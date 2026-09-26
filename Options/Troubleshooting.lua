local addonName, ns = ...
local HC = ns.HammerCore
local O, T = ns.Options, HC.Theme

local function yesNo(value)
    return value and "yes" or "no"
end

local function moduleStatus()
    if not ns.Sound:NeedsData() then return "off" end
    return ns.Sound.activeModule or "no built-in data for this instance"
end

local function statusText()
    return table.concat({
        "Zone: " .. tostring(ns.Sound.activeScopeName or "World")
            .. " (" .. tostring(ns.Sound.activeScopeKey or "world:0") .. ")",
        "Sound data: " .. moduleStatus(),
        "Catalogue + learned spell IDs: " .. tostring(#ns.Sound:ActiveRecords()),
        "Sound-candidate spell IDs: " .. tostring(#ns.Sound:ActiveSoundRecords()),
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
        "Revision: " .. tostring(ns.REVISION or "unknown"),
        "Zone: " .. tostring(ns.Sound.activeScopeName or "World")
            .. " (" .. tostring(ns.Sound.activeScopeKey or "world:0") .. ")",
        "Instance: " .. tostring(ns.Sound.activeInstanceName or "World")
            .. " (" .. tostring(ns.Sound.activeInstanceID or 0) .. ")",
        "Data: " .. moduleStatus(),
        "Dispel sound: " .. yesNo(dispelSound),
        "Snare-removal sound: " .. yesNo(movementSound),
        "Player movement detection: " .. tostring(ns.Escape and ns.Escape.lastCaptureStatus or "no player events observed"),
        "Player speed detection: " .. tostring(ns.MovementDetection and ns.MovementDetection.lastStatus
            or "waiting for player movement"),
        "Player movement text: " .. tostring(ns.MovementAlert and ns.MovementAlert.lastStatus or "no message submitted"),
        "Aura learning: always on",
        "Cell-click audit: " .. yesNo(ns.db.clickAuditEnabled)
            .. " (" .. tostring(ns.ClickLog and ns.ClickLog:Count() or 0) .. " entries)",
        "Cures: " .. ns.CuresText(ns.Sound:CurrentCures()),
        "Catalogue + learned spell IDs: " .. tostring(#ns.Sound:ActiveRecords()),
        "Sound-candidate spell IDs: " .. tostring(#ns.Sound:ActiveSoundRecords()),
        "Dispel sound policy: built-in catalogue and known cure school; not a live dispellability check",
        "Movement sound policy: verified removal candidate and matching enabled ability only",
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

O.StatusText = statusText

-- HammerCore owns the copy window, the status card and "Copy report"; Salve
-- adds its own reports and the click log below them.
function O.ShowForeverSpellReport()
    local report = ns.BuildForeverDispelReport and ns.BuildForeverDispelReport()
        or "Salve Forever spell report\nSpell-report support is unavailable."
    HC.Copy:Show("Copy Forever spell report", report)
end

local function showCopyClickLog()
    local content = ns.ClickLog and ns.ClickLog:Export()
        or "Salve cell-click audit\nno click-log storage is available"
    HC.Copy:Show("Copy Salve click log", content)
end

function O.TroubleshootingExtras(panel, y)
    local probe = O.Button(panel, 150, 22)
    probe:SetPoint("TOPLEFT", 16, y)
    probe:SetText("Run diagnostics")
    O.AttachHint(probe, "Run diagnostics",
        "Check the aura engine, clicks, spell data and sound registrations, and print the result.")
    probe:SetScript("OnClick", function()
        ns.Binding:Report()
        ns.Sound:Report()
        panel.hcRefreshAll()
    end)
    local forever = O.Button(panel, 165, 22)
    forever:SetPoint("LEFT", probe, "RIGHT", 8, 0)
    forever:SetText("Copy Forever spells")
    O.AttachHint(forever, "Copy Forever spells",
        "Copy the detected Forever cure families and observed spellbook IDs for a missing-ability report. This never enables manually entered spells.")
    forever:SetScript("OnClick", O.ShowForeverSpellReport)
    y = y - 38

    _, y = O.Header(panel, "Aura learning", y)
    _, y = O.Text(panel, "Records readable dispellable auras and reported roots or snares; private auras cannot be recorded.", y)
    y = y - 8

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
        panel.hcRefreshAll()
    end)
    local copyLog = O.Button(panel, 120, 22)
    copyLog:SetPoint("LEFT", clear, "RIGHT", 8, 0)
    copyLog:SetText("Copy click log")
    O.AttachHint(copyLog, "Copy click log",
        "Open a timestamped, copy-ready export of recorded Salve-cell clicks.")
    copyLog:SetScript("OnClick", showCopyClickLog)
    return y - 38
end
