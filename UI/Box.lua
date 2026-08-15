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

function Box.Create(index, parent)
    local box = CreateFrame("Button", "SalveBox" .. index, parent,
        "SecureActionButtonTemplate")
    box:RegisterForClicks("AnyDown")

    -- Dim plate behind everything: what you see when the unit is clean.
    box.plate = box:CreateTexture(nil, "BACKGROUND")
    box.plate:SetAllPoints()
    box.plate:SetColorTexture(0.11, 0.11, 0.11, 1)

    -- ☠ THE FILL AND THE STACK COUNT ARE NOT CREATED HERE. Both must be built
    --   fresh as children of the button the ENGINE creates, inside
    --   initializeFrame -- the API will not accept a region that lives anywhere
    --   else, and writes after that window are refused. See Features/AuraBinding.
    --   Everything below is ours alone and the engine never touches it.

    box.border = box:CreateTexture(nil, "BORDER")
    box.border:SetPoint("TOPLEFT", -1, 1)
    box.border:SetPoint("BOTTOMRIGHT", 1, -1)
    box.border:SetColorTexture(0, 0, 0, 0.9)

    box.name = box:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    box.name:SetPoint("LEFT", 3, 0)
    box.name:SetPoint("RIGHT", -3, 0)
    box.name:SetJustifyH("LEFT")

    box.hl = box:CreateTexture(nil, "HIGHLIGHT")
    box.hl:SetAllPoints()
    box.hl:SetColorTexture(1, 1, 1, 0.18)

    return box
end

-- Secure attributes. Out of combat only -- callers guard.
function Box.Bind(box, unit)
    box.unit = unit

    box:SetAttribute("unit", unit)

    -- Which spell sits on which button is the user's call; ns.ResolveClicks
    -- applies their choice, falling back to detection where they have not made
    -- one. Both attributes are fixed once written -- that is what keeps the box
    -- working in combat without anything of ours running.
    local left, rightType, right = ns.ResolveClicks()

    box:SetAttribute("type1", "spell")
    box:SetAttribute("spell1", left)

    if rightType == "spell" then
        box:SetAttribute("type2", "spell")
        box:SetAttribute("spell2", right)
    elseif rightType == "target" then
        box:SetAttribute("type2", "target")
        box:SetAttribute("spell2", nil)
    else
        box:SetAttribute("type2", nil)
        box:SetAttribute("spell2", nil)
    end
end

-- Name text and the clean-state dimming. Both are ours, both are safe in
-- combat, and neither reads an aura.
--
-- UnitName may itself be secret in restricted content. FontString:SetText
-- accepts secrets, so this is fine -- as long as we never compare the result.
function Box.Restyle(box)
    local db = ns.db

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

    -- The plate is ours, so its alpha is ours. The engine's fill sits above it
    -- and appears only when there is something to dispel, so this reads as
    -- "dim when clean" without anything of ours knowing whether it is.
    box.plate:SetAlpha(db.showWhenClean and db.cleanAlpha or 0)
end
