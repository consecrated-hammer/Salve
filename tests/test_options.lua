local function equal(actual, expected, label)
    if actual ~= expected then
        error(("%s: expected %s, got %s"):format(label, tostring(expected), tostring(actual)))
    end
end

local pages = {}
local ns = {
    VERSION = "0.1.0",
    REVISION = "test-revision",
    DISPELLABLE_FILTER = "HARMFUL",
    db = {
        soundEnabled = false,
        learnMode = false,
        bindings = {},
    },
    knownDispels = {
        { id = 4987, name = "Cleanse", cures = { Magic = true, Disease = true } },
    },
    Options = {
        NewPage = function(spec, build)
            pages[#pages + 1] = { name = spec.name, build = build }
        end,
    },
    Sound = {
        activeScopeName = "Test Zone",
        activeScopeKey = "map:1",
        activeInstanceName = "Eastern Kingdoms",
        activeInstanceID = 0,
        activeModule = nil,
        registered = 0,
        expected = 0,
        NeedsData = function() return false end,
        ActiveRecords = function() return {} end,
        CurrentCures = function() return { Magic = true, Disease = true } end,
    },
    Binding = {
        boundCount = 1,
        containersBuilt = 1,
        Probe = function()
            return {
                usable = true,
                methods = {
                    SetUnit = true,
                    AddAuraSlot = true,
                    SetEnabled = true,
                    UpdateAllAuras = true,
                },
            }
        end,
    },
    Bindings = {
        List = function() return { { key = "BUTTON1" } } end,
        Describe = function() return "Cleanse (automatic)" end,
        Label = function() return "Left click" end,
    },
}

function ns.CuresText(cures)
    local names = {}
    for _, name in ipairs({ "Magic", "Curse", "Disease", "Poison" }) do
        if cures[name] then names[#names + 1] = name end
    end
    return table.concat(names, ", ")
end

for _, path in ipairs({
    "Options/Salve.lua",
    "Options/Visibility.lua",
    "Options/Dispel.lua",
    "Options/Troubleshooting.lua",
    "Options/Commands.lua",
    "Options/About.lua",
}) do
    assert(loadfile(path))("Salve", ns)
end

equal(#pages, 6, "six options pages registered")
for i, name in ipairs({ "Salve", "Visibility", "Dispels", "Troubleshooting", "Commands", "About" }) do
    equal(pages[i].name, name, "page order " .. i)
end

local config = {
    columns = 5,
    boxWidth = 20,
    boxHeight = 20,
    spacing = 1,
    scale = 1,
    orientation = "HORIZONTAL",
}
local solo = ns.Options.PreviewLayout(1, config, 500, 80)
equal(solo.count, 1, "solo preview")
equal(solo.across, 1, "solo width")

local party = ns.Options.PreviewLayout(5, config, 500, 80)
equal(party.across, 5, "party preview fills row")
equal(party.down, 1, "party preview has one row")

local raid = ns.Options.PreviewLayout(40, config, 500, 80)
equal(raid.across, 5, "raid preview respects columns")
equal(raid.down, 8, "raid preview wraps all members")
if raid.gridWidth > 500 or raid.gridHeight > 80 then
    error("raid preview did not fit its viewport")
end

config.columns = 1
config.boxWidth = 300
config.boxHeight = 150
config.spacing = 12
config.scale = 2
local extreme = ns.Options.PreviewLayout(40, config, 500, 80)
if extreme.gridWidth > 500.001 or extreme.gridHeight > 80.001 then
    error("extreme raid preview did not shrink to fit")
end

config.columns = 5
config.boxWidth = 20
config.boxHeight = 20
config.spacing = 1
config.scale = 1
config.orientation = "VERTICAL"
local vertical = ns.Options.PreviewLayout(40, config, 500, 80)
equal(vertical.across, 8, "vertical raid grows across")
equal(vertical.down, 5, "vertical raid respects rows per column")

local report = ns.Options.BuildDiagnosticReport()
if not report:find("Version: 0.1.0", 1, true) then error("report omits version") end
if not report:find("Aura engine: ready", 1, true) then error("report omits engine state") end
if report:find("|c", 1, true) then error("copy report contains chat colour escapes") end

-- ☠ ASSERT CONSISTENCY, NOT A LITERAL DATE. This used to pin 2026-08-16, so
--   every release failed here and had to edit the assertion -- which teaches
--   you to update the test rather than ask whether the change was right. What
--   actually matters is that the TOC's version and release date agree with the
--   CHANGELOG heading, which is the same thing release CI enforces.
local toc = assert(io.open("Salve.toc", "r")):read("*a")

local version = toc:match("## Version:%s*([%d%.]+)")
if not version then error("Salve.toc has no ## Version") end

local releaseDate = toc:match("## X%-ReleaseDate:%s*(%d%d%d%d%-%d%d%-%d%d)")
if not releaseDate then error("Salve.toc has no well-formed X-ReleaseDate") end

local changelog = assert(io.open("CHANGELOG.md", "r")):read("*a")
local heading = ("## [%s] - %s"):format(version, releaseDate)
if not changelog:find(heading, 1, true) then
    error(("CHANGELOG.md has no '%s' heading"):format(heading))
end

print("options tests passed")
