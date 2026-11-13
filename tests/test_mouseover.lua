-- Mouseover dispel keys: the macro each hidden button holds.
local wow = dofile("tests/hammercore/wow.lua")
wow.Install()

local function equal(actual, expected, label)
    if actual ~= expected then
        error(("%s: expected %s, got %s"):format(label, tostring(expected), tostring(actual)))
    end
end

local locked = false
InCombatLockdown = function() return locked end
local ns = { db = { mouseoverFallback = "NONE" }, CanDispel = function() return true end,
    spellName = "Cleanse", secondaryName = "Cleanse Toxins" }
assert(loadfile("Features/Mouseover.lua"))("Salve", ns)
local M = ns.Mouseover
local primary, secondary = _G.SalveMouseoverPrimary, _G.SalveMouseoverSecondary

equal(primary:GetAttribute("type"), "macro", "macro button")
equal(primary:GetAttribute("useOnKeyDown"), true, "fires once on key down")
M:Update()
equal(primary:GetAttribute("macrotext"), "/cast [@mouseover,help,nodead] Cleanse", "primary macro")
equal(secondary:GetAttribute("macrotext"), "/cast [@mouseover,help,nodead] Cleanse Toxins", "secondary macro")

ns.db.mouseoverFallback = "TARGET"
M:Update()
equal(primary:GetAttribute("macrotext"), "/cast [@mouseover,help,nodead][@target,help,nodead] Cleanse", "target fallback")
ns.db.mouseoverFallback = "PLAYER"
M:Update()
equal(primary:GetAttribute("macrotext"), "/cast [@mouseover,help,nodead][@player] Cleanse", "self fallback")

ns.secondaryName = "Cleanse"
M:Update()
equal(secondary:GetAttribute("macrotext"), nil, "no second key when there's one dispel")

locked = true
ns.spellName = "Purify"
equal(M:Update(), false, "never rewritten in combat")
equal(primary:GetAttribute("macrotext"), "/cast [@mouseover,help,nodead][@player] Cleanse", "keeps the old macro")
locked = false

ns.CanDispel = function() return false end
M:Update()
equal(primary:GetAttribute("macrotext"), nil, "nothing to cast without a dispel")

-- Only the individual commands are offered, on both clients.
for _, forever in ipairs({ false, true }) do
    ns.isCamelot = forever
    ns.CanDispel = function() return true end
    ns.spellName, ns.secondaryName = "Cure Poison", "Remove Curse"
    ns.db.mouseoverFallback = "TARGET"
    InCombatLockdown = function() return false end
    M:Update()
    equal(primary:GetAttribute("macrotext"), "/cast [@mouseover,help,nodead][@target,help,nodead] Cure Poison", "individual poison key")
    equal(secondary:GetAttribute("macrotext"), "/cast [@mouseover,help,nodead][@target,help,nodead] Remove Curse", "individual curse key")
    equal(M.BINDINGS.BOTH, nil, "combined command not offered")
    equal(M.BUTTONS.BOTH, nil, "combined secure button not offered")
    equal(_G.SalveMouseoverBoth, nil, "no new combined secure button created")
    equal(M:BoundKey("BOTH"), nil, "retired command lookup harmless")
    equal(#M:DiagnosticLines(), 2, "diagnostics only describe individual dispels")
end
print("mouseover tests passed")
