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
    { key = "BUTTON2", role = ns.ROLE_SECONDARY },
}

-- ── Key strings ────────────────────────────────────────────────────────────

local BUTTON_LABEL = {
    BUTTON1 = "Left click", BUTTON2 = "Right click", BUTTON3 = "Middle click",
    BUTTON4 = "Mouse 4",    BUTTON5 = "Mouse 5",
}

-- "SHIFT-BUTTON2" -> "Shift + Right click"
function Bindings:Label(key)
    if not key then return "unbound" end
    local mods, button = key:match("^(.-)(BUTTON%d)$")
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
    local mods, button = key:match("^(.-)BUTTON(%d)$")
    if not button then return nil end

    local prefix = ""
    if mods:find("ALT")   then prefix = prefix .. "alt-"   end
    if mods:find("CTRL")  then prefix = prefix .. "ctrl-"  end
    if mods:find("SHIFT") then prefix = prefix .. "shift-" end

    return prefix, button
end

-- ── Resolution ─────────────────────────────────────────────────────────────

local function spellFor(entry)
    if entry.role == ns.ROLE_PRIMARY then
        return ns.spellName
    elseif entry.role == ns.ROLE_SECONDARY then
        return ns.secondaryName or ns.spellName
    elseif entry.spell then
        for _, s in ipairs(ns.knownDispels or {}) do
            if s.id == entry.spell then return s.name end
        end
        -- Known last session, gone this one (a respec). Fall back rather than
        -- leaving the button silently dead.
        return ns.spellName
    end
end

function Bindings:List()
    local list = ns.db and ns.db.bindings
    if not list or #list == 0 then return ns.defaultBindings end
    return list
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

    local name = spellFor(entry)
    if not name then return "no dispel known", nil end

    local icon
    for _, s in ipairs(ns.knownDispels or {}) do
        if s.name == name then
            if C_Spell and C_Spell.GetSpellTexture then
                icon = C_Spell.GetSpellTexture(s.id)
            end
            break
        end
    end

    local suffix = entry.role == ns.ROLE_PRIMARY and " (automatic)"
        or entry.role == ns.ROLE_SECONDARY and " (automatic)" or ""
    return name .. suffix, icon
end
