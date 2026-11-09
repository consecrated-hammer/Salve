local addonName, ns = ...

-- ============================================================
-- Cooldown bar
-- ============================================================
-- A strip of icons beside the grid for the spells bound on Actions, each
-- with its own sweep, then any active lockouts (Forbearance) labelled with
-- the member's name. Off by default; lockouts on the bar show even with the
-- spells switched off.
--
-- ☠ A plain, mouse-dead child of SalveFrame. It moves and hides with the
--   panel (including when attached), and nothing secure is anchored to it,
--   so it can be laid out, shown and faded in combat. Never anchor a box or
--   any other protected frame to it: that would make it protected too.

ns.CooldownBar = {}
local Bar = ns.CooldownBar

local Instance = {}
Instance.__index = Instance

local function StyleCountdown(cooldown, size)
    local text = cooldown.GetCountdownFontString and cooldown:GetCountdownFontString()
    if not text then return end
    local fontPath = STANDARD_TEXT_FONT
    if not fontPath and GameFontNormal and GameFontNormal.GetFont then
        fontPath = GameFontNormal:GetFont()
    end
    if fontPath then text:SetFont(fontPath, math.max(8, math.floor(size * 0.5 + 0.5)), "OUTLINE") end
    text:SetTextColor(1, 0.86, 0.18, 1)
    text:ClearAllPoints()
    text:SetPoint("CENTER", cooldown, "CENTER", 1, 0)
end

local function CreateIcon(parent)
    local frame = CreateFrame("Frame", nil, parent)
    if frame.EnableMouse then frame:EnableMouse(false) end
    frame:SetAlpha(0)
    frame.backing = frame:CreateTexture(nil, "BACKGROUND")
    frame.backing:SetPoint("TOPLEFT", frame, "TOPLEFT", -1, 1)
    frame.backing:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 1, -1)
    frame.backing:SetColorTexture(0, 0, 0, 0.85)
    frame.texture = frame:CreateTexture(nil, "ARTWORK")
    frame.texture:SetAllPoints(frame)
    if frame.texture.SetTexCoord then frame.texture:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
    -- The cells' own border, used when the bar matches the panel.
    frame.border = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    frame.border:SetPoint("TOPLEFT", frame, "TOPLEFT", -1, 1)
    frame.border:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 1, -1)
    if frame.border.SetBackdrop then
        frame.border:SetBackdrop({ edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 8 })
        frame.border:SetBackdropBorderColor(0.55, 0.55, 0.55, 0.72)
    end
    if frame.border.EnableMouse then frame.border:EnableMouse(false) end
    frame.border:Hide()

    local cooldown = CreateFrame("Cooldown", nil, frame, "CooldownFrameTemplate")
    cooldown:SetAllPoints(frame)
    if cooldown.SetDrawSwipe then cooldown:SetDrawSwipe(true) end
    if cooldown.SetDrawEdge then cooldown:SetDrawEdge(false) end
    if cooldown.SetDrawBling then cooldown:SetDrawBling(false) end
    if cooldown.SetSwipeColor then cooldown:SetSwipeColor(0, 0, 0, 0.72) end
    if cooldown.SetHideCountdownNumbers then cooldown:SetHideCountdownNumbers(false) end
    if cooldown.SetMinimumCountdownDuration then cooldown:SetMinimumCountdownDuration(0) end
    if cooldown.EnableMouse then cooldown:EnableMouse(false) end
    frame.border:SetFrameLevel(cooldown:GetFrameLevel() + 2)
    return { frame = frame, cooldown = cooldown }
end

-- A lockout icon: a bar icon with the member's name along the bottom.
local function CreateLockoutIcon(parent)
    local icon = CreateIcon(parent)
    local overlay = CreateFrame("Frame", nil, icon.frame)
    overlay:SetAllPoints(icon.frame)
    if overlay.EnableMouse then overlay:EnableMouse(false) end
    overlay:SetFrameLevel(icon.cooldown:GetFrameLevel() + 3)
    icon.name = overlay:CreateFontString(nil, "OVERLAY")
    icon.name:SetPoint("BOTTOMLEFT", icon.frame, "BOTTOMLEFT", 1, 1)
    icon.name:SetPoint("BOTTOMRIGHT", icon.frame, "BOTTOMRIGHT", -1, 1)
    if icon.name.SetWordWrap then icon.name:SetWordWrap(false) end
    if icon.name.SetJustifyH then icon.name:SetJustifyH("CENTER") end
    return icon
end

