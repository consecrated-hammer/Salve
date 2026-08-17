local addonName, ns = ...

-- ============================================================
-- Event routing
-- ============================================================
-- Note what is NOT here in normal operation: UNIT_AURA. Salve does not react to
-- aura changes -- the engine drives every lit box directly. The cooldown path
-- only forwards the dispel's opaque Duration object into Blizzard cooldown
-- widgets; it never reads an aura or branches on secret combat state.
--
-- UNIT_AURA uses dedicated per-unit listener frames ONLY while opt-in learn
-- mode is on. ns.Sound:SetLearning owns those registrations.

local frame = CreateFrame("Frame", "SalveEventFrame")

frame:SetScript("OnEvent", function(_, event, arg1, arg2, arg3)
    if event == "ADDON_LOADED" then
        if arg1 ~= addonName then return end
        ns.InitConfig()
        if ns.db.showStartupMessage then
            ns.Print("loaded — version " .. tostring(ns.VERSION)
                .. ". Type |cffffd100/salve|r for settings.")
        end
        ns.Sound:DiscoverModules()
        -- ☠ Only now is ns.db real. The option pages queued themselves at file
        --   scope precisely so they could be built here instead of against nil.
        ns.Options.BuildAll()
        frame:UnregisterEvent("ADDON_LOADED")

    elseif event == "PLAYER_LOGIN" then
        ns.UpdateDispelSpell()
        ns.Escape:Update()
        if ns.Options.RefreshDispel then ns.Options.RefreshDispel() end
        ns.Panel:Create()
        -- Broker first: it is a no-op without LibStub, and it never affects the
        -- minimap button, which Salve always owns. See UI/Broker.lua.
        ns.Broker:Create()
        ns.Minimap:Create()
        ns.Minimap:Update()
        ns.RequestRebuild()

    elseif event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
        ns.Sound:ActivateCurrentInstance()
        if ns.Options.RefreshTroubleshooting then ns.Options.RefreshTroubleshooting() end
        ns.RequestRebuild()

    elseif event == "GROUP_ROSTER_UPDATE" then
        ns.Sound:OnRosterChanged()
        if ns.Options.RefreshTroubleshooting then ns.Options.RefreshTroubleshooting() end
        ns.RequestRebuild()

    elseif event == "PLAYER_SPECIALIZATION_CHANGED"
        or event == "SPELLS_CHANGED" then
        if ns.UpdateDispelSpell() then
            if ns.Options.RefreshDispel then ns.Options.RefreshDispel() end
            ns.Escape:Update()
            ns.Sound:OnDispelChanged()
            if ns.Options.RefreshTroubleshooting then ns.Options.RefreshTroubleshooting() end
            ns.RequestRebuild()
        end

    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        -- ☠ THE SWEEP IS DRIVEN BY CASTS, NOT BY SPELL_UPDATE_COOLDOWN.
        --   That event fires on EVERY global cooldown, and the duration object
        --   it hands back during a GCD *is* the GCD -- so refreshing on it made
        --   every box sweep constantly for a second and a half, whatever you
        --   cast. The sweep became noise rather than information.
        --
        --   Refreshing only when a DISPEL actually goes off means the swipe
        --   shows the dispel's own cooldown and nothing else. The Duration
        --   object animates itself to completion, so there is nothing to clear.
        if arg1 == "player" and ns.Bindings:IsDispelSpell(arg3) then
            ns.Binding:RefreshCooldowns()
        end

    elseif event == "SPELL_UPDATE_CHARGES" then
        ns.Binding:RefreshCooldowns()

    elseif event == "LOSS_OF_CONTROL_ADDED" then
        -- Unlike aura data, the loss-of-control API supplies the ROOT/SNARE
        -- classification and spell ID. This captures movement effects during a
        -- pull without any manual command.
        local unit, effectIndex = arg1, arg2
        -- Older clients sent only an index and exposed player-only data.
        if type(unit) == "number" and effectIndex == nil then
            effectIndex, unit = unit, "player"
        end
        ns.Escape:CaptureLossOfControl(unit, effectIndex)

    elseif event == "PLAYER_REGEN_ENABLED" then
        -- ☠ Release a drag that crossed into combat FIRST. Until this runs the
        --   panel is still following the cursor, and a rebuild would anchor
        --   boxes against a frame that is still moving.
        if ns.pendingDragStop then ns.Handle:Release() end
        ns.Sound:FlushPendingLearning()
        ns.Sound:FlushPending()
        ns.FlushPending()
        -- A reset requested mid-fight was deferred rather than erroring.
        if ns.deferredPosition then ns.Panel:ApplyPosition() end
    end
end)

for _, e in ipairs({
    "ADDON_LOADED",
    "PLAYER_LOGIN",
    "PLAYER_ENTERING_WORLD",
    "ZONE_CHANGED_NEW_AREA",
    "GROUP_ROSTER_UPDATE",
    "PLAYER_SPECIALIZATION_CHANGED",
    "SPELLS_CHANGED",
    -- ☠ Deliberately NOT SPELL_UPDATE_COOLDOWN: it fires on every GCD. See the
    --   UNIT_SPELLCAST_SUCCEEDED branch above.
    "SPELL_UPDATE_CHARGES",
    "LOSS_OF_CONTROL_ADDED",
    "PLAYER_REGEN_ENABLED",
}) do
    frame:RegisterEvent(e)
end

-- Only the player's own casts matter, so filter at registration rather than
-- taking every group member's cast and discarding it in Lua.
if frame.RegisterUnitEvent then
    frame:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
else
    frame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
end
