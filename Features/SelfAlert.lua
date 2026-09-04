local addonName, ns = ...

-- Self-only instructions for exceptional server-scripted dispels that have no
-- Blizzard dispel type. This is deliberately not a group-target detector or
-- cell highlight: it only tells the affected player to act for themself.

ns.SelfAlert = {}
local SelfAlert = ns.SelfAlert
local plain = ns.Sound.Plain

local frame = CreateFrame("Frame")
frame:SetScript("OnEvent", function() SelfAlert:OnCombatLog() end)
SelfAlert.active = false

local function show(message)
    -- Floating combat text is the preferred, low-noise delivery. UIErrorsFrame
    -- is retained only for UIs that do not expose the combat-text helper.
    if CombatText_AddMessage and CombatText_StandardScroll then
        pcall(CombatText_AddMessage, message, CombatText_StandardScroll,
            1, 0.22, 0.22, "crit")
        return
    end
    if UIErrorsFrame and UIErrorsFrame.AddMessage then
        pcall(UIErrorsFrame.AddMessage, UIErrorsFrame, message, 1, 0.22, 0.22)
    end
end

function SelfAlert:OnCombatLog()
    if not (ns.db and ns.db.selfDispelNotification) then return end
    if not (CombatLogGetCurrentEventInfo and UnitGUID and ns.Sound) then return end

    local ok, _, eventType, _, _, _, _, _, destinationGUID, _, _, _, spellID =
        pcall(CombatLogGetCurrentEventInfo)
    if not ok or plain(eventType) ~= "SPELL_AURA_APPLIED" then return end
    destinationGUID, spellID = plain(destinationGUID), plain(spellID)
    local playerGUID = plain(UnitGUID("player"))
    if not destinationGUID or not playerGUID or destinationGUID ~= playerGUID then return end

    local record = ns.Sound:ActiveSelfDispelAlerts()[spellID]
    if not record then return end
    show("|cffff3838" .. tostring(record.name or "DISPEL") .. " - DISPEL YOURSELF|r")
end

-- CLEU cannot be unit-filtered, so do not subscribe to its high-volume event
-- stream outside a scope with a reviewed self-only alert this character can
-- actually answer. On a relevant pull, the destination GUID check above is
-- still the first action after decoding the event.
function SelfAlert:Update()
    local alerts = ns.Sound and ns.Sound.ActiveSelfDispelAlerts
        and ns.Sound:ActiveSelfDispelAlerts() or {}
    local shouldListen = ns.db and ns.db.selfDispelNotification and next(alerts) ~= nil
    if shouldListen == self.active then return end
    self.active = shouldListen
    if shouldListen then
        frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    else
        frame:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    end
end
