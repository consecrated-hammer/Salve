local function equal(actual, expected, label)
    if actual ~= expected then
        error(("%s: expected %s, got %s"):format(label, tostring(expected), tostring(actual)))
    end
end

local locked = false
function InCombatLockdown() return locked end
function GetTime() return 100 end

local alpha = 0.65
local ns = {
    Print = function() end,
    Panel = {
        frame = {
            GetAlpha = function() return alpha end,
            SetAlpha = function(_, value) alpha = value end,
        },
    },
}

assert(loadfile("UI/Preview.lua"))("Salve", ns)

local preview = ns.Preview
equal(preview:NeedsDispel(1, 1), true, "solo preview lights one cell")
equal(preview:NeedsDispel(1, 2), false, "two-person preview keeps one cell clear")
equal(preview:NeedsDispel(2, 2), true, "two-person preview lights one cell")
equal(preview:NeedsDispel(2, 5), true, "party preview lights first dispel")
equal(preview:NeedsDispel(4, 5), true, "party preview lights second dispel")
equal(preview:NeedsDispel(3, 5), false, "party preview leaves other cells clear")
local shown = false
preview.Create = function(self)
    self.frame = self.frame or { Hide = function() shown = false end }
end
preview.Refresh = function() shown = true end

equal(preview:Start(), true, "preview starts out of combat")
equal(preview.active, true, "preview active")
equal(alpha, 0, "live panel hidden while preview runs")
equal(shown, true, "preview shown")

preview:Stop()
equal(preview.active, false, "preview stopped")
equal(alpha, 0.65, "live panel alpha restored")
equal(shown, false, "preview hidden")

locked = true
equal(preview:Start(), false, "preview refuses combat")
equal(preview.active, false, "combat start leaves preview inactive")
equal(alpha, 0.65, "combat refusal leaves live panel visible")

print("preview lifecycle tests passed")
