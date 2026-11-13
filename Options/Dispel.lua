local addonName, ns = ...
local HC = ns.HammerCore
local O, T = ns.Options, HC.Theme

-- Retained as a pure helper for callers/tests which used the original inline
-- layout. The Actions page below uses two independent columns instead.
function O.DispelLayout(knownTop, dispelCount, escapeCount)
    local knownRows = math.max(1, dispelCount or 0)
    local escapeRows = math.max(1, escapeCount or 0)
    local layout = {}
    layout.knownNoteY = knownTop - knownRows * 32 - 2
    layout.paletteY = layout.knownNoteY - 20
    layout.escapeHeaderY = knownTop - knownRows * 32 - 48
    layout.escapeNoteY = layout.escapeHeaderY - 28
    layout.escapeTop = layout.escapeHeaderY - 52
    layout.buttonsTop = layout.escapeTop - escapeRows * 32 - 12
    return layout
end

local function spellIcon(spellID)
    return C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(spellID)
        or "Interface\\Icons\\INV_Misc_QuestionMark"
end
O.SpellIcon = spellIcon

local function findSpell(spellID)
    for _, spell in ipairs(ns.PersonalDispel and ns.PersonalDispel.spells or {}) do
        if spell.id == spellID then return spell, "PERSONAL" end
    end
    for _, spell in ipairs(ns.knownDispels or {}) do
        if spell.id == spellID then return spell, "DISPEL" end
    end
    for _, spell in ipairs(ns.knownEscapes or {}) do
        if spell.id == spellID then return spell, "ESCAPE" end
    end
end

local function spellTooltip(owner, spell)
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    if GameTooltip.SetSpellByID then
        GameTooltip:SetSpellByID(spell.id)
    else
        GameTooltip:SetText(spell.name)
    end
    if spell.selfOnly then
        GameTooltip:AddLine("Self only dispel. The R cue marks a Curse while this action is ready.", 0.55, 0.58, 0.64, true)
    elseif spell.scope == ns.ESCAPE_SELF then
        GameTooltip:AddLine("Self only movement removal.", 0.55, 0.58, 0.64, true)
    elseif spell.scope == ns.ESCAPE_ALLY then
        GameTooltip:AddLine("Can remove movement impairment from a group member.", 0.55, 0.58, 0.64, true)
    elseif spell.scope == ns.ESCAPE_AREA then
        GameTooltip:AddLine("Places a ground-area effect; allies in it can be freed.", 0.55, 0.58, 0.64, true)
    end
    GameTooltip:Show()
end

-- Unbinding a movement spell also opts it out of escapes and its sweep.
local function disableEscape(spellID)
    local escapes = {}
    for id in pairs(ns.db.escapes) do
        if id ~= spellID then escapes[id] = true end
    end
    ns.Set("escapes", escapes)
    if ns.db.movementSweepSpellIDs and ns.db.movementSweepSpellIDs[spellID] then
        local selected = {}
        for id, enabled in pairs(ns.db.movementSweepSpellIDs) do
            if id ~= spellID and enabled then selected[id] = true end
        end
        ns.Set("movementSweepSpellIDs", selected)
        if ns.Binding and ns.Binding.RefreshMovementCooldowns then
            ns.Binding:RefreshMovementCooldowns("movement action disabled")
        end
    end
end

