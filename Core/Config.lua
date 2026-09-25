local addonName, ns = ...

-- Every visual and behavioural choice lives here. Nothing in Salve is baked in;
-- if you find yourself wanting to ask the user a question, add a key instead.

ns.defaults = {
    -- Position & size. 20x20 is Decursive's MUF size, straight from its
    -- Dcr_DebuffsFrame.xml -- deliberately tiny, and names cannot fit at that
    -- size, which is why showNames starts off.
    -- ☠ There is deliberately no `locked` key. showHandle IS the lock state --
    --   two keys for one concept is how they drift apart. Use ns.IsLocked().
    scale         = 1.0,
    columns       = 5,
    boxWidth      = 20,
    boxHeight     = 20,
    spacing       = 1,
    point         = { "CENTER", "CENTER", 0, -140 },
    settingsPoint = { "CENTER", "CENTER", 0, 0 },

    -- Appearance
    showNames     = false,
    -- Who you are pointing at and what each click does. On by default: the
    -- bindings are configurable, so without it there is nothing on screen that
    -- says what a box will cast.
    showTooltip   = true,
    -- Tooltip content is deliberately separate from the master toggle. It
    -- lets a player keep a compact action reminder without accepting the
    -- default Blizzard unit tooltip on every small cell.
    tooltipUnitInfo = false,
    tooltipActions = true,
    tooltipSpellDescriptions = false,
    tooltipAnchor = "RIGHT",
    -- Blizzard draws this itself from private aura data. It is not an aura
    -- inspection by Salve, and defaults on for the familiar DF-style marker.
    showDispelTypeIcon = true,
    dispelTypeIconSize = 20,
    dispelTypeIconPosition = "BOTTOMLEFT",
    nameJustifyH  = "LEFT",
    nameJustifyV  = "MIDDLE",
    nameFontSize  = 11,
    cooldownJustifyH = "CENTER",
    cooldownJustifyV = "MIDDLE",
    cooldownFontSize = 14,
    showStacks    = true,   -- engine-driven; Blizzard hides it at one stack
    useClassColours = false,
    showWhenClean = true,
    cleanAlpha    = 0.25,
    showHandle    = true,   -- the persistent drag grip, like Decursive's
    handlePosition = "TOPLEFT",
    showStartupMessage = true,

    -- Behaviour
    -- Click bindings. Fresh/restored profiles use automatic defaults (left =
    -- primary dispel, plus right = a distinct secondary or enabled movement
    -- removal). bindingsCustom lets
    -- an intentionally empty edited list remain empty instead of springing
    -- back to defaults after the last row is cleared.
    bindings       = {},
    bindingsCustom = false,
    -- Optional timestamp-only history of clicks on armed Salve cells. The
    -- entries themselves live in SalveClickLog, separate from preferences.
    clickAuditEnabled = false,

    -- HORIZONTAL fills a row then wraps to the next; VERTICAL fills a column
    -- then wraps to the next. `columns` is the wrap point either way.
    orientation   = "HORIZONTAL",
    horizontalGrowth = "RIGHT",
    verticalGrowth   = "DOWN",

    -- ALWAYS | NEVER, combined with the conditions below. See
    -- Features/Visibility.lua for why this is a state driver and not Show/Hide.
    visibilityMode = "ALWAYS",
    visibility     = {},

    -- Alert sound. Typed spell IDs come from Salve's built-in catalogue for
    -- the current instance.
    -- `soundEnabled` remains as a migrated compatibility key. The two alert
    -- paths are independently useful: a player may want native dispel sounds
    -- without a warning for every verified snare.
    soundEnabled  = false,
    dispelSoundEnabled = false,
    movementSoundEnabled = false,
    movementTextNotification = true,
    movementTextOutput = "SCREEN",
    movementChatWindow = 0,
    selfDispelNotification = true,
    soundChannel  = "Master",
    soundFile     = nil,

    -- Compatibility state for older code and diagnostics. Aura learning is a
    -- core feature now and is normalized on at every load rather than exposed
    -- as a preference.
    learnMode     = true,

    -- Movement-impairment category. `escapes` is the set of your own spells
    -- you have opted in to. Learned discoveries deliberately live in the
    -- separate SalveLearnedDB saved-variable block, not in preferences.
    escapes         = {},
    -- Each bound movement action may draw its own coloured clock-hand edge.
    -- Colours and enabled state are stored by spell ID for every class.
    movementSweepSpellID = nil,
    movementSweepSpellIDs = {},
    movementSweepColours = {},

    -- Saved-variable migrations. Increment only when an old shape needs an
    -- explicit conversion; ordinary new defaults do not need a bump.
    schemaVersion = 9,

    -- Minimap button
    showMinimap   = true,
    minimapAngle  = 225,
}

