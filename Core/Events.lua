local addonName, ns = ...

-- ============================================================
-- Event routing
-- ============================================================
-- Note what is NOT here in normal operation: UNIT_AURA. Salve does not react to
-- aura changes -- the engine drives every lit box directly -- so nothing of ours
-- runs during a fight. The only things that move us are the roster changing, the
-- spec changing, and combat ending with work queued.
--
-- UNIT_AURA is registered ONLY while learn mode is on, purely to harvest spell
-- IDs for the companion addon. ns.Sound:ToggleLearn owns that registration.

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
        ns.Sound:Apply()
        -- Learn mode defaults ON, so the listener has to be installed here as
        -- well as by the slash command.
        if ns.db.learnMode then frame:RegisterEvent("UNIT_AURA") end
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

    elseif event == "UNIT_AURA" then
        -- ☠ Only ever registered while learn mode is on. Salve's normal
        --   operation has NO aura event handler, and that must stay true --
        --   it is why nothing of ours runs during a fight.
        ns.Sound:Learn(arg1)

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
