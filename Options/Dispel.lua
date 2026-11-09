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

HC.Settings:NewPage({
    name = "Key Bindings",
    title = "Key Bindings",
    group = "main",
    description = "The mouse buttons that cast your spells on a lit cell.", columns = 1,
}, function(panel, y)
    local function refreshAll()
        ns.RequestRebuildSoon(0.05)
        if ns.Options.RefreshMovementSweeps then ns.Options.RefreshMovementSweeps() end
    end
    local bottom = HC.Bindings.Page(panel, y, {
        inputs = { mouse = true },
        poolTitle = "Your spells",
        poolHint = "Click a spell, then the mouse button that casts it.",
        empty = "Nothing bound yet. Pick a spell on the right, then click a mouse button.",
        label = function(key) return ns.Bindings:Label(key) end,
        tooltip = function(owner, entry) spellTooltip(owner, entry.spell) end,
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
            sections[#sections + 1] = { title = "Frees movement", items = ally, empty = "No spells detected." }
            sections[#sections + 1] = { title = "Area movement", items = area, empty = "No spells detected." }
            sections[#sections + 1] = { title = "Self only", items = self, empty = "No spells detected." }
            return sections
        end,
        bound = function()
            local list = {}
            for _, bound in ipairs(O.BoundSpells()) do
                local entry = item(bound.spell, bound.kind)
                entry.key = bound.entry.key
                list[#list + 1] = entry
            end
            return list
        end,
        bind = function(entry, key)
            -- Choosing a movement spell is its opt-in.  Cancelling leaves it inert.
            if entry.kind == "ESCAPE" then ns.db.escapes[entry.id] = true end
            local function bound()
                if entry.kind == "ESCAPE" and ns.db.movementAlertsEnabled ~= false then
                    ns.Print("Movement alerts are in beta and may not work correctly. Disable them on Movement if needed.")
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
            ns.Bindings:ClearSpellBinding(spellID)
            local _, kind = findSpell(spellID)
            if kind == "ESCAPE" then disableEscape(spellID) end
            refreshAll()
        end,
        clearAll = function()
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
    ns.Options.RefreshDispel = panel.hcBindingsLayout
    return bottom
end)
