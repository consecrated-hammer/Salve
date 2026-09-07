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
local tooltipTitle, tooltipSpellID, tooltipAnchor
GameTooltip = {
    SetOwner = function(_, _, anchor) tooltipAnchor = anchor end,
    SetText = function(_, title)
        if type(title) ~= "string" then error("tooltip title must be text") end
        tooltipTitle = title
    end,
    SetSpellByID = function(_, spellID) tooltipSpellID = spellID end,
    AddLine = function() end,
    Show = function() end,
    Hide = function() end,
    IsOwned = function() return false end,
}
InterfaceOptions_AddCategory = function() end
GetNumGroupMembers = function() return 0 end
C_Spell = { GetSpellTexture = function() return 134400 end }

local ns = {
    VERSION = "1.4.1",
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
        tooltipUnitInfo = false, tooltipActions = true, tooltipSpellDescriptions = false,
        showDispelTypeIcon = true, dispelTypeIconSize = 20,
        dispelTypeIconPosition = "BOTTOMLEFT",
        visibilityMode = "ALWAYS", soundEnabled = false, dispelSoundEnabled = false,
        movementSoundEnabled = false, movementTextNotification = true,
        selfDispelNotification = true, soundChannel = "Master",
        soundFile = nil, movementColour = { r = 0.92, g = 0.20, b = 0.08, a = 0.68 },
        point = { "CENTER", "CENTER", 0, -140 },
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
        tooltipUnitInfo = false, tooltipActions = true, tooltipSpellDescriptions = false,
        showDispelTypeIcon = true, dispelTypeIconSize = 20,
        dispelTypeIconPosition = "BOTTOMLEFT",
        visibilityMode = "ALWAYS", visibility = {}, soundEnabled = false,
        dispelSoundEnabled = false, movementSoundEnabled = false, movementTextNotification = true,
        selfDispelNotification = true, soundChannel = "Master", bindings = {}, escapes = {},
        movementSweepSpellIDs = { [1044] = true }, movementSweepColours = {},
        movementColour = { r = 0.2, g = 0.3, b = 0.4, a = 0.5 },
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
    SpellID = function(_, entry) return entry.spell or 4987 end,
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
    "Options/Salve.lua", "Options/Tooltips.lua", "Options/Dispel.lua", "Options/Visibility.lua",
    "Options/Alerts.lua",
    "Options/Commands.lua", "Options/Troubleshooting.lua", "Options/LearnedSpells.lua", "Options/About.lua",
}) do
    assert(loadfile(path))("Salve", ns)
end

ns.Options.BuildAll()
equal(ns.Options.window.name, "SalveSettingsFrame",
    "movable settings window is constructed")
equal(ns.db.movementSweepSpellIDs[1044], true,
    "options build preserves saved sweep selections before spell discovery")

local dynamicHint
for _, value in ipairs(objects) do
    if type(value.salveHintTitle) == "function" and value.scripts.OnEnter then
        dynamicHint = value
        break
    end
end
if not dynamicHint then error("dynamic layout hint was not built") end
dynamicHint.scripts.OnEnter(dynamicHint)
equal(tooltipTitle, "Cells per row", "dynamic tooltip resolves its label before SetText")
equal(tooltipAnchor, "ANCHOR_CURSOR", "settings hints stay at the cursor over live previews")

local spellHint
for _, value in ipairs(objects) do
    if value.salveSpellID == 4987 and value.scripts.OnEnter then
        spellHint = value
        break
    end
end
if not spellHint then error("spell hover tooltip was not built") end
spellHint.scripts.OnEnter(spellHint)
equal(tooltipSpellID, 4987, "action palette opens the native spell tooltip")

local function findText(text)
    for _, value in ipairs(objects) do
        if value.text == text then return value end
    end
end

local unitsLabel = findText("Units")
equal(unitsLabel.shown, true, "in-settings preview controls are always visible")
local showPreview
for _, value in ipairs(objects) do
    if value.Text and value.Text.text == "Preview settings on screen" then
        showPreview = value
        break
    end
end
if not showPreview then error("on-screen preview checkbox was not built") end
showPreview.scripts.OnClick()
equal(unitsLabel.shown, true, "in-settings preview remains available with live preview")
showPreview.scripts.OnClick()
equal(unitsLabel.shown, true, "in-settings preview remains available after live preview closes")

local function findButtonWithLabel(label)
    for _, value in ipairs(objects) do
        if value.Text and value.Text.text == label then return value end
    end
end
local previewDispellable = findButtonWithLabel("Preview dispellable")
previewDispellable.scripts.OnClick(previewDispellable)
equal(ns.Preview.cellState, "CLEAR", "preview dispellable checkbox clears the simulated effect")
previewDispellable.scripts.OnClick(previewDispellable)
equal(ns.Preview.cellState, "DISPELLABLE", "preview dispellable checkbox restores the simulated effect")

