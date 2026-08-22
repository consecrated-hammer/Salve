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

print("panel layout tests passed")
