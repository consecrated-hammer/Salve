local addonName, ns = ...

-- ============================================================
-- One box = one group member
-- ============================================================
-- A SecureActionButton with a FIXED unit and a FIXED spell. Because neither
-- attribute ever changes, nothing here needs rewriting mid-combat -- which is
-- the entire reason Salve does not need Decursive's machinery. The clicking
-- half is solved by never being clever about it.

ns.Box = {}
local Box = ns.Box

local function CooldownPoint(horizontal, vertical)
    horizontal = horizontal or "CENTER"
    vertical = vertical or "MIDDLE"
    if vertical == "MIDDLE" then
        return horizontal == "CENTER" and "CENTER" or horizontal
    end
    if horizontal == "CENTER" then return vertical end
    return vertical .. horizontal
end

local function StyleCooldownText(box)
    local cooldown = box and box.dispelCooldown
    local text = cooldown and cooldown.GetCountdownFontString
        and cooldown:GetCountdownFontString()
    if not text then return end

    local size = tonumber(ns.db and ns.db.cooldownFontSize) or 14
    local fontPath = STANDARD_TEXT_FONT
    if not fontPath and GameFontNormal and GameFontNormal.GetFont then
        fontPath = GameFontNormal:GetFont()
    end
    if fontPath then text:SetFont(fontPath, size, "THICKOUTLINE") end
    text:SetTextColor(1, 0.86, 0.18, 1)
    if text.SetShadowColor then text:SetShadowColor(0, 0, 0, 1) end
    if text.SetShadowOffset then text:SetShadowOffset(1, -1) end
    text:ClearAllPoints()
    -- On a small icon the only sensible place for the number is its middle.
    if box.cooldownIconMode then
        text:SetPoint("CENTER", cooldown, "CENTER", 1, 0)
        return
    end
    local point = CooldownPoint(ns.db and ns.db.cooldownJustifyH,
        ns.db and ns.db.cooldownJustifyV)
    local x = point:find("LEFT", 1, true) and 3
        or (point:find("RIGHT", 1, true) and -3 or 0)
    local y = point:find("TOP", 1, true) and -1
        or (point:find("BOTTOM", 1, true) and 1 or 0)
    -- Centre + Middle benefits from a small optical nudge. Edge alignments
    -- already have deliberate padding and should not move.
    if point == "CENTER" then x, y = 2, -1 end
    text:SetPoint(point, cooldown, point, x, y)
end

local function StyleNameText(box)
    local text = box and box.name
    if not text then return end
    local fontPath, _, flags
    if GameFontHighlightSmall and GameFontHighlightSmall.GetFont then
        fontPath, _, flags = GameFontHighlightSmall:GetFont()
    end
    fontPath = fontPath or STANDARD_TEXT_FONT
    if fontPath then
        text:SetFont(fontPath, tonumber(ns.db and ns.db.nameFontSize) or 11,
            flags or "")
    end
end

function Box.CreateMovementCooldown(box, index)
    local cooldown = CreateFrame("Cooldown", nil, box, "CooldownFrameTemplate")
    cooldown:SetAllPoints(box)
    cooldown:SetFrameLevel((box.movementFrameLevel or (box:GetFrameLevel() + 13)) + (index or 1))
    if cooldown.SetDrawSwipe then cooldown:SetDrawSwipe(false) end
    if cooldown.SetDrawEdge then cooldown:SetDrawEdge(true) end
    if cooldown.SetDrawBling then cooldown:SetDrawBling(false) end
    if cooldown.SetHideCountdownNumbers then cooldown:SetHideCountdownNumbers(true) end
    if cooldown.SetMinimumCountdownDuration then cooldown:SetMinimumCountdownDuration(0) end
    if cooldown.EnableMouse then cooldown:EnableMouse(false) end
    Box.WatchCooldown(cooldown)
    return cooldown
end

-- ── Cooldown icons ─────────────────────────────────────────────────────────
--
-- Whole box is the original look: the sweep covers the cell. Icon moves each
-- sweep onto a small spell icon that shows only while the spell recovers,
-- which keeps names readable. Features/Cooldowns.lua decides visibility.
--
-- ☠ The icons and the cooldown widgets are plain children of the secure box.
--   Re-anchoring and fading them is allowed in combat; nothing secure is ever
--   anchored to them.

