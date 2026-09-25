local addonName, ns = ...
local Options = ns.Options

-- Page files are loaded before SavedVariables are available. This module owns
-- their lifecycle; Shared.lua deliberately owns only reusable UI controls.
Options.queue = {}

function Options.NewPage(spec, build)
    if type(spec) == "string" then spec = { name = spec } end
    spec.build = build
    Options.queue[#Options.queue + 1] = spec
end

function Options.BuildAll()
    Options.CreateWindow()
    Options.CreateLauncher()
    Options.queue = {}
end

-- ADDON_LOADED is the normal construction point, after saved variables exist.
-- If it is interrupted, an explicit open gets one safe retry and a readable
-- failure instead of a dead slash command.
function Options.EnsureBuilt()
    if Options.window then return true end
    local ok, err = pcall(Options.BuildAll)
    if ok and Options.window then
        Options.buildError = nil
        return true
    end
    Options.buildError = tostring(err or "settings window was not created")
    return false
end

function ns.OpenOptions(pageName)
    if not Options.EnsureBuilt() then
        ns.Print("settings could not be built: "
            .. tostring(Options.buildError or "unknown error"))
        return
    end
    if SettingsPanel and SettingsPanel.IsShown and SettingsPanel:IsShown() then
        if HideUIPanel then HideUIPanel(SettingsPanel) else SettingsPanel:Hide() end
    end
    Options.ShowPage(pageName)
    Options.window:Show()
    Options.window:Raise()
end
