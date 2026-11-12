local addonName, ns = ...

-- ============================================================
-- Cast trace: /salve trace
-- ============================================================
-- Prints your own spell casts and the game's red error text while it's on,
-- for checking what a click or macro really did (say, whether a two-line
-- dispel macro reached its second line). Off after every reload. Spell IDs
-- can be secret in restricted content; then the line just says so.

ns.CastTrace = { on = false }
local CastTrace = ns.CastTrace

local EVENTS = {
    UNIT_SPELLCAST_SENT = 4,          -- unit, target, castGUID, spellID
    UNIT_SPELLCAST_SUCCEEDED = 3,     -- unit, castGUID, spellID
    UNIT_SPELLCAST_FAILED = 3,
    UNIT_SPELLCAST_FAILED_QUIET = 3,
    UNIT_SPELLCAST_INTERRUPTED = 3,
}

local function isSecret(value)
    return issecretvalue and issecretvalue(value) and true or false
end

local function spellText(spellID)
    if isSecret(spellID) then return "a hidden spell" end
    if type(spellID) ~= "number" then return tostring(spellID) end
    local name = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(spellID)
        or (GetSpellInfo and GetSpellInfo(spellID))
    return (name or "?") .. " (" .. spellID .. ")"
end

local frame = CreateFrame("Frame")
frame:SetScript("OnEvent", function(_, event, ...)
    if event == "UI_ERROR_MESSAGE" then
        local message = select(2, ...)
        ns.Print("trace: error " .. (isSecret(message) and "(hidden)" or tostring(message)))
        return
    end
    local short = event:gsub("^UNIT_SPELLCAST_", ""):lower()
    ns.Print("trace: " .. short .. " " .. spellText(select(EVENTS[event], ...)))
end)

function CastTrace:Toggle()
    self.on = not self.on
    for event in pairs(EVENTS) do
        if self.on then
            if frame.RegisterUnitEvent then
                pcall(frame.RegisterUnitEvent, frame, event, "player")
            else
                pcall(frame.RegisterEvent, frame, event)
            end
        else
            pcall(frame.UnregisterEvent, frame, event)
        end
    end
    if self.on then frame:RegisterEvent("UI_ERROR_MESSAGE") else frame:UnregisterEvent("UI_ERROR_MESSAGE") end
    ns.Print("cast trace " .. (self.on and "on: your casts and errors print here" or "off"))
end
