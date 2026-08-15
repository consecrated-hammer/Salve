local addonName, ns = ...

-- ============================================================
-- The engine binding — the heart of Salve
-- ============================================================
-- Midnight makes aura data SECRET. Tainted Lua may store, pass and concatenate
-- a secret; it may NOT compare it, do arithmetic on it, take its length, index
-- it, or use it as a table key. Every one of those raises "execution tainted",
-- once per aura per frame, which is what makes a broken dispel addon unusable
-- rather than merely wrong.
--
-- The way out is not to guard every read. It is to never read at all. We hand
-- the engine a filter and some art; it decides what matches, when it is
-- visible, what colour it is and what the stack count says.
--
-- ============================================================
-- BUILD ORDER — DO NOT REORDER
-- ============================================================
--   CreateFrame("AuraContainer", nil, parent, "CustomAuraContainerTemplate")
--     -> SetAllPoints
--     -> SetUnit(unit)
--     -> AddAuraSlot(slotKey, filterString, { initializeFrame = ... })
--     -> SetEnabled(true)                                    <-- LAST, always
--
-- ☠ SetEnabled GATES AURA-EVENT REGISTRATION and must come last. Without it the
--   slot renders once and then goes permanently stale -- which looks exactly
--   like "the addon works until the first debuff falls off".
--
-- ☠ AddAuraSlot takes THREE arguments (key, filter, options), not one config
--   table. A table in the key position is rejected, the pcall swallows it, and
--   nothing ever lights up.
--
-- ☠ ADDONS NO LONGER CREATE AURA BUTTONS. The container creates and anchors its
--   own; we register a slot and Blizzard calls initializeFrame per button so we
--   can style it.
--
-- ☠ initializeFrame IS A PRE-SEAL WINDOW. Region creation and every button-level
--   write must happen inside it. Once it returns, the engine applies
--   DenyTaintedAccessWhenAurasAreSecret and later writes are refused precisely
--   when auras are secret -- i.e. in exactly the content this addon is for.
--
-- ☠ BUILD FRESH REGIONS AS CHILDREN OF THE BUTTON. You may not hand the engine
--   a texture that lives somewhere else and you may not SetParent an existing
--   scripted widget onto the button; forbidden-aspect inheritance blocks it.
--
-- ☠ NEVER CREATE OR ENABLE A CONTAINER IN COMBAT. That is a hard client error
--   pcall cannot catch. Callers gate on InCombatLockdown; this file re-checks.
--
-- ☠ NEVER Show()/Hide() a bound region afterwards. The engine owns Shown.
-- ☠ OnUpdate and animation drivers do NOT tick inside the button subtree
--   (onUpdateMode=disabled propagates). Host any driver outside it.

ns.Binding = {}
local Binding = ns.Binding

local SLOT_KEY = "salveDispel"

-- ── Capability probe ───────────────────────────────────────────────────────
-- These interfaces are new in 12.1.0 and undocumented publicly. Probe once,
-- record what this client offers, and report it from /salve probe.

Binding.caps = nil

-- Everything Attach's sequence actually depends on. A client missing any of
-- these cannot be driven by this file, and pretending otherwise would attach
-- "successfully" to a container with no unit or no event registration --
-- boxes that never light up and never report a failure.
local REQUIRED = { "AddAuraSlot", "SetUnit", "SetEnabled" }

local function probe()
    if Binding.caps then return Binding.caps end

    -- ☠ NEVER CACHE A COMBAT-TIME PROBE. Creating a container in combat is a
    --   hard client error, so we cannot test then -- but recording that as
    --   "unsupported" would be a lie that outlives the fight. /salve probe typed
    --   mid-pull once disabled the addon for the rest of the session: every
    --   later rebuild read the cached false and refused to bind anything.
    if InCombatLockdown() then
        return { container = false, methods = {}, usable = false, deferred = true }
    end

    local caps = { container = false, methods = {}, usable = false }

    local ok, c = pcall(CreateFrame, "AuraContainer", nil, UIParent,
        "CustomAuraContainerTemplate")
    if ok and c then
        caps.container = true
        for _, m in ipairs({
            "AddAuraSlot", "AddAuraGroup", "SetUnit",
            "SetEnabled", "UpdateAllAuras",
        }) do
            caps.methods[m] = type(c[m]) == "function"
        end
        pcall(c.SetParent, c, nil)

        caps.usable = true
        for _, m in ipairs(REQUIRED) do
            if not caps.methods[m] then caps.usable = false break end
        end
    end

    Binding.caps = caps
    return caps
end

Binding.Probe = probe