function Box.CooldownStyle()
    local db = ns.db
    local style = db and db.cooldownStyle
    if style == "AUTO" then return db.showNames and "ICON" or "BOX" end
    return style == "ICON" and "ICON" or "BOX"
end

-- Hooked once at creation. A finished sweep is the edge where the icon
-- should go away, so it asks for a re-check of that spell only.
function Box.WatchCooldown(cooldown)
    if not cooldown or cooldown.salveWatched or not cooldown.HookScript then return end
    cooldown.salveWatched = true
    cooldown:HookScript("OnCooldownDone", function(self)
        if ns.Cooldowns and self.salveSpellID then ns.Cooldowns:Request(self.salveSpellID) end
    end)
end

local function CreateCooldownIcon(box)
    local frame = CreateFrame("Frame", nil, box)
    if frame.EnableMouse then frame:EnableMouse(false) end
    frame:SetAlpha(0)
    frame.texture = frame:CreateTexture(nil, "ARTWORK")
    frame.texture:SetAllPoints(frame)
    if frame.texture.SetTexCoord then frame.texture:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
    return frame
end

-- The dispel first, then each movement action that sweeps on this cell, in
-- the same order Features/AuraBinding.lua hands them their widgets.
function Box.CellCooldowns(box)
    local entries = {}
    if ns.spellID then entries[1] = { spellID = ns.spellID, cooldown = box.dispelCooldown, movement = false } end
    local sweeps = ns.Escape and ns.Escape.SweepSpellIDs and ns.Escape:SweepSpellIDs() or {}
    for index, spellID in ipairs(sweeps) do
        local cooldown = box.movementCooldowns and box.movementCooldowns[index]
        if cooldown and ns.Escape:CanSweepForUnit(spellID, box.unit) then
            entries[#entries + 1] = { spellID = spellID, cooldown = cooldown, movement = true }
        end
    end
    return entries
end

local function LayoutCooldownIcons(box, placed)
    local point = ns.db.cooldownIconPosition or "RIGHT"
    local leftward = point:find("RIGHT", 1, true) ~= nil
    local x = point:find("LEFT", 1, true) and 1 or (leftward and -1 or 0)
    local y = point:find("TOP", 1, true) and -1 or (point:find("BOTTOM", 1, true) and 1 or 0)
    for index, icon in ipairs(placed) do
        icon.frame:ClearAllPoints()
        if index == 1 then
            icon.frame:SetPoint(point, box, point, x, y)
        elseif leftward then
            icon.frame:SetPoint("RIGHT", placed[index - 1].frame, "LEFT", -1, 0)
        else
            icon.frame:SetPoint("LEFT", placed[index - 1].frame, "RIGHT", 1, 0)
        end
    end
end

local function RestoreBoxSweep(box)
    for _, icon in ipairs(box.cooldownIcons or {}) do
        icon.frame:SetAlpha(0)
        icon.frame:Hide()
        icon.mode = nil
    end
    local cooldown = box.dispelCooldown
    cooldown:ClearAllPoints()
    cooldown:SetAllPoints(box)
    cooldown:SetAlpha(1)
    for _, movement in ipairs(box.movementCooldowns or {}) do
        movement:ClearAllPoints()
        movement:SetAllPoints(box)
        movement:SetAlpha(1)
        if movement.SetDrawSwipe then movement:SetDrawSwipe(false) end
        if movement.SetDrawEdge then movement:SetDrawEdge(true) end
    end
    box.cooldownIconMode = false
    StyleCooldownText(box)
end

-- A lockout debuff such as Forbearance on this member, with its own timer.
-- `entry` is { spellID, start, duration } from Features/Lockouts.lua, or nil.
function Box.UpdateLockoutIcon(box, entry)
    local icon = box.lockoutIcon
    if not entry then
        if icon then icon:Hide() end
        return
    end
    if not icon then
        icon = CreateFrame("Frame", nil, box)
        if icon.EnableMouse then icon:EnableMouse(false) end
        icon.texture = icon:CreateTexture(nil, "ARTWORK")
        icon.texture:SetAllPoints(icon)
        if icon.texture.SetTexCoord then icon.texture:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
        icon.cooldown = CreateFrame("Cooldown", nil, icon, "CooldownFrameTemplate")
        icon.cooldown:SetAllPoints(icon)
        if icon.cooldown.SetDrawEdge then icon.cooldown:SetDrawEdge(false) end
        if icon.cooldown.SetDrawBling then icon.cooldown:SetDrawBling(false) end
        if icon.cooldown.SetReverse then icon.cooldown:SetReverse(true) end
        if icon.cooldown.SetSwipeColor then icon.cooldown:SetSwipeColor(0, 0, 0, 0.6) end
        if icon.cooldown.SetMinimumCountdownDuration then icon.cooldown:SetMinimumCountdownDuration(0) end
        if icon.cooldown.EnableMouse then icon.cooldown:EnableMouse(false) end
        box.lockoutIcon = icon
    end
    local db = ns.db
    local size = math.max(8, math.min(48, tonumber(db.lockoutIconSize) or 14))
    local point = db.lockoutIconPosition or "TOPLEFT"
    icon:SetSize(size, size)
    icon:ClearAllPoints()
    icon:SetPoint(point, box, point, 0, 0)
    -- Above the sweeps and the cooldown icons: it's the one warning on the
    -- cell that says "not this one".
    icon:SetFrameLevel((box.movementFrameLevel or (box:GetFrameLevel() + 13)) + 8)
    icon.texture:SetTexture(ns.Cooldowns.SpellTexture(entry.spellID))
    local text = icon.cooldown.GetCountdownFontString and icon.cooldown:GetCountdownFontString()
    if text then
        local fontPath = STANDARD_TEXT_FONT
        if fontPath then text:SetFont(fontPath, math.max(7, math.floor(size * 0.6 + 0.5)), "OUTLINE") end
    end
    icon.cooldown:SetCooldown(entry.start, entry.duration)
    icon:Show()
end

-- `entries` is only passed by the preview, with a fixed state per spell.
function Box.UpdateCooldownIcons(box, target, entries)
    if not box.dispelCooldown then return end
    if Box.CooldownStyle() ~= "ICON" then
        if box.cooldownIconMode then RestoreBoxSweep(box) end
        return
    end

    entries = entries or Box.CellCooldowns(box)
    local size = math.max(8, math.min(64, tonumber(ns.db.cooldownIconSize) or 16))
    box.cooldownIcons = box.cooldownIcons or {}
    local icons = {}
    for index, entry in ipairs(entries) do
        local icon = box.cooldownIcons[index] or {}
        box.cooldownIcons[index] = icon
        icon.frame = icon.frame or CreateCooldownIcon(box)
        if icon.spellID ~= entry.spellID then icon.mode = nil end
        icon.spellID = entry.spellID
        icon.forcedState = entry.state
        icon.cooldown = entry.cooldown
        icon.cooldownAlpha = true
        icon.frame.texture:SetTexture(ns.Cooldowns.SpellTexture(entry.spellID))
        icon.frame:SetSize(size, size)
        -- Just under its own sweep, which already sits above the aura fill
        -- and the name.
        icon.frame:SetFrameLevel(math.max(0, entry.cooldown:GetFrameLevel() - 1))
        icon.frame:Show()
        local cooldown = entry.cooldown
        cooldown.salveSpellID = entry.spellID
        cooldown:ClearAllPoints()
        cooldown:SetAllPoints(icon.frame)
        if entry.movement then
            if cooldown.SetDrawEdge then cooldown:SetDrawEdge(false) end
            if cooldown.SetDrawSwipe then cooldown:SetDrawSwipe(true) end
            if cooldown.SetSwipeColor then cooldown:SetSwipeColor(0, 0, 0, 0.72) end
        end
        icons[index] = icon
    end
    for index = #entries + 1, #box.cooldownIcons do
        local icon = box.cooldownIcons[index]
        icon.frame:SetAlpha(0)
        icon.frame:Hide()
        icon.mode = nil
    end
    -- An unused widget may still point at an icon it had before.
    local used = {}
    for _, entry in ipairs(entries) do used[entry.cooldown] = true end
    local widgets = { box.dispelCooldown }
    for _, movement in ipairs(box.movementCooldowns or {}) do widgets[#widgets + 1] = movement end
    for _, widget in ipairs(widgets) do
        if not used[widget] then
            widget:ClearAllPoints()
            widget:SetAllPoints(box)
            widget:SetAlpha(1)
        end
    end

    box.cooldownIconMode = true
    LayoutCooldownIcons(box, ns.Cooldowns:Arrange(icons, false, target))
    StyleCooldownText(box)
end


-- ── Tooltip ────────────────────────────────────────────────────────────────
--
-- Who you are pointing at, and what each button will do to them. The bindings
-- are configurable and the spells change with specialisation, so the tooltip is
-- built from the live binding list rather than hardcoded to "left cleanses".
--
-- ☠ Scripts are attached at CREATION. The box is a secure action button, so
--   setting scripts on it during combat would be a blocked action -- but doing
--   it once here, out of combat, is fine and never needs repeating.
local function ShowBoxTooltip(box)
    if ns.Probe then ns.Probe:NoteBoxEnter() end
    if not (ns.db and ns.db.showTooltip) then return end
    if not box.unit or not UnitExists(box.unit) then return end

    local anchor = ns.db.tooltipAnchor or "RIGHT"
    local anchors = {
        RIGHT = "ANCHOR_RIGHT",
        LEFT = "ANCHOR_LEFT",
        CURSOR = "ANCHOR_CURSOR",
    }
    GameTooltip:SetOwner(box, anchors[anchor] or "ANCHOR_RIGHT")

    -- SetUnit gives the game's own unit tooltip -- name, level, class -- and
    -- handles restricted or secret unit identity itself, which we may not.
    if ns.db.tooltipUnitInfo ~= false then
        GameTooltip:SetUnit(box.unit)
    else
        -- Keep a useful title when Blizzard's full unit section is hidden.
        -- UnitName is public unit identity, unlike private aura metadata.
        local name = UnitName and UnitName(box.unit)
        GameTooltip:SetText(name or "Group member")
    end

    local bindings = ns.Bindings and ns.Bindings:List()
    if ns.db.tooltipActions ~= false and bindings and #bindings > 0 then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Salve actions", 0.45, 0.82, 0.68)
        for _, entry in ipairs(bindings) do
            local what = ns.Bindings:Describe(entry, box.unit)
            if what then
                local spellID = ns.Bindings.SpellID and ns.Bindings:SpellID(entry)
                local action = (what:gsub(" %(automatic%)$", ""))
                GameTooltip:AddDoubleLine(
                    ns.Bindings:Label(entry.key),
                    action,
                    1, 0.82, 0.26,
                    1, 1, 1)
                if ns.db.tooltipSpellDescriptions and type(spellID) == "number"
                    and C_Spell and C_Spell.GetSpellDescription then
                    local ok, description = pcall(C_Spell.GetSpellDescription, spellID)
                    if ok and type(description) == "string" and description ~= "" then
                        GameTooltip:AddLine(description, 0.72, 0.72, 0.72, true)
                    end
                end
            end
        end
    end

    GameTooltip:Show()
end

local function HideBoxTooltip(box)
    if GameTooltip:IsOwned(box) then GameTooltip:Hide() end
end

-- Features/Range.lua re-shows the tooltip when Blizzard's debuff tooltip
-- button takes the hover from the box.
Box.ShowTooltip = ShowBoxTooltip
Box.HideTooltip = HideBoxTooltip

local function CreateVisuals(box, registerCooldown)
    -- Dim plate behind everything: what you see when the unit is clean. Use
    -- Blizzard's status-bar artwork instead of a flat colour so bare 20x20
    -- boxes still have a little depth when unit names are hidden.
    box.plate = box:CreateTexture(nil, "BACKGROUND")
    box.plate:SetAllPoints()
    box.plate:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
    box.plate:SetVertexColor(0.18, 0.18, 0.18, 1)

    -- ☠ THE FILL AND THE STACK COUNT ARE NOT CREATED HERE. Both must be built
    --   fresh as children of the button the ENGINE creates, inside
    --   initializeFrame -- the API will not accept a region that lives anywhere
    --   else, and writes after that window are refused. See Features/AuraBinding.
    --   Everything below is ours alone and the engine never touches it.

    -- The aura carrier is a child frame and therefore renders above ordinary
    -- regions on the secure box. Put a mouse-dead backdrop frame above it so
    -- Blizzard's tooltip edge remains a visible divider in both clean and
    -- dispellable states, independently of whether the name is shown.
    box.border = CreateFrame("Frame", nil, box, "BackdropTemplate")
    box.border:SetPoint("TOPLEFT", box, "TOPLEFT", -1, 1)
    box.border:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", 1, -1)
    box.border:SetFrameLevel(box:GetFrameLevel() + 12)
    box.border:SetBackdrop({
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 8,
    })
    box.border:SetBackdropBorderColor(0.55, 0.55, 0.55, 0.72)
    box.border:EnableMouse(false)
    box.border:SetAlpha(ns.db.showBorders == false and 0 or 1)

    -- Keep the spell cooldown on Salve's own frame tree, outside Blizzard's
    -- sealed aura-button subtree. Every box shows the same primary-dispel
    -- cooldown, which is useful after one debuff is removed while another unit
    -- still needs attention. The widget is mouse-dead; secure clicks continue
    -- to land on the box underneath it.
    box.dispelCooldown = CreateFrame("Cooldown", nil, box, "CooldownFrameTemplate")
    box.dispelCooldown:SetAllPoints(box)
    box.dispelCooldown:SetFrameLevel(box:GetFrameLevel() + 5)
    if box.dispelCooldown.SetDrawSwipe then box.dispelCooldown:SetDrawSwipe(true) end
    if box.dispelCooldown.SetDrawEdge then box.dispelCooldown:SetDrawEdge(false) end
    if box.dispelCooldown.SetDrawBling then box.dispelCooldown:SetDrawBling(false) end
    if box.dispelCooldown.SetSwipeColor then
        box.dispelCooldown:SetSwipeColor(0, 0, 0, 0.72)
    end
    if box.dispelCooldown.SetHideCountdownNumbers then
        box.dispelCooldown:SetHideCountdownNumbers(false)
    end
    if box.dispelCooldown.SetMinimumCountdownDuration then
        box.dispelCooldown:SetMinimumCountdownDuration(0)
    end
    if box.dispelCooldown.EnableMouse then box.dispelCooldown:EnableMouse(false) end
    if registerCooldown then
        ns.Binding:RegisterCooldown(box.dispelCooldown)
        Box.WatchCooldown(box.dispelCooldown)
    end
    StyleCooldownText(box)

    -- One thin coloured edge per selected movement action. They draw only a
    -- clock hand, so concurrent cooldowns stay distinguishable by colour.
    box.movementCooldown = Box.CreateMovementCooldown(box, 1)
    box.movementCooldowns = { box.movementCooldown }
    if registerCooldown then ns.Binding:RegisterMovementCooldown(box.movementCooldown, box) end

    -- ☠ THE NAME LIVES ON ITS OWN FRAME, NOT ON THE BOX. The engine's aura
    --   button is a CHILD frame of this box, and a child renders above every
    --   region of its parent -- so an opaque fill on that button covers a
    --   FontString drawn here. The name would vanish exactly when the box lit
    --   up, which is the one moment it matters. A child frame of our own,
    --   levelled above the engine's, is the only way to stay on top.
    --   Features/AuraBinding.lua re-asserts the level once it knows the
    --   button's.
    box.textLayer = CreateFrame("Frame", nil, box)
    box.textLayer:SetAllPoints(box)
    box.textLayer:SetFrameLevel(box:GetFrameLevel() + 10)

    box.name = box.textLayer:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    box.name:SetPoint("TOPLEFT", box, "TOPLEFT", 3, -1)
    box.name:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -3, 1)
    box.name:SetJustifyH("LEFT")
    box.name:SetJustifyV("MIDDLE")
    StyleNameText(box)

    -- The movement badge (Box.SetMovementPrompt) is created lazily: only the
    -- player's cell ever shows one.

    return box
end

function Box.Create(index, parent)
    local box = CreateFrame("Button", "SalveBox" .. index, parent,
        "SecureActionButtonTemplate")
    box:RegisterForClicks("AnyDown")

    box:HookScript("OnEnter", ShowBoxTooltip)
    box:HookScript("OnLeave", HideBoxTooltip)
    -- Attached once, out of combat. The logger records only an already-armed
    -- Salve action and its unit token; it never asks the secret aura carrier
    -- why the cell was visible.
    box:HookScript("OnClick", function(self, button)
        if ns.Probe then ns.Probe:NoteBoxClick() end
        if ns.ClickLog then ns.ClickLog:Record(self, button) end
        if ns.Lockouts then ns.Lockouts:NoteClick(self, button) end
    end)

    CreateVisuals(box, true)

    box.hl = box:CreateTexture(nil, "HIGHLIGHT")
    box.hl:SetAllPoints()
    box.hl:SetColorTexture(1, 1, 1, 0.18)

    return box
end

-- Test-mode boxes live on UIParent, not inside Settings. They deliberately use
-- the SAME Salve-owned plate, border, name and cooldown construction as the
-- secure live boxes. Only the aura fill and stack are synthetic: Blizzard's
-- AuraContainer owns those on live boxes and does not expose an API for addons
-- to inject a fake aura into it.
function Box.CreatePreview(parent)
    local box = CreateFrame("Frame", nil, parent)
    CreateVisuals(box, false)

    box.previewFill = box:CreateTexture(nil, "ARTWORK")
    box.previewFill:SetAllPoints(box)
    box.previewFill:SetColorTexture(1, 1, 1, 1)

    -- Synthetic aura artwork belongs only to non-secure preview boxes. Live
    -- icons remain owned by Blizzard's native aura binding.
    box.previewAuraLayer = CreateFrame("Frame", nil, box)
    box.previewAuraLayer:SetAllPoints(box)
    box.previewAuraLayer:SetFrameLevel(box:GetFrameLevel() + 1)
    box.previewAuraLayer:EnableMouse(false)
    box.previewDispelIcon = box.previewAuraLayer:CreateTexture(nil, "OVERLAY")
    box.previewDispelIcon:Hide()

    box.previewStack = box.textLayer:CreateFontString(nil, "OVERLAY",
        "NumberFontNormalSmall")
    box.previewStack:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -1, 0)

    return box
