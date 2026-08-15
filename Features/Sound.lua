local addonName, ns = ...

-- ============================================================
-- The affliction alert  ⚠ EXPERIMENTAL
-- ============================================================
-- Decursive played a sound the moment something dispellable landed. Doing the
-- same on 12.1 is awkward, because the obvious API cannot express what we need.
--
-- WHY NOT THE NATIVE SOUND API. C_UnitAuras.AddAuraSound(trigger, {unitToken,
-- spellID, soundFileName, outputChannel}) is real, read-free, and exactly the
-- right shape -- except it is keyed PER SPELL ID. Salve never knows the spell
-- list; the whole design is "let the engine decide what is dispellable". Using
-- it would mean a hand-maintained database of every dispellable debuff in the
-- game, registered per unit across 40 units. That is the baggage we deleted.
--
-- WHAT WE DO INSTEAD. The engine already owns our alert holder's Shown aspect
-- and calls SetShown on it when a matching aura appears. SetShown fires OnShow.
-- So OnShow IS the "something dispellable landed" event -- no aura read, no
-- comparison, no spell list.
--
-- ☠ THIS IS UNVERIFIED. Two things could sink it: the setter may reject a Frame
--   where it wants a Texture, and running tainted Lua from an engine-driven
--   callback may not be legal. `/salve probe` reports whether the hook has ever
--   actually fired. Default OFF until it has.

ns.Sound = {}
local Sound = ns.Sound

local ALERT = "Interface\\AddOns\\Salve\\Sounds\\AfflictionAlert.ogg"

-- Diagnostics for /salve probe.
Sound.hookInstalled = false
Sound.fireCount     = 0

-- Suppression window. Binding a slot fires OnShow for auras that are ALREADY
-- present, so a fresh pull or a /reload mid-fight would machine-gun the alert.
-- Everything inside this window after a rebuild is swallowed.
local SETTLE = 1.0
local settleUntil = 0

function Sound:Settle()
    settleUntil = GetTime() + SETTLE
end

local lastPlayed = 0

local function play()
    if not ns.db.soundEnabled then return end

    local now = GetTime()
    if now < settleUntil then return end
    if now - lastPlayed < (ns.db.soundThrottle or 2) then return end

    lastPlayed = now
    Sound.fireCount = Sound.fireCount + 1
    PlaySoundFile(ALERT, ns.db.soundChannel or "Master")
end

-- ☠ HOOKING THE ENGINE'S BUTTON DIRECTLY DOES NOT WORK. Measured in game on
--   2026-08-15: HookScript("OnShow") on the button returned by initializeFrame
--   is REFUSED -- "/salve probe" reported "not installed, 2 rejected", one per
--   button. The engine seals that button against tainted script attachment.
--
-- So we attach to a frame of OUR OWN instead, created as a child of the button
-- inside initializeFrame (region creation there is allowed, which is how the
-- fill texture gets built). A child's OnShow fires when its parent becomes
-- visible, so the engine showing the button still reaches us -- but the script
-- lives on a frame the engine has no claim over.
--
-- ⚠ Also unproven. OnUpdate and animation drivers are known not to tick inside
--   the button subtree (onUpdateMode=disabled propagates), and OnShow may turn
--   out to be suppressed the same way. The probe counts firings; the sound
--   stays off by default until it reports a non-zero count.
function Sound:Hook(button)
    if button.salveAlert then return end

    local ok, alert = pcall(CreateFrame, "Frame", nil, button)
    if not ok or not alert then
        Sound.hookFailures = (Sound.hookFailures or 0) + 1
        return
    end

    -- Must be shown in its own right, or the parent becoming visible will not
    -- produce an OnShow on it.
    alert:SetSize(1, 1)
    alert:SetPoint("TOPLEFT")
    alert:Show()

    if not pcall(alert.SetScript, alert, "OnShow", play) then
        Sound.hookFailures = (Sound.hookFailures or 0) + 1
        return
    end

    button.salveAlert   = alert
    Sound.hookInstalled = true
end

function Sound:Test()
    PlaySoundFile(ALERT, ns.db.soundChannel or "Master")
end