function Binding:Report()
    local caps = probe()
    ns.Print("engine binding report")

    if caps.deferred then
        ns.Print("  |cffffd100can't probe in combat|r — the test needs to build a "
            .. "container, which is forbidden while locked down. Run this again "
            .. "once you're out of combat.")
        return
    end

    ns.Print("  AuraContainer frame type: "
        .. (caps.container and "|cff44ff44yes|r" or "|cffff4444NO|r"))
    for _, m in ipairs({ "SetUnit", "AddAuraSlot", "SetEnabled", "UpdateAllAuras" }) do
        ns.Print("  " .. m .. ": "
            .. (caps.methods[m] and "|cff44ff44yes|r" or "|cffff4444no|r"))
    end
    ns.Print("  usable: " .. (caps.usable and "|cff44ff44yes|r"
        or "|cffff4444NO — a required method is missing|r"))
    ns.Print("  buttons initialised: " .. tostring(self.boundCount or 0))
    -- Containers are never reclaimed by the client, so this only ever grows.
    -- It should track the number of boxes, not the number of roster changes;
    -- if it climbs during normal play, the retarget fast path has broken.
    ns.Print("  containers built: " .. tostring(self.containersBuilt or 0))
    if self.lastFailure then
        ns.Print("  |cffff4444last attach failure:|r " .. self.lastFailure)
    end
    ns.Print("  filter: " .. ns.DISPELLABLE_FILTER)
    ns.Print("  dispel spell: " .. tostring(ns.spellName or "|cffff4444none known|r"))
    ns.Print("  sound hook: "
        .. (ns.Sound.hookInstalled and "|cff44ff44installed|r" or "|cffff4444not installed|r")
        .. ", fired " .. tostring(ns.Sound.fireCount) .. "x"
        .. ((ns.Sound.hookFailures or 0) > 0
            and (", |cffff4444" .. ns.Sound.hookFailures .. " rejected|r") or ""))
end

Binding.boundCount = 0

-- ── The initializer ────────────────────────────────────────────────────────
-- Called by the engine, once per button it creates. Everything we will ever be
-- allowed to do to this button happens here.

local function initializeFrame(box)
    return function(b)
        -- The engine's buttons default to mouse-enabled, which would steal the
        -- clicks from the secure button underneath and make the box dead.
        pcall(function()
            if b.SetMouseClickEnabled then b:SetMouseClickEnabled(false) end
            if b.SetMouseMotionEnabled then b:SetMouseMotionEnabled(false) end
        end)

        pcall(b.SetSize, b, box:GetWidth(), box:GetHeight())

        -- Fill: created HERE, as a child of the button. The engine tints it by
        -- dispel type and owns its visibility from AddDispelTypeTexture onward.
        if not b.salveFill then
            b.salveFill = b:CreateTexture(nil, "ARTWORK")
            b.salveFill:SetAllPoints(b)
            b.salveFill:SetColorTexture(1, 1, 1, 1)
        end

        if b.AddDispelTypeTexture then
            pcall(function()
                if b.ClearDispelTypeTextures then b:ClearDispelTypeTextures() end
                b:AddDispelTypeTexture(b.salveFill)
            end)
        end

        -- Stack count, likewise engine-written.
        -- ☠ Pass an EMPTY options table and never a formatter: a Lua formatter
        --   running on a secret count throws inside the engine's dirty pass,
        --   where it cannot be caught.
        if ns.db.showStacks and b.SetApplicationCount then
            if not b.salveStack then
                b.salveStack = b:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
                b.salveStack:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -1, 0)
            end
            pcall(b.SetApplicationCount, b, b.salveStack, {})
        end

        -- The affliction alert. The engine shows this button exactly when a
        -- dispellable aura appears, so OnShow is a read-free "something landed"
        -- event -- no aura read, no comparison, no spell list.
        -- ⚠ Still unproven: see Features/Sound.lua. /salve probe reports whether
        --   it has ever actually fired.
        ns.Sound:Hook(b)

        Binding.boundCount = Binding.boundCount + 1
    end
end

-- ── Attaching one box ──────────────────────────────────────────────────────

function Binding:Container(box)
    if box.auraContainer then return box.auraContainer end

    local ok, c = pcall(CreateFrame, "AuraContainer", nil, box,
        "CustomAuraContainerTemplate")
    if not ok or not c then return nil end

    c:SetAllPoints(box)
    box.auraContainer = c
    return c
end

