-- This runs automatically in both lint and release CI via test_*.lua.
package.path = "./tests/hammercore/?.lua;" .. package.path
local wow = require("wow")

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
    local registrations, rows = {}, {}
    for line in io.lines(tocName) do
        local entry = line:gsub("\r", ""):gsub("\\", "/")
        if entry:match("%.xml$") then
            wow.LoadHammerCore(entry:match("^(.*)/[^/]+$"), "Salve", ns)
            local UI = ns.HammerCore.UI
            local register, makeRow, actionButton = UI.RegisterRow, UI.Row, UI.ActionButton
            UI.RegisterRow = function(parent, row, label)
                local resolved = type(label) == "function" and label() or label
                local owner = parent.hcHeaderOwner or parent
                local previous = owner.hcRows and owner.hcRows[resolved]
                assert(not previous or previous == row, "duplicate setting label: " .. tostring(resolved))
                registrations[#registrations + 1] = { owner = owner, row = row, label = resolved }
                return register(parent, row, label)
            end
            UI.ActionButton = function(...)
                local button, y = actionButton(...)
                rows[#rows + 1] = button
                return button, y
            end
            UI.Row = function(...)
                local row = makeRow(...)
                rows[#rows + 1] = row
                return row
            end
        elseif entry:match("%.lua$") then
            assert(loadfile(entry))("Salve", ns)
        end
    end
    local events = _G.SalveEventFrame
    events.scripts.OnEvent(events, "ADDON_LOADED", "Salve")
    -- Spells known to this character, as spell discovery would record them.
    ns.knownDispels = { { id = 4987, name = "Cleanse", cures = { Magic = true } } }
    ns.knownEscapes = { { id = 1044, name = "Blessing of Freedom", scope = "ALLY", note = "" } }
    return ns, registrations, rows
end

local checked = 0
for _, toc in ipairs({ "Salve.toc", "Salve_Camelot.toc" }) do
    local ns, registrations, rows = loadAddon(toc, { hammerCore = {}, schemaVersion = 12 })
    local settings = ns.HammerCore.Settings
    settings:Show("Salve")
    assert(next(settings.errors) == nil, "every page must build before checking search")
    local bodies, indexed = {}, {}
    for name, page in pairs(settings.pages) do
        for tab, body in pairs(page.bodies or {}) do
            bodies[body] = { page = name, tab = tab }
            for label, row in pairs(body.hcRows or {}) do indexed[row] = true end
        end
    end
    local initialCount = #registrations
    for index = 1, initialCount do
        local item = registrations[index]
        local location = bodies[item.owner]
        assert(location, "setting registered outside a page body: " .. tostring(item.label))
        local found = false
        for _, result in ipairs(settings:Search(item.label, 10000)) do
            if result.page == location.page and result.tab == location.tab and result.label == item.label then
                found = true
                assert(settings:Focus(result.page, result.label, result.tab), "search result cannot be focused: " .. item.label)
                break
            end
        end
        assert(found, "setting missing from search: " .. location.page .. " / " .. item.label)
        checked = checked + 1
    end
    for _, row in ipairs(rows) do
        assert(indexed[row], "standard settings row was never registered for search")
    end
    for query, expected in pairs({ preset = "Salve", target = "Salve", ["mouseover dispel"] = "Key Bindings",
        ["re-centre panel"] = "Position", ["sort by"] = "Salve", ["clear all bindings"] = "Key Bindings", ["your spells"] = "Key Bindings", ["attach to"] = "Position", anchor = "Tooltips", ["Also alert on sudden slows"] = "Alerts", ["Move movement text"] = "Alerts", ["Announce new learning zone"] = "Alerts" }) do
        local found = false
        for _, result in ipairs(settings:Search(query, 10000)) do
            if result.page == expected then found = true end
        end
        assert(found, "custom control/keyword missing from search: " .. query)
    end
    -- Mark storage scope without renaming searchable rows or changing saved keys.
    local profileRows = {
        Salve = {
            Layout = { "Compact layout preset", "Named layout preset", "Raid wall layout preset", "Fill", "Start corner", "Cells per row", "Cells per column", "Spacing", "Width", "Height", "Panel scale" },
            ["Names and icons"] = { "Show unit names", "Name position", "Name text size" },
            Members = { "Sort by", "Role order", "Reverse order", "Your cell" },
        },
        Position = { Position = { "Handle position", "Attach to", "Attach side", "Attach gap", "Align", "Up / down" } },
        Visibility = { Visibility = { "Show panel" } },
    }
    local affected = { Salve = { Layout = true, ["Names and icons"] = true, Members = true },
        Position = { Position = true }, Visibility = { Visibility = true }, Cooldowns = { Bar = true } }
    for _, scale in ipairs({ 0.7, 1.3 }) do
        ns.HammerCore.State().settingsScale = scale
        settings:ApplyScale()
        for pageName, page in pairs(settings.pages) do
            if pageName == "Salve" or pageName == "Position" or pageName == "Visibility" or pageName == "Cooldowns" then
                for tabName, body in pairs(page.bodies) do
                    settings:Show(pageName, tabName)
                    local expected = {}
                    for _, label in ipairs(profileRows[pageName] and profileRows[pageName][tabName] or {}) do expected[label] = true end
                    for label, row in pairs(body.hcRows or {}) do
                        local profile = expected[label] or (pageName == "Cooldowns" and tabName == "Bar" and label ~= "Reset bar" and label ~= "Bar spells")
                        assert(row.hcSettingScope == (profile and "profile" or "shared"), pageName .. "/" .. tabName .. ": storage scope for " .. label)
                        local icon = rawget(row, "hcScopeIcon")
                        assert((icon and icon:IsShown() or false) == (profile or false), "profile glyph matches scope for " .. label)
                        if profile then
                            assert(row.hcScopeMarker.mouseEnabled == false, "scope glyph must not intercept clicks")
                            assert(row.hcScopeMarker:GetFrameLevel() > row:GetFrameLevel(), "glyph stays above switch fill")
                            if label:find(" layout preset", 1, true) then
                                local textX = select(2, row.Text:GetPoint())
                                local markerX = select(4, row.hcScopeMarker:GetPoint())
                                assert(type(textX) == "number" and textX >= markerX + row.hcScopeMarker:GetWidth() + 4,
                                    "preset text reserves the profile glyph gutter")
                            end
                        end
                    end
                    local count = 0
                    for _, region in ipairs(wow.regions) do
                        if type(region.text) == "string" and region.text:find("Profile icon:", 1, true) then
                            local parent = region.parent
                            while parent and parent ~= body do parent = parent.parent end
                            if parent == body then count = count + 1 end
                        end
                    end
                    local hasProfileRows = affected[pageName] and affected[pageName][tabName]
                    assert(count == (hasProfileRows and 1 or 0), pageName .. "/" .. tabName .. ": one legend only where needed")
                    if hasProfileRows then assert(wow.Visible(body.hcScopeLegend), "legend remains visible with dependent controls hidden") end
                end
            end
        end
    end
    -- Empty movement categories disappear; the options stay below the changing pool.
    local function visibleText(text)
        for _, region in ipairs(wow.regions) do
            if region.text == text and wow.Visible(region) then return region end
        end
    end
    settings:Show("Key Bindings")
    ns.knownEscapes = {}
    ns.Options.RefreshDispel()
    assert(not visibleText("FREE AN ALLY") and not visibleText("FREE THE GROUP") and not visibleText("FREE YOURSELF"), "empty movement headings hidden")
    assert(visibleText("No movement spells for this character."), "one empty movement explanation")
    local fallback = settings.pages["Key Bindings"].bodies["Key Bindings"].hcRows["Mouseover fallback"]
    local emptyY = select(5, fallback.parent:GetPoint())
    ns.knownEscapes = {
        { id = 1044, name = "Ally escape", scope = ns.ESCAPE_ALLY },
        { id = 900001, name = "Area escape", scope = ns.ESCAPE_AREA },
        { id = 900002, name = "Self escape", scope = ns.ESCAPE_SELF },
    }
    ns.Options.RefreshDispel()
    assert(visibleText("FREE AN ALLY") and visibleText("FREE THE GROUP") and visibleText("FREE YOURSELF"), "only available categories shown")
    assert(not visibleText("No movement spells for this character."), "empty explanation hides when spells available")
    assert(select(5, fallback.parent:GetPoint()) < emptyY, "mouseover options follow pool growth")
    assert(settings:Focus("Key Bindings", "Mouseover fallback"), "moved options remain searchable")
    -- A two-dispel character is offered each grid and mouseover action separately.
    ns.spellName, ns.spellID, ns.secondaryName, ns.secondaryID = "Cure Poison", 8946, "Remove Curse", 2782
    ns.knownDispels = { { id = 8946, name = "Cure Poison", cures = { Poison = true } },
        { id = 2782, name = "Remove Curse", cures = { Curse = true } } }
    ns.Options.RefreshDispel()
    ns.Mouseover:Update()
    settings:Show("Cooldowns", "Bar")
    local barBody = settings.pages.Cooldowns.bodies.Bar
    settings.pages.Cooldowns.hcRefreshAll()
    local perSpell = assert(barBody.hcRows["Bar spell: " .. ns.Cooldowns.SpellName(8946)], "individual bar spell row built")
    assert(perSpell.hcSettingScope == "profile" and perSpell.hcScopeIcon:IsShown(), "per-spell controls retain profile markers")
    assert(barBody.hcRows["Bar spells"].hcSettingScope == "shared" and not rawget(barBody.hcRows["Bar spells"], "hcScopeIcon"), "searchable bar section has no stray glyph")

    local bindings = settings.pages["Key Bindings"].bodies["Key Bindings"].hcRows
    for _, label in ipairs({ "Bind: Cure Poison", "Bind: Remove Curse", "Bind: Mouseover Cure Poison", "Bind: Mouseover Remove Curse" }) do
        assert(bindings[label], "individual dispel action offered: " .. label)
    end
    for label in pairs(bindings) do assert(not label:find(" or ", 1, true), "combined tile must not be offered") end
    assert(not bindings["Both dispels: try first"], "combined order setting removed")
    assert(not ns.Mouseover.BINDINGS.BOTH, "combined command not offered")
    ns.Set("roleIcon", "OFF")
    local role = assert(settings:Focus("Salve", "Role icon size", "Names and icons"))
    local body = settings.pages.Salve.bodies["Names and icons"]
    assert(role == body.hcRows["Role and marker icon"], "hidden role size focuses its enabling row")
    ns.Set("showTooltip", false)
    local tooltipBody = settings.pages.Tooltips.bodies.Tooltips
    local debuff = tooltipBody.hcRows["Show Blizzard debuff tooltip"]
    assert(settings:Focus("Tooltips", "Show Blizzard debuff tooltip") == debuff,
        "native debuff tooltip stays accessible with cell tooltips off")
    assert(settings:Focus("Tooltips", "Anchor") == settings.pages.Tooltips.bodies.Tooltips.hcRows["Show cell tooltips"],
        "hidden tooltip anchor focuses its master")
end
io.write("settings search: " .. checked .. " registrations checked on both clients\n")
