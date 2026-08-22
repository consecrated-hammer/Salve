local addonName, ns = ...

-- ============================================================
-- Click bindings
-- ============================================================
-- Which button casts which dispel. Any mouse button, with any combination of
-- Shift / Ctrl / Alt, so mouse 4 or shift-right are as ordinary as left click.
--
-- ☠ MOUSE BUTTONS ONLY, AND THAT IS NOT AN OVERSIGHT. A secure action button
--   takes its orders from attributes keyed by mouse button ("type1", "spell1",
--   "shift-type2"...). A KEYBOARD key cannot be routed to "whichever box the
--   cursor happens to be over" -- that needs a mouseover macro, which is a
--   different mechanism entirely and belongs to the unit under the pointer
--   rather than to this panel.
--
-- ☠ EVERY ATTRIBUTE WRITE IS OUT OF COMBAT. Callers gate on InCombatLockdown.

ns.Bindings = {}
local Bindings = ns.Bindings

-- Auto-resolution roles, so a binding survives a specialisation change: the
-- spell it casts is looked up fresh rather than frozen at the time you set it.
ns.ROLE_PRIMARY   = "PRIMARY"
ns.ROLE_SECONDARY = "SECONDARY"

ns.defaultBindings = {
    { key = "BUTTON1", role = ns.ROLE_PRIMARY },
}

function Bindings:Defaults()
    local list = ns.defaultBindings
    -- A secondary click is useful only when the specialisation genuinely has
    -- a different second dispel. Falling back to the primary spell produced
    -- two rows that both cast Cleanse and implied an ability choice that did
    -- not exist.
    if ns.secondaryName and ns.secondaryName ~= ns.spellName then
        return {
            list[1],
            { key = "BUTTON2", role = ns.ROLE_SECONDARY },
        }
    end
    return list
end

-- ── Key strings ────────────────────────────────────────────────────────────

local BUTTON_LABEL = {
    BUTTON1 = "Left click", BUTTON2 = "Right click", BUTTON3 = "Middle click",
    BUTTON4 = "Mouse 4",    BUTTON5 = "Mouse 5",
}