function Binding:Attach(box, unit)
    local caps = probe()
    -- usable, not just `container`: a client with AddAuraSlot but no SetUnit or
    -- SetEnabled would otherwise attach and silently never light up.
    if not caps.usable then return false end
    -- Creating or enabling a container in combat is a hard error, not a pcall.
    if InCombatLockdown() then return false end

    -- ── Slot identity ─────────────────────────────────────────────────────
    -- Everything BAKED INTO the slot at creation time, and nothing else.
    --
    -- ☠ THE UNIT IS DELIBERATELY NOT IN HERE. A unit change is a RETARGET --
    --   SetUnit works in place on a live container -- so rebuilding the slot
    --   for one would throw away a perfectly good frame tree on every roster
    --   change. That matters more than it looks: WoW frames have no destructor,
    --   so a discarded container and its engine-created children survive until
    --   /reload. A raid with people joining and leaving would allocate a new
    --   tree per change, forever.
    --
    -- ☠ THE BOX SIZE *IS* IN HERE. The engine button is sized inside
    --   initializeFrame and can never be resized afterwards (writes are refused
    --   once that window closes), so a width or height change genuinely does
    --   need a new slot. Leaving it out left resized boxes with an engine
    --   button still at the old dimensions.
    local sig = table.concat({
        tostring(ns.db.showStacks), ns.db.boxWidth, ns.db.boxHeight,
    }, "|")

    -- Fast path: same slot, possibly a different unit, possibly parked.
    if box.boundSig == sig and box.auraContainer then
        local c = box.auraContainer

        if box.boundUnit ~= unit and caps.methods.SetUnit then
            if not pcall(c.SetUnit, c, unit) then
                self:Detach(box)
                return false
            end
            box.boundUnit = unit
        end

        -- Coming back from a park. Re-enabling is what re-registers the
        -- container for aura events, so it is as load-bearing here as it is on
        -- the build path.
        if box.parked then
            if not pcall(c.SetEnabled, c, true) then
                self:Detach(box)
                return false
            end
            box.parked = nil
        end

        if caps.methods.UpdateAllAuras then pcall(c.UpdateAllAuras, c) end
        return true
    end

    -- ☠ Drop the whole container rather than adding a second slot: AddAuraSlot
    --   appends, so re-registering would leave the old slot live and accumulate
    --   one more each time.
    self:Detach(box)

    local c = self:Container(box)
    if not c then return false end

    -- ☠ EVERY STEP BELOW IS CHECKED. Ignoring a pcall result here and caching
    --   boundSig anyway left a container with no unit, or never registered for
    --   aura events, that no later rebuild would ever retry -- one member
    --   permanently unlit, silently, with the fast path above hiding it. That is
    --   the exact shape a changed or partially-supported API would take.
    if caps.methods.SetUnit and not pcall(c.SetUnit, c, unit) then
        self:Detach(box)
        return false
    end

    if not pcall(c.AddAuraSlot, c, SLOT_KEY, ns.DISPELLABLE_FILTER, {
        initializeFrame = initializeFrame(box),
    }) then
        self:Detach(box)
        return false
    end

    -- ☠ LAST. This is what registers the container for aura events.
    if caps.methods.SetEnabled and not pcall(c.SetEnabled, c, true) then
        self:Detach(box)
        return false
    end

    box.boundUnit = unit
    box.boundSig  = sig
    Binding.containersBuilt = (Binding.containersBuilt or 0) + 1

    if caps.methods.UpdateAllAuras then
        pcall(c.UpdateAllAuras, c)
    end

    return true
end

-- ── Parking ────────────────────────────────────────────────────────────────
--
-- What a box does when the group shrinks. NOT Detach.
--
-- ☠ WoW frames have no destructor. Dropping a container's last reference does
--   not reclaim it or its engine-created children until /reload. Leaving a raid
--   for a party would discard 35 frame trees; rejoining would build 35 more,
--   and every transition for the rest of the session adds another set.
--
-- So a surplus box keeps its container and slot and merely stops listening.
-- Coming back is then the retarget fast path above: SetUnit, re-enable, done.
function Binding:Park(box)
    local c = box.auraContainer
    if not c then return end

    pcall(function()
        if c.SetEnabled then c:SetEnabled(false) end
    end)

    box.parked    = true
    box.boundUnit = nil
end

-- Real teardown. Only for a container that failed to build correctly -- a
-- healthy one is parked, never detached.
function Binding:Detach(box)
    -- ☠ Not a Hide(): the engine owns Shown on everything it bound. Disabling
    --   and dropping the container is the only clean way to stop it.
    if box.auraContainer then
        pcall(function()
            if box.auraContainer.SetEnabled then box.auraContainer:SetEnabled(false) end
        end)
        box.auraContainer:SetParent(nil)
        box.auraContainer = nil
    end
    box.boundUnit = nil
    box.boundSig  = nil
    box.parked    = nil
end
