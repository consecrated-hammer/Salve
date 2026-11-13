local addonName, ns = ...

-- ============================================================
-- Mouseover dispel keys
-- ============================================================
-- Two hidden secure buttons, bound to keys through Blizzard's own Key
-- Bindings (Bindings.xml, AddOns > Salve). Each holds a fixed macro:
--
--   /cast [@mouseover,help,nodead] Cleanse
--
-- so the key cleanses whoever is under the pointer: a raid frame from any
-- addon, a nameplate, or the player in the world. Nothing of ours runs at
-- the key press; the game evaluates the macro, in combat or out. The macro
-- is rewritten only out of combat, when the dispel spells change.
--
-- Optionally it falls back to your target or yourself when nothing friendly
-- is under the pointer.

ns.Mouseover = {}
local Mouseover = ns.Mouseover

Mouseover.BUTTONS = { PRIMARY = "SalveMouseoverPrimary", SECONDARY = "SalveMouseoverSecondary" }
Mouseover.BINDINGS = {
    PRIMARY = "CLICK SalveMouseoverPrimary:LeftButton",
    SECONDARY = "CLICK SalveMouseoverSecondary:LeftButton",
}

BINDING_HEADER_SALVE = "Salve"
_G["BINDING_NAME_" .. Mouseover.BINDINGS.PRIMARY] = "Mouseover dispel"
_G["BINDING_NAME_" .. Mouseover.BINDINGS.SECONDARY] = "Mouseover second dispel"


local FALLBACK = {
    NONE = "",
    TARGET = "[@target,help,nodead]",
    PLAYER = "[@player]",
}

-- The macro for one spell name, or nil when there's nothing to cast.
function Mouseover.MacroText(spellName, fallback)
    if type(spellName) ~= "string" or spellName == "" then return nil end
    return "/cast [@mouseover,help,nodead]" .. (FALLBACK[fallback] or "") .. " " .. spellName
end

local function button(name)
    local b = _G[name]
    if b then return b end
    b = CreateFrame("Button", name, UIParent, "SecureActionButtonTemplate")
    -- One cast per key press whatever ActionButtonUseKeyDown is set to.
    b:RegisterForClicks("AnyDown")
    b:SetAttribute("useOnKeyDown", true)
    b:SetAttribute("type", "macro")
    if b.EnableMouse then b:EnableMouse(false) end
    b:Hide()
    return b
end

function Mouseover:Spells()
    local primary = ns.spellName
    local secondary = ns.secondaryName
    if secondary == primary then secondary = nil end
    return primary, secondary
end

-- Out of combat only: callers are Panel:Rebuild and the settings.
function Mouseover:Update()
    if InCombatLockdown and InCombatLockdown() then return false end
    local fallback = ns.db and ns.db.mouseoverFallback or "NONE"
    local primary, secondary = nil, nil
    if ns.CanDispel and ns.CanDispel() then primary, secondary = self:Spells() end
    local texts = {
        PRIMARY = self.MacroText(primary, fallback),
        SECONDARY = self.MacroText(secondary, fallback),
    }
    for role, name in pairs(self.BUTTONS) do
        button(name):SetAttribute("macrotext", texts[role])
    end
    self.texts = texts
    return true
end

function Mouseover:BoundKey(role)
    local command = self.BINDINGS[role]
    if not command or not GetBindingKey then return nil end
    return GetBindingKey(command)
end

function Mouseover:DiagnosticLines()
    local lines = {}
    for _, role in ipairs({ "PRIMARY", "SECONDARY" }) do
        lines[#lines + 1] = "Mouseover " .. role:lower() .. ": "
            .. tostring(self:BoundKey(role) or "no key") .. ", "
            .. tostring(self.texts and self.texts[role] or "nothing to cast")
    end
    return lines
end

for _, name in pairs(Mouseover.BUTTONS) do button(name) end
