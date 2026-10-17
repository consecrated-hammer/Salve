local addonName, ns = ...

-- Optional personal cures are deliberately separate from class-wide dispels.
-- Never add their schools to Sound:CurrentCures or automatic click roles.
ns.PersonalDispel = { spells = {} }
local Personal = ns.PersonalDispel
local SHATTER_CURSE = 1299026

function Personal:Fail(message)
    self.failure = message
    if not self.warnedFailure and ns.Print then
        self.warnedFailure = true
        ns.Print("Personal dispel cue could not bind. Its click still works; see /salve debug. Reload after checking the client API.")
    end
end

local function plain(value)
    if issecretvalue and issecretvalue(value) then return nil end
    return value
end

function Personal:IsPlayer(unit)
    if unit == "player" then return true end
    if type(unit) ~= "string" or not UnitIsUnit then return false end
    local ok, same = pcall(UnitIsUnit, unit, "player")
    return ok and plain(same) == true
end

function Personal:Update()
    local previous = self.spells[1] and self.spells[1].id
    self.spells = {}
    local build
    if GetBuildInfo then local _, current = GetBuildInfo(); build = tonumber(plain(current)) end
    local race
    if UnitRace then local _, token = UnitRace("player"); race = plain(token) end
    if ns.isCamelot and build and build >= 70425 and race == "Orc" then
        local known = (IsPlayerSpell and plain(IsPlayerSpell(SHATTER_CURSE)) == true)
            or (IsSpellKnown and plain(IsSpellKnown(SHATTER_CURSE)) == true)
        if known and C_Spell and C_Spell.GetSpellInfo then
            local info = C_Spell.GetSpellInfo(SHATTER_CURSE)
            if type(plain(info)) == "table" and type(plain(info.name)) == "string" then
                self.spells[1] = { id = SHATTER_CURSE, name = info.name,
                    selfOnly = true, limited = true, cures = { Curse = true } }
            end
        end
    end
    self:Refresh()
    return previous ~= (self.spells[1] and self.spells[1].id)
end

function Personal:Enabled()
    local spell = self.spells[1]
    if not spell or not ns.Bindings then return false end
    -- Personal spells have explicit bindings only; no automatic role resolves
    -- to them. Read saved entries directly so polling an unbound racial never
    -- constructs the automatic default-binding list.
    for _, entry in ipairs(ns.db and ns.db.bindings or {}) do
        if entry.spell == spell.id and entry.action ~= "NONE" and entry.action ~= "TARGET" then return true end
    end
    return false
end

function Personal:CellUnit(unit)
    -- Use the stable token before arming a protected box. A raidN alias can
    -- refer to someone else after a roster change during combat, when the
    -- secure attributes cannot be changed. 'player' always remains us.
    return self:Enabled() and self:IsPlayer(unit) and "player" or unit
end

-- Only readable, current cooldown evidence can advertise a ready personal
-- action. Unknown/secret values fail closed. No hardcoded three-minute timer.
function Personal:Ready()
    if not self:Enabled() then self.status = "unbound"; return false end
    local getter = C_Spell and C_Spell.GetSpellCooldown
    if not getter then self.status = "cooldown unavailable"; return false end
    local ok, info = pcall(getter, SHATTER_CURSE)
    if not ok or type(plain(info)) ~= "table" then self.status = "cooldown unavailable"; return false end
    local start, duration, enabled = plain(info.startTime), plain(info.duration), plain(info.isEnabled)
    if type(start) ~= "number" or type(duration) ~= "number" or enabled ~= true
        or start ~= start or duration ~= duration or start < 0 or duration < 0 then
        self.status = "cooldown unknown"; return false
    end
    local ready = duration == 0 or start + duration <= GetTime()
    self.status = ready and "ready" or "on cooldown"
    return ready
end

function Personal:Refresh()
    self.wasEnabled = self:Enabled()
    local ready = self:Ready()
    for _, box in ipairs(ns.Panel and ns.Panel.boxes or {}) do
        if box.personalDispelHolder then
            -- This wrapper is ours; the engine owns its bound descendants.
            box.personalDispelHolder:SetAlpha(ready and not box.personalDispelFailed
                and self:IsPlayer(box.unit) and 1 or 0)
        end
    end
end

function Personal:Attach(box, unit)
    if ns.StructuralChangesUnsafe and ns.StructuralChangesUnsafe() then return end
    if not self:Enabled() or not self:IsPlayer(unit) then
        if box.personalDispelHolder then box.personalDispelHolder:SetAlpha(0) end
        return
    end
    if not box.personalDispelHolder then
        local caps = ns.Binding and ns.Binding:Probe()
        if not (caps and caps.usable) then self:Fail("personal aura engine unavailable"); return end
        local holder = CreateFrame("Frame", nil, box)
        holder:SetAllPoints(box)
        holder:SetFrameLevel(box:GetFrameLevel() + 20)
        holder:EnableMouse(false)
        holder:SetAlpha(0)
        box.personalDispelHolder = holder
    end
    local holder = box.personalDispelHolder
    if not box.personalDispelContainer then
        -- Player identity is fixed even when the roster uses a raidN alias.
        -- Curse matching is native, with no aura lookup or Lua aura callback.
        local ok, container = pcall(CreateFrame, "AuraContainer", nil, holder, "CustomAuraContainerTemplate")
        if not ok or not container then self:Fail("personal aura container unavailable"); return end
        box.personalDispelContainer = container
        container:SetAllPoints(holder)
        local bound, err = pcall(function()
            local slot = container:AddAuraSlot("salvePersonalCurse", "HARMFUL", {
                candidateFilters = { includeDispelTypes = { Curse = true } },
                initializeFrame = function(button)
                    button:SetMouseClickEnabled(false)
                    button:SetMouseMotionEnabled(false)
                    button:SetSize(10, 10)
                    -- Bind the R artwork itself. A separate FontString would
                    -- not inherit the texture's native Shown aspect and could
                    -- stay visible with no matching aura.
                    local icon = button:CreateTexture(nil, "ARTWORK")
                    icon:SetAllPoints(button)
                    icon:SetTexture("Interface\\AddOns\\Salve\\Textures\\PersonalDispel")
                    button:AddDispelTypeTexture(icon, {
                        style = Enum.CustomAuraButtonDispelTypeTextureStyle.PreserveAsset,
                        showWhenHarmful = true, showWhenHelpful = false, showIcon = false,
                    })
                end,
            })
            slot:SetPoint("TOPLEFT", holder, "TOPLEFT")
            slot:SetSize(10, 10)
            container:SetUnit("player")
            container:SetEnabled(true)
        end)
        if not bound then
            self:Fail(tostring(err))
            box.personalDispelFailed = true
            return
        end
    end
    if not box.personalDispelFailed then self:Refresh() end
end

-- The throttle only checks our spell's readiness, never aura data. It also
-- clears cues immediately on roster identity changes during combat.
local frame, elapsed = CreateFrame("Frame"), 0
frame:SetScript("OnUpdate", function(_, delta)
    elapsed = elapsed + delta
    if elapsed < 0.2 then return end
    elapsed = 0
    if Personal:Enabled() or Personal.wasEnabled then Personal:Refresh() end
end)
