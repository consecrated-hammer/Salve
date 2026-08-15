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

-- Hooked onto the button the ENGINE creates, from inside initializeFrame --
-- the one window in which writing to that button is allowed. The engine shows
-- the button exactly when a dispellable aura appears, so OnShow is the event.
--
-- ⚠ OnUpdate and animation drivers are known not to tick inside the button
--   subtree (onUpdateMode=disabled propagates down it). OnShow is a script
--   rather than a driver, so it should survive that -- but "should" is the
--   whole reason the sound defaults to off and the probe counts firings.
function Sound:Hook(button)
    if button.salveHooked then return end

    -- ☠ Only claim success if the hook actually took. Setting the flags first
    --   meant a rejected HookScript still blocked every retry AND made
    --   /salve probe report the hook as installed -- a diagnostic confidently
    --   reporting the opposite of the truth, on the one feature that exists
    --   because its mechanism is unproven.
    if not pcall(button.HookScript, button, "OnShow", play) then
        Sound.hookFailures = (Sound.hookFailures or 0) + 1
        return
    end

    button.salveHooked  = true
    Sound.hookInstalled = true
end

function Sound:Test()
    PlaySoundFile(ALERT, ns.db.soundChannel or "Master")
end
