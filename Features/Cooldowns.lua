local addonName, ns = ...

-- ============================================================
-- Cooldown icons: when to show them
-- ============================================================
-- The cell icons and the cooldown bar show a spell only while it recovers.
-- Deciding that is the only new thing here; the sweeps themselves still come
-- from Blizzard's opaque duration object, forwarded untouched as before.
--
-- Three ways to know, best first:
--   1. READABLE. C_Spell.GetSpellCooldown's isActive and isOnGCD are plain
--      booleans for the player's own spells. Show while active and not just
--      the global cooldown. Ready icons can then leave their slot entirely.
--   2. CURVE. If those flags turn secret, the duration object evaluates a
--      step curve engine-side (0 when ready, 1 while recovering) and the
--      result goes straight into SetAlpha. Lua never compares it, so slots
--      stay fixed: nothing may move based on a value we can't read.
--   3. OPEN. Neither works on this client: show the icon. A visible icon
--      with an idle sweep is wrong but harmless; a hidden one on cooldown
--      would cost the player a dispel.
--
-- ☠ No polling. State is re-checked on edges only: the player's own cast
--   (after the one-tick wait Core/Events.lua already makes), each cooldown
--   widget's OnCooldownDone, a rebuild, a spell change and a setting change.

ns.Cooldowns = {}
local Cooldowns = ns.Cooldowns

Cooldowns.READY_ALPHA = 0.35
Cooldowns.lastPath = {}     -- [spellID] = "readable" | "curve" | "open"
Cooldowns.updates = 0

local function secret(value)
    return issecretvalue and issecretvalue(value)
end

-- Whether any of this is switched on. Off, Salve looks exactly as it did
-- before cooldown icons existed and none of the code below runs.
function Cooldowns:Enabled()
    local db = ns.db
    if not db then return false end
    return db.cooldownBar == true or (ns.Box and ns.Box.CooldownStyle() == "ICON") or false
end

-- "ACTIVE", "READY", or nil when this client won't say.
function Cooldowns:State(spellID)
    if type(spellID) ~= "number" or not (C_Spell and C_Spell.GetSpellCooldown) then return nil end
    local ok, info = pcall(C_Spell.GetSpellCooldown, spellID)
    if not ok or type(info) ~= "table" then return nil end
    local active, gcd = info.isActive, info.isOnGCD
    if secret(active) or secret(gcd) then return nil end
    if type(active) == "boolean" then
        return (active and gcd ~= true) and "ACTIVE" or "READY"
    end
    -- Clients without isActive: the start and duration, if they're plain.
    -- Anything at or under 1.5 seconds is treated as the global cooldown.
    local start, duration = info.startTime, info.duration
    if secret(start) or secret(duration)
        or type(start) ~= "number" or type(duration) ~= "number" then return nil end
    return (start > 0 and duration > 1.5) and "ACTIVE" or "READY"
end

local curves = {}
local function stepCurve(readyAlpha)
    if curves[readyAlpha] then return curves[readyAlpha] end
    if not (C_CurveUtil and C_CurveUtil.CreateCurve and Enum and Enum.LuaCurveType) then return nil end
    local ok, curve = pcall(function()
        local c = C_CurveUtil.CreateCurve()
        c:SetType(Enum.LuaCurveType.Step)
        c:AddPoint(0, readyAlpha)
        c:AddPoint(0.001, 1)
        return c
    end)
    if ok and curve then curves[readyAlpha] = curve end
    return curves[readyAlpha]
end

local function setAlpha(icon, value)
    if not pcall(icon.frame.SetAlpha, icon.frame, value) then return false end
    -- Cell sweeps live on the box, not inside the icon, so they need their
    -- own alpha.
    if icon.cooldownAlpha and icon.cooldown then
        if not pcall(icon.cooldown.SetAlpha, icon.cooldown, value) then return false end
    end
    return true
end

