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
    local point = CooldownPoint(ns.db and ns.db.cooldownJustifyH,
        ns.db and ns.db.cooldownJustifyV)
    local x = point:find("LEFT", 1, true) and 3
        or (point:find("RIGHT", 1, true) and -3 or 0)
    local y = point:find("TOP", 1, true) and -1
        or (point:find("BOTTOM", 1, true) and 1 or 0)
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

function Box.Create(index, parent)
    local box = CreateFrame("Button", "SalveBox" .. index, parent,
        "SecureActionButtonTemplate")
    box:RegisterForClicks("AnyDown")

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
    ns.Binding:RegisterCooldown(box.dispelCooldown)
    StyleCooldownText(box)

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

    box.hl = box:CreateTexture(nil, "HIGHLIGHT")
    box.hl:SetAllPoints()
    box.hl:SetColorTexture(1, 1, 1, 0.18)

    return box
end

-- Secure attributes. Out of combat only -- callers guard.
function Box.Bind(box, unit)
    box.unit = unit

    box:SetAttribute("unit", unit)

    -- Any mouse button, with any modifiers. Every attribute is fixed once
    -- written, which is what keeps the box working through a fight with nothing
    -- of ours running. See Features/Bindings.lua.
    ns.Bindings:Apply(box)
end

-- Name text and the clean-state dimming. Both are ours, both are safe in
-- combat, and neither reads an aura.
--
-- UnitName may itself be secret in restricted content. FontString:SetText
-- accepts secrets, so this is fine -- as long as we never compare the result.
function Box.Restyle(box)
    local db = ns.db

    box.name:SetJustifyH(db.nameJustifyH or "LEFT")
    box.name:SetJustifyV(db.nameJustifyV or "MIDDLE")
    StyleNameText(box)

    if db.showNames and box.unit then
        box.name:SetText(UnitName(box.unit))
        local _, class = UnitClass(box.unit)
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
        local _, class = UnitClass(box.unit)
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
