-- The role and raid-marker icon: what it shows, where it sits, and that it
-- never compares a secret role or marker.
local wow = dofile("tests/hammercore/wow.lua")
wow.Install()

local function equal(actual, expected, label)
    if actual ~= expected then
        error(("%s: expected %s, got %s"):format(label, tostring(expected), tostring(actual)))
    end
end

local ns = { db = {
    roleIcon = "BOTH", roleIconRoles = "TANKHEALER", roleIconPosition = "TOPRIGHT",
    roleIconPlacement = "EDGE", roleIconSize = 10,
    dispelTypeIconPosition = "BOTTOMLEFT", lockoutIconPosition = "TOPLEFT",
} }
assert(loadfile("UI/Box.lua"))("Salve", ns)
local Box = ns.Box

-- Anchors.
local p, r = Box.RoleBadgeAnchor("TOPRIGHT", "EDGE")
equal(p, "RIGHT", "edge keeps the icon inside horizontally"); equal(r, "TOPRIGHT", "edge sits on the top border")
p, r = Box.RoleBadgeAnchor("BOTTOMLEFT", "EDGE")
equal(p, "LEFT", "bottom-left edge point"); equal(r, "BOTTOMLEFT", "bottom-left edge relative")
p, r = Box.RoleBadgeAnchor("TOPLEFT", "CORNER")
equal(p, "CENTER", "corner centres on the point"); equal(r, "TOPLEFT", "corner relative")
p, r = Box.RoleBadgeAnchor("BOTTOMRIGHT", "INSIDE")
equal(p, "BOTTOMRIGHT", "inside point"); equal(r, "BOTTOMRIGHT", "inside relative")

-- Content by mode.
local kind, value = Box.RoleBadgeContent("TANK", 8)
equal(kind, "MARKER", "marker wins when set"); equal(value, 8, "marker index")
kind, value = Box.RoleBadgeContent("HEALER", nil)
equal(kind, "ROLE", "falls back to role"); equal(value, "HEALER", "role value")
equal(Box.RoleBadgeContent("DAMAGER", nil), nil, "DPS hidden with tank and healer only")
equal(Box.RoleBadgeContent("DAMAGER", 2), "MARKER", "markers aren't filtered by role")
ns.db.roleIconRoles = "ALL"
equal(Box.RoleBadgeContent("DAMAGER", nil), "ROLE", "DPS shown with All")
ns.db.roleIcon = "ROLE"
equal(Box.RoleBadgeContent("TANK", 8), "ROLE", "role mode ignores markers")
ns.db.roleIcon = "MARKER"
equal(Box.RoleBadgeContent("TANK", nil), nil, "marker mode shows nothing without one")
ns.db.roleIcon = "OFF"
equal(Box.RoleBadgeContent("TANK", 8), nil, "off shows nothing")

-- Secret or missing values become nil rather than erroring on comparison.
local secret = {}
issecretvalue = function(v) return v == secret end
UnitGroupRolesAssigned = function() return secret end
GetRaidTargetIndex = function() return secret end
equal(Box.UnitRole("party1"), nil, "secret role reads as none")
equal(Box.UnitMarker("party1"), nil, "secret marker reads as none")
UnitGroupRolesAssigned = function() return "NONE" end
ns.Panel = { PlayerSpecRole = function() return "HEALER" end }
equal(Box.UnitRole("player"), "HEALER", "your own role falls back to spec")
equal(Box.UnitRole("party1"), nil, "others don't use your spec")
GetRaidTargetIndex = function() return 3 end
equal(Box.UnitMarker("party1"), 3, "readable marker")
GetRaidTargetIndex = function() error("restricted") end
equal(Box.UnitMarker("party1"), nil, "a failing lookup reads as none")

-- Drawing on a box, and the movement badge taking the same corner.
ns.db.roleIcon = "BOTH"
local box = CreateFrame("Button", nil, UIParent)
box:SetSize(20, 20)
C_Texture = { GetAtlasInfo = function() return nil end }
Box.ShowRoleBadge(box, "TANK", nil)
equal(box.roleBadge:IsShown(), true, "role icon shows")
equal(box.roleBadge.texture.texture, "Interface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES", "missing atlas uses the roles sheet")
equal(box.roleBadge:GetPoint(), "RIGHT", "default placement is on edge")
Box.ShowRoleBadge(box, "TANK", 8)
equal(box.roleBadge.texture.texture, "Interface\\TargetingFrame\\UI-RaidTargetingIcon_8", "skull texture")

Box.SetMovementPrompt(box, true, nil)
equal(Box.MovementBadgePosition(), "TOPRIGHT", "badge defaults top right")
equal(box.roleBadge:IsShown(), false, "movement badge takes the shared corner")
Box.SetMovementPrompt(box, false)
equal(box.roleBadge:IsShown(), true, "role icon returns when the badge clears")
ns.db.roleIconPosition = "BOTTOMRIGHT"
Box.SetMovementPrompt(box, true, nil)
equal(box.roleBadge:IsShown(), true, "different corners both show")

box.unit = nil
Box.UpdateRoleBadge(box)
equal(box.roleBadge:IsShown(), false, "an empty box hides the icon")

print("role badge tests passed")
