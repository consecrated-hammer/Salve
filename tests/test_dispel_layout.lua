local function equal(actual, expected, label)
    if actual ~= expected then
        error(("%s: expected %s, got %s"):format(
            label, tostring(expected), tostring(actual)))
    end
end

local ns = {
    Options = {
        NewPage = function() end,
    },
}

assert(loadfile("Options/Dispel.lua"))("Salve", ns)

local first = ns.Options.DispelLayout(-36, 1, 2)
local revisit = ns.Options.DispelLayout(-36, 1, 2)
equal(first.escapeTop, revisit.escapeTop,
    "first visit and repeat visit use identical escape position")
equal(first.buttonsTop, revisit.buttonsTop,
    "first visit and repeat visit use identical footer position")

local none = ns.Options.DispelLayout(-36, 0, 0)
local one = ns.Options.DispelLayout(-36, 1, 1)
equal(none.buttonsTop, one.buttonsTop,
    "empty states reserve exactly one explanatory row")

local twoEscapes = ns.Options.DispelLayout(-36, 1, 2)
local threeEscapes = ns.Options.DispelLayout(-36, 1, 3)
equal(threeEscapes.buttonsTop, twoEscapes.buttonsTop - 32,
    "each detected escape adds exactly one row")

local twoDispels = ns.Options.DispelLayout(-36, 2, 2)
equal(twoDispels.buttonsTop, twoEscapes.buttonsTop - 32,
    "each detected dispel adds exactly one inline binding row")

print("dispel layout tests passed")
