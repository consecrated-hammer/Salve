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
    local ns = loadAddon(toc)
    local settings = ns.HammerCore.Settings
    settings:Show("Cooldowns", "Cells")
    for name, err in pairs(settings.errors) do error(name .. ": " .. err) end
    local function button(label)
        for _, frame in ipairs(wow.frames) do
            if type(rawget(frame, "Text")) == "table" and frame.Text.text == label and frame.scripts.OnClick and wow.Visible(frame) then return frame end
        end
        error("no visible button " .. label)
    end
    local function visible(label) return wow.Visible(assert(wow.FindText(label), label)) end
    local function refresh(page)
        settings.pages[page].hcRefreshAll()
    end
    local function set(key, value, page)
        ns.Set(key, value)
        refresh(page)
    end
    set("cooldownStyle", "BOX", "Cooldowns")
    equal(visible("Cooldown icon size"), false, toc .. ": whole-cell style hides icon size")
    set("cooldownStyle", "ICON", "Cooldowns")
    equal(visible("Cooldown icon size"), true, toc .. ": icon style reveals size")
    equal(visible("Number text size"), true, toc .. ": numbers now live on Cooldowns Cells")

    settings:Show("Cooldowns", "Bar")
    set("cooldownBar", false, "Cooldowns")
    set("lockoutIcons", false, "Cooldowns")
    equal(visible("Bar position"), false, toc .. ": inactive bar hides geometry")
    equal(visible("Show when ready"), false, toc .. ": inactive bar hides ready switch")
    set("lockoutPlacement", "BAR", "Cooldowns")
    set("lockoutIcons", true, "Cooldowns")
    equal(visible("Bar position"), true, toc .. ": bar lockouts retain bar geometry")
    equal(visible("Show when ready"), false, toc .. ": lockouts do not enable cooldown-ready switch")
    set("cooldownBarMatchPanel", true, "Cooldowns")
    equal(visible("Bar icon size"), false, toc .. ": matching cells hides custom size")
    set("cooldownBarMatchPanel", false, "Cooldowns")
    equal(visible("Bar icon size"), true, toc .. ": custom size returns")

    settings:Show("Cooldowns", "Lockouts")
    equal(visible("Lockout icon size"), false, toc .. ": bar-only lockouts hide cell controls")
    set("lockoutPlacement", "BOTH", "Cooldowns")
    equal(visible("Lockout icon size"), true, toc .. ": both placements reveal cell controls")
    set("lockoutIcons", false, "Cooldowns")
    equal(visible("Show on"), false, toc .. ": lockout master hides placement")
    equal(visible("Lockout icon size"), false, toc .. ": lockout master hides size")

    ns.Set("cooldownFontSize", 31)
    ns.Set("cooldownBarGap", 37)
    ns.Set("lockoutIconSize", 29)
    settings:Show("Cooldowns", "Cells")
    wow.Click(button("Reset Cells"))
    equal(ns.db.cooldownFontSize, ns.defaults.cooldownFontSize, toc .. ": Cells reset restores number size")
    equal(ns.db.cooldownBarGap, 37, toc .. ": Cells reset preserves bar")
    equal(ns.db.lockoutIconSize, 29, toc .. ": Cells reset preserves lockouts")
    settings:Show("Cooldowns", "Bar")
    wow.Click(button("Reset Bar"))
    equal(ns.db.cooldownBarGap, ns.defaults.cooldownBarGap, toc .. ": Bar reset restores bar")
    equal(ns.db.lockoutIconSize, 29, toc .. ": Bar reset preserves lockouts")
    settings:Show("Cooldowns", "Lockouts")
    wow.Click(button("Reset Lockouts"))
    equal(ns.db.lockoutIconSize, ns.defaults.lockoutIconSize, toc .. ": Lockouts reset restores lockouts")

    settings:Show("Alerts")
    set("movementAlertsEnabled", false, "Alerts")
    equal(visible("Play movement alert sound"), false, toc .. ": movement master hides sound")
    equal(visible("Show movement text"), false, toc .. ": movement master hides text")
    set("movementAlertsEnabled", true, "Alerts")
    set("movementTextNotification", false, "Alerts")
    equal(visible("Movement text destination"), false, toc .. ": text switch hides destination")
    set("movementTextNotification", true, "Alerts")
    set("movementTextOutput", "SCREEN", "Alerts")
    equal(visible("Movement chat tab"), false, toc .. ": screen output hides chat tab")
    set("movementTextOutput", "CHAT", "Alerts")
    equal(visible("Movement chat tab"), true, toc .. ": chat output reveals chat tab")
    local stopped = 0
    ns.MovementAlert.StopPreview = function() stopped = stopped + 1 end
    -- The harness does not cascade ancestor OnHide events to descendants.
    for _, body in pairs(settings.pages.Alerts.bodies) do
        if body.content and body.content.scripts.OnHide then body.content.scripts.OnHide(body.content) end
    end
    settings:Show("Tooltips")
    assert(stopped > 0, toc .. ": leaving Alerts stops text preview")
    set("showTooltip", false, "Tooltips")
    equal(visible("Anchor"), false, toc .. ": tooltip master hides anchor")
    equal(visible("Show Salve actions"), false, toc .. ": tooltip master hides actions")
    set("showTooltip", true, "Tooltips")
    set("tooltipActions", false, "Tooltips")
    equal(visible("Anchor"), true, toc .. ": tooltip master restores anchor")
    equal(visible("Show spell descriptions"), false, toc .. ": actions switch hides descriptions")
    set("tooltipActions", true, "Tooltips")
    equal(visible("Show spell descriptions"), true, toc .. ": actions switch restores descriptions")

    local bound = {}
    ns.Options.BoundSpells = function() return bound end
    settings:Show("Cooldowns", "Cells")
    bound = { { kind = "ESCAPE", spell = { id = 1044, name = "Freedom" } } }
    ns.Options.RefreshMovementSweeps()
    local matches = settings:Search("Movement sweep: Freedom")
    equal(#matches, 1, toc .. ": newly bound movement spell is searchable")
    bound = {}
    ns.Options.RefreshMovementSweeps()
    equal(#settings:Search("Movement sweep: Freedom"), 0, toc .. ": unbinding removes stale sweep search row")
end
print("Salve cooldown, alert and tooltip settings: passed both TOCs")
