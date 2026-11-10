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
local function loadAddon(tocName, saved, version)
    local camelot = tocName:find("Camelot") and "Camelot" or nil
    wow.Install({ Salve = { Version = version or "1.5.26-dev1", ["X-Salve-Target"] = camelot } })
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
        "Salve,Profiles,Sorting,Attach,Cooldowns,Tooltips,Key Bindings,Visibility,Alerts,Movement,Learned Spells,What's new,Commands,Troubleshooting,About",
        toc .. ": rail order")
    local failures = {}
    for name, err in pairs(HC.Settings.errors) do failures[#failures + 1] = name .. ": " .. err end
    equal(table.concat(failures, "; "), "", toc .. ": every settings page builds")
    equal(ns.db.movementSweepSpellIDs[1044], true, toc .. ": building settings keeps saved sweep selections")
    for _, spec in ipairs(HC.Settings.order) do
        HC.Settings:Show(spec.name)
        equal(HC.Settings.selected, spec.name, toc .. ": " .. spec.name .. " opens")
    end
    -- Every What's new button must open a page that exists.
    local pages = {}
    for _, spec in ipairs(HC.Settings.order) do pages[spec.name] = true end
    for _, release in ipairs(ns.WHATS_NEW) do
        for _, item in ipairs(release.items) do
            if item.page then
                equal(pages[item.page], true, toc .. ": What's new page " .. item.page .. " exists")
            end
        end
    end
    equal(HC.Commands.byName.whatsnew ~= nil, true, toc .. ": /salve whatsnew is registered")

    -- Page content carried over from the old settings shell.
    for _, text in ipairs({ "Show dispel-type icon", "Show Salve actions", "Show self-dispel combat text",
        "Show personal Freedom movement text", "Show minimap button", "Show startup message",
        "Hide on flights", "Minimap right-click", "Handle right-click" }) do
        equal(wow.FindText(text) ~= nil, true, toc .. ": settings offer '" .. text .. "'")
    end
    for _, text in ipairs({ "Show spell IDs", "Show privacy note", "Show actions heading" }) do
        equal(wow.FindText(text), nil, toc .. ": settings omit '" .. text .. "'")
    end

    local minimapRows = 0
    for _, region in ipairs(wow.regions) do
        if region.text == "Minimap right-click" then minimapRows = minimapRows + 1 end
    end
    equal(minimapRows, 1, toc .. ": one Minimap right-click row, HammerCore's")

    -- Hide on flights rides HammerCore's takeoff and landing, without
    -- LibTaxiData's estimates.
    equal(HC.Flights.enabled, true, toc .. ": flight tracking is on")
    equal(HC.Flights.Estimates(), false, toc .. ": no flight time estimates")
    UnitOnTaxi = function() return true end
    HC.Flights.frame.scripts.OnEvent(HC.Flights.frame, "PLAYER_ENTERING_WORLD")
    equal(ns.Visibility:HiddenForFlight(), true, toc .. ": a flight hides Salve")
    UnitOnTaxi = function() return false end
    HC.Flights:Tick()
    equal(ns.Visibility:HiddenForFlight(), false, toc .. ": landing brings Salve back")
    -- A dialogue flight has no flight-map click: control loss plus taxi state.
    UnitOnTaxi = function() return true end
    HC.Flights.frame.scripts.OnEvent(HC.Flights.frame, "PLAYER_CONTROL_LOST")
    equal(ns.Visibility:HiddenForFlight(), true, toc .. ": a dialogue flight hides Salve")
    UnitOnTaxi = function() return false end
    HC.Flights:Tick()
    equal(ns.Visibility:HiddenForFlight(), false, toc .. ": and landing brings it back")
    UnitOnTaxi = nil

    -- The live preview opens from the header in its own window.
    HC.Settings:Show("Salve")
    assert(wow.FindButton("Show live preview"), toc .. ": Panel offers the live preview")
    wow.Click(wow.FindButton("Show live preview"))
    equal(ns.Preview:IsWindowShown(), true, toc .. ": the header button opens the live preview")
    assert(wow.FindButton("Hide live preview"), toc .. ": and then offers to hide it")
    local drawnScale
    ns.Preview.settingsPreview.frame.SetScale = function(_, value) drawnScale = value end
    ns.Set("scale", 1.5)
    ns.Preview:RefreshSettingsPreview()
    equal(drawnScale, ns.Panel:Layout(ns.db.previewUnits).scale, toc .. ": the preview draws at the panel's own scale")
    ns.Set("scale", ns.defaults.scale)
    HC.Settings:Show("Sorting")
    equal(ns.Preview:IsWindowShown(), true, toc .. ": it stays open across pages")
    assert(wow.FindButton("Hide live preview"), toc .. ": Sorting offers it too")
    HC.Settings:Show("Commands")
    equal(wow.Visible(wow.FindButton("Hide live preview")), false, toc .. ": reference pages don't")
    HC.Settings:Show("Salve")

    -- Presets.
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
    ns.Box.SetMovementPrompt(box, true, 1044)
    equal(box.border.alpha, 0, toc .. ": movement cue leaves border hidden")
    equal(box.movementBadge:IsShown(), true, toc .. ": movement badge still draws")
    equal(box.movementBadge.spellID, 1044, toc .. ": badge points at the movement spell")
    local cellW, cellH = box:GetWidth(), box:GetHeight()
    box:SetSize(20, 20)
    ns.Box.SetMovementPrompt(box, true, 1044)
    equal(box.movementBadge:GetWidth(), 10, toc .. ": a small cell keeps its debuff visible under the badge")
    box:SetSize(cellW, cellH)
    equal(ns.Box.MovementBadgePosition(), "TOPRIGHT",
        toc .. ": badge avoids the dispel-type and lockout corners")
    ns.Box.SetMovementPrompt(box, false)
    equal(box.movementBadge:IsShown(), false, toc .. ": clearing hides the badge")
    equal(box.border.alpha, 0, toc .. ": clearing movement cue leaves border hidden")
    ns.Set("showTooltip", false)
    local layer
    ns.Preview.window.SetFrameStrata = function(_, strata) layer = strata end
    ns.Preview:ApplyWindowLayer()
    equal(layer, "FULLSCREEN", toc .. ": the preview keeps in front of settings by default")
    clickText("Keep in front")
    equal(ns.db.previewWindowOnTop, false, toc .. ": Keep in front saves off")
    equal(layer, "DIALOG", toc .. ": off, it shares the settings window's layer")
    clickText("Keep in front")
    local redraws = 0
    local redraw = ns.Preview.RefreshSettingsPreview
    ns.Preview.RefreshSettingsPreview = function(self) redraws = redraws + 1; return redraw(self) end
    ns.Set("boxWidth", 60)
    ns.Set("cooldownFontSize", 16)
    equal(redraws, 2, toc .. ": settings changes redraw the live preview straight away")
    ns.Preview.RefreshSettingsPreview = redraw
    ns.Set("boxWidth", ns.defaults.boxWidth)
    ns.Set("cooldownFontSize", ns.defaults.cooldownFontSize)
    clickText("Movement sweep")
    equal(ns.Preview.movementSweepState, true, toc .. ": the window's switch previews the sweep")
    -- Sample states mix freely, and say why one can't show.
    equal(ns.Preview.cooldownState, "READY", toc .. ": the dispel starts ready, so the debuff reads clearly")
    clickText("Dispel on cooldown")
    equal(ns.Preview.cooldownState, "COOLDOWN", toc .. ": the cooldown state is its own switch")
    equal(ns.Preview.cellState, "DISPELLABLE", toc .. ": alongside the debuff")
    clickText("Dispel on cooldown")
    local bound, enabled = ns.Cooldowns.BoundSpells, ns.Escape.IsEnabledSpell
    ns.Cooldowns.BoundSpells = function() return { 1044 } end
    ns.Escape.IsEnabledSpell = function(_, id) return id == 1044 end
    clickText("Rooted")
    local badges = 0
    for _, sample in ipairs(ns.Preview.settingsPreview.boxes) do
        if sample:IsShown() and sample.movementBadge and sample.movementBadge:IsShown() then
            badges = badges + 1
            equal(sample.movementBadge.spellID, 1044, toc .. ": the rooted badge shows the bound freedom spell")
        end
    end
    equal(badges, 1, toc .. ": Rooted badges only the player's cell")
    ns.Cooldowns.BoundSpells, ns.Escape.IsEnabledSpell = bound, enabled
    ns.Preview:RefreshSettingsPreview()
    assert(ns.Preview.settingsPreview.note.text:find("Rooted: no movement spell is bound", 1, true),
        toc .. ": the note explains a state that can't show")
    ns.Set("lockoutIcons", false)
    assert(ns.Preview.settingsPreview.note.text:find("Show lockout debuffs is off", 1, true),
        toc .. ": and a lockout that's turned off")
    clickText("Rooted")
    -- Each tab resets only its own settings.
    ns.Set("boxWidth", 70)
    ns.Set("nameFontSize", 18)
    HC.Settings:Show("Salve", "Cells")
    wow.Click(wow.FindButton("Reset Cells"))
    equal(ns.db.showTooltip, false, toc .. ": Reset Cells leaves tooltip preference alone")
    equal(ns.db.showBorders, true, toc .. ": Reset Cells restores borders")
    equal(box.border.alpha, 1, toc .. ": Reset Cells restores live outline")
    equal(ns.db.boxWidth, 70, toc .. ": Reset Cells leaves Layout alone")
    equal(ns.db.nameFontSize, 18, toc .. ": and Text")
    equal(ns.Preview.movementSweepState, true, toc .. ": and the preview window's own switches")
    HC.Settings:Show("Salve", "Text")
    wow.Click(wow.FindButton("Reset Text"))
    equal(ns.db.nameFontSize, ns.defaults.nameFontSize, toc .. ": Reset Text restores text size")
    equal(ns.db.boxWidth, 70, toc .. ": and leaves Layout alone")
    HC.Settings:Show("Salve", "Layout")
    wow.Click(wow.FindButton("Reset Layout"))
    equal(ns.db.boxWidth, ns.defaults.boxWidth, toc .. ": Reset Layout restores cell width")
    clickText("Movement sweep")
    ns.Box.RestylePreview(previewBox, "Tester", "PALADIN")
    equal(previewBox.border.alpha, 1, toc .. ": preview outline can be restored")

    -- Fill and Start corner write the old saved keys; both axes always apply.
    HC.Settings:Show("Salve")
    choose("Fill", "Columns")
    equal(ns.db.orientation, "VERTICAL", toc .. ": Fill sets orientation")
    choose("Start corner", "Bottom right")
    equal(ns.db.verticalGrowth, "UP", toc .. ": bottom corner grows up")
    equal(ns.db.horizontalGrowth, "LEFT", toc .. ": right corner grows left")
    choose("Fill", "Rows")
    choose("Start corner", "Bottom left")
    equal(ns.db.orientation .. ":" .. ns.db.verticalGrowth .. ":" .. ns.db.horizontalGrowth,
        "HORIZONTAL:UP:RIGHT", toc .. ": rows from the bottom left")
    equal(ns.Panel:GrowthAnchor(), "BOTTOMLEFT", toc .. ": anchored at the bottom left")
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
    HC.Settings:Show("Salve", "Text")
    equal(wow.Visible(wow.FindText("Name position")), true, toc .. ": name details show on the Text tab")
    clickText("Show unit names")
    equal(wow.Visible(wow.FindText("Name position")), false, toc .. ": name details collapse")
    equal(wow.Visible(wow.FindText("Show unit names")), true, toc .. ": name enable remains visible")
    HC.Settings:Show("Salve", "Cells")
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
    HC.Settings:Show("Salve", "Cells")
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
    HC.Settings:Show("Key Bindings")
    equal(ns.Preview.active, true, toc .. ": preview persists across pages")
    local stops = 0
    local stop = ns.Preview.Stop
    ns.Preview.Stop = function(self) stops = stops + 1; self.active = false end
    HC.Settings:Hide()
    equal(stops, 1, toc .. ": closing settings stops the preview")
    ns.Preview.Stop = stop
    equal(ns.Preview:IsWindowShown(), false, toc .. ": closing settings closes the live preview")
    HC.Settings:Show("Salve")
    equal(ns.Preview:IsWindowShown(), false, toc .. ": it stays closed by default")
    HC.Settings:Hide()
    ns.db.previewWindowOpen = true
    HC.Settings:Show("Salve")
    equal(ns.Preview:IsWindowShown(), true, toc .. ": Open with settings reopens it")
    ns.db.previewWindowOpen = false

    -- Movement page owns every automatic movement control.
    HC.Settings:Show("Movement")
    assert(wow.FindText("MOVEMENT SWEEPS"), toc .. ": sweep settings live on Movement")
    assert(wow.FindText("No movement spells bound yet.") or wow.FindText("Show sweep"),
        toc .. ": the sweep section lists bound movement spells or says none")
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
    clickText("Open Key Bindings")
    equal(HC.Settings.selected, "Key Bindings", toc .. ": Movement links to Key Bindings")

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

-- Layout profiles: seeding, switching, quick menus and the slash command.
for _, toc in ipairs({ "Salve.toc", "Salve_Camelot.toc" }) do
    local ns = loadAddon(toc, { columns = 8, schemaVersion = 9,
        point = { "BOTTOMLEFT", "BOTTOMLEFT", 300, 120 } })
    local HC = ns.HammerCore
    local P = HC.Profiles
    ns.Panel:Create()
    -- The harness has no state drivers; count rebuild requests instead.
    local rebuilds = 0
    ns.RequestRebuild = function() rebuilds = rebuilds + 1 end
    equal(table.concat(P:Names(), ","), "Party,Raid 20,Raid 40", toc .. ": starter profiles")
    equal(P:Loaded(), "Party", toc .. ": Party is active on upgrade")
    equal(ns.db.columns, 8, toc .. ": the upgrade keeps the current layout")
    equal(ns.db.previewUnits, 5, toc .. ": Party previews five")
    equal(SalveDB.hcProfiles.list["Raid 40"].point[3], 300, toc .. ": every profile starts at the old position")

    P:Switch("Raid 40", "manual")
    equal(ns.db.previewUnits, 40, toc .. ": Raid 40 previews forty")
    equal(rebuilds, 1, toc .. ": a switch rebuilds the panel")
    ns.Set("columns", 10)
    ns.Set("verticalGrowth", "UP")
    P:Switch("Party", "manual")
    equal(ns.db.columns, 8, toc .. ": Party keeps its own columns")
    equal(ns.db.verticalGrowth, "DOWN", toc .. ": Party keeps its own start corner")
    SlashCmdList.SALVE("profile raid 40")
    equal(P:Loaded(), "Raid 40", toc .. ": /salve profile switches, ignoring case")
    equal(ns.db.columns .. ":" .. ns.db.verticalGrowth, "10:UP", toc .. ": Raid 40 comes back as left")
    equal(wow.LastPrint(), "Salve: switched to the Raid 40 profile", toc .. ": the command confirms")

    -- Minimap right-click: HammerCore's menu, with Salve's handle toggle and profiles.
    equal(HC.spec.minimap.rightClick, nil, toc .. ": Salve uses HammerCore's right-click")
    equal(HC.Minimap.RightClickMode(), "menu", toc .. ": the minimap opens the menu by default")
    equal(HC.Minimap.RightClickLabel(), "menu", toc .. ": minimap tooltip names the menu")
    HC.Minimap:RightClick()
    equal(HC.Menu:IsShown(), true, toc .. ": minimap right-click opens the menu")
    local function menuOrder()
        local order = {}
        for index, item in ipairs(HC.Minimap:MenuItems()) do
            order[index] = item.separator and "-" or tostring(item.text)
        end
        return table.concat(order, ",")
    end
    -- What the open menu shows, lines included.
    local function shownOrder()
        local order = {}
        for _, item in ipairs(HC.Menu.items) do
            if item.shown then order[#order + 1] = tostring(item.spec.text) end
        end
        local rules = 0
        for _, rule in ipairs(HC.Menu.rules) do if rule.shown then rules = rules + 1 end end
        return table.concat(order, ",") .. " (" .. rules .. " lines)"
    end
    equal(menuOrder(), "Salve settings,Profiles,-,Hide drag handle,-,Party,Raid 20,Raid 40",
        toc .. ": settings and Profiles, a line, the handle toggle, a line, then the profiles")
    equal(shownOrder(), "Salve settings,Profiles,Hide drag handle,Party,Raid 20,Raid 40 (2 lines)",
        toc .. ": the minimap menu shows every item and both lines")
    local minimapOrder = shownOrder()
    HC.Menu:Close()
    local locked = ns.IsLocked()
    for _, item in ipairs(HC.Minimap:MenuItems()) do
        if item.text == "Hide drag handle" then item.func() end
    end
    equal(ns.IsLocked(), not locked, toc .. ": the menu toggles the drag handle")
    equal(HC.Minimap:MenuItems()[4].text, "Show drag handle", toc .. ": the toggle follows the handle")
    HC.State().minimapRightClick = "settings"
    HC.Minimap:RightClick()
    equal(HC.Settings:IsShown(), true, toc .. ": Minimap right-click on Settings opens settings")
    HC.Settings:Hide()
    HC.State().minimapRightClick = nil
    ns.SetLocked(false)
    equal(ns.db.handleRightClick, "PROFILES", toc .. ": handle right-click opens the menu by default")
    wow.Click(ns.Handle.frame, "RightButton")
    equal(HC.Menu:IsShown(), true, toc .. ": the handle opens the menu")
    equal(shownOrder(), minimapOrder, toc .. ": the handle menu matches the minimap's")
    local _, anchor = HC.Menu.frame:GetPoint()
    equal(anchor, ns.Handle.frame, toc .. ": the handle menu opens under the handle")
    HC.Menu:Close()

    -- The page builds, with Salve's quick-switch rows.
    HC.Settings:Show("Profiles")
    equal(HC.Settings.selected, "Profiles", toc .. ": Profiles page opens")
    choose("Handle right-click", "Open settings")
    equal(ns.db.handleRightClick, "SETTINGS", toc .. ": handle right-click setting")
    choose("Mode", "Ask first")
    equal(SalveDB.hcProfiles.auto.mode, "ASK", toc .. ": auto-switch mode from the page")
    HC.Settings:Show("Salve")
    assert(wow.FindButton("Save as new..."), toc .. ": the Panel page offers Save as new")
    equal(wow.FindButton("Save as new..."):GetPoint(), "LEFT", toc .. ": Save as new follows the profile dropdown")
end

-- What's new fires once for a dev build of the next release, and not again.
for _, toc in ipairs({ "Salve.toc", "Salve_Camelot.toc" }) do
    local saved = { hammerCore = { startupMessage = false, whatsNewSeen = "1.9.0" } }
    local ns = loadAddon(toc, saved, "1.10.0-dev1")
    local HC = ns.HammerCore
    local W = HC.WhatsNew
    assert(W.eventFrame, toc .. ": an update from 1.9.0 schedules What's new")
    -- The window opens on a short timer after entering the world.
    C_Timer.After = function(_, fn) fn() end
    W.eventFrame.scripts.OnEvent(W.eventFrame, "PLAYER_ENTERING_WORLD")
    equal(W.frame ~= nil and W.frame.shown, true, toc .. ": What's new shows after the update")
    assert(wow.FindText("Salve 1.10.0"), toc .. ": it lists 1.10.0")
    equal(wow.FindText("Salve 1.8.0"), nil, toc .. ": releases already seen stay hidden")
    assert(wow.FindButton("Open Profiles"), toc .. ": a button opens the Profiles page")
    assert(wow.FindButton("Open Panel"), toc .. ": a button opens the Panel page")
    equal(saved.hammerCore.whatsNewSeen, "1.12.0", toc .. ": showing records the newest entry")
    wow.Click(wow.FindButton("Open Profiles"))
    equal(HC.Settings.selected, "Profiles", toc .. ": the button opens Profiles")

    -- The What's new page keeps the history, with an unread badge until visited.
    HC.Settings:Show("What's new")
    assert(wow.FindText("Salve 1.0.0"), toc .. ": the page lists the first stable release")
    assert(wow.FindText("EARLIER RELEASES"), toc .. ": back-filled history is grouped")
    local badge = HC.Settings.buttons["What's new"].unreadBadge
    badge.complete.scripts.OnFinished()
    equal(badge.shown, false, toc .. ": visiting clears the badge")

    ns = loadAddon(toc, saved, "1.10.0-dev2")
    equal(ns.HammerCore.WhatsNew.eventFrame, nil, toc .. ": the next dev build stays quiet")
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