local previewCooldown = findButtonWithLabel("Preview on cooldown")
previewCooldown.scripts.OnClick(previewCooldown)
equal(ns.Preview.cooldownState, "READY", "preview cooldown checkbox clears the simulated cooldown")
previewCooldown.scripts.OnClick(previewCooldown)
equal(ns.Preview.cooldownState, "COOLDOWN", "preview cooldown checkbox restores the simulated cooldown")

local namedPreset = findText("Named")
namedPreset.scripts.OnClick()
equal(ns.db.boxWidth, 95, "Named preset sets cell width")
equal(ns.db.boxHeight, 20, "Named preset sets cell height")
equal(ns.db.columns, 5, "Named preset sets cells per row")
equal(ns.db.spacing, 1, "Named preset sets spacing")
equal(ns.db.showNames, true, "Named preset shows names")
equal(ns.db.showTooltip, true, "Named preset preserves tooltip setting")
equal(ns.db.scale, 1, "Named preset preserves scale")
equal(ns.Preview.count, 5, "Named preset previews five units")

local raidWallPreset = findText("Raid wall")
raidWallPreset.scripts.OnClick()
equal(ns.db.columns, 10, "Raid wall preset sets ten cells per row")
equal(ns.db.spacing, 0, "Raid wall preset removes cell gaps")
equal(ns.db.showNames, false, "Raid wall preset hides names")
equal(ns.Preview.count, 40, "Raid wall preset previews forty units")

local pageCount = 0
for _ in pairs(ns.Options.pages) do pageCount = pageCount + 1 end
equal(pageCount, 9, "all nine pages live in the movable window")
equal(ns.Options.pages.Alerts ~= nil, true, "Alerts page is built")
equal(ns.Options.pages.Tooltips ~= nil, true, "Tooltips page is built")
equal(findText("Right of cell") ~= nil, true,
    "Tooltips anchor dropdown supplies its current display label")
equal(findText("Show spell IDs") == nil, true,
    "Tooltips page omits developer-only spell IDs")
equal(findText("Show privacy note") == nil, true,
    "Tooltips page omits the redundant privacy note")
equal(findText("Show Salve actions") ~= nil, true,
    "Tooltips page offers control over the Salve action list")
equal(findText("Show actions heading") == nil, true,
    "Tooltips page omits the redundant actions-heading switch")
equal(findText("Show dispel-type icon") ~= nil, true,
    "Panel page offers the native dispel marker")
equal(findText("Show self-dispel combat text") ~= nil, true,
    "Alerts page offers the optional self-dispel instruction")
equal(findText("Show Freedom movement text") ~= nil, true,
    "Alerts page offers the optional Freedom instruction")
local dispelIconPosition = findText("Bottom left")
equal(dispelIconPosition.salveDropdown, true,
    "Dispel icon position uses Salve's dark dismissible dropdown")
local visibilityMenu
for _, value in ipairs(objects) do
    if value.Text and value.Text.text == "Always" then
        visibilityMenu = value
        break
    end
end
equal(visibilityMenu.template, "BackdropTemplate",
    "Show Salve uses Salve's bordered custom select control")

for _, frame in pairs(named) do
    if frame.scripts.OnShow then frame.scripts.OnShow(frame) end
end

ns.OpenOptions("Visibility")
equal(ns.Options.window.shown, true, "direct settings command opens movable window")
equal(ns.Options.selectedPage, "Visibility", "requested custom page is selected")
ns.Preview.active = true
ns.Options.ShowPage("Actions")
equal(ns.Preview.active, true, "preview persists while navigating settings pages")
equal(previewStops, 0, "page navigation does not stop preview")
ns.Options.ShowPage("Alerts")
equal(ns.Options.selectedPage, "Alerts", "Alerts page is selectable")
equal(ns.Options.pages.Alerts.shown, true, "Alerts page is shown")
ns.Options.ShowPage("Visibility")
equal(ns.Options.selectedPage, "Visibility", "Visibility identifier still opens Visibility")
equal(ns.Options.pages.Visibility.shown, true, "Visibility page is shown")
ns.Options.ShowPage("not a Salve page")
equal(ns.Options.selectedPage, "Salve", "unknown page falls back to Panel")
equal(ns.Options.pages.Salve.shown, true, "Panel is shown for an unknown page")

local resetAlerts = findText("Reset Alerts")
resetAlerts.scripts.OnClick()
equal(ns.db.dispelSoundEnabled, false, "Reset Alerts restores dispel sound default")
equal(ns.db.movementSoundEnabled, false, "Reset Alerts restores snare-removal sound default")
equal(ns.db.movementTextNotification, true, "Reset Alerts restores Freedom movement text default")
equal(ns.db.selfDispelNotification, true, "Reset Alerts restores self-dispel instruction")
equal(ns.db.soundChannel, "Master", "Reset Alerts restores sound channel default")
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
