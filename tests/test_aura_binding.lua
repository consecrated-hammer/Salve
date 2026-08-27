local function equal(actual, expected, label)
    if actual ~= expected then
        error(("%s: expected %s, got %s"):format(label, tostring(expected), tostring(actual)))
    end
end

local ns = {
    db = { showStacks = false, boxWidth = 20, boxHeight = 20 },
    DISPELLABLE_FILTER = "HARMFUL",
    DISPEL_TYPES = { "Magic", "Curse", "Disease", "Poison" },
    spellID = 4987,
    Bindings = {
        List = function() return {} end,
        Describe = function() return "test" end,
        Label = function() return "test" end,
        IsDispelSpell = function(_, spellID) return spellID == 4987 end,
    },
    knownDispels = {
        { cures = { Magic = true, Disease = true } },
        { cures = { Poison = true } },
    },
    Escape = {
        Active = function() return true end,
        HasAllyEscape = function() return false end,
        AllSpellIDs = function() return { 45678 } end,
        CooldownSpellID = function() return 1044 end,
        IsEnabledSpell = function(_, spellID) return spellID == 1044 end,
    },
    CuresText = function() return "none" end,
    Print = function() end,
}

UIParent = {}
InCombatLockdown = function() return false end
local encounterActive = false
IsEncounterInProgress = function() return encounterActive end
Enum = {
    CustomAuraButtonDispelTypeTextureStyle = { PreserveAsset = 3 },
}

local rejectDispel = true
local capturedOptions
local capturedFilter
local capturedSlotOptions
local capturedSlots = {}
local anchoredTo = {}
local cooldownDurationObject = {}
local appliedDuration
local movementCooldownDurationObject = {}
local appliedMovementDuration
local movementDispelTextureBinds = 0

C_Spell = {
    GetSpellCooldownDuration = function(spellID)
        if spellID == 4987 then return cooldownDurationObject end
        if spellID == 1044 then return movementCooldownDurationObject end
        error("unexpected cooldown spell " .. tostring(spellID))
    end,
}

local function texture()
    return {
        SetAllPoints = function() end,
        SetPoint = function() end,
        SetHeight = function() end,
        SetWidth = function() end,
        SetColorTexture = function() end,
    }
end

local function auraButton(slotKey)
    return {
        SetAllPoints = function(_, owner) anchoredTo[slotKey] = owner end,
        SetMouseClickEnabled = function() end,
        SetMouseMotionEnabled = function() end,
        SetSize = function() end,
        GetFrameLevel = function() return 1 end,
        CreateTexture = function() return texture() end,
        ClearDispelTypeTextures = function() end,
        AddDispelTypeTexture = function(_, _, options)
            if slotKey == "salveMovement" then
                movementDispelTextureBinds = movementDispelTextureBinds + 1
            end
            if rejectDispel then error("options rejected") end
            if options then capturedOptions = options end
        end,
    }
end

CreateFrame = function(frameType)
    local container = {}
    function container:SetAllPoints() end
    function container:SetParent() end
    function container:SetUnit() end
    function container:SetEnabled() end
    function container:UpdateAllAuras() end
    function container:AddAuraGroup() end
    function container:AddAuraSlot(slotKey, filter, options)
        capturedFilter = filter
        capturedSlotOptions = options
        capturedSlots[slotKey] = { filter = filter, options = options }
        local button = auraButton(slotKey)
        options.initializeFrame(button)
        return button
    end
    return container
end

local chunk = assert(loadfile("Features/AuraBinding.lua"))
chunk("Salve", ns)

local function box()
    return {
        GetWidth = function() return 20 end,
        GetHeight = function() return 20 end,
    }
end

local rejected = box()
equal(ns.Binding:Attach(rejected, "player"), false,
    "failed dispel carrier rejects attachment")
if not ns.Binding.lastFailure:find("options rejected", 1, true) then
    error("carrier failure was not retained for diagnostics")
end

rejectDispel = false
local accepted = box()
equal(ns.Binding:Attach(accepted, "player"), true,
    "valid dispel carrier attaches")
equal(anchoredTo.salveDispel, accepted, "returned dispel slot is anchored over its Salve box")
equal(anchoredTo.salveMovement, accepted, "returned movement slot is anchored over its Salve box")
equal(capturedSlots.salveDispel.filter, "HARMFUL", "dispel slot uses the broad harmful filter")
equal(capturedSlots.salveDispel.options.candidateFilters.includeDispelTypes.Magic, true,
    "known Magic cure included in native candidate filter")