-- "SHIFT-BUTTON2" -> "Shift + Right click"
function Bindings:Label(key)
    if not key then return "unbound" end
    local mods, button = key:match("^(.-)(BUTTON%d+)$")
    if not button then return key end

    local parts = {}
    for _, m in ipairs({ "ALT", "CTRL", "SHIFT" }) do
        if mods:find(m) then
            parts[#parts + 1] = m:sub(1, 1) .. m:sub(2):lower()
        end
    end
    parts[#parts + 1] = BUTTON_LABEL[button] or button
    return table.concat(parts, " + ")
end

-- Builds the canonical key string from a captured mouse button plus whatever
-- modifiers were held. Order is fixed so two captures of the same combination
-- always produce the same string.
function Bindings:Capture(button)
    local n = button and button:match("^Button(%d+)$")
    if button == "LeftButton"   then n = "1" end
    if button == "RightButton"  then n = "2" end
    if button == "MiddleButton" then n = "3" end
    if not n then return nil end

    local prefix = ""
    if IsAltKeyDown()     then prefix = prefix .. "ALT-"   end
    if IsControlKeyDown() then prefix = prefix .. "CTRL-"  end
    if IsShiftKeyDown()   then prefix = prefix .. "SHIFT-" end

    return prefix .. "BUTTON" .. n
end

-- Splits a key string into the secure-attribute prefix and button number.
-- WoW expects modifiers lowercase and in alt-ctrl-shift order.
local function attributeParts(key)
    -- ☠ %d+, not %d. Gaming mice go well past button 9, and Capture happily
    --   records BUTTON10 -- a single-digit pattern then failed to match, so the
    --   binding saved, displayed, and never cast anything.
    local mods, button = key:match("^(.-)BUTTON(%d+)$")
    if not button then return nil end

    local prefix = ""
    if mods:find("ALT")   then prefix = prefix .. "alt-"   end
    if mods:find("CTRL")  then prefix = prefix .. "ctrl-"  end
    if mods:find("SHIFT") then prefix = prefix .. "shift-" end

    return prefix, button
end

-- ── Resolution ─────────────────────────────────────────────────────────────

local function knownSpell(spellID)
    for _, s in ipairs(ns.knownDispels or {}) do
        if s.id == spellID then return s, "DISPEL" end
    end
    for _, s in ipairs(ns.knownEscapes or {}) do
        if s.id == spellID then return s, "ESCAPE" end
    end
end

local function spellFor(entry)
    if entry.role == ns.ROLE_PRIMARY then
        return ns.spellName, ns.spellID, "DISPEL"
    elseif entry.role == ns.ROLE_SECONDARY then
        if ns.secondaryName then
            return ns.secondaryName, ns.secondaryID, "DISPEL"
        end
        return ns.spellName, ns.spellID, "DISPEL"
    elseif entry.spell then
        local spell, kind = knownSpell(entry.spell)
        if not spell then return nil end
        -- An escape checkbox controls both the movement overlay and whether its
        -- click action is armed. A stale saved binding must never silently cast
        -- a spell the player has explicitly disabled.
        if kind == "ESCAPE"
            and not (ns.db and ns.db.escapes and ns.db.escapes[spell.id]) then
            return nil
        end
        return spell.name, spell.id, kind
    end
end

function Bindings:SpellID(entry)
    if entry.role == ns.ROLE_PRIMARY then return ns.spellID end
    if entry.role == ns.ROLE_SECONDARY then return ns.secondaryID or ns.spellID end
    return entry.spell
end

function Bindings:KeysForSpell(spellID)
    local keys = {}
    for _, entry in ipairs(self:List()) do
        if self:SpellID(entry) == spellID and entry.key then
            keys[#keys + 1] = entry.key
        end
    end
    return keys
end

-- One row in Options owns one action. Rebinding replaces every old chord for
-- that spell, which keeps the page truthful instead of hiding duplicate
-- bindings behind a single button.
function Bindings:SetSpellBinding(spellID, key)
    if type(spellID) ~= "number" or not attributeParts(key or "") then
        return false, "invalid mouse binding"
    end

    local list = self:Materialise()
    for _, entry in ipairs(list) do
        if entry.key == key and self:SpellID(entry) ~= spellID then
            local what = self:Describe(entry)
            return false, self:Label(key) .. " is already assigned to " .. what
        end
    end

    local kept = {}
    for _, entry in ipairs(list) do
        if self:SpellID(entry) ~= spellID then kept[#kept + 1] = entry end
    end

    local replacement = { key = key, spell = spellID }
    if spellID == ns.spellID then
        replacement.spell = nil
        replacement.role = ns.ROLE_PRIMARY
    elseif spellID == ns.secondaryID then
        replacement.spell = nil
        replacement.role = ns.ROLE_SECONDARY
    end
    kept[#kept + 1] = replacement
    ns.db.bindings = kept
    ns.db.bindingsCustom = true
    return true
end

function Bindings:ClearSpellBinding(spellID)
    local found = false
    for _, entry in ipairs(self:List()) do
        if self:SpellID(entry) == spellID then
            found = true
            break
        end
    end
    -- Do not turn automatic defaults into a frozen custom list merely because
    -- an unrelated, currently unbound action was disabled in the options.
    if not found then return false end

    local kept = {}
    for _, entry in ipairs(self:Materialise()) do
        if self:SpellID(entry) ~= spellID then kept[#kept + 1] = entry end
    end
    ns.db.bindings = kept
    ns.db.bindingsCustom = true
    return true
end

function Bindings:List()
    local list = ns.db and ns.db.bindings
    if ns.db and ns.db.bindingsCustom then return list or {} end
    if not list or #list == 0 then return self:Defaults() end
    return list
end

-- Turns the shared defaults into the player's own editable copy. Call before
-- any edit.
--
-- ☠ COPY THE ENTRY TABLES, NOT JUST THE LIST. ns.defaultBindings is module
--   state shared by every character; editing a row in place would mutate it, and
--   since an empty list means "use the defaults", deleting your customisations
--   would then restore the mutated version rather than left-and-right click.
--   Written out here rather than relying on CopyTable's depth, which is a
--   Blizzard global whose behaviour is not ours to depend on.
function Bindings:Materialise()
    if ns.db.bindingsCustom then
        ns.db.bindings = ns.db.bindings or {}
        return ns.db.bindings
    end
    if ns.db.bindings and #ns.db.bindings > 0 then
        ns.db.bindingsCustom = true
        return ns.db.bindings
    end

    local copy = {}
    for i, entry in ipairs(self:Defaults()) do
        local e = {}
        for k, v in pairs(entry) do e[k] = v end
        copy[i] = e
    end

    ns.db.bindings = copy
    ns.db.bindingsCustom = true
    return copy
end

-- ── Applying ───────────────────────────────────────────────────────────────

function Bindings:Apply(box)
    -- ☠ Clear only what we previously wrote. Blanket-clearing every button and
    --   modifier combination would be 40 attribute pairs per box per rebuild --
    --   1600 in a full raid, for nothing.
    --
    -- ☠ RECORD THE FULL ATTRIBUTE NAMES, not a prefix-to-button map. Two
    --   bindings on different buttons share a prefix whenever neither uses a
    --   modifier -- which is exactly the default pair, left and right. Keying
    --   the record by prefix meant the second overwrote the first, so cleanup
    --   cleared button 2 twice and left button 1 installed: a binding you had
    --   deleted carried on casting.
    if box.appliedAttrs then
        for _, attr in ipairs(box.appliedAttrs) do
            box:SetAttribute(attr, nil)
        end
    end

    box.appliedAttrs = {}

    local function set(attr, value)
        box:SetAttribute(attr, value)
        box.appliedAttrs[#box.appliedAttrs + 1] = attr
    end

    for _, entry in ipairs(self:List()) do
        local prefix, button = attributeParts(entry.key or "")
        if prefix and button then
            local typeAttr  = prefix .. "type" .. button
            local spellAttr = prefix .. "spell" .. button

            if entry.action == "TARGET" then
                set(typeAttr, "target")
                set(spellAttr, nil)
            elseif entry.action == "NONE" then
                set(typeAttr, nil)
                set(spellAttr, nil)
            else
                local spell = spellFor(entry)
                if spell then
                    set(typeAttr, "spell")
                    set(spellAttr, spell)
                end
            end
        end
    end
end

-- What a binding currently casts, for the options list.
function Bindings:Describe(entry)
    if entry.action == "TARGET" then return "Target the unit", nil end
    if entry.action == "NONE"   then return "Do nothing", nil end

    local name, spellID = spellFor(entry)
    if not name then return "no dispel known", nil end

    local icon = spellID and C_Spell and C_Spell.GetSpellTexture
        and C_Spell.GetSpellTexture(spellID)

    local suffix = entry.role == ns.ROLE_PRIMARY and " (automatic)"
        or entry.role == ns.ROLE_SECONDARY and " (automatic)" or ""
    return name .. suffix, icon
end

-- True when spellID is one of this character's dispels. Used to decide whether
-- a cast should drive the cooldown sweep -- casting anything else must not,
-- or the swipe just tracks the global cooldown.
function Bindings:IsDispelSpell(spellID)
    if type(spellID) ~= "number" then return false end
    for _, s in ipairs(ns.knownDispels or {}) do
        if s.id == spellID then return true end
    end
    return false
end
