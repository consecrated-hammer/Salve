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

local function alertPlayerMovement(movement, isVerifiedMovement)
    if ns.db and ns.db.movementAlertsEnabled == false then return end
    if movement and movement.kind == "BLOCKED" then
        if ns.Panel then ns.Panel:SetMovementPrompt(nil, false) end
        if ns.MovementAlert and ns.MovementAlert.Clear then ns.MovementAlert:Clear() end
        return
    end
    local detector = ns.MovementDetection
    local blocked = detector and detector.ControlBlockReason and detector:ControlBlockReason()
    if blocked or (movement and movement.kind == "CLEAR") then
        if ns.Panel then ns.Panel:SetMovementPrompt(nil, false) end
        if blocked then
            detector.controlBlocked, detector.alerted = true, false
            detector.lastStatus = blocked
            if ns.MovementAlert and ns.MovementAlert.Clear then ns.MovementAlert:Clear() end
        end
        return
    end
    -- Only the speed detector emits kind SLOW. A matching movement ability
    -- does not prove an inferred speed drop is curable, so it is opt-in.
    local inferred = movement and movement.kind == "SLOW" and not isVerifiedMovement
    if inferred and not (ns.db and ns.db.inferredSlowAlertsEnabled) then return end
    local spell = ns.Escape:MovementAlertSpell("player", movement)
    local actionable = isVerifiedMovement and spell and movement
        and (movement.kind == "SLOW" or movement.locType == "ROOT"
            or movement.locType == "SNARE")
    -- Inferred slows stay silent even when the player opts into their cue.
    if actionable then
        ns.Sound:PlayMovementWarning()
    end
    if spell and ns.MovementAlert then
        ns.MovementAlert:Notify("player", movement, spell)
    end
    -- An explicit movement alert already describes the current impairment.
    -- Do not replace it with the speed heuristic's generic SLOWED message.
    if spell and detector and movement and movement.locType then detector.alerted = true end
    -- A speed drop is only an inference: terrain, transfers and client-side
    -- movement-state changes can produce one without a removable impairment.
    -- The orange player-cell cue needs the explicit loss-of-control signal or
    -- the player's Include inferred slows opt-in. The cue only points at the
    -- existing secure mouse binding; it never rewrites a click.
    if (actionable or (inferred and spell)) and ns.Panel then
        ns.Panel:SetMovementPrompt(spell, true)
    end
end

local movementRecheckPending = false
local pendingMovementKeys, recheckAllMovement = {}, false
local function movementKey(movement)
    -- Missing IDs cannot identify the same transient effect on a later tick.
    if type(movement.spellID) ~= "number" then return nil end
    return tostring(movement.spellID) .. ":" .. tostring(movement.locType)
end
local function scheduleMovementRecheck(addedMovement)
    if ns.db and ns.db.movementAlertsEnabled == false then return end
    if addedMovement then
        local key = movementKey(addedMovement)
        if not key then return end
        pendingMovementKeys[key] = true
    else
        recheckAllMovement = true
    end
    if movementRecheckPending then return end
    movementRecheckPending = true
    -- Coalesce synchronous additions so a root and simultaneous fear/stun are
    -- evaluated together, and discard roots that expired before this tick.
    C_Timer.After(0, function()
        movementRecheckPending = false
        local keys, all = pendingMovementKeys, recheckAllMovement
        pendingMovementKeys, recheckAllMovement = {}, false
        if ns.db and ns.db.movementAlertsEnabled == false then return end
        local api = C_LossOfControl
        if not (api and api.GetActiveLossOfControlDataCount) then return end
        local ok, count = pcall(api.GetActiveLossOfControlDataCount)
        if not ok or (issecretvalue and issecretvalue(count)) or type(count) ~= "number"
            or count ~= count or count < 0 or count > 64 then return end
        local chosen, verified
        for index = 1, count do
            local _, isVerified, movement = ns.Escape:CaptureLossOfControl("player", index)
            if movement and (all or keys[movementKey(movement)]) and (not chosen or isVerified) then
                chosen, verified = movement, isVerified
            end
        end
        if chosen then alertPlayerMovement(chosen, verified) end
    end)
end

