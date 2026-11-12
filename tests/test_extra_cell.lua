-- The extra target/focus cell: secure show rule, refresh on change, and it
-- never shows a stale debuff.
local wow = dofile("tests/hammercore/wow.lua")
wow.Install()

local function equal(actual, expected, label)
    if actual ~= expected then
        error(("%s: expected %s, got %s"):format(label, tostring(expected), tostring(actual)))
    end
end

local secretTrue = {}
issecretvalue = function(v) return rawequal(v, secretTrue) end
InCombatLockdown = function() return false end
UnitName = function() return "Random" end
UnitClass = function() return "Priest", "PRIEST" end
date = function() return "2026-11-12 19:00" end

local drivers = {}
RegisterStateDriver = function(frame, kind, rule) drivers[frame] = rule end
UnregisterStateDriver = function(frame) drivers[frame] = nil end

local inRaid, inParty = false, false
UnitPlayerOrPetInRaid = function() return inRaid end
UnitPlayerOrPetInParty = function() return inParty end

local refreshOK, updates = true, 0
local attachOK = true
local ns = {
    db = { extraCell = "TARGET", extraCellSkipGroup = true, showNames = false, roleIcon = "OFF" },
    CanDispel = function() return true end,
    Bindings = { Apply = function() end },
    Binding = {
        Attach = function(_, box, unit)
            if not attachOK then return false end
            box.auraContainer = { UpdateAllAuras = function()
                updates = updates + 1
                if not refreshOK then error("refused") end
            end }
            return true
        end,
        Park = function() end,
        RegisterCooldown = function() end,
        RegisterMovementCooldown = function() end,
    },
}
SalveClickLog = {}
assert(loadfile("UI/Box.lua"))("Salve", ns)
local placed
ns.Panel = {
    PlaceBox = function(_, box, index) placed = { index = index } end,
    PlaceBoxAt = function(_, box, cell) placed = { x = cell.x, y = cell.y } end,
}
assert(loadfile("Features/ExtraCell.lua"))("Salve", ns)
local X = ns.ExtraCell
local panel = CreateFrame("Frame", "SalveFrame", UIParent)
local box = X:Create(panel)
local layout = { width = 20, height = 20, spacing = 1 }

X:Rebuild(6, layout)
equal(box:GetAttribute("unit"), "target", "clicks aim at the target token")
equal(drivers[box], "[@target,help,nodead] show; hide", "secure show rule")
equal(placed.index, 6, "next grid spot")
equal(X.boundEvent, "PLAYER_TARGET_CHANGED", "listens for target changes")
equal(updates, 1, "refreshed once on build")
equal(X.holder:GetAlpha(), 1, "visible for a stranger")

inParty = true
X:Changed()
equal(updates, 2, "refreshed on change")
equal(X.holder:GetAlpha(), 0, "faded for a group member")
ns.db.extraCellSkipGroup = false
X:ApplyFade()
equal(X.holder:GetAlpha(), 1, "shown for group members when allowed")
ns.db.extraCellSkipGroup = true

inParty = secretTrue
local fromBoolean
X.holder.SetAlphaFromBoolean = function(_, value, yes, no) fromBoolean = { value, yes, no } end
X:ApplyFade()
assert(fromBoolean and rawequal(fromBoolean[1], secretTrue) and fromBoolean[2] == 0 and fromBoolean[3] == 1,
    "secret group answer goes through SetAlphaFromBoolean")
inParty = false

UnitIsUnit = function() return true end
X:ApplyFade()
equal(X.holder:GetAlpha(), 0, "faded when you target yourself")
UnitIsUnit = nil

refreshOK = false
X:Changed()
equal(X.holder:GetAlpha(), 0, "a refused refresh hides the cell rather than show stale colour")
equal(SalveClickLog.extraCell.refreshFailed, 1, "refusals are saved")
refreshOK = true
X:Changed()
equal(X.holder:GetAlpha(), 1, "back once a refresh works")
equal(SalveClickLog.extraCell.refreshOK, 3, "successes are saved")

ns.db.extraCell = "FOCUS"
X:Rebuild(3, layout, { x = 0, y = -42 })
equal(box:GetAttribute("unit"), "focus", "focus token")
equal(drivers[box], "[@focus,help,nodead] show; hide", "focus show rule")
equal(placed.y, -63, "attached: sits under the last cell")

attachOK = false
X:Rebuild(3, layout)
equal(drivers[box], nil, "no show rule without a native colour")
equal(box:IsShown(), false, "hidden when it can't light up")
attachOK = true

ns.db.extraCell = "OFF"
X:Rebuild(3, layout)
equal(box.unit, nil, "off unbinds")
equal(drivers[box], nil, "off removes the show rule")
