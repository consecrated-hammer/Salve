local addonName, ns = ...

-- ============================================================
-- Probe: a small on-screen troubleshooting helper
-- ============================================================
-- Opened only by the "Open probe" button in Troubleshooting.
-- Nothing runs until then, and it never reopens by itself after a reload.
-- While open it snapshots what this client lets Salve see about range and
-- debuffs, two seconds into each fight and when you hover a cell, and copies
-- the lot in one go. Built to answer whether Blizzard has changed the rules.
--
-- Every read is pcall'd and every value is described, never compared: a
-- secret value may be stored, passed and concatenated, nothing else.

ns.Probe = { open = false, boxEnters = 0, boxClicks = 0 }
local Probe = ns.Probe

local MAX_UNITS = 5
local LOG_MAX = 30

local function isSecret(value)
    return issecretvalue and issecretvalue(value) and true or false
end

local function describe(value)
    if isSecret(value) then return "secret" end
    local kind = type(value)
    if kind == "nil" then return "nil" end
    if kind == "boolean" or kind == "number" then return kind .. " " .. tostring(value) end
    if kind == "string" then return "string \"" .. value .. "\"" end
    return kind
end

-- Text that may be secret: concatenation is allowed, so show it either way.
local function showText(value)
    if not isSecret(value) and value == nil then return "nil" end
    local ok, text = pcall(function() return "\"" .. value .. "\"" end)
    if not ok then return "unprintable (" .. tostring(text) .. ")" end
    return text .. (isSecret(value) and " (secret)" or "")
end

-- pcall and describe the first result, or the error.
local function try(fn, ...)
    if type(fn) ~= "function" then return "missing" end
    local ok, result = pcall(fn, ...)
    if not ok then return "error: " .. tostring(result) end
    return describe(result)
end

local function inCombat()
    return InCombatLockdown and InCombatLockdown() and true or false
end

local function privateTooltip()
    if not Probe.tooltip and CreateFrame then
        local ok, tip = pcall(CreateFrame, "GameTooltip", "SalveProbeTooltip", nil, "GameTooltipTemplate")
        if ok then Probe.tooltip = tip end
    end
    return Probe.tooltip
end

local function tooltipSummary(tip)
    local okLines, count = pcall(tip.NumLines, tip)
    local left = _G.SalveProbeTooltipTextLeft1
    local okText, text = false, nil
    if left and left.GetText then okText, text = pcall(left.GetText, left) end
    return "lines " .. (okLines and describe(count) or "error") .. ", first "
        .. (okText and showText(text) or "unreadable")
end

