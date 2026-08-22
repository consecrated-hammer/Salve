local function equal(actual, expected, label)
    if actual ~= expected then
        error(("%s: expected %s, got %s"):format(label, tostring(expected), tostring(actual)))
    end
end

local soundRefreshes = 0
local changedKey
local ns = {
    Sound = {
        OnSettingChanged = function(_, key)
            soundRefreshes = soundRefreshes + 1
            changedKey = key
        end,
    },
}

SalveDB = {
    learnMode = true,
    learned = { [12345] = "Old discovery" },
    learnedMovement = { [23456] = "Old Root" },
}
SalveLearnedDB = nil

local chunk = assert(loadfile("Core/Config.lua"))
chunk("Salve", ns)
ns.InitConfig()

equal(ns.db.schemaVersion, 6, "schema migrated")
equal(ns.db.learnMode, true, "learning normalized on")
equal(ns.db.soundEnabled, false, "alert sound defaults off")
equal(ns.db.showStartupMessage, true, "startup message defaults on")
equal(ns.db.useClassColours, false, "class-coloured clear cells default off")
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
equal(ns.db.schemaVersion, 6, "duplicate-binding migration applied")
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

print("config tests passed")
