local addonName, ns = ...

local PET_BY_OWNER = {
    player = "pet",
    party1 = "partypet1", party2 = "partypet2", party3 = "partypet3", party4 = "partypet4",
}

function ns.MonitoredPetUnit(owner)
    local unit = PET_BY_OWNER[owner]
    local db = ns.db
    if not unit or not db or IsInRaid() or not ns.CanDispel() then return nil end
    if owner == "player" then
        return db.showOwnPet and unit or nil
    end
    if db.showPartyPets and IsInGroup() then return unit end
end

function ns.AppendMonitoredPets(units)
    local ownPet = ns.MonitoredPetUnit("player")
    if ownPet and UnitExists(ownPet) then units[#units + 1] = ownPet end
    for i = 1, 4 do
        local pet = ns.MonitoredPetUnit("party" .. i)
        if pet and UnitExists(pet) then units[#units + 1] = pet end
    end
end
