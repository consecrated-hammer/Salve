local function equal(actual, expected, label)
    if actual ~= expected then
        error(("%s: expected %s, got %s"):format(label, tostring(expected), tostring(actual)))
    end
end

-- A secret is a sentinel the code may pass along but must never test.
local SECRET = setmetatable({}, { __index = function() error("indexed a secret") end })
issecretvalue = function(v) return rawequal(v, SECRET) end

local spellAnswer, unitAnswer = {}, {}
C_Spell = { IsSpellInRange = function(_, unit) return spellAnswer[unit] end }
UnitInRange = function(unit) return unitAnswer[unit] end
UnitExists = function() return true end

local ns = { spellID = 4987, db = { outOfRangeAlpha = 0.4, showTooltip = true, tooltipDebuff = true } }
local function box(unit)
    local b = { unit = unit, alpha = 1, shown = true, over = false }
    function b:SetAlpha(a) self.alpha = a; self.fromBoolean = nil end
    function b:SetAlphaFromBoolean(v, a, c) self.fromBoolean = { v, a, c } end
    function b:IsShown() return self.shown end
    function b:IsVisible() return self.shown end
    function b:IsMouseOver() return self.over end
    return b
end
local me, friend, far, secret = box("player"), box("party1"), box("party2"), box("party3")
ns.Panel = { boxes = { me, friend, far, secret } }
assert(loadfile("Features/Range.lua"))("Salve", ns)

spellAnswer.party1, spellAnswer.party2 = true, false
spellAnswer.party3, unitAnswer.party3 = nil, SECRET
spellAnswer.player = false
ns.Range:UpdateAll()
equal(me.alpha, 1, "own cell never fades")
equal(friend.alpha, 1, "in dispel range stays solid")
equal(far.alpha, 0.4, "out of dispel range fades")
assert(secret.fromBoolean and rawequal(secret.fromBoolean[1], SECRET), "secret range goes to SetAlphaFromBoolean")
equal(secret.fromBoolean[3], 0.4, "secret range uses the faded alpha")

spellAnswer.party2 = nil
unitAnswer.party2 = false
ns.Range:UpdateUnit("party2")
equal(far.alpha, 0.4, "group range fallback fades")
unitAnswer.party2 = nil
ns.Range:UpdateUnit("party2")
equal(far.alpha, 1, "no answer stays solid")

spellAnswer.party2 = false
ns.db.outOfRangeAlpha = 1
ns.Range:UpdateAll()
equal(far.alpha, 1, "100% turns fading off")
ns.db.outOfRangeAlpha = 0.4

-- Hover fix: show Salve's tooltip when the box misses OnEnter.
local owner, shows, hides = nil, 0, 0
GameTooltip = { IsOwned = function(_, b) return owner == b end }
ns.Box = { ShowTooltip = function(b) owner = b; shows = shows + 1 end,
    HideTooltip = function(b) if owner == b then owner = nil end; hides = hides + 1 end }
friend.over = true
ns.Range:Hover()
equal(owner, friend, "hovered cell shows Salve's tooltip")
ns.Range:Hover()
equal(shows, 1, "an owned tooltip isn't re-shown")
friend.over = false
ns.Range:Hover()
equal(owner, nil, "leaving the cell hides it")
ns.db.tooltipDebuff = false
friend.over = true
ns.Range:Hover()
equal(shows, 1, "no polling with the debuff tooltip off")
