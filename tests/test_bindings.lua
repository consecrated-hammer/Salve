local function equal(actual, expected, label)
    if actual ~= expected then
        error(("%s: expected %s, got %s"):format(label, tostring(expected), tostring(actual)))
    end
end

local ns = {
    db = { bindings = {} },
    spellName = "Cleanse",
    knownDispels = {},
}

assert(loadfile("Features/Bindings.lua"))("Salve", ns)

local defaults = ns.Bindings:List()
equal(#defaults, 1, "one detected dispel gets one default binding")
equal(defaults[1].key, "BUTTON1", "primary dispel defaults to left click")

ns.secondaryName = "Cauterizing Flame"
defaults = ns.Bindings:List()
equal(#defaults, 2, "distinct secondary dispel gets a second binding")
equal(defaults[2].key, "BUTTON2", "secondary dispel defaults to right click")

ns.secondaryName = "Cleanse"
equal(#ns.Bindings:List(), 1, "duplicate secondary spell is not exposed")

print("binding tests passed")
