local function equal(actual, expected, label)
    if actual ~= expected then
        error(("%s: expected %s, got %s"):format(label, tostring(expected), tostring(actual)))
    end
end

local ns = {
    db = { clickAuditEnabled = false },
    Bindings = {
        Capture = function(_, button) return button == "LeftButton" and "BUTTON1" end,
    },
}

time = function() return 1788000123 end
assert(loadfile("Core/ClickLog.lua"))("Salve", ns)
ns.ClickLog:Init()

local box = {
    unit = "party1",
    clickAuditActions = {
        BUTTON1 = { kind = "DISPEL", spellID = 213644, spellName = "Cleanse Toxins" },
    },
}

ns.ClickLog:Record(box, "LeftButton")
equal(ns.ClickLog:Count(), 0, "audit is off by default")

ns.db.clickAuditEnabled = true
ns.ClickLog:Record(box, "LeftButton")
equal(ns.ClickLog:Count(), 1, "armed cell click is stored")
local entry = SalveClickLog.entries[1]
equal(entry.timestamp, 1788000123, "click has a timestamp")
equal(entry.unit, "party1", "click records unit token")
equal(entry.button, "BUTTON1", "click records binding")
equal(entry.kind, "DISPEL", "click records action kind")
equal(entry.spellID, 213644, "click records selected spell")

ns.ClickLog:Record(box, "RightButton")
equal(ns.ClickLog:Count(), 1, "unarmed click is ignored")
date = function(_, timestamp) return "2026-08-29 20:02:03" end
local export = ns.ClickLog:Export()
assert(export:find('"entries":[', 1, true), "export is JSON")
assert(export:find('"fields":["timestamp","unit","binding","action","spellId","spellName"]',
    1, true), "export describes compact entry fields")
assert(export:find('["2026-08-29 20:02:03","party1","BUTTON1","DISPEL",213644,"Cleanse Toxins"]',
    1, true), "export has compact stored action")
ns.ClickLog:Clear()
equal(ns.ClickLog:Count(), 0, "clear removes history")

print("click log tests passed")
