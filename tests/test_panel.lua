local function equal(actual, expected, label)
    if actual ~= expected then
        error(("%s: expected %s, got %s"):format(label, tostring(expected), tostring(actual)))
    end
end

local ns = {
    db = {
        columns = 5,
        boxWidth = 20,
        boxHeight = 20,
        spacing = 1,
        scale = 1,
        orientation = "HORIZONTAL",
        horizontalGrowth = "RIGHT",
        verticalGrowth = "DOWN",
    },
    Escape = {
        IsPlayerUnit = function(_, unit) return unit == "raid3" end,
    },
    Bindings = {
        FirstKeyForSpell = function(_, spellID) return spellID == 1044 and "BUTTON2" end,
    },
    Box = {
        SetMovementPrompt = function(box, active) box.prompt = active end,
    },
}

assert(loadfile("UI/Panel.lua"))("Salve", ns)

local solo = ns.Panel:Layout(1)
equal(solo.across, 1, "solo width")
equal(solo.down, 1, "solo height")
equal(solo.frameWidth, 20, "solo frame width")

local party = ns.Panel:Layout(5)
equal(party.across, 5, "party fills row")
equal(party.down, 1, "party row count")
equal(party.frameWidth, 104, "party frame width includes gaps")

local raid = ns.Panel:Layout(40)
equal(raid.across, 5, "raid respects columns")
equal(raid.down, 8, "raid wraps rows")
equal(raid.frameHeight, 167, "raid frame height includes gaps")

ns.db.orientation = "VERTICAL"
local vertical = ns.Panel:Layout(40)
equal(vertical.across, 8, "vertical raid grows across")
equal(vertical.down, 5, "vertical raid respects column length")

local function placed(index, layout)
    local point
    local box = {
        SetSize = function() end,
        ClearAllPoints = function() end,
        GetParent = function() return {} end,
        SetPoint = function(_, _, _, _, x, y) point = { x, y } end,
    }
    ns.Panel:PlaceBox(box, index, layout)
    return point[1], point[2]
end

ns.db.orientation = "HORIZONTAL"
ns.db.horizontalGrowth = "RIGHT"
local forward = ns.Panel:Layout(5)
local x1 = placed(1, forward)
local x5 = placed(5, forward)
equal(x1, 0, "left-to-right starts at left anchor")
equal(x5, 84, "left-to-right ends at right edge")

ns.db.horizontalGrowth = "LEFT"
local reverse = ns.Panel:Layout(5)
x1 = placed(1, reverse)
x5 = placed(5, reverse)
equal(x1, 84, "right-to-left starts at right anchor")
equal(x5, 0, "right-to-left ends at left edge")

ns.db.orientation = "VERTICAL"
ns.db.verticalGrowth = "UP"
local upward = ns.Panel:Layout(5)
local _, y1 = placed(1, upward)
local _, y5 = placed(5, upward)
equal(y1, -84, "bottom-to-top starts at bottom anchor")
equal(y5, 0, "bottom-to-top ends at top edge")

ns.db.orientation = "HORIZONTAL"
ns.db.horizontalGrowth = "LEFT"
local anchoredPoint
local anchored = {
    GetPoint = function() return "TOPLEFT", {}, "CENTER", 0, 0 end,
    GetLeft = function() return 10 end,
    GetRight = function() return 114 end,
    GetTop = function() return 200 end,
    GetBottom = function() return 180 end,
    ClearAllPoints = function() end,
    SetPoint = function(_, point, _, relativePoint, x, y)
        anchoredPoint = { point, relativePoint, x, y }
    end,
}
UIParent = {}
equal(ns.Panel:NormalizeGrowthAnchor(anchored), true,
    "reverse horizontal flow normalizes its anchor")
equal(ns.db.point[1], "TOPRIGHT", "right-to-left stores right edge anchor")
equal(ns.db.point[3], 114, "right edge coordinate is preserved")
equal(anchoredPoint[1], "TOPRIGHT", "frame is reanchored at right edge")

