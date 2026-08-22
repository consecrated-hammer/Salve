local addonName, ns = ...

-- ============================================================
-- Event routing
-- ============================================================
-- Salve's visible dispel state never reacts to UNIT_AURA: the engine drives
-- every lit box directly. Dedicated per-unit listeners observe only readable
-- metadata for the always-on, location-scoped learning catalogue. The
-- cooldown path
-- only forwards the dispel's opaque Duration object into Blizzard cooldown
-- widgets; it never reads an aura or branches on secret combat state.
--
-- UNIT_AURA uses dedicated per-unit listener frames owned by ns.Sound.

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
        local dispelChanged = ns.UpdateDispelSpell()
        local escapeChanged = ns.Escape:Update()
        if dispelChanged or escapeChanged then
            if ns.Options.RefreshDispel then ns.Options.RefreshDispel() end
            if dispelChanged then
                ns.Sound:OnDispelChanged()
            end
            if ns.Options.RefreshTroubleshooting then ns.Options.RefreshTroubleshooting() end
            ns.RequestRebuild()
        end

    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        -- Only a successful player dispel should start the sweep. Refreshing on
        -- SPELL_UPDATE_COOLDOWN makes every ordinary cast paint the GCD over
        -- the boxes. Do not refresh synchronously here either: Retail can fire
        -- UNIT_SPELLCAST_SUCCEEDED before the dispel's own cooldown has replaced
        -- the GCD-shaped duration object. One event-loop tick lets Blizzard
        -- commit the real Cleanse/Purify/etc. cooldown first.
        if ns.Binding:ObserveDispelCast(arg1, arg3) then
            C_Timer.After(0, function()
                ns.Binding:RefreshCooldowns("deferred player dispel")
            end)
        end

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

    elseif event == "PLAYER_REGEN_DISABLED" then
        -- Test cells are intentionally non-secure, but a preview must never
        -- cover the real clickable panel once combat begins.
        if ns.Preview then ns.Preview:Stop() end

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
    -- Deliberately not SPELL_UPDATE_COOLDOWN: it fires on every GCD. The
    -- player-only UNIT_SPELLCAST_SUCCEEDED registration below is the gate.
    "LOSS_OF_CONTROL_ADDED",
    "PLAYER_REGEN_DISABLED",
    "PLAYER_REGEN_ENABLED",
}) do
    frame:RegisterEvent(e)
end

-- Filter at registration so group members' casts never enter Lua. The handler
-- then narrows this further to Salve's known dispel spell IDs.
if frame.RegisterUnitEvent then
    frame:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
else
    frame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
end