-- Bound spells, in binding order.  A disabled escape isn't bound.
function O.BoundSpells()
    local bound = {}
    for _, entry in ipairs(ns.Bindings:List()) do
        local spellID = ns.Bindings:SpellID(entry)
        local spell, kind = findSpell(spellID)
        if spell and kind == "ESCAPE" and not ns.db.escapes[spellID] then spell = nil end
        if spell then bound[#bound + 1] = { entry = entry, spell = spell, kind = kind } end
    end
    return bound
end

local function item(spell, kind)
    local detail = kind == "DISPEL" and ("Dispels " .. ns.CuresText(spell.cures)) or nil
    return { id = spell.id, name = spell.name, icon = spellIcon(spell.id), detail = detail,
        spell = spell, kind = kind }
end

-- Mouseover keys: game key bindings rather than cell clicks. They cast on
-- whoever is under the pointer anywhere, so they take keys as well as mouse
-- buttons and the wheel. See Features/Mouseover.lua.
local MOUSEOVER_INPUTS = { keys = true, mouse = true, wheel = true }

local function mouseoverItems()
    local items = {}
    local primary, secondary = ns.Mouseover:Spells()
    local function add(role, name, spellID)
        if not name then return end
        items[#items + 1] = {
            id = "MOUSEOVER_" .. role, role = role, kind = "MOUSEOVER",
            name = "Mouseover " .. name, icon = spellIcon(spellID),
            inputs = MOUSEOVER_INPUTS, spellID = spellID,
            command = ns.Mouseover.BINDINGS[role],
        }
    end
    if ns.CanDispel and ns.CanDispel() then
        add("PRIMARY", primary, ns.spellID)
        add("SECONDARY", secondary, ns.secondaryID)
    end
    return items
end

local function mouseoverTooltip(owner, entry)
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:SetText(entry.name)
    GameTooltip:AddLine("Casts on a friendly player under the mouse: any raid frame, a nameplate or the player. Works in combat.",
        1, 1, 1, true)
    GameTooltip:Show()
end

HC.Settings:NewPage({
    name = "Key Bindings",
    profileScope = false,
    title = "Key Bindings",
    group = "main",
    description = "Mouse buttons for cells, and keys for mouseover dispels.", columns = 1,
}, function(panel, y)
    local function refreshAll()
        ns.RequestRebuildSoon(0.05)
        if ns.Options.RefreshMovementSweeps then ns.Options.RefreshMovementSweeps() end
    end
    local flow = O.Flow(panel)
    local editor = O.Section(panel, 1)
    local bottom = HC.Bindings.Page(editor, -4, {
        inputs = { mouse = true },
        poolTitle = "Your spells",
        poolHint = "Click a spell, then the mouse button that casts it. Mouseover dispel keys are included below.",
        empty = "Nothing bound yet. Pick a spell on the right, then click a mouse button.",
        label = function(key) return ns.Bindings:Label(key) end,
        tooltip = function(owner, entry)
            if entry.kind == "MOUSEOVER" then return mouseoverTooltip(owner, entry) end
            spellTooltip(owner, entry.spell)
        end,
        pool = function()
            local sections = {}
            local dispels = {}
            for _, spell in ipairs(ns.knownDispels or {}) do dispels[#dispels + 1] = item(spell, "DISPEL") end
            sections[#sections + 1] = { title = "Dispels", items = dispels, empty = "No dispels for this character." }
            local personal = ns.PersonalDispel and ns.PersonalDispel.spells or {}
            if #personal > 0 then
                local items = {}
                for _, spell in ipairs(personal) do items[#items + 1] = item(spell, "PERSONAL") end
                sections[#sections + 1] = { title = "Personal dispels", items = items }
            end
            local ally, area, self = {}, {}, {}
            for _, spell in ipairs(ns.knownEscapes or {}) do
                local list = spell.scope == ns.ESCAPE_ALLY and ally or spell.scope == ns.ESCAPE_AREA and area or self
                list[#list + 1] = item(spell, "ESCAPE")
            end
            for _, section in ipairs({ { title = "Free an ally", items = ally },
                { title = "Free the group", items = area }, { title = "Free yourself", items = self } }) do
                if #section.items > 0 then sections[#sections + 1] = section end
            end
            if #ally + #area + #self == 0 then
                sections[#sections + 1] = { title = "Movement", items = {}, empty = "No movement spells for this character." }
            end
            sections[#sections + 1] = { title = "Mouseover keys", items = mouseoverItems(),
                empty = "No dispels for this character." }
            return sections
        end,
        bound = function()
            local list = {}
            for _, bound in ipairs(O.BoundSpells()) do
                local entry = item(bound.spell, bound.kind)
                entry.key = bound.entry.key
                list[#list + 1] = entry
            end
            for _, entry in ipairs(mouseoverItems()) do
                entry.key = HC.Bindings.CommandKey(entry.command)
                if entry.key then list[#list + 1] = entry end
            end
            return list
        end,
        bind = function(entry, key)
            if entry.kind == "MOUSEOVER" then
                local ok, message, conflict = HC.Bindings.BindCommand(entry.command, key)
                if ok then return true end
                if conflict ~= "conflict" then return false, message end
                return false, message .. ".", function()
                    return HC.Bindings.BindCommand(entry.command, key, true)
                end
            end
            -- Choosing a movement spell is its opt-in.  Cancelling leaves it inert.
            if entry.kind == "ESCAPE" then ns.db.escapes[entry.id] = true end
            local function bound()
                if entry.kind == "ESCAPE" and ns.db.movementAlertsEnabled ~= false then
                    ns.Print("Movement alerts are in beta and may not work correctly. Disable them on Alerts if needed.")
                end
                refreshAll()
                return true
            end
            local ok, message, conflict = ns.Bindings:SetSpellBinding(entry.id, key)
            if ok then return bound() end
            if conflict ~= "conflict" then return false, message end
            -- Already taken: offer Replace, which moves the click here and
            -- leaves the other spell unbound.
            return false, message .. ".", function()
                local forced, why = ns.Bindings:SetSpellBinding(entry.id, key, true)
                if not forced then return false, why end
                return bound()
            end
        end,
        unbind = function(spellID)
            for _, entry in ipairs(mouseoverItems()) do
                if entry.id == spellID then
                    HC.Bindings.ClearCommand(entry.command)
                    return
                end
            end
            ns.Bindings:ClearSpellBinding(spellID)
            local _, kind = findSpell(spellID)
            if kind == "ESCAPE" then disableEscape(spellID) end
            refreshAll()
        end,
        clearAll = function()
            if InCombatLockdown and InCombatLockdown() then
                ns.Print("Bindings cannot be cleared in combat.")
                return
            end
            for _, command in pairs(ns.Mouseover.BINDINGS) do HC.Bindings.ClearCommand(command) end
            ns.db.bindings = {}
            ns.db.bindingsCustom = true
            ns.Set("escapes", {})
            ns.Set("movementSweepSpellIDs", {})
            if ns.Binding and ns.Binding.RefreshMovementCooldowns then
                ns.Binding:RefreshMovementCooldowns("all movement actions cleared")
            end
            refreshAll()
        end,
    })
    flow:Add(editor, function() return -bottom + 4 end)
    local preferences = O.Section(panel, 1)
    y = -4
    -- Follow the pool so the available mouseover tiles explain this choice.
    _, y = O.Dropdown(preferences, "Mouseover fallback",
        "Mouseover dispel keys cast on a friendly player under the pointer, or this when there isn't one. Bind individual dispels in the mouseover tiles above.", y,
        { "NONE", "TARGET", "PLAYER" }, { "Do nothing", "Use target", "Use yourself" },
        function() return ns.db.mouseoverFallback end,
        function(value) ns.Set("mouseoverFallback", value) end, 560, 150, 200)
    flow:Add(preferences, -O.Flush(preferences, y) + 4)
    editor.hcSetBottom = function(value)
        bottom = value
        flow:Layout()
    end
    ns.Options.RefreshDispel = editor.hcBindingsLayout
    return flow:Layout()
end)
