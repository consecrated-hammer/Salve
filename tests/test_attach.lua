local function equal(actual, expected, label)
    if actual ~= expected then
        error(("%s: expected %s, got %s"):format(label, tostring(expected), tostring(actual)))
    end
end

-- A host unit button or header: a rectangle in its own units, plus scale.
local function frame(left, top, width, height, unit, scale)
    local f = { shown = true, scale = scale or 1, unit = unit, kids = {}, hooks = {} }
    function f:IsVisible() return self.shown end
    function f:GetEffectiveScale() return self.scale end
    function f:GetLeft() return left end
    function f:GetRight() return left + width end
    function f:GetTop() return top end
    function f:GetBottom() return top - height end
    function f:GetAttribute(key) if key == "unit" then return self.unit end end
    function f:GetChildren() return unpack(self.kids) end
    function f:HookScript(script) self.hooks[script] = true end
    return f
end

local loaded = {}
C_AddOns = { IsAddOnLoaded = function(name) return loaded[name] == true end }
local timers = 0
C_Timer = { After = function() timers = timers + 1 end }

local ns = { db = { attachTo = "NONE", attachSide = "RIGHT", attachGap = 2 } }
assert(loadfile("Features/Attach.lua"))("Salve", ns)
local Attach = ns.Attach

local function rect(left, top, width, height, unit)
    return { left = left, right = left + width, top = top, bottom = top - height, unit = unit }
end

-- Party in one column: 40px frames whose bottoms are 50px apart.
local function partyColumn(units)
    local rects = {}
    for i, unit in ipairs(units) do rects[i] = rect(100, 500 - (i - 1) * 50, 100, 40, unit) end
    return rects
end
local party = { "player", "party1", "party2", "party3", "party4" }

local cells = Attach.PlanBeside(party, partyColumn(party), "RIGHT", 2, 20, 20, 1)
equal(cells[1].left, 202, "right side starts one gap past the host")
equal(cells[1].top, 490, "cell is centred on its member's frame")
equal(cells[2].top, 440, "cells keep the host's 50px pitch")
equal(cells[5].top, 290, "last cell lines up with the last frame")

cells = Attach.PlanBeside(party, partyColumn(party), "LEFT", 2, 20, 20, 1)
equal(cells[1].left, 78, "left side ends one gap before the host")

-- Align and nudge: frames run 500 to 460, so the cell's top moves to match.
cells = Attach.PlanBeside(party, partyColumn(party), "RIGHT", 2, 20, 20, 1, "TOP")
equal(cells[1].top, 500, "top aligns with the frame's top")
cells = Attach.PlanBeside(party, partyColumn(party), "RIGHT", 2, 20, 20, 1, "BOTTOM")
equal(cells[1].top, 480, "bottom aligns with the frame's bottom")
equal(cells[2].top, 430, "aligned cells keep the host's pitch")
cells = Attach.PlanBeside(party, partyColumn(party), "RIGHT", 2, 20, 20, 1, "TOP", -3)
equal(cells[1].top, 497, "a negative nudge moves cells down")
cells = Attach.PlanBeside(party, partyColumn({ "party1", "party2", "party3", "party4" }),
    "RIGHT", 2, 20, 20, 1, "BOTTOM", 4)
equal(cells[1].top, 284, "an extra slot aligns and nudges like the rest")

-- Matched by unit: the host's order wins over Salve's.
local hostOrder = { "party2", "player", "party1", "party3", "party4" }
cells = Attach.PlanBeside(party, partyColumn(hostOrder), "RIGHT", 2, 20, 20, 1)
equal(cells[3].top, 490, "party2's cell sits beside party2's frame")
equal(cells[1].top, 440, "player's cell sits beside the player's frame")

-- The host hides the player: their cell takes the next slot down.
cells = Attach.PlanBeside(party, partyColumn({ "party1", "party2", "party3", "party4" }),
    "RIGHT", 2, 20, 20, 1)
equal(cells[2].top, 490, "party1 still lines up when the player is hidden")
equal(cells[1].top, 290, "hidden player's cell takes the next slot after the last frame")
equal(cells[1].left, 202, "the extra slot stays in the last column")

