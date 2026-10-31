local addonName, ns = ...

-- ============================================================
-- Attach to another addon's group frames
-- ============================================================
-- Salve's boxes are secure buttons with fixed units, so they cannot follow a
-- host's frames by themselves in combat. Instead, out of combat, Salve reads
-- where the host's unit buttons sit and anchors its own frame to one of the
-- host's SECURE headers. When the host's block moves, Salve moves with it,
-- mid-fight included. Only a host reshuffle inside the block waits for the
-- next out-of-combat rebuild.
--
-- ☠ Never anchor to a host's plain container frame. A protected frame anchored
--   to an unprotected one makes that frame protected too, so the host's own
--   in-combat moves of it would start failing and be blamed on the host.
--
-- Geometry here is in screen pixels (frame units times effective scale), so
-- the host's scale and Salve's scale never have to agree.

ns.Attach = {}
local Attach = ns.Attach

local function numbered(prefix, suffix)
    local names = {}
    for group = 1, 8 do names[group] = prefix .. group .. (suffix or "") end
    return names
end

local function join(...)
    local list = {}
    for _, names in ipairs({ ... }) do
        for _, name in ipairs(names) do list[#list + 1] = name end
    end
    return list
end

-- Pinned headers are deliberately absent: pinned frames repeat members
-- already shown elsewhere. Danders' arena header is the player's own team,
-- shown in arena instead of its party header.
Attach.HOSTS = {
    DANDERS = {
        addon = "DandersFrames",
        label = "DandersFrames",
        headers = join({ "DandersPartyHeader", "DandersArenaHeader", "DandersFlatRaidHeader" },
            numbered("DandersRaidGroup", "Header")),
        buttons = {},
    },
    ELLESMERE = {
        addon = "EllesmereUIRaidFrames",
        label = "EllesmereUI",
        headers = join({ "ERFPartyHeader", "ERFFlatHeader" }, numbered("ERFGroupHeader")),
        -- With "self first" on, Ellesmere shows the player on this fixed
        -- button beside its party header rather than inside it.
        buttons = { "ERFPartySelfButton" },
    },
}
Attach.HOST_ORDER = { "DANDERS", "ELLESMERE" }

-- Which corner of Salve is pinned for each side. The header's end of the
-- anchor is the point the host itself pins that header by (see Plan), with
-- these corners as the fallback.
local POINTS = {
    RIGHT = { "TOPLEFT", "TOPRIGHT" },
    LEFT = { "TOPRIGHT", "TOPLEFT" },
    BOTTOM = { "TOPLEFT", "BOTTOMLEFT" },
    TOP = { "BOTTOMLEFT", "TOPLEFT" },
}

local COLUMN_TOLERANCE = 2
local MAX_RETRIES = 5

local function readableNumber(value)
    return type(value) == "number" and not (issecretvalue and issecretvalue(value))
        and value == value
end

function Attach:IsLoaded(key)
    local host = self.HOSTS[key]
    if not host then return false end
    local api = C_AddOns
    local isLoaded = api and api.IsAddOnLoaded or IsAddOnLoaded
    if type(isLoaded) ~= "function" then return false end
    local ok, loaded = pcall(isLoaded, host.addon)
    return ok and loaded == true
end

function Attach.ScreenRect(frame)
    if not (frame and frame.IsVisible and frame:IsVisible()) then return nil end
    local scale = frame:GetEffectiveScale()
    local left, right = frame:GetLeft(), frame:GetRight()
    local top, bottom = frame:GetTop(), frame:GetBottom()
    if not (readableNumber(scale) and readableNumber(left) and readableNumber(right)
        and readableNumber(top) and readableNumber(bottom)) then
        return nil
    end
    return { left = left * scale, right = right * scale, top = top * scale, bottom = bottom * scale }
end

local VALID_POINTS = {
    TOPLEFT = true, TOP = true, TOPRIGHT = true, LEFT = true, CENTER = true,
    RIGHT = true, BOTTOMLEFT = true, BOTTOM = true, BOTTOMRIGHT = true,
}

local function corner(rect, point)
    local x = point:find("LEFT", 1, true) and rect.left
        or (point:find("RIGHT", 1, true) and rect.right) or (rect.left + rect.right) / 2
    local y = point:find("TOP", 1, true) and rect.top
        or (point:find("BOTTOM", 1, true) and rect.bottom) or (rect.top + rect.bottom) / 2
    return x, y
end

-- ☠ Anchor to the point the host pins its header by, not to the edge facing
--   Salve. A secure header resizes itself mid-fight when someone joins or
--   leaves, and only the host's own anchor point holds still while it does.
--   Following a moving edge could slide Salve over the host's frames, where
--   its secure boxes would steal the host's clicks until combat ends.
local function fixedPoint(frame)
    local ok, point = pcall(frame.GetPoint, frame, 1)
    if ok and type(point) == "string" and not (issecretvalue and issecretvalue(point))
        and VALID_POINTS[point] then
        return point
    end
    return nil
end

-- Host layout changes (resizing frames, switching party and raid frames)
-- show up as these scripts. Hooks only queue a rebuild, which waits for
-- combat to end like every other one.
function Attach:Watch(frame)
    self.watched = self.watched or {}
    if self.watched[frame] or not frame.HookScript then return end
    self.watched[frame] = true
    local function changed() Attach:HostChanged() end
    for _, script in ipairs({ "OnShow", "OnHide", "OnSizeChanged" }) do
        pcall(frame.HookScript, frame, script, changed)
    end
end

function Attach:HostChanged()
    if not ns.db or (ns.db.attachTo or "NONE") == "NONE" then return end
    if ns.RequestRebuildSoon then ns.RequestRebuildSoon(0.1) end
end

-- Hosts reposition their own buttons on the same roster events Salve sees,
-- in an order neither controls. Look again shortly afterwards.
function Attach:RosterChanged()
    self.retries = 0
    self:HostChanged()
end

local function addButton(found, seen, button)
    local unit = button.GetAttribute and button:GetAttribute("unit")
    if type(unit) ~= "string" or (issecretvalue and issecretvalue(unit)) or seen[unit] then
        return false
    end
    local rect = Attach.ScreenRect(button)
    if not rect then return false end
    rect.unit = unit
    seen[unit] = true
    found[#found + 1] = rect
    return true
end

-- Every visible host unit button with its unit and screen rectangle, plus a
-- secure frame to anchor to.
function Attach:Collect(key)
    local host = self.HOSTS[key]
    if not host then return nil end
    local found, seen, anchor = {}, {}, nil
    for _, name in ipairs(host.headers) do
        local header = _G[name]
        if header and header.GetChildren then
            self:Watch(header)
            if header:IsVisible() then
                local any = false
                for _, child in ipairs({ header:GetChildren() }) do
                    if addButton(found, seen, child) then any = true end
                end
                if any and not anchor and Attach.ScreenRect(header) then anchor = header end
            end
        end
    end
    for _, name in ipairs(host.buttons) do
        local button = _G[name]
        if button then
            self:Watch(button)
            if addButton(found, seen, button) and not anchor then anchor = button end
        end
    end
    if #found == 0 or not anchor then return nil end
    return found, anchor
end

local function sameUnit(a, b)
    if a == b then return true end
    if not UnitIsUnit then return false end
    local ok, same = pcall(UnitIsUnit, a, b)
    return ok and not (issecretvalue and issecretvalue(same)) and same == true
end

-- Columns are the host's distinct horizontal positions, so raid groups laid
-- out as columns stay columns in Salve, and groups laid out as rows keep
-- their rows. Salve's own columns are packed tight beside the host block.
local function columns(rects)
    local order = {}
    for i, rect in ipairs(rects) do
        rect.cx = (rect.left + rect.right) / 2
        rect.cy = (rect.top + rect.bottom) / 2
        order[i] = rect
    end
    table.sort(order, function(a, b) return a.cx < b.cx end)
    local count, last = 0, nil
    for _, rect in ipairs(order) do
        if not last or rect.cx - last > COLUMN_TOLERANCE then count = count + 1 end
        last = rect.cx
        rect.column = count
    end
    return count
end

-- Cells for LEFT and RIGHT. `units` is Salve's unit list, matched to host
-- buttons by unit, or a count (the test panel), which takes host buttons in
-- reading order. `align` (TOP, CENTER or BOTTOM) lines each cell up with
-- that edge of its member's host frame, then `offset` moves it up or down.
function Attach.PlanBeside(units, rects, side, gap, width, height, spacing, align, offset)
    local columnCount = columns(rects)
    local hostLeft, hostRight = math.huge, -math.huge
    for _, rect in ipairs(rects) do
        hostLeft = math.min(hostLeft, rect.left)
        hostRight = math.max(hostRight, rect.right)
    end

    local count = type(units) == "number" and units or #units
    local slots, used = {}, {}
    if type(units) == "number" then
        local reading = {}
        for i, rect in ipairs(rects) do reading[i] = rect end
        table.sort(reading, function(a, b)
            if a.column ~= b.column then return a.column < b.column end
            return a.cy > b.cy
        end)
        for i = 1, math.min(count, #reading) do slots[i] = reading[i] end
    else
        for i, unit in ipairs(units) do
            for _, rect in ipairs(rects) do
                if not used[rect] and sameUnit(rect.unit, unit) then
                    slots[i], used[rect] = rect, true
                    break
                end
            end
        end
    end

    -- Members the host doesn't show (its own frame hidden, say) take the next
    -- slots after the host's last frame: further down its last column, or
    -- along the row when the host is a single row.
    local rows, lastRow = 0, nil
    local byY = {}
    for i, rect in ipairs(rects) do byY[i] = rect.cy end
    table.sort(byY, function(a, b) return a > b end)
    for _, y in ipairs(byY) do
        if not lastRow or lastRow - y > COLUMN_TOLERANCE then rows = rows + 1 end
        lastRow = y
    end
    local lastColumn = {}
    for _, rect in ipairs(rects) do
        if rect.column == columnCount then lastColumn[#lastColumn + 1] = rect.cy end
    end
    table.sort(lastColumn, function(a, b) return a > b end)
    local lowest = lastColumn[#lastColumn]
    local pitch = #lastColumn > 1 and (lastColumn[1] - lowest) / (#lastColumn - 1)
        or (rects[1].top - rects[1].bottom)
    -- Extra slots borrow a host frame's height so Top and Bottom still work.
    local halfHeight = (rects[1].top - rects[1].bottom) / 2
    local alongRow = rows == 1 and columnCount > 1

    local cells, extra = {}, 0
    for i = 1, count do
        local rect = slots[i]
        if rect then
            cells[i] = { column = rect.column, cy = rect.cy, half = (rect.top - rect.bottom) / 2 }
        else
            extra = extra + 1
            if alongRow then
                cells[i] = { column = columnCount + extra, cy = lowest, half = halfHeight }
            else
                cells[i] = { column = columnCount, cy = lowest - extra * pitch, half = halfHeight }
            end
        end
    end

    local total = alongRow and columnCount + extra or columnCount
    for _, cell in ipairs(cells) do
        if side == "LEFT" then
            cell.left = hostLeft - gap - (total - cell.column + 1) * width
                - (total - cell.column) * spacing
        else
            cell.left = hostRight + gap + (cell.column - 1) * (width + spacing)
        end
        if align == "TOP" then
            cell.top = cell.cy + cell.half
        elseif align == "BOTTOM" then
            cell.top = cell.cy - cell.half + height
        else
            cell.top = cell.cy + height / 2
        end
        cell.top = cell.top + (offset or 0)
    end
    return cells
end

-- The frame rectangle for TOP and BOTTOM, where Salve's grid stays together.
-- It lines up with the host block's edge that Salve's grid starts from.
function Attach.PlanStacked(rects, side, gap, frameWidth, frameHeight, fromRight)
    local left, right, top, bottom = math.huge, -math.huge, -math.huge, math.huge
    for _, rect in ipairs(rects) do
        left, right = math.min(left, rect.left), math.max(right, rect.right)
        top, bottom = math.max(top, rect.top), math.min(bottom, rect.bottom)
    end
    local frameLeft = fromRight and right - frameWidth or left
    local frameTop = side == "TOP" and top + gap + frameHeight or bottom - gap
    return { left = frameLeft, right = frameLeft + frameWidth, top = frameTop,
        bottom = frameTop - frameHeight }
end

function Attach:Retry()
    self.retries = (self.retries or 0) + 1
    if self.retries > MAX_RETRIES or not (C_Timer and C_Timer.After) then return end
    -- Hosts can build their headers after Salve's first rebuild.
    C_Timer.After(2, function() Attach:HostChanged() end)
end

-- A placement for Salve's frame, or nil for the normal saved position.
-- `scale` is the effective scale of the frame being placed. Cell offsets
-- and the anchor offset come back in that frame's own units. The test panel
-- passes `preview` so its plan never changes the live panel's status.
function Attach:Plan(units, layout, scale, preview)
    local db = ns.db
    local key = db.attachTo or "NONE"
    local count = type(units) == "number" and units or #units
    local function fail(status)
        if not preview then self.status = status end
        return nil
    end
    if key == "NONE" then return fail("NONE") end
    if not self:IsLoaded(key) then return fail("NOT_LOADED") end
    if count == 0 then return fail("EMPTY") end
    local rects, anchor = self:Collect(key)
    local anchorRect = rects and Attach.ScreenRect(anchor)
    if not anchorRect then
        if not preview then self:Retry() end
        return fail("NO_FRAMES")
    end
    if not preview then self.retries = 0 end

    local side = db.attachSide or "RIGHT"
    local gap = (tonumber(db.attachGap) or 2) * scale
    local frameRect, cells
    if side == "LEFT" or side == "RIGHT" then
        cells = Attach.PlanBeside(units, rects, side, gap,
            layout.width * scale, layout.height * scale, layout.spacing * scale,
            db.attachAlign or "CENTER", (tonumber(db.attachOffsetY) or 0) * scale)
        frameRect = { left = math.huge, right = -math.huge, top = -math.huge, bottom = math.huge }
        for _, cell in ipairs(cells) do
            frameRect.left = math.min(frameRect.left, cell.left)
            frameRect.right = math.max(frameRect.right, cell.left + layout.width * scale)
            frameRect.top = math.max(frameRect.top, cell.top)
            frameRect.bottom = math.min(frameRect.bottom, cell.top - layout.height * scale)
        end
    else
        local fromRight = layout.orientation ~= "VERTICAL" and layout.horizontalGrowth == "LEFT"
        frameRect = Attach.PlanStacked(rects, side, gap,
            layout.frameWidth * scale, layout.frameHeight * scale, fromRight)
    end

    local point = POINTS[side][1]
    local anchorPoint = fixedPoint(anchor) or POINTS[side][2]
    local fx, fy = corner(frameRect, point)
    local ax, ay = corner(anchorRect, anchorPoint)
    local plan = {
        anchor = anchor, point = point, anchorPoint = anchorPoint,
        x = (fx - ax) / scale, y = (fy - ay) / scale,
        width = (frameRect.right - frameRect.left) / scale,
        height = (frameRect.top - frameRect.bottom) / scale,
    }
    if cells then
        plan.cells = {}
        for i, cell in ipairs(cells) do
            plan.cells[i] = {
                x = (cell.left - frameRect.left) / scale,
                y = (cell.top - frameRect.top) / scale,
            }
        end
    end
    if not preview then self.status = "ATTACHED" end
    return plan
end

function Attach:StatusText()
    local host = self.HOSTS[ns.db and ns.db.attachTo]
    local name = host and host.label or "the host"
    if self.status == "ATTACHED" then return "Attached to " .. name .. "." end
    if self.status == "NOT_LOADED" then return name .. " isn't loaded. Using the saved position." end
    if self.status == "NO_FRAMES" then
        return "No " .. name .. " group frames on screen. Using the saved position."
    end
    if self.status == "EMPTY" then return "Attaches when the panel has cells." end
    return "Not attached."
end
