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

    -- Appearance
    showNames     = false,
    -- Who you are pointing at and what each click does. On by default: the
    -- bindings are configurable, so without it there is nothing on screen that
    -- says what a box will cast.
    showTooltip   = true,
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
    -- Click bindings. Empty means "use the defaults" (left = primary dispel,
    -- plus right = secondary only when it is a genuinely different spell),
    -- which is how a fresh install and a spec change both stay sensible.
    bindings      = {},

    -- HORIZONTAL fills a row then wraps to the next; VERTICAL fills a column
    -- then wraps to the next. `columns` is the wrap point either way.
    orientation   = "HORIZONTAL",

    -- ALWAYS | NEVER, combined with the conditions below. See
    -- Features/Visibility.lua for why this is a state driver and not Show/Hide.
    visibilityMode = "ALWAYS",
    visibility     = {},

    -- Alert sound. Typed spell IDs come from the bundled load-on-demand
    -- Salve_Data_* module for the current instance.
    soundEnabled  = false,
    soundChannel  = "Master",
    soundFile     = nil,

    -- Learning is a diagnostic capture mode, never normal combat work. It is
    -- deliberately opt-in, session-only, and scoped to the current location
    -- and group units in Sound.lua.
    learnMode     = false,

    -- Movement-impairment category. `escapes` is the set of your own spells you
    -- have opted in to (keyed by spell ID); `learnedMovement` is the set of
    -- root/snare spell IDs captured with /salve snared.
    escapes         = {},
    learnedMovement = {},
    learned       = {},

    -- Saved-variable migrations. Increment only when an old shape needs an
    -- explicit conversion; ordinary new defaults do not need a bump.
    schemaVersion = 4,

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

function ns.InitConfig()
    SalveDB = SalveDB or {}
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

    -- Normalize on every load, not only at the schema boundary. A profile can
    -- reach schema 4 before an older synced Options file finishes writing its
    -- duplicate rows. Secure attributes can hold only one action per mouse
    -- chord, so duplicates are never meaningful and are safe to collapse.
    local deduped, seen = {}, {}
    for _, entry in ipairs(type(SalveDB.bindings) == "table" and SalveDB.bindings or {}) do
        local key = type(entry) == "table" and entry.key
        if type(key) ~= "string" or not seen[key] then
            deduped[#deduped + 1] = entry
            if type(key) == "string" then seen[key] = true end
        end
    end
    SalveDB.bindings = deduped

    -- These visibility choices were removed. Clear their saved values too so
    -- a profile cannot retain invisible conditions that no longer appear in
    -- the options page or summary.
    SalveDB.visibility.mounted = nil
    SalveDB.visibility.notMounted = nil

    -- ☠ Learning PERSISTS across logout and /reload. It used to reset itself,
    --   on the theory that a forgotten listener was a hazard -- but in practice
    --   the traffic is light, and for movement-impairing effects learning is
    --   not a diagnostic at all: it is the primary source of data, because
    --   Blizzard's journal only describes boss abilities and dungeon snares
    --   come from trash. Resetting it meant the one category that depends on it
    --   never accumulated anything.

    ns.db = SalveDB
    return ns.db
end

-- Keys that change the panel's shape or its secure attributes need a full
-- rebuild; everything else is a restyle.
local GEOMETRY = {
    columns = true, boxWidth = true, boxHeight = true, spacing = true,
    scale = true, showNames = true, showStacks = true, orientation = true,
    bindings = true,
    -- ☠ visibilityMode belongs here even though it changes no geometry: the
    --   state driver is only (re)registered from Panel:Rebuild, so treating it
    --   as a restyle left the old driver installed. Choosing Never did nothing
    --   until an unrelated roster event happened along.
    visibilityMode = true,
}

function ns.Set(key, value)
    if ns.db[key] == value then return end
    ns.db[key] = value

    if key == "soundEnabled" or key == "soundChannel" or key == "soundFile" then
        if ns.Sound then ns.Sound:OnSettingChanged(key) end
        return
    end

    if key == "showStartupMessage" then return end

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
end