local function rangeLines(lines, unit)
    local ok, inRange, checked = pcall(UnitInRange, unit)
    lines[#lines + 1] = "    UnitInRange: " .. (ok and (describe(inRange) .. ", checked " .. describe(checked))
        or ("error: " .. tostring(inRange)))
    if C_Spell and C_Spell.IsSpellInRange and type(ns.spellID) == "number" then
        lines[#lines + 1] = "    IsSpellInRange(" .. ns.spellID .. "): " .. try(C_Spell.IsSpellInRange, ns.spellID, unit)
    end
    lines[#lines + 1] = "    UnitIsConnected: " .. try(UnitIsConnected, unit)
    if ns.Range then
        local okRange, result = pcall(ns.Range.InRange, ns.Range, unit)
        lines[#lines + 1] = "    Salve range: " .. (okRange and describe(result) or "error")
            .. " (" .. tostring(ns.Range.lastStatus) .. ")"
    end
end

local function auraLines(lines, unit)
    if not (C_UnitAuras and C_UnitAuras.GetAuraDataByIndex) then
        lines[#lines + 1] = "    GetAuraDataByIndex: missing"
        return
    end
    local ok, aura = pcall(C_UnitAuras.GetAuraDataByIndex, unit, 1, ns.DISPELLABLE_FILTER)
    if not ok then
        lines[#lines + 1] = "    GetAuraDataByIndex: error: " .. tostring(aura)
    elseif not isSecret(aura) and aura == nil then
        lines[#lines + 1] = "    GetAuraDataByIndex: no dispellable debuff"
    else
        lines[#lines + 1] = "    GetAuraDataByIndex: " .. describe(aura)
        if type(aura) == "table" and not isSecret(aura) then
            local okName, name = pcall(function() return aura.name end)
            lines[#lines + 1] = "    aura.name: " .. (okName and showText(name) or "error")
        end
    end

    -- Can the game fill a tooltip with the debuff for us? In Midnight combat
    -- it answers with an empty tooltip, which is why the debuff tooltip is
    -- Blizzard's own.
    local tip = privateTooltip()
    if tip and type(tip.SetUnitDebuff) == "function" then
        pcall(tip.SetOwner, tip, WorldFrame or UIParent, "ANCHOR_NONE")
        local okSet, err = pcall(tip.SetUnitDebuff, tip, unit, 1, ns.DISPELLABLE_FILTER)
        lines[#lines + 1] = "    SetUnitDebuff: " .. (okSet and ("ok, " .. tooltipSummary(tip)) or ("error: " .. tostring(err)))
        pcall(tip.Hide, tip)
    end
end

function Probe:DiagnosticLines()
    local lines = {}
    lines[#lines + 1] = "Probe, Salve " .. tostring(ns.VERSION or "?") .. " ("
        .. (inCombat() and "in combat" or "out of combat") .. "):"
    local count = 0
    for _, box in ipairs(ns.Panel and ns.Panel.boxes or {}) do
        if box.unit and count < MAX_UNITS then
            count = count + 1
            lines[#lines + 1] = "  " .. box.unit .. ":"
            rangeLines(lines, box.unit)
            auraLines(lines, box.unit)
        end
    end
    if count == 0 then lines[#lines + 1] = "  no live cells" end
    local f = Probe.alphaFrame
    if not f and CreateFrame then
        local ok, frame = pcall(CreateFrame, "Frame")
        if ok then Probe.alphaFrame, f = frame, frame end
    end
    lines[#lines + 1] = "  SetAlphaFromBoolean: " .. ((f and type(f.SetAlphaFromBoolean) == "function") and "yes" or "no")
    lines[#lines + 1] = "  debuff tooltip: " .. ((ns.db and ns.db.tooltipDebuff ~= false) and "on" or "off")
        .. ", out of range opacity " .. tostring(ns.db and ns.db.outOfRangeAlpha)
    lines[#lines + 1] = "  cell hovers " .. self.boxEnters .. ", cell clicks " .. self.boxClicks
    return lines
end

-- ── Log ────────────────────────────────────────────────────────────────────

local function log()
    ns.db.probeLog = type(ns.db.probeLog) == "table" and ns.db.probeLog or {}
    return ns.db.probeLog
end

function Probe:Snapshot(reason)
    local entries = log()
    local stamp = date and date("%H:%M:%S") or "?"
    entries[#entries + 1] = "[" .. stamp .. "] " .. tostring(reason or "manual") .. "\n"
        .. table.concat(self:DiagnosticLines(), "\n")
    while #entries > LOG_MAX do table.remove(entries, 1) end
    self:UpdateHelper()
end

function Probe:CopyLog()
    local HC = ns.HammerCore
    local text = table.concat(log(), "\n\n")
    if text == "" then text = "No snapshots yet." end
    if HC and HC.Copy then HC.Copy:Show("Salve probe results", text) end
end

function Probe:ClearLog()
    ns.db.probeLog = {}
    self.boxEnters, self.boxClicks = 0, 0
    self:UpdateHelper()
end

function Probe:NoteBoxEnter()
    if not self.open then return end
    self.boxEnters = self.boxEnters + 1
    local now = GetTime and GetTime() or 0
    if self.lastHoverSnapshot and now - self.lastHoverSnapshot < 3 then return end
    self.lastHoverSnapshot = now
    self:Snapshot("auto: cell hover")
end

function Probe:NoteBoxClick()
    if not self.open then return end
    self.boxClicks = self.boxClicks + 1
    self:UpdateHelper()
end

-- ── Window ─────────────────────────────────────────────────────────────────
-- Plain frames only, so every button works in combat. The combat event is
-- registered only while the window is open.

local function helperButton(parent, label, onClick)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(112, 22)
    b:SetText(label)
    b:SetScript("OnClick", onClick)
    return b
end

function Probe:BuildHelper()
    if self.helper then return self.helper end
    local f = CreateFrame("Frame", "SalveProbeHelper", UIParent, "BackdropTemplate")
    f:SetSize(250, 100)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 200)
    f:SetFrameStrata("DIALOG")
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    if f.SetBackdrop then
        f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
        f:SetBackdropColor(0.05, 0.06, 0.08, 0.92)
        f:SetBackdropBorderColor(0.45, 0.82, 0.68, 1)
    end
    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.title:SetPoint("TOPLEFT", 10, -8)
    f.title:SetText("Salve probe  |cff888888" .. tostring(ns.VERSION or "?") .. "|r")
    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 2, 2)
    close:SetScript("OnClick", function() Probe:Show(false) end)
    f.status = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.status:SetPoint("TOPLEFT", 10, -28)
    f.status:SetPoint("RIGHT", -10, 0)
    f.status:SetJustifyH("LEFT")

    local snapshot = helperButton(f, "Snapshot", function() Probe:Snapshot("manual") end)
    snapshot:SetPoint("TOPLEFT", 10, -44)
    local clear = helperButton(f, "Clear", function() Probe:ClearLog() end)
    clear:SetPoint("TOPRIGHT", -10, -44)
    local copy = helperButton(f, "Copy results", function() Probe:CopyLog() end)
    copy:SetPoint("TOPLEFT", 10, -70)
    copy:SetWidth(230)

    f:SetScript("OnEvent", function()
        if C_Timer and C_Timer.After then
            C_Timer.After(2, function() if Probe.open then Probe:Snapshot("auto: 2s into combat") end end)
        end
    end)
    self.helper = f
    return f
end

function Probe:UpdateHelper()
    local f = self.helper
    if not f then return end
    f.status:SetText(("Snapshots %d, cell hovers %d, clicks %d"):format(#log(), self.boxEnters, self.boxClicks))
end

function Probe:Show(show)
    if show == nil then show = not self.open end
    self.open = show and true or false
    if show then
        local f = self:BuildHelper()
        f:RegisterEvent("PLAYER_REGEN_DISABLED")
        f:Show()
        self:UpdateHelper()
    elseif self.helper then
        self.helper:UnregisterEvent("PLAYER_REGEN_DISABLED")
        self.helper:Hide()
    end
end
