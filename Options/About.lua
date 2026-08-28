local addonName, ns = ...
local O = ns.Options

local tips = {
    "For external use only. Side effects may include fewer purple swirls.",
    "If it lights up, click it.",
    "Drag the gold handle. The cells have important clicking to do.",
    "Master sound still works when sound effects are muted.",
    "Aura learning quietly fills the gaps. On purpose.",
    "Purple swirl? Salve first, questions later.",
    "A glowing cell is not a suggestion.",
    "One click removes a debuff. Repeated clicks express concern.",
    "A dispel on cooldown is not ignoring you. It is thinking.",
    "Side effects may include suspiciously clean raid frames.",
    "If nothing lights up, congratulations. Or run diagnostics.",
    "Apply directly to affected party members. Avoid eyes and damage meters.",
    "The raid leader said 'dispel'. This is your moment.",
    "If everyone is purple, start with yourself. You are holding the mouse.",
    "Salve contains no aloe. The lawyers insisted.",
    "Not tested on murlocs. They would not sign the consent form.",
    "Keep out of reach of DPS. They will bind it to Heroism.",
    "The gold handle is not loot. Please stop rolling Need.",
    "If the tank asks who dispelled it, look professionally innocent.",
    "The square knows what it did.",
    "Cleanse responsibly. Salve does not judge your mouse-button choices.",
    "Follower NPCs also deserve healthcare. Probably.",
    "Do not use on enrage effects. That is a differently shaped problem.",
    "Eight seconds is plenty of time to decide who gets the next dispel.",
    "Hovering reveals tooltips. Staring intensely does not.",
    "Lua arrays start at 1. Zero did not make the raid roster.",
    "There are two hard problems in addon development: naming things, cache invalidation, and off-by-one errors.",
}

local applicationLines = {
    "You apply Salve. Much better.",
    "You apply Salve. The options feel cleaner already.",
    "You apply Salve. No raid members were harmed.",
    "You apply Salve. The bottle makes a reassuring little noise.",
    "You apply Salve. Somewhere, a purple swirl feels nervous.",
    "You apply Salve. The tooltip recommends another click.",
}

O.NewPage({
    name = "About",
    title = "About",
    group = "REFERENCE",
    description = "Version, credits, and questionable medical advice.",
}, function(panel, y)
    local function card(height)
        local frame = CreateFrame("Frame", nil, panel, "BackdropTemplate")
        frame:SetPoint("TOPLEFT", 16, y)
        frame:SetSize(540, height)
        frame:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
        })
        frame:SetBackdropColor(unpack(O.theme.raised))
        frame:SetBackdropBorderColor(unpack(O.theme.edge))
        y = y - height - 14
        return frame
    end

    local label = panel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    label:SetPoint("TOPLEFT", 16, y)
    label:SetText("ABOUT")
    label:SetTextColor(unpack(O.theme.muted))
    y = y - 22

    local labelCard = card(72)
    local info = labelCard:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    info:SetPoint("TOPLEFT", 12, -12)
    info:SetWidth(516)
    info:SetJustifyH("LEFT")
    info:SetText(table.concat({
        "|cffffd100Version|r  " .. tostring(ns.VERSION or "unknown")
            .. "    |cffffd100Released|r  " .. tostring(ns.GetMetadata("X-ReleaseDate") or "unknown"),
        "|cffffd100Author|r  " .. tostring(ns.GetMetadata("Author") or "unknown")
            .. "    |cffffd100Licence|r  " .. tostring(ns.GetMetadata("X-License") or "GPL-3.0"),
        "|cffffd100CurseForge|r  " .. tostring(ns.GetMetadata("X-CurseForge") or ""),
        "|cffffd100Source|r  " .. tostring(ns.GetMetadata("X-Website") or ""),
    }, "\n"))

    local noteCard = card(120)
    local noteHeading = noteCard:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    noteHeading:SetPoint("TOPLEFT", 12, -10)
    noteHeading:SetText("PRACTITIONER'S NOTE")
    noteHeading:SetTextColor(unpack(O.theme.accent))
    local tip = noteCard:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    tip:SetPoint("TOPLEFT", 12, -31)
    tip:SetWidth(510)
    tip:SetJustifyH("LEFT")
    local lastTip
    local function showTip()
        local nextTip
        repeat nextTip = math.random(#tips) until #tips == 1 or nextTip ~= lastTip
        lastTip = nextTip
        tip:SetText(tips[nextTip])
    end
    panel.salveRefresh[#panel.salveRefresh + 1] = showTip
    local apply = CreateFrame("Button", nil, noteCard, "UIPanelButtonTemplate")
    apply:SetSize(174, 54)
    apply:SetPoint("BOTTOMLEFT", 12, 10)
    apply:SetText("Apply Salve")
    local applyIcon = apply:CreateTexture(nil, "ARTWORK")
    applyIcon:SetSize(32, 32)
    applyIcon:SetPoint("LEFT", 6, 0)
    applyIcon:SetTexture("Interface\\AddOns\\Salve\\Textures\\SalveTransparent")
    applyIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    if apply.Text then
        apply.Text:ClearAllPoints()
        apply.Text:SetPoint("CENTER", 8, 0)
    end
    O.AttachHint(apply, "Apply Salve", "Applies a ceremonial, entirely non-medical coat of Salve.")
    apply:SetScript("OnClick", function()
        showTip()
        if ns.Sound and ns.Sound.Test then ns.Sound:Test(true) end
        ns.Print(applicationLines[math.random(#applicationLines)])
    end)
    local credit = panel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    credit:SetPoint("TOPLEFT", 16, y)
    credit:SetText("Decursive alert sound by John Wellesz, used under GPL v3-or-later.")
    return y - 24
end)
