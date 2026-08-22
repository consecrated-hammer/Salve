local function equal(actual, expected, label)
    if actual ~= expected then
        error(("%s: expected %s, got %s"):format(
            label, tostring(expected), tostring(actual)))
    end
end

local objects, named, dropdown, dropdowns
objects, named, dropdowns = {}, {}, {}

local methods = {}
local function object(name, template)
    local value = setmetatable({
        name = name,
        template = template,
        scripts = {},
        shown = true,
    }, { __index = methods })
    objects[#objects + 1] = value
    if name then named[name] = value end
    return value
end

function methods:CreateFontString() return object() end
function methods:CreateTexture() return object() end
function methods:SetScript(name, callback) self.scripts[name] = callback end
function methods:HookScript(name, callback) self.scripts[name] = callback end
function methods:SetShown(value)
    if value then self:Show() else self:Hide() end
end
function methods:Show()
    local changed = not self.shown
    self.shown = true
    if changed and self.scripts.OnShow then self.scripts.OnShow(self) end
end
function methods:Hide()
    local changed = self.shown
    self.shown = false
    if changed and self.scripts.OnHide then self.scripts.OnHide(self) end
end
function methods:IsShown() return self.shown end
function methods:SetChecked(value) self.checked = value end
function methods:GetChecked() return self.checked end
function methods:SetDefaultText(value) self.defaultText = value end
function methods:SetText(value) self.text = value end
function methods:GetFrameLevel() return 1 end
function methods:GetVerticalScrollRange() return 0 end
function methods:GetVerticalScroll() return 0 end
function methods:GetID() return self.name end
function methods:SetupMenu(callback)
    local description = {}
    function description:CreateDivider() end
    function description:CreateTitle(label)
        self[#self + 1] = { kind = "title", label = label }
    end
    function description:CreateRadio(label, get, set)
        self[#self + 1] = { kind = "radio", label = label, get = get, set = set }
    end
    function description:CreateCheckbox(label, get, set)
        self[#self + 1] = { kind = "checkbox", label = label, get = get, set = set }
    end
    callback(self, description)
    self.menu = description
end

for _, name in ipairs({
    "SetSize", "SetPoint", "ClearAllPoints", "SetWidth", "SetHeight",
    "SetOrientation", "SetMinMaxValues", "SetValueStep", "SetObeyStepOnDrag",
    "SetValue", "SetHitRectInsets", "SetTextColor", "SetJustifyH", "SetJustifyV",
    "SetTexCoord", "SetTexture", "SetColorTexture", "SetAllPoints", "SetFrameStrata",
    "SetFrameLevel", "SetBackdrop", "SetBackdropColor", "SetBackdropBorderColor",
    "EnableMouse", "EnableMouseWheel", "SetScrollChild", "SetVerticalScroll",
    "SetMultiLine", "SetAutoFocus", "SetFontObject", "SetTextInsets", "SetFocus",
    "ClearFocus", "HighlightText", "SetEnabled", "RegisterEvent", "UnregisterEvent",
    "SetClampedToScreen", "RegisterForDrag", "StartMoving", "StopMovingOrSizing",
    "SetMovable", "Raise",
}) do
    methods[name] = function() end
end

CreateFrame = function(_, name, _, template)
    local frame = object(name, template)
    if template == "WowStyle1DropdownTemplate" then
        dropdown = frame
        dropdowns[#dropdowns + 1] = frame
    end
    return frame
end

UIParent = object("UIParent")
GameTooltip = {
    SetOwner = function() end,
    SetText = function() end,
    AddLine = function() end,
    Show = function() end,
    Hide = function() end,
    IsOwned = function() return false end,
}
InterfaceOptions_AddCategory = function() end
GetNumGroupMembers = function() return 0 end
C_Spell = { GetSpellTexture = function() return 134400 end }

local ns = {
    VERSION = "1.4.0",
    REVISION = "test-settings",
    DISPELLABLE_FILTER = "HARMFUL",
    defaults = {
        orientation = "HORIZONTAL", columns = 5, spacing = 1, scale = 1,
        boxWidth = 20, boxHeight = 20, showTooltip = true, showNames = false,
        nameJustifyH = "LEFT", nameJustifyV = "MIDDLE", nameFontSize = 11,
        cooldownJustifyH = "CENTER", cooldownJustifyV = "MIDDLE",
        cooldownFontSize = 14, showStacks = true, showWhenClean = true,
        cleanAlpha = 0.25, useClassColours = false, showHandle = true,
        handlePosition = "TOPLEFT", showMinimap = true, showStartupMessage = true,
        visibilityMode = "ALWAYS", soundEnabled = false, soundChannel = "Master",
        soundFile = nil, point = { "CENTER", "CENTER", 0, -140 },
        settingsPoint = { "CENTER", "CENTER", 0, 0 },
        horizontalGrowth = "RIGHT", verticalGrowth = "DOWN",
    },
    db = {
        orientation = "HORIZONTAL", columns = 5, spacing = 1, scale = 1,
        boxWidth = 20, boxHeight = 20, showTooltip = true, showNames = false,
        nameJustifyH = "LEFT", nameJustifyV = "MIDDLE", nameFontSize = 11,
        cooldownJustifyH = "CENTER", cooldownJustifyV = "MIDDLE",
        cooldownFontSize = 14, showStacks = true, showWhenClean = true,
        cleanAlpha = 0.25, useClassColours = false, showHandle = true,
        handlePosition = "TOPLEFT", showMinimap = true, showStartupMessage = true,
        visibilityMode = "ALWAYS", visibility = {}, soundEnabled = false,
        soundChannel = "Master", bindings = {}, escapes = {},
        settingsPoint = { "CENTER", "CENTER", 0, 0 },
        horizontalGrowth = "RIGHT", verticalGrowth = "DOWN",
    },
    VIS_CONDITIONS = {
        { key = "inCombat", label = "In combat" },
        { key = "inParty", label = "In a party" },
    },
    knownDispels = {
        { id = 4987, name = "Cleanse", cures = { Magic = true } },
    },
    knownEscapes = {
        { id = 1044, name = "Blessing of Freedom", scope = "ALLY", note = "" },
    },
}

function ns.Set(key, value) ns.db[key] = value end
function ns.RequestRebuildSoon() end
function ns.CuresText() return "Magic" end
function ns.GetMetadata() return "test" end
function ns.Print() end

ns.ESCAPE_ALLY = "ALLY"
ns.Visibility = {
    Summary = function()
        if ns.db.visibilityMode == "NEVER" then return "Never" end
        if ns.db.visibility.inCombat then return "In combat" end
        return "Always"
    end,
}
local previewStops = 0
ns.Preview = {
    active = false,
    Toggle = function(self) self.active = not self.active end,
    Refresh = function() end,
    Stop = function(self)
        if not self.active then return end
        previewStops = previewStops + 1
        self.active = false
    end,
}
ns.Panel = { ApplyPosition = function() end }
ns.Minimap = { Update = function() end }
ns.Sound = {
    activeScopeName = "Test Zone", activeScopeKey = "map:1",
    activeInstanceName = "World", activeInstanceID = 0,
    registered = 0, expected = 0,
    NeedsData = function() return true end,
    ActiveRecords = function() return {} end,
    CurrentCures = function() return { Magic = true } end,
    ActivateCurrentInstance = function() end,
    Test = function() return true end,
    Report = function() end,
}
ns.Binding = {
    boundCount = 1, containersBuilt = 1,
    Probe = function()
        return { usable = true, methods = {
            SetUnit = true, AddAuraSlot = true, SetEnabled = true,
            UpdateAllAuras = true,
        } }
    end,
    CooldownDiagnosticLines = function() return {} end,
    Report = function() end,
}
local bindings = { { key = "BUTTON1" } }
ns.Bindings = {
    List = function() return bindings end,
    Materialise = function() return bindings end,
    KeysForSpell = function(_, spellID)
        return spellID == 4987 and { "BUTTON1" } or {}
    end,
    SetSpellBinding = function() return true end,
    ClearSpellBinding = function() end,
    Describe = function() return "Cleanse (automatic)", 134400 end,
    Label = function() return "Left click" end,
    Capture = function(_, button) return button end,
}

assert(loadfile("Options/Shared.lua"))("Salve", ns)
for _, path in ipairs({
    "Options/Salve.lua", "Options/Visibility.lua", "Options/Dispel.lua",
    "Options/Troubleshooting.lua", "Options/Commands.lua", "Options/About.lua",
}) do
    assert(loadfile(path))("Salve", ns)
end

ns.Options.BuildAll()
equal(ns.Options.window.name, "SalveSettingsFrame",
    "movable settings window is constructed")

local function findText(text)
    for _, value in ipairs(objects) do
        if value.text == text then return value end
    end
end

local unitsLabel = findText("Units")
equal(unitsLabel.shown, false, "preview details start hidden")
local showPreview = findText("Show preview")
showPreview.scripts.OnClick()
equal(unitsLabel.shown, true, "preview details show with live preview")
showPreview.scripts.OnClick()
equal(unitsLabel.shown, false, "preview details hide with live preview")

local pageCount = 0
for _ in pairs(ns.Options.pages) do pageCount = pageCount + 1 end
equal(pageCount, 6, "all six pages live in the movable window")
equal(dropdown.template, "WowStyle1DropdownTemplate",
    "Show Salve uses Blizzard's native dropdown template")
equal(dropdown.defaultText, "Always", "native dropdown shows visibility summary")

local nativeText = {}
for _, frame in ipairs(dropdowns) do nativeText[frame.defaultText] = true end
equal(nativeText.Rows, true, "grid fill uses a native Rows dropdown")
equal(nativeText.Left, true, "grid growth uses a native Left dropdown")

for _, item in ipairs(dropdown.menu) do
    if item.label == "Never" then item.set() end
end
equal(ns.db.visibilityMode, "NEVER", "native Never choice sets base mode")

for _, item in ipairs(dropdown.menu) do
    if item.label == "In combat" then item.set() end
end
equal(ns.db.visibilityMode, "ALWAYS", "condition leaves Never mode")
equal(ns.db.visibility.inCombat, true, "native checkbox stores condition")

for _, frame in pairs(named) do
    if frame.scripts.OnShow then frame.scripts.OnShow(frame) end
end

ns.OpenOptions("Visibility")
equal(ns.Options.window.shown, true, "direct settings command opens movable window")
equal(ns.Options.selectedPage, "Visibility", "requested custom page is selected")
ns.Preview.active = true
ns.Options.ShowPage("Dispels")
equal(ns.Preview.active, true, "preview persists while navigating settings pages")
equal(previewStops, 0, "page navigation does not stop preview")
ns.Options.window:Hide()
equal(ns.Preview.active, false, "closing settings stops preview")
equal(previewStops, 1, "settings window owns preview teardown")

ns.db.showNames = true
ns.db.showWhenClean = false
ns.db.showHandle = false
ns.db.soundEnabled = true
for _, frame in pairs(named) do
    if frame.scripts.OnShow then frame.scripts.OnShow(frame) end
end

print("options build smoke tests passed")
