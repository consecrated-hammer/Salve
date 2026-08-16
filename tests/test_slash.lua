local function equal(actual, expected, label)
    if actual ~= expected then
        error(("%s: expected %s, got %s"):format(label, tostring(expected), tostring(actual)))
    end
end

local bindingReports, soundReports, opened = 0, 0, 0
local messages = {}
local ns = {
    db = { learnMode = false },
    Binding = { Report = function() bindingReports = bindingReports + 1 end },
    Sound = {
        Report = function() soundReports = soundReports + 1 end,
        SetLearning = function() end,
        DumpLearned = function() end,
        ClearLearned = function() end,
    },
    OpenOptions = function() opened = opened + 1 end,
    Print = function(message) messages[#messages + 1] = message end,
    SetLocked = function() end,
    Panel = { ApplyPosition = function() end },
}

SlashCmdList = {}
assert(loadfile("Core/Slash.lua"))("Salve", ns)

SlashCmdList.SALVE("debug")
equal(bindingReports, 1, "debug runs binding report")
equal(soundReports, 1, "debug runs sound report")

SlashCmdList.SALVE("probe")
equal(bindingReports, 2, "probe compatibility alias remains")
equal(soundReports, 2, "probe alias includes sound report")

SlashCmdList.SALVE("")
equal(opened, 1, "bare command opens options")

SlashCmdList.SALVE("help")
local help = table.concat(messages, "\n")
if not help:find("/salve debug", 1, true) then error("help omits debug command") end
if not help:find("/salve help", 1, true) then error("help omits help command") end

print("slash tests passed")
