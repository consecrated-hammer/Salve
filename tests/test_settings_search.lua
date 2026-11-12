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
        ["reset frame position"] = "Position", ["sort by"] = "Salve", ["clear all bindings"] = "Key Bindings", ["your spells"] = "Key Bindings", ["attach to"] = "Position", anchor = "Tooltips" }) do
        local found = false
        for _, result in ipairs(settings:Search(query, 10000)) do
            if result.page == expected then found = true end
        end
        assert(found, "custom control/keyword missing from search: " .. query)
    end
    ns.Set("roleIcon", "OFF")
    local role = assert(settings:Focus("Salve", "Role icon size", "Names and icons"))
    local body = settings.pages.Salve.bodies["Names and icons"]
    assert(role == body.hcRows["Role and marker icon"], "hidden role size focuses its enabling row")
    ns.Set("showTooltip", false)
    assert(settings:Focus("Tooltips", "Anchor") == settings.pages.Tooltips.bodies.Tooltips.hcRows["Show cell tooltips"],
        "hidden tooltip anchor focuses its master")
end
io.write("settings search: " .. checked .. " registrations checked on both clients\n")
