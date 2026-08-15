local addonName, ns = ...

-- ============================================================
-- LibDataBroker, without embedding LibDataBroker
-- ============================================================
-- Being LDB-compatible means Titan Panel, ChocolateBar, Bazooka, ElvUI
-- datatexts and friends can show a Salve entry. Normally that costs four
-- embedded libraries -- LibStub, CallbackHandler, LibDataBroker-1.1 and
-- LibDBIcon-1.0 -- which is precisely the baggage this addon exists to avoid.
--
-- We don't have to pay it. LDB is a REGISTRY, not a dependency: if some other
-- addon has already loaded it, LibStub hands it to us. If nothing has, this
-- file does nothing at all and the rest of Salve is unchanged.
--
-- ☠ THIS IS NOT A DEPENDENCY, AND MUST NEVER BECOME ONE. Registering a launcher
--   is purely ADDITIVE: it gives a display addon something to show, and changes
--   no Salve behaviour whatsoever. Salve is identical with and without it.
--
-- ☠ WHY THERE IS NO LibDBIcon HANDOFF HERE. An earlier version handed the
--   minimap button to LibDBIcon when it was present. That was wrong -- not
--   because of the guarding, which was fine, but because it made Salve behave
--   DIFFERENTLY depending on which other addons were enabled: LibDBIcon stored
--   the icon position in its own saved variables, so disabling the addon that
--   happened to supply the library made Salve's icon appear to jump. One addon,
--   two behaviours, decided by something the user never configured. Salve owns
--   its own minimap button unconditionally (UI/Minimap.lua). Do not "improve"
--   this by reintroducing the handoff.

ns.Broker = {}
local Broker = ns.Broker

local ICON = "Interface\\Icons\\Spell_Holy_Renew"

local function getLib(name)
    if not LibStub then return nil end
    local ok, lib = pcall(LibStub.GetLibrary, LibStub, name, true)
    if ok then return lib end
    return nil
end

function Broker:Create()
    if self.object then return self.object end

    local LDB = getLib("LibDataBroker-1.1")
    if not LDB then return nil end

    local ok, object = pcall(LDB.NewDataObject, LDB, "Salve", {
        type  = "launcher",
        icon  = ICON,
        label = "Salve",

        OnClick = function(_, button)
            -- ☠ See UI/Minimap.lua: IsLocked(), not a `locked` key.
            if button == "RightButton" then
                ns.SetLocked(not ns.IsLocked())
            else
                ns.OpenOptions()
            end
        end,

        OnTooltipShow = function(tooltip)
            if not tooltip or not tooltip.AddLine then return end
            tooltip:AddLine("Salve")
            tooltip:AddLine(ns.spellName or "no dispel on this spec", 0.7, 0.7, 0.7)
            tooltip:AddLine(" ")
            tooltip:AddLine("Click: open options", 0.85, 0.85, 0.85)
            tooltip:AddLine("Right-click: show or hide the drag handle", 0.85, 0.85, 0.85)
        end,
    })

    if not ok then return nil end
    self.object = object
    return object
end