frame:SetScript("OnEvent", function(_, event, arg1, arg2, arg3)
    if event == "ADDON_LOADED" then
        if arg1 ~= addonName then return end
        ns.InitConfig()
        -- HammerCore adopts the old startup, minimap and settings-position
        -- keys, prints the login line and creates the minimap button.
        ns.HammerCore:Start()
        frame:UnregisterEvent("ADDON_LOADED")

    elseif event == "PLAYER_LOGIN" then
        ns.UpdateDispelSpell()
        if ns.PersonalDispel then ns.PersonalDispel:Update() end
        ns.Escape:Update()
        if ns.Options.RefreshDispel then ns.Options.RefreshDispel() end
        ns.Panel:Create()
        -- Broker first: it is a no-op without LibStub, and it never affects the
        -- minimap button, which Salve always owns. See UI/Broker.lua.
        ns.Broker:Create()
        ns.RequestRebuild()

    elseif event == "PLAYER_LEAVING_WORLD" then
        -- Dungeon exits can report a zero/transfer movement speed before the
        -- destination's PLAYER_ENTERING_WORLD event. Reset before that sample
        -- is ever compared against the old zone's reference speed.
        if ns.MovementDetection then ns.MovementDetection:Reset() end
        if ns.Panel then ns.Panel:SetMovementPrompt(nil, false) end

    elseif event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
        if ns.MovementDetection then ns.MovementDetection:Reset() end
        if ns.Panel then ns.Panel:SetMovementPrompt(nil, false) end
        ns.Sound:ActivateCurrentInstance()
        if ns.SelfAlert and ns.SelfAlert.Update then ns.SelfAlert:Update() end
        if ns.Options.RefreshTroubleshooting then ns.Options.RefreshTroubleshooting() end
        ns.RequestRebuild()

    elseif event == "GROUP_ROSTER_UPDATE" then
        ns.Sound:OnRosterChanged()
        if ns.Options.RefreshTroubleshooting then ns.Options.RefreshTroubleshooting() end
        ns.RequestRebuild()

    elseif event == "PLAYER_SPECIALIZATION_CHANGED"
        or event == "SPELLS_CHANGED"
        or (event == "UNIT_PET" and arg1 == "player") then
        local dispelChanged = ns.UpdateDispelSpell()
        local personalChanged = ns.PersonalDispel and ns.PersonalDispel:Update()
        local escapeChanged = ns.Escape:Update()
        if dispelChanged or escapeChanged or personalChanged then
            if ns.Options.RefreshDispel then ns.Options.RefreshDispel() end
            if dispelChanged then
                ns.Sound:OnDispelChanged()
            end
            if ns.Options.RefreshTroubleshooting then ns.Options.RefreshTroubleshooting() end
            ns.RequestRebuild()
        end
        if ns.SelfAlert and ns.SelfAlert.Update then ns.SelfAlert:Update() end

    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        -- Only a successful player dispel should start the sweep. Refreshing on
        -- SPELL_UPDATE_COOLDOWN makes every ordinary cast paint the GCD over
        -- the boxes. Do not refresh synchronously here either: Retail can fire
        -- UNIT_SPELLCAST_SUCCEEDED before the dispel's own cooldown has replaced
        -- the GCD-shaped duration object. One event-loop tick lets Blizzard
        -- commit the real Cleanse/Purify/etc. cooldown first.
        local movementSpellID = ns.Binding:ObserveMovementCast(arg1, arg3)
        if movementSpellID then
            if ns.MovementDetection then
                alertPlayerMovement(ns.MovementDetection:AcknowledgeRemoval(), false)
            end
            C_Timer.After(0, function()
                ns.Binding:RefreshMovementCooldowns("deferred player movement removal",
                    movementSpellID)
            end)
        elseif ns.Binding:ObserveDispelCast(arg1, arg3) then
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
        if unit ~= "player" then return end
        local _, _, movement = ns.Escape:CaptureLossOfControl(unit, effectIndex)
        -- Clear stale prompts immediately when control is lost, but wait one
        -- tick before issuing a new action instruction.
        alertPlayerMovement(nil, false)
        if movement then scheduleMovementRecheck(movement) end

    elseif event == "PLAYER_REGEN_DISABLED" then
        if ns.MovementAlert and ns.MovementAlert.StopPreview then ns.MovementAlert:StopPreview() end
        -- Test cells are intentionally non-secure, but a preview must never
        -- cover the real clickable panel once combat begins.
        if ns.Preview then ns.Preview:Stop() end

    elseif event == "ENCOUNTER_END" then
        -- IsEncounterInProgress can remain true until the event finishes.
        -- Retry on the next tick; if ordinary combat lockdown is still active,
        -- RequestRebuild leaves the work queued for PLAYER_REGEN_ENABLED.
        C_Timer.After(0, function()
            ns.Sound:FlushPending()
            ns.FlushPending()
        end)

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

frame:SetScript("OnUpdate", function(_, elapsed)
    local detector = ns.MovementDetection
    local movement = detector and detector:Sample(elapsed)
    if movement and movement.kind == "RECHECK" then
        scheduleMovementRecheck()
    elseif movement then
        alertPlayerMovement(movement, false)
    end
end)

for _, e in ipairs({
    "ADDON_LOADED",
    "PLAYER_LOGIN",
    "PLAYER_LEAVING_WORLD",
    "PLAYER_ENTERING_WORLD",
    "ZONE_CHANGED_NEW_AREA",
    "GROUP_ROSTER_UPDATE",
    "PLAYER_SPECIALIZATION_CHANGED",
    "SPELLS_CHANGED",
    -- Deliberately not SPELL_UPDATE_COOLDOWN: it fires on every GCD. The
    -- player-only UNIT_SPELLCAST_SUCCEEDED registration below is the gate.
    "LOSS_OF_CONTROL_ADDED",
    "ENCOUNTER_END",
    "PLAYER_REGEN_DISABLED",
    "PLAYER_REGEN_ENABLED",
}) do
    frame:RegisterEvent(e)
end

-- Filter at registration so group members' casts never enter Lua. The handler
-- then narrows this further to Salve's known dispel spell IDs.
if frame.RegisterUnitEvent then
    frame:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
    -- Warlock's Command Demon can become Singe Magic only while an Imp is
    -- active. Filter at registration: other players' pets cannot affect this
    -- character's armed dispel or justify a secure rebuild.
    frame:RegisterUnitEvent("UNIT_PET", "player")
else
    frame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
    frame:RegisterEvent("UNIT_PET")
end
