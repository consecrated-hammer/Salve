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
    description = "Version, credits, and questionable medical advice.",
}, function(panel, y)
    local info = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    info:SetPoint("TOPLEFT", 16, y)
    info:SetWidth(520)
    info:SetJustifyH("LEFT")
    info:SetText(table.concat({
        "|cffffd100Version|r  " .. tostring(ns.VERSION or "unknown"),
        "|cffffd100Released|r  " .. tostring(ns.GetMetadata("X-ReleaseDate") or "unknown"),
        "|cffffd100Author|r  " .. tostring(ns.GetMetadata("Author") or "unknown"),
        "|cffffd100Licence|r  " .. tostring(ns.GetMetadata("X-License") or "GPL-3.0"),
        "|cffffd100CurseForge|r  " .. tostring(ns.GetMetadata("X-CurseForge") or ""),
        "|cffffd100Source|r  " .. tostring(ns.GetMetadata("X-Website") or ""),
    }, "\n"))
    y = y - 114

    local credit = panel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    credit:SetPoint("TOPLEFT", 16, y)
    credit:SetWidth(520)
    credit:SetJustifyH("LEFT")
    credit:SetText("Decursive alert sound by John Wellesz, used under GPL v3-or-later.")
    y = y - 36

    local tip = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    tip:SetPoint("TOPLEFT", 16, y)
    tip:SetWidth(520)
    tip:SetJustifyH("LEFT")
    local lastTip
    local function showTip()
        local nextTip
        repeat nextTip = math.random(#tips) until #tips == 1 or nextTip ~= lastTip
        lastTip = nextTip
        tip:SetText("|cffffd100Tip:|r " .. tips[nextTip])
    end
    panel.salveRefresh[#panel.salveRefresh + 1] = showTip
    y = y - 44

    local apply = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    apply:SetSize(176, 44)
    apply:SetPoint("TOPLEFT", 16, y)
    apply:SetText("")
    local applyIcon = apply:CreateTexture(nil, "ARTWORK")
    applyIcon:SetSize(32, 32)
    applyIcon:SetPoint("LEFT", 8, 0)
    applyIcon:SetTexture("Interface\\AddOns\\Salve\\Textures\\SalveTransparent")
    local applyText = apply:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    applyText:SetPoint("LEFT", applyIcon, "RIGHT", 10, 0)
    applyText:SetText("Apply Salve")
    O.AttachHint(apply, "Apply Salve", "Clicking this has no effect. Mostly.")
    apply:SetScript("OnClick", function()
        showTip()
        if ns.Sound:Test(true) then
            ns.Print(applicationLines[math.random(#applicationLines)])
        end
    end)
    return y - 56
end)
