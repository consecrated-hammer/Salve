local function equal(actual, expected, label)
    if actual ~= expected then
        error(("%s: expected %s, got %s"):format(label, tostring(expected), tostring(actual)))
    end
end

local soundRefreshes = 0
local changedKey
local selfAlertRefreshes = 0
local ns = {
    Sound = {
        OnSettingChanged = function(_, key)
            soundRefreshes = soundRefreshes + 1
            changedKey = key
        end,
    },
    SelfAlert = {
        Update = function() selfAlertRefreshes = selfAlertRefreshes + 1 end,
    },
}
ns.RequestRebuildSoon = function() end

SalveDB = {
    learnMode = true,
    learned = { [12345] = "Old discovery" },
    learnedMovement = { [23456] = "Old Root" },
}
SalveLearnedDB = nil

local chunk = assert(loadfile("Core/Config.lua"))
chunk("Salve", ns)
ns.InitConfig()

equal(ns.db.schemaVersion, 9, "schema migrated")
equal(ns.db.learnMode, true, "learning normalized on")
equal(ns.db.soundEnabled, false, "alert sound defaults off")
equal(ns.db.dispelSoundEnabled, false, "dispel alert sound defaults off")
equal(ns.db.movementSoundEnabled, false, "snare-removal sound defaults off")
equal(ns.db.movementTextNotification, true, "Freedom movement text defaults on")
equal(ns.db.selfDispelNotification, true, "self-dispel combat text defaults on")
equal(type(ns.db.movementSweepSpellIDs), "table", "movement sweep selections default to a table")
equal(type(ns.db.movementSweepColours), "table", "movement sweep colours default to a table")
equal(ns.db.showStartupMessage, true, "startup message defaults on")
equal(ns.db.useClassColours, false, "class-coloured clear cells default off")
equal(ns.db.tooltipUnitInfo, false, "default Blizzard unit tooltip defaults off")
equal(ns.db.showDispelTypeIcon, true, "native dispel-type icon defaults on")
equal(ns.db.dispelTypeIconSize, 20, "native dispel-type icon defaults to 20 pixels")
equal(ns.db.dispelTypeIconPosition, "BOTTOMLEFT", "native dispel-type icon defaults bottom left")
equal(ns.db.nameJustifyH, "LEFT", "unit names default left")
equal(ns.db.nameJustifyV, "MIDDLE", "unit names default middle")
equal(ns.db.nameFontSize, 11, "unit name text size default")
equal(ns.db.cooldownJustifyH, "CENTER", "cooldown text defaults centred")
equal(ns.db.cooldownJustifyV, "MIDDLE", "cooldown text defaults middle")
equal(ns.db.cooldownFontSize, 14, "cooldown text size default")
equal(ns.db.handlePosition, "TOPLEFT", "drag handle defaults above cell one")
equal(ns.db.horizontalGrowth, "RIGHT", "horizontal flow defaults left to right")
equal(ns.db.verticalGrowth, "DOWN", "vertical flow defaults top to bottom")
equal(ns.db.settingsPoint[1], "CENTER", "settings window defaults centred")
equal(ns.learned.auras["world:0"].spells[12345].name, "Old discovery", "legacy ID preserved")
equal(ns.learned.auras["world:0"].spells[12345].dispelType, nil, "unsafe legacy type not invented")
equal(ns.db.learned, nil, "discoveries removed from preferences")
equal(ns.learned.movement[23456], "Old Root", "movement discovery migrated")
equal(ns.db.learnedMovement, nil, "movement discoveries removed from preferences")

ns.Set("soundEnabled", true)
equal(soundRefreshes, 1, "sound setting refreshes native registrations")
equal(changedKey, "soundEnabled", "sound setting identifies changed key")

ns.Set("selfDispelNotification", false)
equal(selfAlertRefreshes, 1, "self-dispel setting updates only its combat-log listener")

