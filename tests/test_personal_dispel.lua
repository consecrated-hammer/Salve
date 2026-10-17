local function equal(actual, expected, label)
    assert(actual == expected, label .. ": " .. tostring(actual) .. " ~= " .. tostring(expected))
end
local build, race, known, locked = "70425", "Orc", true, false
local cooldown = { startTime = 0, duration = 0, isEnabled = true }
local secret = {}
issecretvalue = function(value) return value == secret end
GetBuildInfo = function() return "1.60.1", build end
UnitRace = function() return race, race end
UnitClass = function() return "Warrior", "WARRIOR" end
UnitIsUnit = function(unit) return unit == "raid3" end
IsPlayerSpell = function(id) return id == 1299026 and known end
GetTime = function() return 100 end
C_Spell = { GetSpellInfo = function() return { name = "Shatter Curse" } end,
    GetSpellCooldown = function() return cooldown end }
Enum = { CustomAuraButtonDispelTypeTextureStyle = { PreserveAsset = 0 } }
local containers = {}
local function widget()
    local w = { alpha = 0 }
    for _, name in ipairs({ "SetAllPoints", "SetPoint", "SetSize", "SetFrameLevel", "EnableMouse",
        "SetMouseClickEnabled", "SetMouseMotionEnabled", "SetColorTexture", "SetText", "SetTexture" }) do
        w[name] = function() end
    end
    w.SetAlpha = function(self, value) self.alpha = value end
    w.SetScript = function(self, name, handler) self[name] = handler end
    w.GetFrameLevel = function() return 1 end
    w.CreateTexture, w.CreateFontString = widget, widget
    w.AddDispelTypeTexture = function() end
    return w
end
CreateFrame = function(kind)
    local w = widget()
    if kind == "AuraContainer" then
        containers[#containers + 1] = w
        w.AddAuraSlot = function(self, key, filter, options)
            self.filter, self.options = filter, options
            options.initializeFrame(widget())
            return widget()
        end
        w.SetUnit = function(self, unit) self.unit = unit end
        w.SetEnabled = function(self, enabled) self.enabled = enabled end
    end
    return w
end
local ns = { isCamelot = true, db = { bindings = {}, escapes = {} },
    DISPEL_TYPES = { "Magic", "Curse", "Disease", "Poison" },
    StructuralChangesUnsafe = function() return locked end,
    Binding = { Probe = function() return { usable = true } end }, Panel = { boxes = {} } }
assert(loadfile("Features/Dispel.lua"))("Salve", ns)
assert(loadfile("Features/Bindings.lua"))("Salve", ns)
assert(loadfile("Features/PersonalDispel.lua"))("Salve", ns)
local p = ns.PersonalDispel
ns.UpdateDispelSpell()
equal(ns.spellID, nil, "racial cannot become an automatic class dispel")
p:Update()
equal(#p.spells, 1, "racial is discovered on a class without cures")
equal(p:Enabled(), false, "racial starts unbound")
local originalList = ns.Bindings.List
ns.Bindings.List = function() error("readiness must not allocate default bindings") end
equal(p:Enabled(), false, "unbound racial polling skips default binding construction")
ns.Bindings.List = originalList
equal(p:Ready(), false, "unbound racial cannot prompt")
assert(ns.Bindings:SetSpellBinding(1299026, "SHIFT-BUTTON2"))
equal(p:Ready(), true, "bound and ready")
local box = widget()
box.unit = p:CellUnit("raid3")
equal(box.unit, "player", "raid alias is normalised before arming")
local attrs = {}
box.SetAttribute = function(_, key, value) attrs[key] = value end
ns.Panel.boxes = { box }
ns.Bindings:Apply(box)
equal(attrs["shift-type2"], "spell", "player raid alias is armed")
equal(attrs["shift-unit2"], "player", "personal secure action targets self explicitly")
p:Attach(box, box.unit)
equal(containers[1].unit, "player", "aura slot observes self")
equal(containers[1].filter, "HARMFUL", "native harmful filter")
equal(containers[1].options.candidateFilters.includeDispelTypes.Curse, true, "native Curse classification")
equal(box.personalDispelHolder.alpha, 1, "ready wrapper is visible")
locked = true
UnitIsUnit = function() return false end
p:Refresh()
equal(box.personalDispelHolder.alpha, 1, "combat raid reorder leaves the literal player cell on self")
equal(attrs["shift-unit2"], "player", "frozen action still belongs to the player cell")
locked = false
cooldown = { startTime = 90, duration = 180, isEnabled = true }
p:Refresh()
equal(box.personalDispelHolder.alpha, 0, "cooling racial cannot prompt")
cooldown = { startTime = 0, duration = secret, isEnabled = true }
equal(p:Ready(), false, "secret cooldown fails closed")
cooldown = secret
equal(p:Ready(), false, "secret cooldown record is never indexed")
cooldown = { startTime = 0, duration = 0, isEnabled = true }
box.unit = "party1"
p:Refresh()
equal(box.personalDispelHolder.alpha, 0, "roster retarget hides personal cue")
ns.Bindings:Apply(box)
equal(attrs["shift-type2"], nil, "ally cell cannot cast racial")
equal(attrs["shift-unit2"], nil, "retarget clears explicit self attribute")
equal(ns.Bindings:Describe(ns.db.bindings[2], "party1"), nil, "ally tooltip omits racial")
box.unit = "player"
locked = true
local before = #containers
p:Attach(widget(), "player")
equal(#containers, before, "combat never creates aura containers")
locked = false
local failedBox = widget()
failedBox.unit = "player"
local originalCreateFrame = CreateFrame
CreateFrame = function(kind)
    local frame = originalCreateFrame(kind)
    if kind == "AuraContainer" then frame.AddAuraSlot = function() error("unsupported native filter") end end
    return frame
end
p:Attach(failedBox, "player")
CreateFrame = originalCreateFrame
ns.Panel.boxes[#ns.Panel.boxes + 1] = failedBox
p:Refresh()
equal(failedBox.personalDispelHolder.alpha, 0, "a rejected native slot remains suppressed")
assert(p.failure:find("unsupported native filter", 1, true), "native failure is recorded")
ns.Bindings:ClearSpellBinding(1299026)
p:Refresh()
equal(box.personalDispelHolder.alpha, 0, "unbinding suppresses existing cue")
UnitClass = function() return "Mage", "MAGE" end
IsPlayerSpell = function(id) return id == 475 or id == 1299026 end
ns.UpdateDispelSpell()
equal(ns.spellID, 475, "normal Curse cure remains primary")
equal(ns.secondaryID, nil, "racial never becomes a secondary")
equal(#ns.knownDispels, 1, "racial is not part of group cure or sound coverage")
build = "70374"
p:Update()
equal(#p.spells, 0, "older immunity-only builds are excluded")
build, race = "70425", "Human"
p:Update()
equal(#p.spells, 0, "other races excluded")
race, ns.isCamelot = "Orc", false
p:Update()
equal(#p.spells, 0, "Retail excluded")
print("personal dispel tests passed")
