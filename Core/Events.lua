local addonName, ns = ...

-- ============================================================
-- Event routing
-- ============================================================
-- Note what is NOT here: UNIT_AURA. Salve does not listen for aura changes,
-- because it never reacts to them -- the engine drives every lit box directly.
-- The only things that move us are the roster changing, the spec changing, and
-- combat ending with work queued.

local frame = CreateFrame("Frame", "SalveEventFrame")

frame:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 ~= addonName then return end
        ns.InitConfig()
        -- ☠ Only now is ns.db real. The option pages queued themselves at file
        --   scope precisely so they could be built here instead of against nil.
        ns.Options.BuildAll()
        frame:UnregisterEvent("ADDON_LOADED")

    elseif event == "PLAYER_LOGIN" then
        ns.UpdateDispelSpell()
        ns.Panel:Create()
        -- Broker first: it is a no-op without LibStub, and it never affects the
        -- minimap button, which Salve always owns. See UI/Broker.lua.
        ns.Broker:Create()
        ns.Minimap:Create()
        ns.Minimap:Update()
        ns.RequestRebuild()

    elseif event == "PLAYER_ENTERING_WORLD"
        or event == "GROUP_ROSTER_UPDATE" then
        ns.RequestRebuild()

    elseif event == "PLAYER_SPECIALIZATION_CHANGED"
        or event == "SPELLS_CHANGED"
        or event == "LEARNED_SPELL_IN_TAB" then
        if ns.UpdateDispelSpell() then
            ns.RequestRebuild()
        end

    elseif event == "PLAYER_REGEN_ENABLED" then
        -- ☠ Release a drag that crossed into combat FIRST. Until this runs the
        --   panel is still following the cursor, and a rebuild would anchor
        --   boxes against a frame that is still moving.
        if ns.pendingDragStop then ns.Handle:Release() end
        ns.FlushPending()
        -- A reset requested mid-fight was deferred rather than erroring.
        if ns.deferredPosition then ns.Panel:ApplyPosition() end
    end
end)

for _, e in ipairs({
    "ADDON_LOADED",
    "PLAYER_LOGIN",
    "PLAYER_ENTERING_WORLD",
    "GROUP_ROSTER_UPDATE",
    "PLAYER_SPECIALIZATION_CHANGED",
    "SPELLS_CHANGED",
    "LEARNED_SPELL_IN_TAB",
    "PLAYER_REGEN_ENABLED",
}) do
    frame:RegisterEvent(e)
end
