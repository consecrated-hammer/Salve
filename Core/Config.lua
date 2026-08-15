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
    showInSolo    = true,
    showInParty   = true,
    showInRaid    = true,
    -- Which spell each mouse button casts. 0 = whatever detection chose;
    -- -1 = target the unit; -2 = do nothing; anything else is a spell ID.
    leftSpell     = 0,
    rightSpell    = 0,

    -- HORIZONTAL fills a row then wraps to the next; VERTICAL fills a column
    -- then wraps to the next. `columns` is the wrap point either way.
    orientation   = "HORIZONTAL",

    -- Alert sound. Off until /salve probe confirms the hook actually fires.
    soundEnabled  = false,
    soundThrottle = 2,
    soundChannel  = "Master",

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
    leftSpell = true, rightSpell = true,
    showInSolo = true, showInParty = true, showInRaid = true,
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
