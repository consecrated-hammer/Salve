local function equal(actual, expected, label)
    if actual ~= expected then
        error(("%s: expected %s, got %s"):format(label, tostring(expected), tostring(actual)))
    end
end

local SECRET = setmetatable({}, { __index = function() error("indexed a secret") end })
issecretvalue = function(v) return rawequal(v, SECRET) end
InCombatLockdown = function() return true end
UnitInRange = function() return SECRET, SECRET end
UnitIsConnected = function() return true end
C_Spell = { IsSpellInRange = function() return true end }
C_UnitAuras = { GetAuraDataByIndex = function() error("tainted") end }
date = function() return "12:00:00" end

local ns = { db = {}, spellID = 4987, VERSION = "1.12.0", DISPELLABLE_FILTER = "HARMFUL|RAID_PLAYER_DISPELLABLE" }
ns.Panel = { boxes = { { unit = "party1" } } }
assert(loadfile("Features/Probe.lua"))("Salve", ns)

local text = table.concat(ns.Probe:DiagnosticLines(), "\n")
assert(text:find("Probe, Salve 1.12.0 %(in combat%)"), "version and combat state")
assert(text:find("UnitInRange: secret, checked secret"), "secret range described")
assert(text:find("IsSpellInRange%(4987%): boolean true"), "plain range described")
assert(text:find("GetAuraDataByIndex: error: "), "aura read error captured")

ns.Probe:NoteBoxEnter()
equal(ns.Probe.boxEnters, 0, "nothing counted while closed")
ns.Probe.open = true
ns.Probe:NoteBoxEnter()
equal(#ns.db.probeLog, 1, "a cell hover snapshots while open")
for _ = 1, 40 do ns.Probe:Snapshot("auto") end
equal(#ns.db.probeLog, 30, "log is capped")
local copied
ns.HammerCore = { Copy = { Show = function(_, _, t) copied = t end } }
ns.Probe:CopyLog()
assert(copied and copied:find("%[12:00:00%] auto"), "copy joins snapshots")
ns.Probe:ClearLog()
equal(#ns.db.probeLog, 0, "clear empties log")