SalveDB = {
    schemaVersion = 3,
    learnMode = true,
    learned = {},
    visibility = { mounted = true, notMounted = true, inCombat = true },
    bindings = {
        { key = "BUTTON1", role = "PRIMARY" },
        { key = "BUTTON1", role = "PRIMARY" },
        { key = "BUTTON1", role = "PRIMARY" },
    },
}
SalveLearnedDB = nil
ns.InitConfig()
-- Learning PERSISTS now. For movement-impairing effects it is the primary
-- data source, not a diagnostic, so resetting it meant that category never
-- accumulated anything.
equal(ns.db.learnMode, true, "learning survives UI reload")
equal(ns.db.schemaVersion, 9, "duplicate-binding migration applied")
equal(#ns.db.bindings, 1, "duplicate mouse bindings collapsed")
equal(ns.db.bindingsCustom, true, "legacy explicit bindings remain custom")
equal(ns.db.visibility.mounted, nil, "removed mounted condition cleared")
equal(ns.db.visibility.notMounted, nil, "removed not-mounted condition cleared")
equal(ns.db.visibility.inCombat, true, "remaining visibility condition preserved")

SalveDB.bindings[2] = { key = "BUTTON1", role = "PRIMARY" }
ns.InitConfig()
equal(#ns.db.bindings, 1, "current-schema duplicate bindings also collapse")

SalveDB.learnMode = false
ns.InitConfig()
equal(ns.db.learnMode, true, "existing profiles cannot retain disabled learning")

SalveDB = { schemaVersion = 6, soundEnabled = true }
SalveLearnedDB = nil
ns.InitConfig()
equal(ns.db.dispelSoundEnabled, true, "legacy sound setting enables dispel sound")
equal(ns.db.movementSoundEnabled, true, "legacy sound setting enables snare-removal sound")

SalveDB = { schemaVersion = 8, movementSweepSpellID = 1044 }
SalveLearnedDB = nil
ns.InitConfig()
equal(ns.db.movementSweepSpellIDs[1044], true,
    "legacy single sweep selection migrates into the multi-sweep set")
equal(ns.db.movementSweepSpellID, nil, "legacy single sweep selection is cleared")

-- SavedVariables are persisted input, not trusted Lua. A bad or partly
-- written profile must recover to independent sane values on the next load.
SalveDB = {
    schemaVersion = "future",
    bindings = "broken",
    visibility = false,
    escapes = 17,
    movementSweepSpellIDs = "broken",
    movementSweepColours = "broken",
    scale = "nan",
    columns = 0,
    point = { "CENTER" },
    settingsPoint = "broken",
    handlePosition = "MIDDLE",
    soundFile = {},
    tooltipAnchor = "DIAGONAL",
    soundChannel = "Unknown",
}
SalveLearnedDB = nil
ns.InitConfig()
equal(ns.db.schemaVersion, 9, "invalid schema is normalized")
equal(type(ns.db.bindings), "table", "invalid bindings are repaired")
equal(type(ns.db.visibility), "table", "invalid visibility is repaired")
equal(type(ns.db.escapes), "table", "invalid escapes are repaired")
equal(ns.db.scale, 1, "invalid scale is repaired")
equal(ns.db.columns, 1, "columns are clamped to a safe minimum")
equal(ns.db.point[1], "CENTER", "invalid panel point is repaired")
equal(ns.db.settingsPoint[1], "CENTER", "invalid settings point is repaired")
equal(ns.db.tooltipAnchor, "RIGHT", "invalid tooltip anchor is repaired")
equal(ns.db.soundChannel, "Master", "invalid sound channel is repaired")
equal(ns.db.handlePosition, "TOPLEFT", "invalid handle position is repaired")
equal(ns.db.soundFile, nil, "invalid sound file is repaired")
ns.db.bindings.injected = true
ns.InitConfig()
equal(ns.defaults.bindings.injected, nil, "repaired table defaults are not shared")

print("config tests passed")
