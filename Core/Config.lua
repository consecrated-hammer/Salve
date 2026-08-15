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
    showStacks    = true,   -- engine-driven; Blizzard hides it at one stack
    showWhenClean = true,
    cleanAlpha    = 0.25,
    showHandle    = true,   -- the persistent drag grip, like Decursive's

    -- Behaviour
    -- Click bindings. Empty means "use the defaults" (left = primary dispel,
    -- right = secondary), which is how a fresh install and a spec change both
    -- stay sensible. See Features/Bindings.lua.
    bindings      = {},

    -- HORIZONTAL fills a row then wraps to the next; VERTICAL fills a column
    -- then wraps to the next. `columns` is the wrap point either way.
    orientation   = "HORIZONTAL",

    -- ALWAYS | NEVER, combined with the conditions below. See
    -- Features/Visibility.lua for why this is a state driver and not Show/Hide.
    visibilityMode = "ALWAYS",
    visibility     = {},

    -- Alert sound. Spell IDs come from a companion addon (Salve_SeasonData);
    -- see Features/Sound.lua for why this cannot be driven by a filter.
    soundEnabled  = false,
    soundChannel  = "Master",
    soundFile     = nil,

    -- Learn mode is ADDITIVE and on by default: anything the season data misses
    -- gets picked up by playing, and what it finds persists here.
    learnMode     = true,
    learned       = {},

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
    SalveDB = copyDefaults(SalveDB or {}, ns.defaults)
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

    -- Debounced: settings arrive from sliders, which fire on every drag tick.
    -- Events (roster, spec) call ns.RequestRebuild directly and stay immediate.
    if GEOMETRY[key] then
        ns.RequestRebuildSoon()
    elseif ns.Panel and ns.Panel.Restyle then
        ns.Panel:Restyle()
    end

    if key == "showHandle" and ns.Handle then ns.Handle:Update() end
    if key == "showMinimap" and ns.Minimap then ns.Minimap:Update() end
end