-- Sets one icon's alpha and returns how it was decided. `evaluate` false
-- keeps an unreadable icon as it was: re-evaluating Freedom's curve just
-- after a Cleanse would read the global cooldown and light it up.
function Cooldowns:Apply(icon, showReady, evaluate)
    local readyAlpha = showReady and self.READY_ALPHA or 0
    -- The preview fixes each spell's state rather than asking the client.
    local state = icon.forcedState or self:State(icon.spellID)
    if state then
        if not icon.forcedState then self.lastPath[icon.spellID] = "readable" end
        icon.mode = state == "ACTIVE" and "SHOWN" or (showReady and "DIMMED" or "HIDDEN")
        setAlpha(icon, state == "ACTIVE" and 1 or readyAlpha)
        return icon.mode
    end
    if evaluate == false and icon.mode then return icon.mode end

    local duration = ns.Binding and ns.Binding.CooldownDuration
        and ns.Binding.CooldownDuration(icon.spellID)
    local curve = stepCurve(readyAlpha)
    if duration and curve and duration.EvaluateRemainingDuration then
        local ok, value = pcall(duration.EvaluateRemainingDuration, duration, curve, readyAlpha)
        if ok and setAlpha(icon, value) then
            self.lastPath[icon.spellID] = "curve"
            icon.mode = "CURVE"
            return icon.mode
        end
    end
    self.lastPath[icon.spellID] = "open"
    icon.mode = "OPEN"
    setAlpha(icon, 1)
    return icon.mode
end

-- Applies every icon, then returns the ones that need a slot. Readable
-- state lets hidden icons give up their slot; any unreadable icon pins the
-- whole row to fixed slots.
-- Whether an unreadable icon should be evaluated again now. A full re-check
-- in combat (a restyle) leaves them alone: only their own cast or finished
-- sweep is a safe moment, away from someone else's global cooldown.
function Cooldowns:ShouldEvaluate(icon, target)
    if target ~= nil then return target == icon.spellID end
    return not (InCombatLockdown and InCombatLockdown())
end