-- The player's frame can have a raid token. Gold movement guidance must not
-- silently disappear merely because that token is not literally "player".
ns.Panel.boxes = { { unit = "raid3" }, { unit = "party1" } }
ns.Panel:SetMovementPrompt({ id = 1044 }, true)
equal(ns.Panel.boxes[1].prompt, true, "raid-token player receives movement prompt")
equal(ns.Panel.boxes[2].prompt, nil, "other party member does not receive player prompt")

-- ── Sort order ──
local function entries()
    return {
        { index = 1, unit = "player", isPlayer = true, role = "DAMAGER", name = "Mira" },
        { index = 2, unit = "party1", role = "HEALER", name = "zed" },
        { index = 3, unit = "party2", role = "TANK", name = "Anya" },
        { index = 4, unit = "party3", role = nil, name = nil },
        { index = 5, unit = "party4", role = "DAMAGER", name = "bram" },
    }
end
local function order(list)
    local units = {}
    for i, entry in ipairs(list) do units[i] = entry.unit end
    return table.concat(units, " ")
end
local function sortWith(mode, roleOrder, reverse, selfPosition)
    ns.db.sortMode, ns.db.sortRoleOrder = mode, roleOrder
    ns.db.sortReverse, ns.db.sortSelf = reverse, selfPosition
    return order(ns.Panel:SortEntries(entries()))
end

equal(sortWith("GROUP", nil, false, "SORTED"), "player party1 party2 party3 party4",
    "group order is unchanged")
equal(sortWith("GROUP", nil, true, "SORTED"), "party4 party3 party2 party1 player",
    "reverse group order")
equal(sortWith("ROLE", "TANK,HEALER,DAMAGER", false, "SORTED"),
    "party2 party1 player party4 party3", "role order with ties in group order, no role last")
equal(sortWith("ROLE", "DAMAGER,HEALER,TANK", false, "SORTED"),
    "player party4 party1 party2 party3", "custom role order")
equal(sortWith("ROLE", "TANK,HEALER,DAMAGER", false, "FIRST"),
    "player party2 party1 party4 party3", "own cell pinned first")
equal(sortWith("ROLE", "TANK,HEALER,DAMAGER", true, "LAST"),
    "party3 party4 party1 party2 player", "reverse keeps own pinned cell last")
equal(sortWith("NAME", nil, false, "SORTED"), "party2 party4 player party1 party3",
    "names sort case-insensitively, unreadable names last")

-- The live path must not compare a secret name or role.
local secret = {}
function issecretvalue(value) return value == secret end
function UnitGroupRolesAssigned(unit)
    return ({ player = "NONE", party1 = secret, party2 = "TANK", party3 = "DAMAGER" })[unit]
end
function UnitName(unit)
    return ({ player = "Mira", party1 = secret, party2 = "Anya", party3 = "Cole" })[unit]
end
-- Retail 12 has only the namespaced spec lookup.
GetSpecialization = nil
C_SpecializationInfo = { GetSpecialization = function() return 2 end }
function GetSpecializationRole(spec) return spec == 2 and "HEALER" or "DAMAGER" end
ns.Escape.IsPlayerUnit = function(_, unit) return unit == "player" end
ns.db.sortMode, ns.db.sortRoleOrder, ns.db.sortReverse, ns.db.sortSelf =
    "ROLE", "TANK,HEALER,DAMAGER", false, "SORTED"
equal(table.concat(ns.Panel:SortUnits({ "player", "party1", "party2", "party3" }), " "),
    "party2 player party3 party1", "player falls back to spec role; secret role goes last")
ns.db.sortMode = "NAME"
equal(table.concat(ns.Panel:SortUnits({ "player", "party1", "party2", "party3" }), " "),
    "party2 party3 player party1", "secret name falls back to group order")
ns.db.sortMode = "GROUP"
local untouched = { "player", "party1" }
equal(ns.Panel:SortUnits(untouched), untouched, "default settings skip sorting entirely")

print("panel layout tests passed")
