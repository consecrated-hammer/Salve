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
        learnMode = true,
        bindings = {},
    },
    knownDispels = {
        { id = 4987, name = "Cleanse", cures = { Magic = true, Disease = true } },
    },
    learned = {
        auras = {
            ["instance:123"] = {
                name = "Test Dungeon",
                spells = {
                    [98765] = {
                        name = "Test Hex", dispelType = "Curse", provenance = "in-game learn",
                    },
                },
            },
        },
        movement = { [339] = "Entangling Roots" },
    },
    Options = {
        NewPage = function(spec, build)
            pages[#pages + 1] = {
                name = spec.name,
                title = spec.title,
                group = spec.group,
                build = build,
            }
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
        CooldownDiagnosticLines = function()
            return { "Cooldown casts: 1 seen, 1 readable, 1 matched" }
        end,
    },
    Bindings = {
        List = function() return { { key = "BUTTON1" } } end,
        SpellID = function() return 4987 end,
        Describe = function() return "Cleanse (automatic)" end,
        KeysForSpell = function() return { "BUTTON1" } end,
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

UnitName = function() return "Test Shaman" end

for _, path in ipairs({
    "Options/Salve.lua",
    "Options/Dispel.lua",
    "Options/Visibility.lua",
    "Options/Alerts.lua",
    "Options/Commands.lua",
    "Options/Troubleshooting.lua",
    "Options/LearnedSpells.lua",
    "Options/About.lua",
}) do
    assert(loadfile(path))("Salve", ns)
end

equal(#pages, 8, "eight options pages registered")
for i, name in ipairs({ "Salve", "Actions", "Visibility", "Alerts", "Commands", "Troubleshooting", "Learned Spells", "About" }) do
    equal(pages[i].name, name, "page order " .. i)
end
equal(pages[1].title, "Panel", "root page has task-focused heading")
equal(pages[1].group, "CORE", "Panel is a Core page")
equal(pages[4].group, "CORE", "Alerts is a Core page")
equal(pages[6].group, "REFERENCE", "Troubleshooting is a Reference page")

local report = ns.Options.BuildDiagnosticReport()
if not report:find("Version: 0.1.0", 1, true) then error("report omits version") end
if not report:find("Aura engine: ready", 1, true) then error("report omits engine state") end
if not report:find("Cooldown casts: 1 seen", 1, true) then
    error("copy report omits cooldown diagnostics")
end
if report:find("|c", 1, true) then error("copy report contains chat colour escapes") end

local spells = ns.Options.BuildLearnedSpellReport()
if not spells:find("Character: Test Shaman", 1, true) then error("spell export omits character") end
if not spells:find("Test Dungeon (instance:123)", 1, true) then
    error("spell export omits learned aura scope")
end
if not spells:find("Test Hex (spell ID 98765; Curse; in-game learn)", 1, true) then
    error("spell export omits learned dispel")
end
if not spells:find("Entangling Roots (spell ID 339; Blizzard loss-of-control)", 1, true) then
    error("spell export omits learned movement spell")
end

-- ☠ ASSERT CONSISTENCY, NOT A LITERAL DATE. This used to pin 2026-08-16, so
--   every release failed here and had to edit the assertion -- which teaches
--   you to update the test rather than ask whether the change was right. What
--   actually matters is that the TOC's version and release date agree with the
--   CHANGELOG heading, which is the same thing release CI enforces.
local toc = assert(io.open("Salve.toc", "r")):read("*a")

local version = toc:match("## Version:%s*(%S+)")
if not version then error("Salve.toc has no ## Version") end

local releaseDate = toc:match("## X%-ReleaseDate:%s*(%d%d%d%d%-%d%d%-%d%d)")
if not releaseDate then error("Salve.toc has no well-formed X-ReleaseDate") end

-- Local/debug stamps intentionally do not create public release notes. Use
-- `-devN` for every copy-to-WoW test build so it is visible in-game.
local isDebugBuild = version:find("-local", 1, true)
    or version:match("%-dev%d+$")
if not isDebugBuild then
    local changelog = assert(io.open("CHANGELOG.md", "r")):read("*a")
    local heading = ("## [%s] - %s"):format(version, releaseDate)
    if not changelog:find(heading, 1, true) then
        error(("CHANGELOG.md has no '%s' heading"):format(heading))
    end
end

print("options tests passed")