local function copyDefaults(dst, src)
    for k, v in pairs(src) do
        if type(v) == "table" then
            if type(dst[k]) ~= "table" then dst[k] = {} end
            copyDefaults(dst[k], v)
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
    return dst
end

local function resetIfWrongType(db, key, expected)
    if type(db[key]) ~= expected then
        -- Table defaults are templates, never shared live state. Sharing one
        -- here would let a damaged saved variable mutate fresh profiles later.
        db[key] = type(ns.defaults[key]) == "table"
            and copyDefaults({}, ns.defaults[key]) or ns.defaults[key]
    end
end

local function numberInRange(db, key, minimum, maximum, integer)
    local value = tonumber(db[key])
    -- Lua accepts "nan" as a number. It is unusable for layout arithmetic and
    -- min/max results vary by client, so treat it like any other bad input.
    if not value or value ~= value then value = ns.defaults[key] end
    value = math.max(minimum, math.min(maximum, value))
    db[key] = integer and math.floor(value + 0.5) or value
end

local function enumOrDefault(db, key, allowed)
    if not allowed[db[key]] then db[key] = ns.defaults[key] end
end

local function validPoint(point)
    local anchors = {
        TOPLEFT = true, TOP = true, TOPRIGHT = true, LEFT = true, CENTER = true,
        RIGHT = true, BOTTOMLEFT = true, BOTTOM = true, BOTTOMRIGHT = true,
    }
    if type(point) ~= "table" then return false end
    local x, y = tonumber(point[3]), tonumber(point[4])
    return anchors[point[1]] and anchors[point[2]]
        and type(x) == "number" and x == x and type(y) == "number" and y == y
end

