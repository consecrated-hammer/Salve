local function equal(actual, expected, label)
    if actual ~= expected then
        error(("%s: expected %s, got %s"):format(label, tostring(expected), tostring(actual)))
    end
end

local ns = {
    db = {
        showStacks = false, boxWidth = 20, boxHeight = 20,
        showDispelTypeIcon = true, dispelTypeIconSize = 20,
        dispelTypeIconPosition = "BOTTOMLEFT",
    },
    DISPELLABLE_FILTER = "HARMFUL|RAID_PLAYER_DISPELLABLE",
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
        SweepSpellIDs = function() return { 1044 } end,
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
    CustomAuraButtonDispelTypeTextureStyle = { Icon = 2, PreserveAsset = 3 },
}

local rejectDispel = true
local capturedOptions
local capturedDispelOptions = {}
local capturedFilter
local capturedSlotOptions
local capturedSlots = {}
local anchoredTo = {}
local cooldownDurationObject = {}
local appliedDuration
local movementCooldownDurationObject = {}
local appliedMovementDuration
local movementDispelTextureBinds = 0
local createdTextures = {}

C_Spell = {
    GetSpellCooldownDuration = function(spellID)
        if spellID == 4987 then return cooldownDurationObject end
        if spellID == 1044 then return movementCooldownDurationObject end
        error("unexpected cooldown spell " .. tostring(spellID))
    end,
}

local function texture()
    local value = {
        SetAllPoints = function() end,
        ClearAllPoints = function() end,
        SetPoint = function(self, point) self.point = point end,
        SetSize = function(self, width, height) self.width, self.height = width, height end,
        SetHeight = function() end,
        SetWidth = function() end,
        SetColorTexture = function() end,
    }
    createdTextures[#createdTextures + 1] = value
    return value
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
            if options then
                capturedOptions = options
                capturedDispelOptions[#capturedDispelOptions + 1] = options
            end
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
equal(capturedSlots.salveDispel.filter, "HARMFUL|RAID_PLAYER_DISPELLABLE",
    "dispel slot requires Blizzard's per-character dispellable classification")
equal(capturedSlots.salveDispel.options.candidateFilters, nil,
    "normal dispel slot relies on Blizzard's by-me classification")
equal(capturedOptions.style, 2,
    "native dispel-type badge uses Blizzard's Icon renderer")
equal(capturedDispelOptions[#capturedDispelOptions - 1].showIcon, false,
    "colour fill never draws Blizzard's default dispel glyph")
equal(createdTextures[#createdTextures].width, 20,
    "native dispel badge is created at its configured size")
equal(createdTextures[#createdTextures].point, "BOTTOMLEFT",
    "native dispel badge is created at its configured position")
equal(capturedSlots.salveMovement, nil,
    "movement slot fails dark because spell-ID filtering is identity-gated")
equal(movementDispelTextureBinds, 0,
    "movement warning uses generic child art, not dispel-type-gated textures")

UnitIsUnit = function(left, right) return left == "raid2" and right == "player" end
local raidSelf = box()
equal(ns.Binding:Attach(raidSelf, "raid2"), true,
    "raid player cell attaches")
equal(capturedSlots.salveMovement, nil,
    "personal movement cell also fails dark without a safe spell-ID filter")
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
equal(capturedOptions.style, 2, "native Icon style remains selected")
equal(capturedOptions.showWhenHarmful, true, "harmful dispels shown")
equal(capturedOptions.showWhenHelpful, false, "helpful effects excluded")

ns.db.showDispelTypeIcon = false
local withoutIcon = box()
equal(ns.Binding:Attach(withoutIcon, "player"), true,
    "icon can be disabled without changing the dispel filter")
equal(capturedOptions.style, 3,
    "disabled icon restores Salve's preserve-asset cell fill")
equal(capturedOptions.showIcon, false,
    "disabled icon leaves no implicit Blizzard glyph on the colour fill")

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