equal(capturedSlots.salveDispel.options.candidateFilters.includeDispelTypes.Disease, true,
    "known Disease cure included in native candidate filter")
equal(capturedSlots.salveDispel.options.candidateFilters.includeDispelTypes.Poison, true,
    "known Poison cure included in native candidate filter")
equal(capturedSlots.salveDispel.options.candidateFilters.includeDispelTypes.Curse, nil,
    "unknown Curse cure excluded from native candidate filter")
equal(capturedSlots.salveMovement.options.candidateFilters.includeSpellIDs[45678], true,
    "movement slot receives known movement spell IDs")
equal(movementDispelTextureBinds, 0,
    "movement warning uses generic child art, not dispel-type-gated textures")

UnitIsUnit = function(left, right) return left == "raid2" and right == "player" end
local raidSelf = box()
equal(ns.Binding:Attach(raidSelf, "raid2"), true,
    "raid player cell attaches")
equal(anchoredTo.salveMovement, raidSelf,
    "personal movement slot is created and anchored for the player's raid token")
local cooldown = {
    SetCooldownFromDurationObject = function(_, duration)
        appliedDuration = duration
    end,
}
ns.Binding:RegisterCooldown(cooldown)
equal(appliedDuration, cooldownDurationObject,
    "opaque primary dispel duration forwarded to Blizzard cooldown")

local movementCooldown = {
    SetCooldownFromDurationObject = function(_, duration)
        appliedMovementDuration = duration
    end,
}
ns.Binding:RegisterMovementCooldown(movementCooldown)
equal(appliedMovementDuration, movementCooldownDurationObject,
    "movement removal duration forwarded to border-sweep cooldown")

local refreshedDuration, refreshedMovementDuration = {}, {}
C_Spell.GetSpellCooldownDuration = function(spellID)
    if spellID == 4987 then return refreshedDuration end
    if spellID == 1044 then return refreshedMovementDuration end
    error("unexpected refreshed cooldown spell " .. tostring(spellID))
end
equal(ns.Binding:ObserveDispelCast("player", 12345), false,
    "ordinary cast is not treated as a dispel")
equal(ns.Binding:ObserveDispelCast("player", 4987), true,
    "known player dispel is recognized")
ns.Binding:RefreshCooldowns("test dispel")
equal(appliedDuration, refreshedDuration,
    "cooldown event refreshes existing native cooldown widgets")
equal(ns.Binding.cooldownDebug.matchedDispelCasts, 1,
    "matched dispel is retained for diagnostics")
equal(ns.Binding.cooldownDebug.lastDurationState, "object returned",
    "duration-object result is retained for diagnostics")
equal(ns.Binding.cooldownDebug.lastSucceeded, 1,
    "successful widget application is retained for diagnostics")
equal(ns.Binding:ObserveMovementCast("player", 1044), 1044,
    "enabled movement removal is recognized")
equal(ns.Binding:ObserveMovementCast("player", 12345), nil,
    "ordinary cast is not treated as a movement removal")
ns.Binding:RefreshMovementCooldowns("test movement", 1044)
equal(appliedMovementDuration, refreshedMovementDuration,
    "movement cast refreshes border-sweep cooldown widgets")
equal(capturedOptions.style, 3, "preserve-asset style passed")
equal(capturedOptions.showWhenHarmful, true, "harmful dispels shown")
equal(capturedOptions.showWhenHelpful, false, "helpful effects excluded")

ns.StructuralChangesUnsafe = function()
    return InCombatLockdown() or IsEncounterInProgress()
end
local originalContainer = accepted.auraContainer
local originalSignature = accepted.boundSig
ns.db.boxWidth = 24
rejectDispel = true
equal(ns.Binding:Attach(accepted, "player"), true,
    "rejected replacement preserves the working aura attachment")
equal(accepted.auraContainer, originalContainer,
    "failed replacement restores the original container")
equal(accepted.boundSig, originalSignature,
    "failed replacement restores the original signature")
if not ns.Binding.lastFailure:find("previous binding preserved", 1, true) then
    error("preserved fallback is not retained in diagnostics")
end

encounterActive = true
equal(ns.Binding:Attach(accepted, "player"), true,
    "active encounter preserves an existing healthy attachment")
equal(accepted.boundSig ~= nil, true,
    "deferred signature change does not detach the working container")

print("aura binding tests passed")