-- Raid, two groups as columns. A short second group keeps its own column.
local raid, raidRects = {}, {}
for i = 1, 8 do raid[i] = "raid" .. i end
for i = 1, 5 do raidRects[#raidRects + 1] = rect(100, 500 - (i - 1) * 50, 100, 40, "raid" .. i) end
for i = 6, 8 do raidRects[#raidRects + 1] = rect(210, 500 - (i - 6) * 50, 100, 40, "raid" .. i) end
cells = Attach.PlanBeside(raid, raidRects, "RIGHT", 2, 20, 20, 1)
equal(cells[1].left, 312, "group one is Salve's first column")
equal(cells[6].left, 333, "group two is Salve's second column")
equal(cells[6].top, 490, "group two's first member lines up with its frame")
equal(cells[5].top, 290, "group one's fifth member lines up with its frame")

-- A host laid out as one row: cells follow the row; a missing member extends it.
local row = {}
for i = 2, 5 do row[#row + 1] = rect(100 + (i - 2) * 110, 500, 100, 40, party[i]) end
cells = Attach.PlanBeside(party, row, "RIGHT", 2, 20, 20, 1)
equal(cells[2].top, 490, "row cells share the row's centre")
equal(cells[3].left, 530 + 2 + 21, "row members keep their columns")
equal(cells[1].left, 530 + 2 + 4 * 21, "the missing member takes the next column")

-- Test panel: a count takes host frames in reading order.
cells = Attach.PlanBeside(3, partyColumn(hostOrder), "RIGHT", 2, 20, 20, 1)
equal(cells[1].top, 490, "test cell one takes the top frame")
equal(cells[3].top, 390, "test cell three takes the third frame")

-- Top and Bottom keep Salve's grid together against the host's edges.
local stacked = Attach.PlanStacked(partyColumn(party), "BOTTOM", 2, 104, 20, false)
equal(stacked.top, 258, "bottom sits one gap below the host")
equal(stacked.left, 100, "bottom lines up with the host's left edge")
stacked = Attach.PlanStacked(partyColumn(party), "TOP", 2, 104, 20, true)
equal(stacked.bottom, 502, "top sits one gap above the host")
equal(stacked.right, 200, "rows from the right line up with the host's right edge")

-- ── Full plan against fake host frames ──
local layout = {
    width = 20, height = 20, spacing = 1, frameWidth = 104, frameHeight = 20,
    orientation = "HORIZONTAL", horizontalGrowth = "RIGHT",
}
equal(Attach:Plan(party, layout, 1), nil, "None leaves the panel alone")
equal(Attach.status, "NONE", "status says not attached")

ns.db.attachTo = "DANDERS"
equal(Attach:Plan(party, layout, 1), nil, "an unloaded host falls back")
equal(Attach.status, "NOT_LOADED", "status names the missing addon")

loaded.DandersFrames = true
equal(Attach:Plan(party, layout, 1), nil, "no host frames falls back")
equal(Attach.status, "NO_FRAMES", "status says the frames aren't on screen")
equal(timers, 1, "a missing header is looked for again later")

local header = frame(100, 500, 100, 240)
for i, unit in ipairs(party) do header.kids[i] = frame(100, 500 - (i - 1) * 50, 100, 40, unit) end
local secret = {}
function issecretvalue(value) return value == secret end
header.kids[#header.kids + 1] = frame(0, 0, 10, 10, secret)
local pinned = frame(400, 500, 100, 40, "player")
_G.DandersPartyHeader = header
_G.DandersPinned1Header = { shown = true, GetChildren = function() return pinned end }

local plan = Attach:Plan(party, layout, 1)
equal(Attach.status, "ATTACHED", "attaches to a visible header")
equal(plan.anchor, header, "anchors to the host's secure header")
equal(plan.point, "TOPLEFT", "right side hangs Salve's top left")
equal(plan.anchorPoint, "TOPRIGHT", "off the header's top right")
equal(plan.x, 2, "anchor offset is the gap")
equal(plan.y, -10, "anchor offset lines the first cell up with the first frame")
equal(plan.cells[2].y, -50, "cell offsets keep the host's pitch")
equal(plan.height, 220, "frame spans the host's rows")
equal(header.hooks.OnSizeChanged, true, "host resizes are watched")

-- Salve at twice the host's scale: screen pitch holds, offsets halve.
plan = Attach:Plan(party, layout, 2)
equal(plan.cells[2].y, -25, "pitch is converted into Salve's own units")
equal(plan.x, 2, "gap scales with the panel, like cell sizes")

ns.db.attachAlign, ns.db.attachOffsetY = "TOP", 5
plan = Attach:Plan(party, layout, 1)
equal(plan.y, 5, "align and nudge reach the full plan")
ns.db.attachAlign, ns.db.attachOffsetY = "CENTER", 0

-- The host pins its header by TOP, so Salve hangs off that fixed point, not
-- the header edge that moves when the header resizes mid-fight.
function header:GetPoint() return "TOP" end
plan = Attach:Plan(party, layout, 1)
equal(plan.anchorPoint, "TOP", "anchors to the host's own fixed point")
equal(plan.x, 52, "offset is measured from that point")
equal(plan.y, -10, "vertical offset is measured from that point")
header.GetPoint = nil

-- The test panel's plan leaves the live status alone.
local before = Attach.status
ns.db.attachTo = "ELLESMERE"
equal(Attach:Plan(3, layout, 1, true), nil, "preview falls back the same way")
equal(Attach.status, before, "preview doesn't change the live panel's status")
ns.db.attachTo = "DANDERS"

-- Arena: Danders shows its arena header (your own team) instead of party.
header.shown = false
local arena = frame(100, 500, 100, 140)
for i = 1, 3 do arena.kids[i] = frame(100, 500 - (i - 1) * 50, 100, 40, party[i]) end
_G.DandersArenaHeader = arena
plan = Attach:Plan({ "player", "party1", "party2" }, layout, 1)
equal(plan.anchor, arena, "arena attaches to Danders' arena header")
header.shown = true
_G.DandersArenaHeader = nil

ns.db.attachSide = "BOTTOM"
plan = Attach:Plan(party, layout, 1)
equal(plan.cells, nil, "bottom keeps Salve's own grid")
equal(plan.point, "TOPLEFT", "bottom hangs Salve's top left")
equal(plan.anchorPoint, "BOTTOMLEFT", "off the header's bottom left")
equal(plan.y, -2, "bottom sits one gap under the header")

-- Ellesmere's self button stands in for the player beside its header.
ns.db.attachTo, ns.db.attachSide = "ELLESMERE", "RIGHT"
loaded.EllesmereUIRaidFrames = true
local erf = frame(100, 450, 100, 190)
for i = 2, 5 do erf.kids[#erf.kids + 1] = frame(100, 500 - (i - 1) * 50, 100, 40, party[i]) end
_G.ERFPartyHeader = erf
_G.ERFPartySelfButton = frame(100, 500, 100, 40, "player")
plan = Attach:Plan(party, layout, 1)
equal(plan.anchor, erf, "Ellesmere anchors to its party header")
equal(plan.cells[1].y, 0, "the self button places the player's cell")
equal(plan.cells[2].y, -50, "party members follow below")

print("attach tests passed")