function Cooldowns:Arrange(icons, showReady, target)
    local fixed = false
    for _, icon in ipairs(icons) do
        local evaluate = self:ShouldEvaluate(icon, target)
        local mode = self:Apply(icon, showReady, evaluate)
        if mode == "CURVE" or mode == "OPEN" then fixed = true end
    end
    local placed = {}
    for _, icon in ipairs(icons) do
        if fixed or icon.mode ~= "HIDDEN" then placed[#placed + 1] = icon end
    end
    return placed
end

-- Every icon's widget calls this from OnCooldownDone, and the cast and
-- rebuild paths call it too. Requests in one frame collapse into one update.
-- A nil spell ID means re-check everything.
local pending, pendingAll, scheduled = {}, false, false
function Cooldowns:Request(spellID)
    -- `active` remembers the last update ran with something enabled, so
    -- switching everything off still gets one update to put the cells back.
    if not (self.active or self:Enabled()) then return end
    if spellID == nil or secret(spellID) or type(spellID) ~= "number" then
        pendingAll = true
    else
        pending[spellID] = true
    end
    if scheduled then return end
    scheduled = true
    local function flush()
        scheduled = false
        local ids, all = pending, pendingAll
        pending, pendingAll = {}, false
        if all then
            Cooldowns:Update(nil)
        else
            for id in pairs(ids) do Cooldowns:Update(id) end
        end
    end
    if C_Timer and C_Timer.After then C_Timer.After(0, flush) else flush() end
end

-- A cast of a bound spell re-checks that spell. A dispel cast under another
-- ID (a talent or pet variant) drives the primary dispel's sweep, so it
-- re-checks that instead.
function Cooldowns:RequestCast(spellID)
    if type(spellID) == "number" and not secret(spellID) then
        for _, id in ipairs(self:BoundSpells()) do
            if id == spellID then return self:Request(id) end
        end
    end
    self:Request(ns.spellID)
end

function Cooldowns:Update(target)
    self.updates = self.updates + 1
    self.active = self:Enabled()
    -- Cells first: switching back to Whole box has to restore them even when
    -- nothing is enabled any more.
    if ns.Panel and ns.Panel.boxes then
        for _, box in ipairs(ns.Panel.boxes) do
            if box.unit and ns.Box.UpdateCooldownIcons then ns.Box.UpdateCooldownIcons(box, target) end
        end
    end
    if ns.CooldownBar then ns.CooldownBar:Update(target) end
end

-- The spells bound on Actions that have a cooldown worth showing, in Actions
-- order, without repeats.
function Cooldowns:BoundSpells()
    local out, seen = {}, {}
    if not (ns.Bindings and ns.Bindings.List) then return out end
    for _, entry in ipairs(ns.Bindings:List()) do
        local id = ns.Bindings:SpellID(entry)
        local wanted = entry.role == ns.ROLE_PRIMARY or entry.role == ns.ROLE_SECONDARY
            or (ns.Escape and ns.Escape:IsEnabledSpell(id))
            or (ns.Bindings.IsDispelSpell and ns.Bindings:IsDispelSpell(id))
        if wanted and type(id) == "number" and not seen[id] then
            seen[id] = true
            out[#out + 1] = id
        end
    end
    return out
end

function Cooldowns.SpellName(spellID)
    if C_Spell and C_Spell.GetSpellName then
        local ok, name = pcall(C_Spell.GetSpellName, spellID)
        if ok and type(name) == "string" then return name end
    end
    if GetSpellInfo then
        local ok, name = pcall(GetSpellInfo, spellID)
        if ok and type(name) == "string" then return name end
    end
    return "Spell " .. tostring(spellID)
end

function Cooldowns.SpellTexture(spellID)
    if C_Spell and C_Spell.GetSpellTexture then
        local ok, texture = pcall(C_Spell.GetSpellTexture, spellID)
        if ok and texture then return texture end
    end
    if GetSpellTexture then
        local ok, texture = pcall(GetSpellTexture, spellID)
        if ok and texture then return texture end
    end
    return 134400
end

Cooldowns.FORBEARANCE = 25771

-- Blizzard lets addons pick out one debuff on a friendly unit only when the
-- spell is flagged never secret (Blizzard_AuraContainerUtil's identity
-- gate). This answers whether Forbearance is, so the cells could show it.
function Cooldowns.AuraSecrecyText(spellID)
    local api = C_Secrets and C_Secrets.GetSpellAuraSecrecy
    if not api then return "secrecy API unavailable" end
    local ok, level = pcall(api, spellID)
    if not ok then return "secrecy check failed" end
    if secret(level) then return "secrecy level is itself secret" end
    local levels = Enum and Enum.SecrecyLevel
    if levels and level == levels.NeverSecret then return "never secret, so cells can show it" end
    for name, value in pairs(levels or {}) do
        if value == level then return "secrecy " .. tostring(name) .. ", so cells can't pick it out" end
    end
    return "secrecy level " .. tostring(level)
end

local PATH_TEXT = {
    readable = "readable",
    curve = "secret, engine curve",
    open = "unreadable, always shown",
}

-- Safe in combat: nothing here builds a frame or touches a secure one. The
-- in-combat answer is the one that matters, since secrecy is combat-only.
function Cooldowns:DiagnosticLines()
    local db = ns.db or {}
    local style = db.cooldownStyle or "BOX"
    local lines = {
        "Cooldown icons: sweep " .. tostring(style)
            .. (style == "AUTO" and (" (" .. (ns.Box and ns.Box.CooldownStyle() or "?") .. ")") or "")
            .. ", bar " .. (db.cooldownBar and "on" or "off")
            .. ", " .. (InCombatLockdown and InCombatLockdown() and "in combat" or "out of combat")
            .. ", updates " .. tostring(self.updates),
        "Curve API: " .. ((C_CurveUtil and C_CurveUtil.CreateCurve) and "yes" or "no"),
        "Forbearance aura: " .. Cooldowns.AuraSecrecyText(Cooldowns.FORBEARANCE),
    }
    if ns.Lockouts then
        for _, line in ipairs(ns.Lockouts:DiagnosticLines()) do lines[#lines + 1] = line end
    end
    for _, id in ipairs(self:BoundSpells()) do
        local state = self:State(id)
        local path = state and "readable" or self.lastPath[id]
        if not state then
            -- Probe the fallback without touching a real icon.
            local probe = { spellID = id, frame = { SetAlpha = function() end } }
            self:Apply(probe, false, true)
            path = self.lastPath[id]
        end
        lines[#lines + 1] = "  " .. self.SpellName(id) .. " (" .. tostring(id) .. "): "
            .. (state and string.lower(state) .. ", " or "") .. (PATH_TEXT[path] or "not checked")
    end
    return lines
end

function Cooldowns:Report()
    for _, line in ipairs(self:DiagnosticLines()) do
        ns.Print("  " .. line)
    end
end