end

function Box.RestylePreview(box, name, classKey)
    local db = ns.db
    box.border:SetAlpha(db.showBorders == false and 0 or 1)

    box.name:SetJustifyH(db.nameJustifyH or "LEFT")
    box.name:SetJustifyV(db.nameJustifyV or "MIDDLE")
    StyleNameText(box)

    if db.showNames then
        box.name:SetText(name or "")
        local c = classKey and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classKey]
        if c then
            box.name:SetTextColor(c.r, c.g, c.b)
        else
            box.name:SetTextColor(1, 1, 1)
        end
    else
        box.name:SetText("")
    end

    local plateColour = db.useClassColours and classKey
        and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classKey]
    if plateColour then
        box.plate:SetVertexColor(plateColour.r, plateColour.g, plateColour.b, 1)
    else
        box.plate:SetVertexColor(0.18, 0.18, 0.18, 1)
    end
    box.plate:SetAlpha(db.showWhenClean and db.cleanAlpha or 0)
    StyleCooldownText(box)
end

-- Secure attributes. Out of combat only -- callers guard.
function Box.Bind(box, unit)
    box.unit = unit
    Box.SetMovementPrompt(box, false)

    box:SetAttribute("unit", unit)

    -- Any mouse button, with any modifiers. Every attribute is fixed once
    -- written, which is what keeps the box working through a fight with nothing
    -- of ours running. See Features/Bindings.lua.
    ns.Bindings:Apply(box)
