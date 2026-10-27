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

local function choose(label, choice)
    local row = assert(wow.FindText(label), label).parent
    for _, frame in ipairs(wow.frames) do
        if frame.parent == row and frame.scripts.OnClick then
            wow.Click(frame)
            break
        end
    end
    for _, region in ipairs(wow.regions) do
        if region.text == choice and wow.Visible(region) and region.parent.value ~= nil
            and region.parent.scripts.OnClick then
            wow.Click(region.parent)
            return
        end
    end
    error("no visible menu choice " .. choice)
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
        "Salve,Tooltips,Actions,Visibility,Alerts,Movement,Learned Spells,Commands,Troubleshooting,About",
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

    -- Border controls restyle the live frame and preview without changing
    -- the secure click target or suppressing movement response cues.
    ns.Panel:Create()
    local box = ns.Panel.boxes[1]
    box.unit = "player"
    local previewBox = ns.Box.CreatePreview(UIParent)
    clickText("Show box borders")
    equal(ns.db.showBorders, false, toc .. ": border checkbox saves false")
    equal(box.border.alpha, 0, toc .. ": border checkbox hides live border")
    ns.Box.RestylePreview(previewBox, "Tester", "PALADIN")
    equal(previewBox.border.alpha, 0, toc .. ": preview hides border too")
    clickText("Show idle backgrounds")
    equal(box.plate.alpha, 0, toc .. ": idle plate can be hidden with the border")
    ns.Box.SetMovementPrompt(box, true)
    equal(box.border.alpha, 0, toc .. ": movement cue leaves border hidden")
    equal(box.actionPrompt:IsShown(), true, toc .. ": movement cue still draws")
    ns.Box.SetMovementPrompt(box, false)
    equal(box.border.alpha, 0, toc .. ": clearing movement cue leaves border hidden")
    ns.Set("showTooltip", false)
    clickText("Preview movement sweep")
    wow.Click(wow.FindButton("Reset Panel"))
    equal(ns.db.showTooltip, false, toc .. ": Panel reset leaves tooltip preference alone")
    equal(ns.Preview.movementSweepState, false, toc .. ": Panel reset clears movement preview")
    equal(ns.db.showBorders, true, toc .. ": Panel reset restores borders")
    equal(box.border.alpha, 1, toc .. ": Panel reset restores live outline")
    ns.Box.RestylePreview(previewBox, "Tester", "PALADIN")
    equal(previewBox.border.alpha, 1, toc .. ": preview outline can be restored")

    -- Combined controls keep the old saved keys, including the inactive axis.
    HC.Settings:Show("Salve")
    ns.Set("horizontalGrowth", "LEFT")
    choose("Grid direction", "Columns from bottom")
    equal(ns.db.orientation, "VERTICAL", toc .. ": direction sets fill")
    equal(ns.db.verticalGrowth, "UP", toc .. ": direction sets growth")
    equal(ns.db.horizontalGrowth, "LEFT", toc .. ": direction preserves other axis")
    clickText("Show unit names")
    local positions = {
        { "Top left", "LEFT", "TOP" }, { "Top centre", "CENTER", "TOP" }, { "Top right", "RIGHT", "TOP" },
        { "Middle left", "LEFT", "MIDDLE" }, { "Centre", "CENTER", "MIDDLE" }, { "Middle right", "RIGHT", "MIDDLE" },
        { "Bottom left", "LEFT", "BOTTOM" }, { "Bottom centre", "CENTER", "BOTTOM" }, { "Bottom right", "RIGHT", "BOTTOM" },
    }
    for _, position in ipairs(positions) do
        for _, spec in ipairs({ { "Name position", "name" }, { "Number position", "cooldown" } }) do
            choose(spec[1], position[1])
            equal(ns.db[spec[2] .. "JustifyH"], position[2], toc .. ": horizontal " .. spec[1])
            equal(ns.db[spec[2] .. "JustifyV"], position[3], toc .. ": vertical " .. spec[1])
        end
    end
    clickText("Show unit names")
    equal(wow.Visible(wow.FindText("Name position")), false, toc .. ": name details collapse")
    equal(wow.Visible(wow.FindText("Show unit names")), true, toc .. ": name enable remains visible")
    clickText("Show idle backgrounds")
    equal(wow.Visible(wow.FindText("Idle opacity")), false, toc .. ": idle details collapse")
    equal(ns.db.cleanAlpha, 0.25, toc .. ": hiding backgrounds remembers opacity")

    -- Both hosts show every aura indicator even with a single preview unit.
    ns.Preview.count = 1
    ns.Preview.cellState = "DISPELLABLE"
    local previousTextureAPI = C_Texture
    C_Texture = { GetAtlasInfo = function() return nil end }
    ns.Set("dispelTypeIconSize", 37)
    ns.Set("dispelTypeIconPosition", "TOPRIGHT")
    ns.Preview:Start()
    ns.Preview:RefreshSettingsPreview()
    for _, sample in ipairs({ ns.Preview.boxes[1], ns.Preview.settingsPreview.boxes[1] }) do
        equal(sample.previewDispelIcon:IsShown(), true, toc .. ": preview displays icon")
        equal(sample.previewDispelIcon.width, 37, toc .. ": preview uses icon size")
        equal(sample.previewDispelIcon:GetPoint(), "TOPRIGHT", toc .. ": preview uses icon position")
        equal(sample.previewDispelIcon.texture, 134400, toc .. ": missing atlas uses visible fallback")
        equal(sample.previewStack.text, "2", toc .. ": solo preview displays stacks")
    end
    C_Texture = { GetAtlasInfo = function() return {} end }
    for _, sample in ipairs({ ns.Preview.boxes[1], ns.Preview.settingsPreview.boxes[1] }) do
        sample.previewDispelIcon.SetAtlas = function(self, atlas) self.testAtlas = atlas end
    end
    ns.Preview:Refresh()
    ns.Preview:RefreshSettingsPreview()
    for _, sample in ipairs({ ns.Preview.boxes[1], ns.Preview.settingsPreview.boxes[1] }) do
        equal(sample.previewDispelIcon.testAtlas, "RaidFrame-Icon-DebuffMagic", toc .. ": available atlas is used")
    end
    C_Texture = previousTextureAPI
    clickText("Show dispel-type icon")
    equal(wow.Visible(wow.FindText("Icon size")), false, toc .. ": icon details collapse")
    ns.Set("showStacks", false)
    ns.Preview:RefreshSettingsPreview()
    for _, sample in ipairs({ ns.Preview.boxes[1], ns.Preview.settingsPreview.boxes[1] }) do
        equal(sample.previewDispelIcon:IsShown(), false, toc .. ": preview hides disabled icon")
        equal(sample.previewStack.text, "", toc .. ": preview hides disabled stacks")
    end
    ns.Preview:Stop()

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

    -- Movement page owns every automatic movement control.
    HC.Settings:Show("Movement")
    equal(ns.db.movementAlertsEnabled, true, toc .. ": movement alerts preserve previous default")
    equal(ns.db.inferredSlowAlertsEnabled, false, toc .. ": inferred slows start opted out")
    clickText("Enable movement alerts (beta)")
    equal(ns.db.movementAlertsEnabled, false, toc .. ": movement master switch saves false")
    local savedEscapes = ns.db.escapes
    clickText("Enable movement alerts (beta)")
    equal(ns.db.movementAlertsEnabled, true, toc .. ": movement master switch can re-enable")
    equal(ns.db.escapes, savedEscapes, toc .. ": movement master switch preserves spell choices")
    equal(wow.LastPrint():find("in beta and may not work correctly", 1, true) ~= nil, true,
        toc .. ": enabling movement alerts warns about beta")
    clickText("Include inferred slows (beta)")
    equal(ns.db.inferredSlowAlertsEnabled, true, toc .. ": inferred slow opt-in saves true")
    equal(wow.LastPrint():find("Inferred slows are in beta", 1, true) ~= nil, true,
        toc .. ": enabling inferred slows warns about beta")
    clickText("Enable movement alerts (beta)")
    ns.db.movementTextOutput, ns.db.movementSoundEnabled = "CHAT", true
    wow.Click(wow.FindButton("Reset Movement"))
    equal(ns.db.movementAlertsEnabled, true, toc .. ": Reset Movement restores the master switch")
    equal(ns.db.inferredSlowAlertsEnabled, false, toc .. ": Reset Movement opts out of inferred slows")
    equal(ns.db.movementSoundEnabled, false, toc .. ": Reset Movement restores the movement sound")
    equal(ns.db.movementTextOutput, "SCREEN", toc .. ": Reset Movement restores the text destination")
    clickText("Open Actions")
    equal(HC.Settings.selected, "Actions", toc .. ": Movement links to Actions for bindings")

    -- Alerts reset.
    HC.Settings:Show("Alerts")
    for _, text in ipairs({ "Enable movement alerts (beta)", "Include inferred slows (beta)",
        "Play snare-removal alert sound", "Show personal Freedom movement text" }) do
        equal(wow.Visible(wow.FindText(text)), false, toc .. ": Alerts no longer shows '" .. text .. "'")
    end
    equal(ns.db.learningScopeMessages, true, toc .. ": scope messages start enabled")
    equal(ns.db.learningDiscoveryMessages, true, toc .. ": discovery messages start enabled")
    clickText("Show learning scope changes")
    clickText("Show newly learned spells")
    equal(ns.db.learningScopeMessages, false, toc .. ": scope message checkbox saves false")
    equal(ns.db.learningDiscoveryMessages, false, toc .. ": discovery message checkbox saves false")
    equal(ns.db.learnMode, true, toc .. ": muting messages keeps learning enabled")
    ns.db.soundChannel, ns.db.selfDispelNotification = "SFX", false
    wow.Click(wow.FindButton("Reset Alerts"))
    equal(ns.db.learningScopeMessages, true, toc .. ": Reset Alerts restores scope messages")
    equal(ns.db.learningDiscoveryMessages, true, toc .. ": Reset Alerts restores discovery messages")
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

-- Every page also builds under HammerCore's Classic theme.
for _, toc in ipairs({ "Salve.toc", "Salve_Camelot.toc" }) do
    local ns = loadAddon(toc, { hammerCore = { theme = "classic" } })
    local HC = ns.HammerCore
    -- Classic is switched off for players until it is reworked; keep it building.
    HC.Theme.registry.classic.available = true
    equal(HC.Theme.IsClassic(), true, toc .. ": classic theme is active")
    HC.Settings:Show()
    local failures = {}
    for name, err in pairs(HC.Settings.errors) do failures[#failures + 1] = name .. ": " .. err end
    equal(table.concat(failures, "; "), "", toc .. ": every settings page builds in classic")
    for _, spec in ipairs(HC.Settings.order) do
        HC.Settings:Show(spec.name)
        equal(HC.Settings.selected, spec.name, toc .. ": " .. spec.name .. " opens in classic")
    end
end

io.write("addon tests passed\n")
