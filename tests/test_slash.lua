local function equal(actual, expected, label)
    if actual ~= expected then
        error(("%s: expected %s, got %s"):format(label, tostring(expected), tostring(actual)))
    end
end

local bindingReports, soundReports, opened, copied, learningChanges = 0, 0, 0, 0, 0
local messages = {}
local ns = {
    VERSION = "1.3.1",
    REVISION = "test-hotfix",
    db = { learnMode = false },
    Binding = { Report = function() bindingReports = bindingReports + 1 end },
    Options = { ShowDiagnosticReport = function() copied = copied + 1 end },
    Sound = {
        Report = function() soundReports = soundReports + 1 end,
        SetLearning = function() learningChanges = learningChanges + 1 end,
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

SlashCmdList.SALVE("debug copy")
equal(copied, 1, "debug copy opens selectable report")
equal(bindingReports, 1, "debug copy does not flood chat")

SlashCmdList.SALVE("probe")
equal(bindingReports, 2, "probe compatibility alias remains")
equal(soundReports, 2, "probe alias includes sound report")

SlashCmdList.SALVE("version")
if not messages[#messages]:find("version 1.3.1  revision test-hotfix", 1, true) then
    error("version prints loaded revision")
end

SlashCmdList.SALVE("learn off")
equal(learningChanges, 0, "legacy learn command cannot disable learning")
if not messages[#messages]:find("always on", 1, true) then
    error("legacy learn command does not explain always-on learning")
end

SlashCmdList.SALVE("")
equal(opened, 1, "bare command opens options")

SlashCmdList.SALVE("help")
local help = table.concat(messages, "\n")
if not help:find("/salve debug", 1, true) then error("help omits debug command") end
if not help:find("/salve debug copy", 1, true) then error("help omits debug copy command") end
if not help:find("/salve help", 1, true) then error("help omits help command") end

print("slash tests passed")
