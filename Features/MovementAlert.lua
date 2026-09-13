local addonName, ns = ...

-- Text instructions for roots and snares that an enabled universally-applicable
-- action can answer. This deliberately receives only the plain loss-of-control
-- classification and unit token; it never inspects an aura or claims a cell is
-- lit/actionable.

ns.MovementAlert = {}
local MovementAlert = ns.MovementAlert

-- Chat tabs are local display frames, never network chat channels. Persist
-- the slot and check it at delivery time in case the tab has been closed.
function MovementAlert:ChatWindows()
    local values, labels = { 0 }, { "Default chat window" }
    for id = 1, (NUM_CHAT_WINDOWS or 10) do
        local name = GetChatWindowInfo and GetChatWindowInfo(id)
        local frame = _G["ChatFrame" .. id]
        if type(name) == "string" and name ~= "" and frame and not frame.isTemporary then
            values[#values + 1], labels[#labels + 1] = id, name .. " (" .. id .. ")"
        end
    end
    local selected = tonumber(ns.db.movementChatWindow) or 0
    local found = false
    for _, id in ipairs(values) do if id == selected then found = true end end
    if not found then
        values[#values + 1], labels[#labels + 1] = selected, "Missing tab; using default"
    end
    return values, labels
end

function MovementAlert:PrintChat(message)
    local id = tonumber(ns.db.movementChatWindow) or 0
    local name = id > 0 and GetChatWindowInfo and GetChatWindowInfo(id)
    local frame = type(name) == "string" and name ~= "" and _G["ChatFrame" .. id]
    if not frame or frame.isTemporary or not frame.AddMessage then frame = DEFAULT_CHAT_FRAME end
    if frame and frame.AddMessage then
        frame:AddMessage("|cff66ddaaSalve:|r " .. message)
    else
        ns.Print(message)
    end
end

function MovementAlert:Frame()
    if self.frame then return self.frame end
    local f = CreateFrame("Frame", nil, UIParent)
    self.frame = f
    f:SetSize(460, 70)
    f:SetFrameStrata("DIALOG")
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    local text = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    text:SetAllPoints()
    f.text = text
    f:SetScript("OnDragStart", function() if self.preview then f:StartMoving() end end)
    f:SetScript("OnDragStop", function()
        f:StopMovingOrSizing()
        local x, y = f:GetCenter()
        local cx, cy = UIParent:GetCenter()
        ns.db.movementTextX, ns.db.movementTextY = x - cx, y - cy
    end)
    f:SetScript("OnUpdate", function(_, elapsed)
        if self.preview then return end
        self.remaining = (self.remaining or 0) - elapsed
        if self.remaining <= 0 then f:Hide() end
    end)
    f:Hide()
    return f
end

function MovementAlert:Position()
    local f = self:Frame()
    f:ClearAllPoints()
    f:SetPoint("CENTER", UIParent, "CENTER",
        tonumber(ns.db.movementTextX) or 0, tonumber(ns.db.movementTextY) or 160)
end

function MovementAlert:StopPreview()
    if not self.preview then return end
    self.preview = false
    if self.frame then
        self.frame:StopMovingOrSizing()
        self.frame:EnableMouse(false)
        self.frame:Hide()
    end
end

function MovementAlert:TogglePreview()
    if self.preview then self:StopPreview() return end
    if InCombatLockdown and InCombatLockdown() then return end
    local message = "|cffffa020YOU ARE ROOTED — BLESSING OF FREEDOM|r"
    local destination = ns.db.movementTextOutput or "SCREEN"
    if destination == "CHAT" or destination == "BOTH" then
        self:PrintChat(message)
        if destination == "CHAT" then return end
    end
    self:Position()
    self.preview = true
    self.frame.text:SetText("YOU ARE ROOTED — BLESSING OF FREEDOM\nDrag to position; click Preview again to finish")
    self.frame:EnableMouse(true)
    self.frame:Show()
end

local function show(message)
    local destination = ns.db.movementTextOutput or "SCREEN"
    if destination == "CHAT" or destination == "BOTH" then
        MovementAlert:PrintChat(message)
        if destination == "CHAT" then return true end
    end
    MovementAlert:StopPreview()
    MovementAlert:Position()
    MovementAlert.remaining = 4
    MovementAlert.frame:EnableMouse(false)
    MovementAlert.frame.text:SetText(message)
    MovementAlert.frame:Show()
    return true
end

function MovementAlert:Notify(unit, movement, spell)
    if unit ~= "player" then return false end
    if not (ns.db and ns.db.movementTextNotification and spell) then return false end
    local kind = movement and (movement.kind or movement.locType)
    if kind ~= "ROOT" and kind ~= "SNARE" and kind ~= "SLOW" then return false end
    local effect = kind == "ROOT" and "ROOTED" or (kind == "SLOW" and "SLOWED" or "SNARED")
    local key = ns.Bindings and ns.Bindings.FirstKeyForSpell and ns.Bindings:FirstKeyForSpell(spell.id)
    local action = key and ns.Bindings:Label(key):upper() .. ": " or ""
    local delivered = show("|cffffa020YOU ARE " .. effect .. " — " .. action
        .. tostring(spell.name or "MOVEMENT REMOVAL"):upper() .. "|r")
    self.lastStatus = delivered and "message submitted" or "message output unavailable"
    return delivered
end