end

local MOVEMENT_BADGE_FALLBACK = "Interface\\Icons\\INV_Misc_QuestionMark"

-- First corner not already claimed by the dispel-type or lockout icon.
function Box.MovementBadgePosition()
    local db = ns.db or {}
    local taken = {
        [db.dispelTypeIconPosition or "BOTTOMLEFT"] = true,
        [db.lockoutIconPosition or "TOPLEFT"] = true,
    }
    for _, corner in ipairs({ "TOPRIGHT", "TOPLEFT", "BOTTOMRIGHT", "BOTTOMLEFT" }) do
        if not taken[corner] then return corner end
    end
    return "TOPRIGHT"
end

-- Salve-owned movement badge: the movement spell's icon in a free corner,
-- with an orange edge. It's driven by safe player-state signals (loss of
-- control or a measured slow) and never reads aura metadata. It sits beside
-- the native dispel fill and icon rather than over them, so a dispel and a
-- root on the same cell both stay readable.
local function MovementBadge(box)
    local badge = box.movementBadge
    if badge then return badge end
    badge = CreateFrame("Frame", nil, box)
    if badge.EnableMouse then badge:EnableMouse(false) end
    badge.edge = badge:CreateTexture(nil, "BACKGROUND")
    badge.edge:SetPoint("TOPLEFT", badge, "TOPLEFT", -1, 1)
    badge.edge:SetPoint("BOTTOMRIGHT", badge, "BOTTOMRIGHT", 1, -1)
    badge.edge:SetColorTexture(1, 0.35, 0.04, 1)
    badge.texture = badge:CreateTexture(nil, "ARTWORK")
    badge.texture:SetAllPoints(badge)
    if badge.texture.SetTexCoord then badge.texture:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
    badge:Hide()
    box.movementBadge = badge
    return badge