local function normalizePreferences(db)
    for _, key in ipairs({ "bindings", "visibility", "escapes", "movementSweepSpellIDs",
        "movementSweepColours" }) do
        resetIfWrongType(db, key, "table")
    end
    for _, key in ipairs({ "showNames", "showTooltip", "tooltipUnitInfo", "tooltipActions",
        "tooltipSpellDescriptions", "showDispelTypeIcon", "showStacks", "useClassColours",
        "showWhenClean", "showHandle", "showStartupMessage", "bindingsCustom", "clickAuditEnabled",
        "soundEnabled", "dispelSoundEnabled", "movementSoundEnabled", "movementTextNotification",
        "selfDispelNotification", "showMinimap" }) do
        resetIfWrongType(db, key, "boolean")
    end
    for _, key in ipairs({ "scale", "cleanAlpha" }) do numberInRange(db, key, 0, key == "scale" and 3 or 1) end
    numberInRange(db, "columns", 1, 40, true)
    numberInRange(db, "boxWidth", 8, 200, true)
    numberInRange(db, "boxHeight", 8, 200, true)
    numberInRange(db, "spacing", 0, 40, true)
    numberInRange(db, "nameFontSize", 6, 48, true)
    numberInRange(db, "cooldownFontSize", 6, 48, true)
    numberInRange(db, "dispelTypeIconSize", 8, 64, true)
    numberInRange(db, "minimapAngle", 0, 360)
    numberInRange(db, "movementChatWindow", 0, 20, true)
    enumOrDefault(db, "orientation", { HORIZONTAL = true, VERTICAL = true })
    enumOrDefault(db, "horizontalGrowth", { LEFT = true, RIGHT = true })
    enumOrDefault(db, "verticalGrowth", { UP = true, DOWN = true })
    enumOrDefault(db, "visibilityMode", { ALWAYS = true, NEVER = true })
    enumOrDefault(db, "tooltipAnchor", { LEFT = true, RIGHT = true, TOP = true, BOTTOM = true, CURSOR = true })
    enumOrDefault(db, "nameJustifyH", { LEFT = true, CENTER = true, RIGHT = true })
    enumOrDefault(db, "nameJustifyV", { TOP = true, MIDDLE = true, BOTTOM = true })
    enumOrDefault(db, "cooldownJustifyH", { LEFT = true, CENTER = true, RIGHT = true })
    enumOrDefault(db, "cooldownJustifyV", { TOP = true, MIDDLE = true, BOTTOM = true })
    enumOrDefault(db, "dispelTypeIconPosition", {
        TOPLEFT = true, TOPRIGHT = true, BOTTOMLEFT = true, BOTTOMRIGHT = true, CENTER = true,
    })
    enumOrDefault(db, "movementTextOutput", { SCREEN = true, CHAT = true, BOTH = true })
    enumOrDefault(db, "soundChannel", { Master = true, SFX = true, Music = true, Ambience = true, Dialog = true })
    enumOrDefault(db, "handlePosition", {
        TOPLEFT = true, TOPRIGHT = true, BOTTOMLEFT = true, BOTTOMRIGHT = true,
    })
    if db.soundFile ~= nil and type(db.soundFile) ~= "string" and type(db.soundFile) ~= "number" then
        db.soundFile = ns.defaults.soundFile
    end
    if not validPoint(db.point) then db.point = { unpack(ns.defaults.point) } end
    if not validPoint(db.settingsPoint) then db.settingsPoint = { unpack(ns.defaults.settingsPoint) } end
end

