package.path = "./tests/hammercore/?.lua;" .. package.path
local wow = require("wow")

local function equal(actual, expected, label)
    if actual ~= expected then
        error(label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
    end
end

-- Click the control that owns a piece of text.
local function clickText(text)
    local region = wow.FindText(text)
    assert(region, "no text " .. text)
    while region and not region.scripts.OnClick do region = region.parent end
    assert(region, "nothing clickable owns " .. text)
    wow.Click(region)
end

-- Load Salve exactly as a TOC lists it, then fire ADDON_LOADED.
local function loadAddon(tocName, saved)
    local camelot = tocName:find("Camelot") and "Camelot" or nil
    wow.Install({ Salve = { Version = "1.5.26-dev1", ["X-Salve-Target"] = camelot } })
    C_Timer = { After = function() end,
        NewTimer = function() return { Cancel = function() end } end,
        NewTicker = function() return { Cancel = function() end } end }
    UnitClass = function() return "Paladin", "PALADIN" end
    GetTime = function() return 100 end
    UnitExists = function(unit) return unit == "player" end
    UnitName = function() return "Tester" end
    UnitIsUnit = function(a, b) return a == b end
    GetNumGroupMembers = function() return 1 end
    GetSpellTexture = function() return 134400 end
    C_Spell = { GetSpellInfo = function(id) return { name = "Spell " .. id, iconID = 134400 } end,
        GetSpellCooldown = function() return nil end, GetSpellTexture = function() return 134400 end }
    GetSpellInfo = function(id) return "Spell " .. tostring(id), nil, 134400 end
    GetBuildInfo = function() return "12.1.0", "1", "", 120100 end
    IsInRaid, IsInGroup = function() return false end, function() return false end
    SalveDB = saved
    local ns = {}
    for line in io.lines(tocName) do
        local entry = line:gsub("\r", ""):gsub("\\", "/")
        if entry:match("%.xml$") then
            wow.LoadHammerCore(entry:match("^(.*)/[^/]+$"), "Salve", ns)
        elseif entry:match("%.lua$") then
            assert(loadfile(entry))("Salve", ns)
        end
    end
    local events = _G.SalveEventFrame
    events.scripts.OnEvent(events, "ADDON_LOADED", "Salve")
    -- Spells known to this character, as spell discovery would record them.
    ns.knownDispels = { { id = 4987, name = "Cleanse", cures = { Magic = true } } }
    ns.knownEscapes = { { id = 1044, name = "Blessing of Freedom", scope = "ALLY", note = "" } }
    return ns
end

for _, toc in ipairs({ "Salve.toc", "Salve_Camelot.toc" }) do
    local ns = loadAddon(toc, { showStartupMessage = true, showMinimap = false, minimapAngle = 33,
        settingsPoint = { "TOPLEFT", "TOPLEFT", 20, -20 }, movementSweepSpellIDs = { [1044] = true } })
    local HC = ns.HammerCore
    equal(wow.LastPrint(), "Salve v1.5.26-dev1 loaded - type /salve for settings, /salve help for commands",
        toc .. ": standard login message")
    equal(HC.State().minimap, false, toc .. ": a hidden minimap stays hidden")
    equal(HC.State().minimapAngle, 33, toc .. ": minimap position is kept")
    equal(HC.State().settingsPoint[3], 20, toc .. ": settings position is kept")
    equal(SalveDB.showMinimap, nil, toc .. ": the old minimap key is removed")
    equal(HC.Minimap.button:GetName(), "SalveMinimapButton", toc .. ": minimap button keeps its name")

    SlashCmdList.SALVE("")
    equal(HC.Settings:IsShown(), true, toc .. ": the bare command opens settings")
    local names = {}
    for _, spec in ipairs(HC.Settings.order) do names[#names + 1] = spec.name end
    equal(table.concat(names, ","),
        "Salve,Tooltips,Actions,Visibility,Alerts,Learned Spells,Theme,Commands,Troubleshooting,About",
        toc .. ": rail order")
    local failures = {}
    for name, err in pairs(HC.Settings.errors) do failures[#failures + 1] = name .. ": " .. err end
    equal(table.concat(failures, "; "), "", toc .. ": every settings page builds")
    equal(ns.db.movementSweepSpellIDs[1044], true, toc .. ": building settings keeps saved sweep selections")
    for _, spec in ipairs(HC.Settings.order) do
        HC.Settings:Show(spec.name)
        equal(HC.Settings.selected, spec.name, toc .. ": " .. spec.name .. " opens")
    end

    -- Page content carried over from the old settings shell.
    for _, text in ipairs({ "Show dispel-type icon", "Show Salve actions", "Show self-dispel combat text",
        "Show personal Freedom movement text", "Show minimap button", "Show startup message" }) do
        equal(wow.FindText(text) ~= nil, true, toc .. ": settings offer '" .. text .. "'")
    end
    for _, text in ipairs({ "Show spell IDs", "Show privacy note", "Show actions heading" }) do
        equal(wow.FindText(text), nil, toc .. ": settings omit '" .. text .. "'")
    end

    -- Presets and the in-settings preview.
    clickText("Named")
    equal(ns.db.boxWidth, 95, toc .. ": Named preset sets cell width")
    equal(ns.db.columns, 5, toc .. ": Named preset sets cells per row")
    equal(ns.db.showNames, true, toc .. ": Named preset shows names")
    clickText("Raid wall")
    equal(ns.db.columns, 10, toc .. ": Raid wall preset sets ten cells per row")
    equal(ns.db.spacing, 0, toc .. ": Raid wall preset removes gaps")
    equal(ns.db.showNames, false, toc .. ": Raid wall preset hides names")

    -- The preview survives page changes and stops when settings close.
    HC.Settings:Show("Salve")
    ns.Preview.active = true
    HC.Settings:Show("Actions")
    equal(ns.Preview.active, true, toc .. ": preview persists across pages")
    local stops = 0
    local stop = ns.Preview.Stop
    ns.Preview.Stop = function(self) stops = stops + 1; self.active = false end
    HC.Settings:Hide()
    equal(stops, 1, toc .. ": closing settings stops the preview")
    ns.Preview.Stop = stop

    -- Alerts reset.
    HC.Settings:Show("Alerts")
    ns.db.soundChannel, ns.db.selfDispelNotification = "SFX", false
    wow.Click(wow.FindButton("Reset Alerts"))
    equal(ns.db.soundChannel, "Master", toc .. ": Reset Alerts restores the sound channel")
    equal(ns.db.selfDispelNotification, true, toc .. ": Reset Alerts restores the self-dispel text")

    -- Commands.
    SlashCmdList.SALVE("lock")
    equal(ns.IsLocked(), true, toc .. ": lock hides the handle")
    SlashCmdList.SALVE("unlock")
    equal(ns.IsLocked(), false, toc .. ": unlock shows it")
    ns.db.visibilityMode = "ALWAYS"
    SlashCmdList.SALVE("toggle")
    equal(ns.db.visibilityMode, "NEVER", toc .. ": toggle hides the panel")
    SlashCmdList.SALVE("toggle")
    SlashCmdList.SALVE("version")
    equal(wow.LastPrint():find(toc:find("Camelot") and "(WoW Forever)" or "(Retail)", 1, true) ~= nil, true,
        toc .. ": version names the client")
    SlashCmdList.SALVE("debug")
    equal(HC.Copy.frame.edit:GetText():find("Aura filter:", 1, true) ~= nil, true,
        toc .. ": debug includes Salve's report")
    SlashCmdList.SALVE("forever")
    equal(HC.Copy.frame.title:GetText(), "Copy Forever spell report", toc .. ": forever opens its report")

    wow.printed = {}
    SlashCmdList.SALVE("help")
    local sawLearned = false
    for _, line in ipairs(wow.printed) do
        if wow.Plain(line) == "  /salve learned clear - Clear recorded auras" then sawLearned = true end
    end
    equal(sawLearned, true, toc .. ": Salve commands are listed in help")
    for _, old in ipairs({ "options", "config", "probe", "handle", "reset", "spells", "learn" }) do
        SlashCmdList.SALVE(old)
        equal(wow.LastPrint(), "Salve: unknown command. Type /salve help for the list.",
            toc .. ": old command '" .. old .. "' is removed")
    end
end

io.write("addon tests passed\n")