end

-- `spellID` is the enabled movement spell the badge points at. The badge only
-- says "this binding may help"; a click still casts whatever the player bound
-- out of combat in Features/Bindings.lua.
function Box.SetMovementPrompt(box, active, spellID)
    if not box then return end
    if active then
        local badge = MovementBadge(box)
        local size = math.max(10, math.min(48, (tonumber(ns.db and ns.db.lockoutIconSize) or 14) + 2))
        -- A dispellable debuff matters more than being rooted, so the badge
        -- stays a corner marker: never more than half the cell, leaving the
        -- debuff colour, stacks and type icon readable (Kevin, 2026-11-10).
        local w, h = box.GetWidth and box:GetWidth() or 0, box.GetHeight and box:GetHeight() or 0
        local cell = math.min(w > 0 and w or size * 2, h > 0 and h or size * 2)
        size = math.max(8, math.min(size, math.floor(cell * 0.5)))
        local point = Box.MovementBadgePosition()
        local inset = point:find("LEFT", 1, true) and 1 or -1
        local lift = point:find("TOP", 1, true) and -1 or 1
        badge:SetSize(size, size)
        badge:ClearAllPoints()
        badge:SetPoint(point, box, point, inset, lift)
        badge:SetFrameLevel((box.movementFrameLevel or (box:GetFrameLevel() + 13)) + 9)
        local texture = spellID and ns.Cooldowns and ns.Cooldowns.SpellTexture(spellID)
        badge.texture:SetTexture(texture or MOVEMENT_BADGE_FALLBACK)
        badge.spellID = spellID
        badge:Show()
        if box.border then box.border:SetBackdropBorderColor(1, 0.35, 0.04, 1) end
    else
        if box.movementBadge then
            box.movementBadge:Hide()
            box.movementBadge.spellID = nil
        end
        if box.border then box.border:SetBackdropBorderColor(0.55, 0.55, 0.55, 0.72) end
    end