function ns.InitConfig()
    -- SavedVariables are user-controlled persisted input. Recover from a
    -- partial write or third-party edit instead of failing ADDON_LOADED.
    SalveDB = type(SalveDB) == "table" and SalveDB or {}
    local oldSchema = tonumber(SalveDB.schemaVersion) or 1
    SalveDB = copyDefaults(SalveDB, ns.defaults)

    if oldSchema < 2 then
        -- The first sound implementation stored learned IDs directly in the
        -- table and enabled its global UNIT_AURA listener by default. Preserve
        -- those IDs as unscoped diagnostics, but never activate them: they have
        -- no instance or dispel-school provenance.
        local oldLearned = SalveDB.learned
        local migrated = {}
        local unscoped = { name = "Unscoped legacy discoveries", spells = {} }
        for spellID, name in pairs(type(oldLearned) == "table" and oldLearned or {}) do
            if type(spellID) == "number" and type(name) ~= "table" then
                unscoped.spells[spellID] = {
                    spellID = spellID,
                    name = type(name) == "string" and name or "?",
                    provenance = "legacy learn",
                }
            end
        end
        if next(unscoped.spells) then migrated[0] = unscoped end
        SalveDB.learned = migrated
        SalveDB.learnMode = false
        SalveDB.schemaVersion = 2
    end

    if oldSchema < 3 then
        -- Instance IDs are valid scopes for dungeons and raids, but outdoor
        -- content used numeric key 0 for every zone. Move existing buckets to
        -- explicit typed keys; legacy outdoor discoveries remain unscoped and
        -- inactive rather than being attributed to an invented map.
        local scoped = {}
        for key, bucket in pairs(type(SalveDB.learned) == "table" and SalveDB.learned or {}) do
            local scopeKey = key
            if type(key) == "number" then
                scopeKey = key > 0 and ("instance:" .. key) or "world:0"
            end
            if type(scopeKey) == "string" and type(bucket) == "table" then
                local target = scoped[scopeKey]
                if not target then
                    target = {
                        name = bucket.name,
                        scopeType = scopeKey:match("^([^:]+):"),
                        scopeID = tonumber(scopeKey:match(":(%d+)$")),
                        spells = {},
                    }
                    scoped[scopeKey] = target
                end
                for spellID, record in pairs(type(bucket.spells) == "table" and bucket.spells or {}) do
                    target.spells[spellID] = record
                end
            end
        end
        SalveDB.learned = scoped
        SalveDB.schemaVersion = 3
    end

    if oldSchema < 4 then
        SalveDB.schemaVersion = 4
    end

    if oldSchema < 5 then
        SalveDB.schemaVersion = 5
    end

    if oldSchema < 6 then
        SalveDB.bindingsCustom = type(SalveDB.bindings) == "table"
            and #SalveDB.bindings > 0
        SalveDB.schemaVersion = 6
    end

    if oldSchema < 7 then
        local enabled = SalveDB.soundEnabled == true
        SalveDB.dispelSoundEnabled = enabled
        SalveDB.movementSoundEnabled = enabled
        SalveDB.schemaVersion = 7
    end

    if oldSchema < 8 then
        SalveDB.schemaVersion = 8
    end

    if oldSchema < 9 then
        local legacy = SalveDB.movementSweepSpellID
        SalveDB.movementSweepSpellIDs = type(SalveDB.movementSweepSpellIDs) == "table"
            and SalveDB.movementSweepSpellIDs or {}
        if type(legacy) == "number" then SalveDB.movementSweepSpellIDs[legacy] = true end
        SalveDB.movementSweepSpellID = nil
        SalveDB.schemaVersion = 9
    end
    -- A profile from a newer build can otherwise retain a fictional future
    -- schema forever after a partial sync. This build owns schema 9.
    SalveDB.schemaVersion = 9

    -- Learning supplies the coverage that encounter-journal data cannot,
    -- especially for trash roots and snares. It is always active in 1.4.0;
    -- preserve the key only as an internal compatibility signal.
    SalveDB.learnMode = true
    normalizePreferences(SalveDB)

    -- Normalize on every load, not only at the schema boundary. A profile can
    -- reach schema 4 before an older synced Options file finishes writing its
    -- duplicate rows. Secure attributes can hold only one action per mouse
    -- chord, so duplicates are never meaningful and are safe to collapse.
    local deduped, seen = {}, {}
    for _, entry in ipairs(SalveDB.bindings) do
        local key = type(entry) == "table" and entry.key
        if type(entry) == "table" and type(key) == "string" and not seen[key] then
            deduped[#deduped + 1] = entry
            seen[key] = true
        end
    end
    SalveDB.bindings = deduped
    SalveDB.movementSweepColours = type(SalveDB.movementSweepColours) == "table"
        and SalveDB.movementSweepColours or {}
    SalveDB.movementSweepSpellIDs = type(SalveDB.movementSweepSpellIDs) == "table"
        and SalveDB.movementSweepSpellIDs or {}
    SalveDB.movementSweepSpellID = nil

    -- These visibility choices were removed. Clear their saved values too so
    -- a profile cannot retain invisible conditions that no longer appear in
    -- the options page or summary.
    SalveDB.visibility.mounted = nil
    SalveDB.visibility.notMounted = nil

    -- Keep discoveries separate from preferences so a helper can share the
    -- SalveLearnedDB block without exposing layout, bindings or minimap data.
    -- Move existing discoveries over losslessly on the first load after this
    -- change; a partially synced profile may already have both tables.
    SalveLearnedDB = type(SalveLearnedDB) == "table" and SalveLearnedDB or {}
    SalveLearnedDB.auras = type(SalveLearnedDB.auras) == "table" and SalveLearnedDB.auras or {}
    SalveLearnedDB.movement = type(SalveLearnedDB.movement) == "table" and SalveLearnedDB.movement or {}
    for scopeKey, bucket in pairs(type(SalveDB.learned) == "table" and SalveDB.learned or {}) do
        local target = SalveLearnedDB.auras[scopeKey]
        if type(target) ~= "table" then
            SalveLearnedDB.auras[scopeKey] = bucket
        elseif type(bucket.spells) == "table" then
            target.spells = type(target.spells) == "table" and target.spells or {}
            for spellID, record in pairs(bucket.spells) do
                if target.spells[spellID] == nil then target.spells[spellID] = record end
            end
        end
    end
    for spellID, name in pairs(type(SalveDB.learnedMovement) == "table" and SalveDB.learnedMovement or {}) do
        if SalveLearnedDB.movement[spellID] == nil then SalveLearnedDB.movement[spellID] = name end
    end
    SalveDB.learned = nil
    SalveDB.learnedMovement = nil
    SalveLearnedDB.schemaVersion = 1

    -- Click history is intentionally separate from both layout preferences
    -- and learned spells. It is diagnostic evidence, not aura metadata.
    if ns.ClickLog and ns.ClickLog.Init then ns.ClickLog:Init() end

    -- ☠ Learning PERSISTS across logout and /reload. It used to reset itself,
    --   on the theory that a forgotten listener was a hazard -- but in practice
    --   the traffic is light, and for movement-impairing effects learning is
    --   not a diagnostic at all: it is the primary source of data, because
    --   Blizzard's journal only describes boss abilities and dungeon snares
    --   come from trash. Resetting it meant the one category that depends on it
    --   never accumulated anything.

    ns.db = SalveDB
    ns.learned = SalveLearnedDB
    return ns.db
end

-- Keys that change the panel's shape or its secure attributes need a full
-- rebuild; everything else is a restyle.
local GEOMETRY = {
    columns = true, boxWidth = true, boxHeight = true, spacing = true,
    scale = true, showNames = true, showStacks = true, orientation = true,
    horizontalGrowth = true, verticalGrowth = true,
    bindings = true, escapes = true,
    showDispelTypeIcon = true,
    dispelTypeIconSize = true, dispelTypeIconPosition = true,
    -- ☠ visibilityMode belongs here even though it changes no geometry: the
    --   state driver is only (re)registered from Panel:Rebuild, so treating it
    --   as a restyle left the old driver installed. Choosing Never did nothing
    --   until an unrelated roster event happened along.
    visibilityMode = true,
}

function ns.Set(key, value)
    if ns.db[key] == value then return end
    ns.db[key] = value

    if key == "soundEnabled" or key == "dispelSoundEnabled"
        or key == "movementSoundEnabled" or key == "soundChannel" or key == "soundFile" then
        if ns.Sound then ns.Sound:OnSettingChanged(key) end
        return
    end

    if key == "showStartupMessage" then return end

    if key == "selfDispelNotification" then
        if ns.SelfAlert and ns.SelfAlert.Update then ns.SelfAlert:Update() end
        return
    end

    -- Debounced: settings arrive from sliders, which fire on every drag tick.
    -- Events (roster, spec) call ns.RequestRebuild directly and stay immediate.
    if GEOMETRY[key] then
        ns.RequestRebuildSoon()
    elseif ns.Panel and ns.Panel.Restyle then
        ns.Panel:Restyle()
    end

    if (key == "showHandle" or key == "handlePosition") and ns.Handle then
        ns.Handle:Update()
    end
    if key == "showMinimap" and ns.Minimap then ns.Minimap:Update() end
    if ns.Preview and ns.Preview.active then ns.Preview:Refresh() end
end