-- Icon size and spacing: the bar's own, or the cells' when matching.
function Bar.Metrics()
    local db = ns.db
    if db.cooldownBarMatchPanel then
        return tonumber(db.boxHeight) or 20, tonumber(db.spacing) or 2
    end
    return tonumber(db.cooldownBarIconSize) or 24, tonumber(db.cooldownBarSpacing) or 2
end

local function StyleFrame(frame)
    local match = ns.db.cooldownBarMatchPanel
    frame.backing:SetShown(not match)
    frame.border:SetShown(match and ns.db.showBorders ~= false or false)
end

function Bar.New(parent, preview)
    local frame = CreateFrame("Frame", nil, parent)
    if frame.EnableMouse then frame:EnableMouse(false) end
    frame:SetSize(1, 1)
    frame:Hide()
    return setmetatable({ parent = parent, frame = frame, icons = {}, lockouts = {}, preview = preview }, Instance)
end

-- The spells the bar shows, before the per-spell toggles.
function Bar:Spells()
    local out = {}
    local hidden = ns.db and ns.db.cooldownBarHidden or {}
    for _, id in ipairs(ns.Cooldowns:BoundSpells()) do
        if not hidden[id] then out[#out + 1] = id end
    end
    return out
end

function Instance:Anchor()
    local db = ns.db
    local side, gap = db.cooldownBarSide or "BOTTOM", tonumber(db.cooldownBarGap) or 4
    local frame = self.frame
    frame:ClearAllPoints()
    if side == "TOP" then
        frame:SetPoint("BOTTOMLEFT", self.parent, "TOPLEFT", 0, gap)
    elseif side == "LEFT" then
        frame:SetPoint("TOPRIGHT", self.parent, "TOPLEFT", -gap, 0)
    elseif side == "RIGHT" then
        frame:SetPoint("TOPLEFT", self.parent, "TOPRIGHT", gap, 0)
    else
        frame:SetPoint("TOPLEFT", self.parent, "BOTTOMLEFT", 0, -gap)
    end
end

-- Points the pool at `spells`, in order. A slot that changes spell forgets
-- how it was last shown, so it gets evaluated afresh.
function Instance:Assign(spells)
    local size = Bar.Metrics()
    local list = {}
    for index, spellID in ipairs(spells) do
        local icon = self.icons[index] or CreateIcon(self.frame)
        self.icons[index] = icon
        if icon.spellID ~= spellID then icon.mode = nil end
        icon.spellID = spellID
        icon.cooldown.salveSpellID = not self.preview and spellID or nil
        if not self.preview and ns.Box and ns.Box.WatchCooldown then ns.Box.WatchCooldown(icon.cooldown) end
        icon.frame.texture:SetTexture(ns.Cooldowns.SpellTexture(spellID))
        icon.frame:SetSize(size, size)
        StyleFrame(icon.frame)
        StyleCountdown(icon.cooldown, size)
        icon.frame:Show()
        list[index] = icon
    end
    for index = #spells + 1, #self.icons do
        local icon = self.icons[index]
        icon.frame:Hide()
        icon.spellID, icon.mode, icon.forcedState = nil, nil, nil
        icon.cooldown.salveSpellID = nil
    end
    return list
end

-- Points the lockout pool at `entries` ({ spellID, name, start, duration }).
-- Their times are Salve's own, so the sweep is set directly.
function Instance:AssignLockouts(entries)
    local size = Bar.Metrics()
    local list = {}
    for index, entry in ipairs(entries) do
        local icon = self.lockouts[index] or CreateLockoutIcon(self.frame)
        self.lockouts[index] = icon
        icon.frame.texture:SetTexture(ns.Cooldowns.SpellTexture(entry.spellID))
        icon.frame:SetSize(size, size)
        StyleFrame(icon.frame)
        StyleCountdown(icon.cooldown, size)
        local fontPath = STANDARD_TEXT_FONT
        if fontPath then icon.name:SetFont(fontPath, math.max(7, math.floor(size * 0.3 + 0.5)), "OUTLINE") end
        icon.name:SetText(entry.name or "")
        icon.cooldown:SetCooldown(entry.start, entry.duration)
        icon.frame:SetAlpha(1)
        icon.frame:Show()
        list[index] = icon
    end
    for index = #entries + 1, #self.lockouts do self.lockouts[index].frame:Hide() end
    return list
end

-- Lays out the placed spell icons, then the lockouts after them, and shows
-- the bar when there's anything on it.
function Instance:Place(spells, entries)
    self.spells = spells
    local placed = {}
    for _, icon in ipairs(spells) do placed[#placed + 1] = icon end
    for _, icon in ipairs(self:AssignLockouts(entries)) do placed[#placed + 1] = icon end
    self:Layout(placed)
    -- With the spells on, the bar stays shown even when empty, as it always
    -- has, so its icons' sweeps keep running.
    self.frame:SetShown(ns.db.cooldownBar == true or #placed > 0)
end

function Instance:Layout(placed)
    local size, spacing = Bar.Metrics()
    local vertical = ns.db.cooldownBarOrientation == "VERTICAL"
    for index, icon in ipairs(placed) do
        local offset = (index - 1) * (size + spacing)
        icon.frame:ClearAllPoints()
        if vertical then
            icon.frame:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 0, -offset)
        else
            icon.frame:SetPoint("TOPLEFT", self.frame, "TOPLEFT", offset, 0)
        end
    end
    local length = math.max(1, #placed * size + math.max(0, #placed - 1) * spacing)
    if vertical then
        self.frame:SetSize(size, length)
    else
        self.frame:SetSize(length, size)
    end
    self:Anchor()
end

-- ── Live bar ───────────────────────────────────────────────────────────────

function Bar:Create(parent)
    if self.live then return end
    self.live = Bar.New(parent, false)
end

function Bar:Anchor()
    if self.live and ns.db then self.live:Anchor() end
end

local function lockoutEntries()
    return ns.Lockouts and ns.Lockouts:BarEntries() or {}
end

-- `target` is the spell whose cast or finished sweep caused this, or nil to
-- re-check every spell.
function Bar:Update(target)
    local live = self.live
    if not live then return end
    local db = ns.db
    if not db then return end
    if not db.cooldownBar then
        live:Assign({})
        live:Place({}, lockoutEntries())
        return
    end

    local icons = live:Assign(self:Spells())
    for _, icon in ipairs(icons) do
        local state = ns.Cooldowns:State(icon.spellID)
        if state == "READY" then
            -- Clear rather than forward: a ready spell's duration object is
            -- the global cooldown, and that sweep would be noise.
            ns.Binding.ApplyCooldown(icon.cooldown, nil)
        elseif (state == "ACTIVE" and (target == nil or target == icon.spellID))
            or (state == nil and (icon.mode == nil or ns.Cooldowns:ShouldEvaluate(icon, target))) then
            ns.Binding.ApplyCooldown(icon.cooldown, ns.Binding.CooldownDuration(icon.spellID))
        end
    end
    live:Place(ns.Cooldowns:Arrange(icons, db.cooldownBarShowReady, target), lockoutEntries())
end

-- A lockout started or ended: re-place what's there without re-checking the
-- spells.
function Bar:UpdateLockouts()
    local live = self.live
    if not (live and ns.db) then return end
    if ns.db.cooldownBar and live.spells then
        live:Place(live.spells, lockoutEntries())
    else
        self:Update(nil)
    end
end

-- ── Preview ────────────────────────────────────────────────────────────────
-- The test panels get a bar of their own: dispels sweep with the test cells'
-- dispel cooldown and movement actions with their movement sweep.

function Bar:RenderPreview(parent, preview)
    if not parent then return end
    local bar = parent.salveCooldownBar
    local lockouts = {}
    -- The test panel's sample lockout: the player's own, on its own timer.
    local sample = preview.lockout or (ns.Preview and ns.Preview.SampleLockout and ns.Preview:SampleLockout())
    if sample and ns.Lockouts and ns.Lockouts:OnBar() then
        lockouts[1] = { spellID = sample.spellID, name = preview.lockoutName,
            start = sample.start, duration = sample.duration }
    end
    if not (ns.db and (ns.db.cooldownBar or #lockouts > 0)) then
        if bar then bar.frame:Hide() end
        return
    end
    if not bar then
        bar = Bar.New(parent, true)
        parent.salveCooldownBar = bar
    end

    local icons = bar:Assign(ns.db.cooldownBar and self:Spells() or {})
    for _, icon in ipairs(icons) do
        local movement = ns.Escape and ns.Escape:IsEnabledSpell(icon.spellID)
        local active, start, duration
        if movement then
            active, start, duration = preview.movementSweepState, preview.movementSweepStart, 25
        else
            active, start, duration = preview.cooldownState == "COOLDOWN", preview.cooldownStart, 8
        end
        icon.forcedState = active and "ACTIVE" or "READY"
        if active and start then
            icon.cooldown:SetCooldown(start, duration)
        elseif icon.cooldown.Clear then
            icon.cooldown:Clear()
        end
    end
    bar:Place(ns.Cooldowns:Arrange(icons, ns.db.cooldownBarShowReady, nil), lockouts)
end