end

-- A class token that is safe to use as a table key. Restyle also runs in
-- combat, where restricted content could make the token secret.
function Box.ClassToken(unit)
    local _, class = UnitClass(unit)
    if class == nil or (issecretvalue and issecretvalue(class)) then return nil end
    return class
end

-- Name text and the clean-state dimming. Both are ours, both are safe in
-- combat, and neither reads an aura.
--
-- UnitName may itself be secret in restricted content. FontString:SetText
-- accepts secrets, so this is fine -- as long as we never compare the result.
function Box.Restyle(box)
    local db = ns.db
    box.border:SetAlpha(db.showBorders == false and 0 or 1)

    box.name:SetJustifyH(db.nameJustifyH or "LEFT")
    box.name:SetJustifyV(db.nameJustifyV or "MIDDLE")
    StyleNameText(box)

    if db.showNames and box.unit then
        box.name:SetText(UnitName(box.unit))
        local class = Box.ClassToken(box.unit)
        local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
        if c then
            box.name:SetTextColor(c.r, c.g, c.b)
        else
            box.name:SetTextColor(1, 1, 1)
        end
    else
        box.name:SetText("")
    end

    local plateColour
    if db.useClassColours and box.unit then
        local class = Box.ClassToken(box.unit)
        plateColour = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    end
    if plateColour then
        box.plate:SetVertexColor(plateColour.r, plateColour.g, plateColour.b, 1)
    else
        box.plate:SetVertexColor(0.18, 0.18, 0.18, 1)
    end

    -- The plate is ours, so its alpha is ours. The engine's fill sits above it
    -- and appears only when there is something to dispel, so this reads as
    -- "dim when clean" without anything of ours knowing whether it is.
    box.plate:SetAlpha(db.showWhenClean and db.cleanAlpha or 0)
    StyleCooldownText(box)
end
