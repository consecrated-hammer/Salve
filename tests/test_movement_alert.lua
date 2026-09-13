local function equal(actual, expected, label)
    if actual ~= expected then
        error(("%s: expected %s, got %s"):format(label, tostring(expected), tostring(actual)))
    end
end

local emitted = {}
local ns = { db = { movementTextNotification = true, movementTextOutput = "CHAT" },
    Print = function(message) emitted[#emitted + 1] = { message = message } end }
assert(loadfile("Features/MovementAlert.lua"))("Salve", ns)

equal(ns.MovementAlert:Notify("player", { locType = "ROOT" },
    { name = "Blessing of Freedom" }), true,
    "Freedom text emits locally for the player")
equal(emitted[1].message, "|cffffa020YOU ARE ROOTED — BLESSING OF FREEDOM|r",
    "Freedom text identifies only the player")

ns.MovementAlert:Notify("player", { locType = "SNARE" }, { name = "Blessing of Freedom" })
equal(emitted[2].message, "|cffffa020YOU ARE SNARED — BLESSING OF FREEDOM|r",
    "Freedom text distinguishes a player snare")

ns.MovementAlert:Notify("player", { kind = "SLOW" }, { name = "Tiger's Lust" })
equal(emitted[3].message, "|cffffa020YOU ARE SLOWED — TIGER'S LUST|r",
    "speed detection uses the common movement alert renderer")

ns.Bindings = {
    FirstKeyForSpell = function() return "BUTTON2" end,
    Label = function() return "Right click" end,
}
ns.MovementAlert:Notify("player", { kind = "SLOW" }, { id = 1044, name = "Blessing of Freedom" })
equal(emitted[4].message, "|cffffa020YOU ARE SLOWED — RIGHT CLICK: BLESSING OF FREEDOM|r",
    "movement alert states the actual configured action chord")

equal(ns.MovementAlert:Notify("party1", { locType = "ROOT" }, { name = "Freedom" }), false, "party ignored")
equal(ns.MovementAlert:Notify("player", { locType = "STUN" }, { name = "Freedom" }), false, "stuns ignored")
ns.db.movementTextNotification = false
equal(ns.MovementAlert:Notify("party1", { locType = "ROOT" },
    { name = "Blessing of Freedom" }), false,
    "movement text respects its independent setting")
equal(#emitted, 4, "disabled setting emits no text")

print("movement alert tests passed")

-- Screen and Both remain local, restore position, expire, and never intercept
-- clicks outside preview mode.
local shown, mouse, screenMessage, savedPoint
local scripts = {}
UIParent = { GetCenter = function() return 500, 300 end }
CreateFrame = function()
    return setmetatable({
        CreateFontString = function()
            return { SetAllPoints = function() end, SetText = function(_, text) screenMessage = text end }
        end,
        SetScript = function(_, name, fn) scripts[name] = fn end,
        Show = function() shown = true end,
        Hide = function() shown = false end,
        EnableMouse = function(_, value) mouse = value end,
        GetCenter = function() return 550, 500 end,
        SetPoint = function(_, _, _, _, x, y) savedPoint = { x, y } end,
    }, { __index = function() return function() end end })
end
ns.db.movementTextNotification = true
ns.db.movementTextOutput = "BOTH"
assert(ns.MovementAlert:Notify("player", { locType = "ROOT" }, { name = "Freedom" }))
assert(#emitted == 5 and screenMessage:find("YOU ARE ROOTED", 1, true))
assert(shown and mouse == false)
scripts.OnUpdate(nil, 5)
assert(not shown)
ns.MovementAlert:TogglePreview()
assert(shown and mouse and ns.MovementAlert.preview)
assert(screenMessage:find("YOU ARE ROOTED", 1, true), "preview uses the live alert grammar")
scripts.OnDragStop()
assert(ns.db.movementTextX == 50 and ns.db.movementTextY == 200)
ns.MovementAlert:StopPreview()
assert(not shown and not mouse)
ns.MovementAlert:Position()
assert(savedPoint[1] == 50 and savedPoint[2] == 200)

local tabMessages, defaultMessages = {}, {}
local tabName = "My alerts"
GetChatWindowInfo = function(id) if id == 3 then return tabName end end
ChatFrame3 = { AddMessage = function(_, text) tabMessages[#tabMessages + 1] = text end }
DEFAULT_CHAT_FRAME = { AddMessage = function(_, text) defaultMessages[#defaultMessages + 1] = text end }
SendChatMessage = function() error("notifications must never send chat") end
ns.db.movementTextOutput, ns.db.movementChatWindow = "CHAT", 3
assert(ns.MovementAlert:Notify("player", { locType = "ROOT" }, { name = "Freedom" }))
assert(#tabMessages == 1 and #defaultMessages == 0)
local values, labels = ns.MovementAlert:ChatWindows()
assert(values[2] == 3 and labels[2] == "My alerts (3)")
tabName = "Renamed alerts"
assert(select(2, ns.MovementAlert:ChatWindows())[2] == "Renamed alerts (3)")
tabName = ""
ns.MovementAlert:PrintChat("fallback")
assert(#tabMessages == 1 and #defaultMessages == 1)
assert(select(2, ns.MovementAlert:ChatWindows())[2] == "Missing tab; using default")
