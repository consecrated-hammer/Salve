local function equal(actual, expected, label)
    if actual ~= expected then
        error(("%s: expected %s, got %s"):format(label, tostring(expected), tostring(actual)))
    end
end

-- ── Minimal frame doubles ──────────────────────────────────────────────────

local function region()
    local r = { points = {}, alpha = 1, shown = true }
    function r:SetAllPoints(target) self.points = { { "ALL", target } } end
    function r:ClearAllPoints() self.points = {} end
    function r:SetPoint(...) self.points[#self.points + 1] = { ... } end
    function r:SetAlpha(value)
        if type(value) == "table" and value.secret then
            if value.reject then error("secret rejected") end
            self.alpha = value.value
            return
        end
        self.alpha = value
    end
    function r:GetAlpha() return self.alpha end
    function r:SetSize(w, h) self.width, self.height = w, h end
    function r:SetTexture(texture) self.texture = texture end
    function r:SetTexCoord() end
    function r:SetColorTexture() end
    function r:Show() self.shown = true end
    function r:Hide() self.shown = false end
    function r:IsShown() return self.shown end
    function r:SetShown(value) self.shown = value and true or false end
    function r:SetBackdrop() end
    function r:SetBackdropBorderColor() end
    function r:SetFont() end
    function r:SetText(text) self.text = text end
    function r:SetWordWrap() end
    function r:SetJustifyH() end
    return r
end

local function frame(kind, parent)
    local f = region()
    f.kind, f.parent, f.level, f.scripts = kind, parent, (parent and parent.level or 0) + 1, {}
    function f:CreateTexture() return region() end
    function f:CreateFontString() return region() end
    function f:EnableMouse() end
    function f:SetFrameLevel(level) self.level = level end
    function f:GetFrameLevel() return self.level end
    function f:HookScript(name, fn) self.scripts[name] = fn end
    if kind == "Cooldown" then
        function f:SetDrawSwipe(value) self.swipe = value end
        function f:SetDrawEdge(value) self.edge = value end
        function f:SetDrawBling() end
        function f:SetSwipeColor() end
        function f:SetEdgeColor() end
        function f:SetHideCountdownNumbers() end
        function f:SetMinimumCountdownDuration() end
        function f:GetCountdownFontString() return nil end
        function f:SetCooldownFromDurationObject(duration) self.duration = duration end
        function f:SetCooldown(start, length) self.start, self.length = start, length end
        function f:Clear() self.duration, self.start, self.cleared = nil, nil, true end
    end
    return f
end

function CreateFrame(kind, _, parent) return frame(kind, parent) end

local locked = false
function InCombatLockdown() return locked end
function issecretvalue(value) return type(value) == "table" and value.secret == true end

local timers = {}
C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end }
local function runTimers()
    local pending = timers
    timers = {}
    for _, fn in ipairs(pending) do fn() end
end

-- Per-spell cooldown info and duration objects the tests can change.
local info, durations = {}, {}
C_Spell = {
    GetSpellCooldown = function(id) return info[id] end,
    GetSpellCooldownDuration = function(id) return durations[id] end,
    GetSpellTexture = function(id) return "tex" .. id end,
    GetSpellName = function(id) return "Spell" .. id end,
}

local CLEANSE, FREEDOM, BOP = 4987, 1044, 1022

local ns = { Print = function() end }
ns.ROLE_PRIMARY, ns.ROLE_SECONDARY = "PRIMARY", "SECONDARY"
ns.spellID = CLEANSE
ns.Binding = {}
ns.Binding.CooldownDuration = function(id) return durations[id] end
ns.Binding.ApplyCooldown = function(cooldown, duration)
    if duration then cooldown:SetCooldownFromDurationObject(duration) else cooldown:Clear() end
    return true
end
local escapes = { [FREEDOM] = true, [BOP] = true }
ns.Escape = {
    IsEnabledSpell = function(_, id) return escapes[id] == true end,
    SweepSpellIDs = function() return { FREEDOM } end,
    CanSweepForUnit = function(_, _, unit) return unit == "player" end,
}
local bindings = {
    { key = "BUTTON1", role = "PRIMARY" },
    { key = "BUTTON2", spell = FREEDOM },
    { key = "BUTTON3", spell = BOP },
    { key = "SHIFT-BUTTON1", role = "SECONDARY" },
}
ns.Bindings = {
    List = function() return bindings end,
    SpellID = function(_, entry)
        if entry.role == "PRIMARY" or entry.role == "SECONDARY" then return ns.spellID end
        return entry.spell
    end,
    IsDispelSpell = function(_, id) return id == CLEANSE end,
}

