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
    },
    knownDispels = {
        { cures = { Magic = true, Disease = true } },
        { cures = { Poison = true } },
    },
    CuresText = function() return "none" end,
    Print = function() end,
}

UIParent = {}
InCombatLockdown = function() return false end
Enum = {
    CustomAuraButtonDispelTypeTextureStyle = { PreserveAsset = 3 },
}

local rejectDispel = true
local capturedOptions
local capturedFilter
local capturedSlotOptions
local anchoredTo
local cooldownDurationObject = {}
local appliedDuration

C_Spell = {
    GetSpellCooldownDuration = function(spellID)
        equal(spellID, 4987, "primary dispel cooldown requested")
        return cooldownDurationObject
    end,
}

local function texture()
    return {
        SetAllPoints = function() end,
        SetColorTexture = function() end,
    }
end

local function auraButton()
    return {
        SetAllPoints = function(_, owner) anchoredTo = owner end,
        SetMouseClickEnabled = function() end,
        SetMouseMotionEnabled = function() end,
        SetSize = function() end,
        GetFrameLevel = function() return 1 end,
        CreateTexture = function() return texture() end,
        ClearDispelTypeTextures = function() end,
        AddDispelTypeTexture = function(_, _, options)
            if rejectDispel then error("options rejected") end
            capturedOptions = options
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
    function container:AddAuraSlot(_, filter, options)
        capturedFilter = filter
        capturedSlotOptions = options
        local button = auraButton()
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
equal(anchoredTo, accepted, "returned aura slot is anchored over its Salve box")
equal(capturedFilter, "HARMFUL", "slot uses the broad harmful filter")
equal(capturedSlotOptions.candidateFilters.includeDispelTypes.Magic, true,
    "known Magic cure included in native candidate filter")
equal(capturedSlotOptions.candidateFilters.includeDispelTypes.Disease, true,
    "known Disease cure included in native candidate filter")
equal(capturedSlotOptions.candidateFilters.includeDispelTypes.Poison, true,
    "known Poison cure included in native candidate filter")
equal(capturedSlotOptions.candidateFilters.includeDispelTypes.Curse, nil,
    "unknown Curse cure excluded from native candidate filter")
local cooldown = {
    SetCooldownFromDurationObject = function(_, duration)
        appliedDuration = duration
    end,
}
ns.Binding:RegisterCooldown(cooldown)
equal(appliedDuration, cooldownDurationObject,
    "opaque primary dispel duration forwarded to Blizzard cooldown")

local refreshedDuration = {}
C_Spell.GetSpellCooldownDuration = function() return refreshedDuration end
ns.Binding:RefreshCooldowns()
equal(appliedDuration, refreshedDuration,
    "cooldown event refreshes existing native cooldown widgets")
equal(capturedOptions.style, 3, "preserve-asset style passed")
equal(capturedOptions.showWhenHarmful, true, "harmful dispels shown")
equal(capturedOptions.showWhenHelpful, false, "helpful effects excluded")

print("aura binding tests passed")