assert(loadfile("Core/Config.lua"))("Salve", ns)
ns.db = {}
for key, value in pairs(ns.defaults) do
    ns.db[key] = type(value) == "table" and {} or value
end

assert(loadfile("Features/Cooldowns.lua"))("Salve", ns)
assert(loadfile("UI/Box.lua"))("Salve", ns)
assert(loadfile("UI/CooldownBar.lua"))("Salve", ns)
local Cooldowns, Box, Bar = ns.Cooldowns, ns.Box, ns.CooldownBar

-- ── Defaults ────────────────────────────────────────

equal(ns.defaults.cooldownStyle, "AUTO", "Auto sweep style is the default")
equal(ns.defaults.cooldownBarMatchPanel, true, "the bar matches the panel by default")
equal(ns.defaults.cooldownBar, false, "the bar is off by default")
equal(ns.defaults.cooldownBarShowReady, false, "ready spells hide by default")
equal(Cooldowns:Enabled(), false, "nothing new runs by default")
Cooldowns:Request()
equal(#timers, 0, "a request with everything off schedules nothing")

-- ── Reading state ──────────────────────────────────────────────────────────

info[CLEANSE] = { isActive = true, isOnGCD = false }
equal(Cooldowns:State(CLEANSE), "ACTIVE", "an active cooldown reads active")
info[CLEANSE] = { isActive = true, isOnGCD = true }
equal(Cooldowns:State(CLEANSE), "READY", "the global cooldown alone reads ready")
info[CLEANSE] = { isActive = false, isOnGCD = false }
equal(Cooldowns:State(CLEANSE), "READY", "an idle spell reads ready")
info[CLEANSE] = { isActive = { secret = true }, isOnGCD = false }
equal(Cooldowns:State(CLEANSE), nil, "a secret flag is never compared")
info[CLEANSE] = { startTime = 50, duration = 8 }
equal(Cooldowns:State(CLEANSE), "ACTIVE", "older clients fall back to plain timings")
info[CLEANSE] = { startTime = 50, duration = 1.5 }
equal(Cooldowns:State(CLEANSE), "READY", "a global-cooldown-length timing reads ready")
info[CLEANSE] = { startTime = { secret = true }, duration = 8 }
equal(Cooldowns:State(CLEANSE), nil, "secret timings are never compared")

-- ── Showing and hiding ─────────────────────────────────────────────────────

local function icon(id) return { spellID = id, frame = region() } end

local a = icon(CLEANSE)
info[CLEANSE] = { isActive = true, isOnGCD = false }
equal(Cooldowns:Apply(a, false), "SHOWN", "active icon shows")
equal(a.frame.alpha, 1, "active icon is opaque")
info[CLEANSE] = { isActive = false }
equal(Cooldowns:Apply(a, false), "HIDDEN", "ready icon hides")
equal(a.frame.alpha, 0, "hidden icon is transparent")
equal(Cooldowns:Apply(a, true), "DIMMED", "ready icon dims with show-when-ready")
equal(a.frame.alpha, Cooldowns.READY_ALPHA, "dimmed alpha")

-- Secret state with no curve support: fail open.
info[CLEANSE] = { isActive = { secret = true } }
durations[CLEANSE] = {}
equal(Cooldowns:Apply(a, false), "OPEN", "unreadable state without a curve shows the icon")
equal(a.frame.alpha, 1, "fail-open icon is opaque")
equal(Cooldowns.lastPath[CLEANSE], "open", "probe records the fail-open path")

-- Secret state with the curve: the engine's value goes straight to SetAlpha.
local curvePoints
C_CurveUtil = { CreateCurve = function()
    local c = { points = {} }
    function c:SetType(t) self.type = t end
    function c:AddPoint(x, y) self.points[#self.points + 1] = { x, y } end
    curvePoints = c.points
    return c
end }
Enum = { LuaCurveType = { Step = "STEP" } }
durations[CLEANSE] = { EvaluateRemainingDuration = function(_, curve, default)
    return { secret = true, value = 0.9, curve = curve, default = default }
end }
local b = icon(CLEANSE)
equal(Cooldowns:Apply(b, false), "CURVE", "secret state uses the engine curve")
equal(b.frame.alpha, 0.9, "curve value reaches SetAlpha")
equal(curvePoints[1][2], 0, "hidden curve starts at zero")
equal(curvePoints[2][2], 1, "hidden curve steps to one")

durations[CLEANSE] = { EvaluateRemainingDuration = function()
    return { secret = true, value = 0.5, reject = true }
end }
local c = icon(CLEANSE)
equal(Cooldowns:Apply(c, false), "OPEN", "a rejected secret alpha fails open")

-- Unreadable icons keep their state unless it's their own edge.
durations[CLEANSE] = { EvaluateRemainingDuration = function()
    return { secret = true, value = 1 }
end }
local d = icon(CLEANSE)
d.mode = "CURVE"
d.frame.alpha = 0
equal(Cooldowns:Apply(d, false, false), "CURVE", "a skipped evaluation keeps the mode")
equal(d.frame.alpha, 0, "a skipped evaluation keeps the alpha")
equal(Cooldowns:ShouldEvaluate(d, FREEDOM), false, "another spell's edge doesn't re-check")
equal(Cooldowns:ShouldEvaluate(d, CLEANSE), true, "its own edge re-checks")
locked = true
equal(Cooldowns:ShouldEvaluate(d, nil), false, "a full re-check in combat leaves it alone")
locked = false
equal(Cooldowns:ShouldEvaluate(d, nil), true, "a full re-check out of combat evaluates")

-- ── Slots ──────────────────────────────────────────────────────────────────

info[CLEANSE] = { isActive = false }
info[FREEDOM] = { isActive = true, isOnGCD = false }
info[BOP] = { isActive = false }
local placed = Cooldowns:Arrange({ icon(CLEANSE), icon(FREEDOM), icon(BOP) }, false, nil)
equal(#placed, 1, "readable state closes up the gaps")
equal(placed[1].spellID, FREEDOM, "only the recovering spell takes a slot")
placed = Cooldowns:Arrange({ icon(CLEANSE), icon(FREEDOM), icon(BOP) }, true, nil)
equal(#placed, 3, "show-when-ready keeps every slot")
info[BOP] = { isActive = { secret = true } }
placed = Cooldowns:Arrange({ icon(CLEANSE), icon(FREEDOM), icon(BOP) }, false, nil)
equal(#placed, 3, "one unreadable spell pins the row to fixed slots")
info[BOP] = { isActive = false }

-- ── Bound spells ───────────────────────────────────────────────────────────

local spells = Cooldowns:BoundSpells()
equal(#spells, 3, "primary and secondary dispel collapse into one spell")
equal(spells[1], CLEANSE, "Actions order: dispel first")
equal(spells[2], FREEDOM, "Actions order: Freedom second")
equal(spells[3], BOP, "Actions order: BoP third")
escapes[BOP] = nil
equal(#Cooldowns:BoundSpells(), 2, "a disabled movement spell drops out")
escapes[BOP] = true

-- ── Cell icon mode ─────────────────────────────────────────────────────────

local box = frame("Button")
box.unit = "player"
box.dispelCooldown = frame("Cooldown", box)
box.dispelCooldown:SetAllPoints(box)
Box.WatchCooldown(box.dispelCooldown)
box.movementCooldowns = { Box.CreateMovementCooldown(box, 1) }

ns.db.cooldownStyle = "BOX"
equal(Box.CooldownStyle(), "BOX", "whole-box sweep style")
Box.UpdateCooldownIcons(box, nil)
equal(box.cooldownIcons, nil, "whole-box mode builds no icons")
equal(box.dispelCooldown.points[1][2], box, "whole-box sweep stays on the cell")

ns.db.cooldownStyle = "AUTO"
ns.db.showNames = false
equal(Box.CooldownStyle(), "BOX", "auto without names is whole box")
ns.db.showNames = true
equal(Box.CooldownStyle(), "ICON", "auto with names is icon")

ns.db.cooldownStyle = "ICON"
info[CLEANSE] = { isActive = true, isOnGCD = false }
info[FREEDOM] = { isActive = false }
Box.UpdateCooldownIcons(box, nil)
equal(#box.cooldownIcons, 2, "an icon for the dispel and the movement sweep")
local dispelIcon = box.cooldownIcons[1]
equal(dispelIcon.frame.texture.texture, "tex" .. CLEANSE, "dispel icon uses the spell texture")
equal(box.dispelCooldown.points[1][2], dispelIcon.frame, "dispel sweep moves onto its icon")
equal(dispelIcon.frame.alpha, 1, "recovering dispel icon shows")
equal(box.dispelCooldown.alpha, 1, "its sweep shows with it")
equal(box.cooldownIcons[2].frame.alpha, 0, "ready Freedom icon hides")
equal(box.movementCooldowns[1].alpha, 0, "and its sweep with it")
equal(box.movementCooldowns[1].swipe, true, "movement sweeps draw a swipe on an icon")
equal(box.movementCooldowns[1].edge, false, "without the clock-hand edge")
equal(box.dispelCooldown.salveSpellID, CLEANSE, "finished sweeps report their spell")
equal(box.cooldownIcons[1].frame.points[1][1], "RIGHT", "icons sit on the right by default")

-- A finished sweep asks for a re-check of its own spell, coalesced.
box.dispelCooldown.scripts.OnCooldownDone(box.dispelCooldown)
equal(#timers, 1, "a finished sweep schedules one update")
box.dispelCooldown.scripts.OnCooldownDone(box.dispelCooldown)
equal(#timers, 1, "a second request in the same frame coalesces")
ns.Panel = { boxes = { box } }
info[CLEANSE] = { isActive = false }
runTimers()
equal(dispelIcon.frame.alpha, 0, "the icon hides once its cooldown is done")

-- Another unit's cell skips a self-only movement sweep.
local other = frame("Button")
other.unit = "party1"
other.dispelCooldown = frame("Cooldown", other)
other.movementCooldowns = { Box.CreateMovementCooldown(other, 1) }
Box.UpdateCooldownIcons(other, nil)
equal(#other.cooldownIcons, 1, "self-only movement sweeps stay off other cells")

-- Back to whole box: everything returns to the cell.
ns.db.cooldownStyle = "BOX"
Box.UpdateCooldownIcons(box, nil)
equal(box.dispelCooldown.points[1][2], box, "dispel sweep returns to the cell")
equal(box.dispelCooldown.alpha, 1, "dispel sweep is visible again")
equal(box.movementCooldowns[1].edge, true, "movement edge returns")
equal(box.movementCooldowns[1].swipe, false, "movement swipe goes")
equal(dispelIcon.frame.shown, false, "icons are hidden")
equal(box.cooldownIconMode, false, "icon mode is off")

-- ── Cooldown bar ───────────────────────────────────────────────────────────

local panel = frame("Frame")
Bar:Create(panel)
Bar:Update(nil)
equal(Bar.live.frame.shown, false, "the bar stays hidden while off")

ns.db.cooldownBar = true
ns.db.cooldownBarMatchPanel = false
equal(Cooldowns:Enabled(), true, "the bar enables cooldown updates")
info[CLEANSE] = { isActive = false }
info[FREEDOM] = { isActive = true, isOnGCD = false }
info[BOP] = { isActive = false }
durations[CLEANSE], durations[FREEDOM], durations[BOP] = { id = "c" }, { id = "f" }, { id = "b" }
Bar:Update(nil)
local icons = Bar.live.icons
equal(Bar.live.frame.shown, true, "the bar shows once on")
equal(#icons, 3, "an icon per bound spell")
equal(icons[1].cooldown.cleared, true, "a ready spell's sweep is cleared, not the GCD")
equal(icons[2].cooldown.duration, durations[FREEDOM], "a recovering spell gets its duration object")
equal(icons[2].frame.alpha, 1, "recovering spell shows")
equal(icons[1].frame.alpha, 0, "ready spell hides")
equal(icons[2].frame.points[1][4], 0, "the only visible icon takes the first slot")
equal(Bar.live.frame.points[1][1], "TOPLEFT", "bottom bar hangs from the grid")
equal(Bar.live.frame.points[1][3], "BOTTOMLEFT", "bottom bar anchors under the grid")
equal(Bar.live.frame.points[1][5], -ns.db.cooldownBarGap, "bottom bar keeps its gap")
equal(icons[2].cooldown.salveSpellID, FREEDOM, "bar sweeps report their spell")

ns.db.cooldownBarShowReady = true
ns.db.cooldownBarSide = "RIGHT"
Bar:Update(nil)
equal(icons[1].frame.alpha, Cooldowns.READY_ALPHA, "ready spells dim with show-when-ready")
equal(ns.db.cooldownBarOrientation, "HORIZONTAL", "the bar runs across by default")
equal(icons[2].frame.points[1][4], ns.db.cooldownBarIconSize + ns.db.cooldownBarSpacing,
    "horizontal icons run across in Actions order")
equal(Bar.live.frame.points[1][3], "TOPRIGHT", "right bar anchors to the grid's right")
equal(Bar.live.frame.height, ns.db.cooldownBarIconSize, "horizontal bar is one icon tall")
ns.db.cooldownBarOrientation = "VERTICAL"
Bar:Update(nil)
equal(icons[2].frame.points[1][5], -(ns.db.cooldownBarIconSize + ns.db.cooldownBarSpacing),
    "vertical icons stack downward in Actions order")
equal(Bar.live.frame.width, ns.db.cooldownBarIconSize, "vertical bar is one icon wide")

-- Matching the panel takes the cell height, spacing and border setting.
ns.db.boxHeight, ns.db.spacing, ns.db.showBorders = 20, 3, false
ns.db.cooldownBarMatchPanel = true
Bar:Update(nil)
equal(icons[1].frame.height, 20, "matched icons are cell height")
equal(icons[2].frame.points[1][5], -23, "matched icons use the cell spacing")
equal(icons[1].frame.backing.shown, false, "matched icons drop the black backing")
equal(icons[1].frame.border.shown, false, "no border while box borders are off")
ns.db.showBorders = true
Bar:Update(nil)
equal(icons[1].frame.border.shown, true, "the cell border follows box borders")
ns.db.cooldownBarMatchPanel = false
ns.db.cooldownBarOrientation = "HORIZONTAL"
Bar:Update(nil)
equal(icons[1].frame.backing.shown, true, "unmatched icons keep their backing")

ns.db.cooldownBarHidden[BOP] = true
Bar:Update(nil)
equal(icons[3].frame.shown, false, "a toggled-off spell leaves the bar")
equal(#Bar:Spells(), 2, "toggled-off spells aren't tracked")

-- In combat with secret state, another spell's edge leaves the bar's
-- unreadable icons as they were.
ns.db.cooldownBarHidden[BOP] = nil
info[CLEANSE] = { isActive = { secret = true } }
info[FREEDOM] = { isActive = { secret = true } }
Bar:Update(nil)
locked = true
icons[1].cooldown.duration = nil
icons[2].cooldown.duration = "kept"
Bar:Update(CLEANSE)
equal(icons[1].cooldown.duration, durations[CLEANSE], "the cast spell's duration is forwarded")
equal(icons[2].cooldown.duration, "kept", "other unreadable spells aren't touched")
locked = false

ns.db.cooldownBar = false
Bar:Update(nil)
equal(Bar.live.frame.shown, false, "switching the bar off hides it")

-- ── Probe ──────────────────────────────────────────────────────────────────

locked = true
durations[CLEANSE] = { EvaluateRemainingDuration = function()
    return { secret = true, value = 1 }
end }
local lines = Cooldowns:DiagnosticLines()
equal(lines[1]:find("in combat", 1, true) ~= nil, true, "probe runs in combat")
local joined = table.concat(lines, "\n")
equal(joined:find("Spell" .. CLEANSE .. " (" .. CLEANSE .. "): secret, engine curve", 1, true) ~= nil,
    true, "probe names the curve path")
equal(joined:find("Spell" .. BOP .. " (" .. BOP .. "): ready, readable", 1, true) ~= nil,
    true, "probe names the readable path")
equal(joined:find("Forbearance aura: secrecy API unavailable", 1, true) ~= nil,
    true, "probe copes without the secrecy API")
C_Secrets = { GetSpellAuraSecrecy = function() return 0 end }
Enum.SecrecyLevel = { NeverSecret = 0, Secret = 2 }
equal(Cooldowns.AuraSecrecyText(25771), "never secret, so cells can show it", "probe reads never-secret")
C_Secrets.GetSpellAuraSecrecy = function() return 2 end
equal(Cooldowns.AuraSecrecyText(25771), "secrecy Secret, so cells can't pick it out", "probe names other levels")
locked = false

-- Lockouts on the bar: after the spells, named, and shown with the spells off.
local lockouts = {}
ns.Lockouts = { BarEntries = function() return lockouts end }
ns.db.cooldownBarShowReady = true
info[CLEANSE], info[FREEDOM], info[BOP] = { isActive = false }, { isActive = false }, { isActive = false }
Bar:Update(nil)
local spellCount = #Bar.live.spells
lockouts = { { spellID = 25771, name = "Tank", start = 50, duration = 30 } }
Bar:UpdateLockouts()
local lockout = Bar.live.lockouts[1]
equal(lockout.name.text, "Tank", "a lockout is labelled with the member")
equal(lockout.cooldown.start, 50, "and sweeps with its own timer")
equal(lockout.frame.points[1][4], spellCount * (ns.db.cooldownBarIconSize + ns.db.cooldownBarSpacing),
    "lockouts follow the spells")
ns.db.cooldownBar = false
Bar:Update(nil)
equal(Bar.live.frame.shown, true, "lockouts show the bar with the spells off")
equal(Bar.live.lockouts[1].frame.points[1][4], 0, "and take the first slot")
lockouts = {}
Bar:UpdateLockouts()
equal(Bar.live.frame.shown, false, "the bar hides when the last lockout ends")
ns.db.cooldownBar = true

print("cooldown icon tests passed")
