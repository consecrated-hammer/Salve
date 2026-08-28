local addonName, ns = ...

-- ============================================================
-- Opt-in cell-click audit
-- ============================================================
-- Aura identity is secret in Midnight, so this records the player's action
-- rather than pretending it can name the aura that made a cell interesting.
-- Keep it in its own SavedVariables block: diagnostics may be shared without
-- exposing panel position, bindings or other preferences.

ns.ClickLog = {}
local ClickLog = ns.ClickLog

local MAX_ENTRIES = 1000

function ClickLog:Init()
    SalveClickLog = type(SalveClickLog) == "table" and SalveClickLog or {}
    SalveClickLog.entries = type(SalveClickLog.entries) == "table"
        and SalveClickLog.entries or {}
    SalveClickLog.schemaVersion = 1
    self.db = SalveClickLog
end

function ClickLog:Count()
    return #(self.db and self.db.entries or {})
end

function ClickLog:Record(box, button)
    if not (ns.db and ns.db.clickAuditEnabled and box and ns.Bindings) then return end

    local key = ns.Bindings:Capture(button)
    local action = key and box.clickAuditActions and box.clickAuditActions[key]
    if not action then return end

    local db = self.db
    if not db then return end
    local entries = db.entries
    entries[#entries + 1] = {
        -- `time()` is deliberately a plain local timestamp: it is easy to
        -- correlate with the character's combat-log line without looking at
        -- an aura or relying on restricted unit data.
        timestamp = time(),
        unit = box.unit,
        button = key,
        kind = action.kind,
        spellID = action.spellID,
        spellName = action.spellName,
    }
    if #entries > MAX_ENTRIES then table.remove(entries, 1) end
end

function ClickLog:Clear()
    if self.db then self.db.entries = {} end
end

local function jsonString(value)
    value = tostring(value or "?")
    value = value:gsub("\\", "\\\\")
    value = value:gsub('"', '\\"')
    value = value:gsub("\n", "\\n")
    value = value:gsub("\r", "\\r")
    value = value:gsub("\t", "\\t")
    return '"' .. value .. '"'
end

function ClickLog:Export()
    local lines = {
        "{",
        '  "format":"Salve cell-click audit",',
        '  "fields":["timestamp","unit","binding","action","spellId","spellName"],',
        '  "entries":[',
    }
    local entries = self.db and self.db.entries or {}
    for index, entry in ipairs(entries) do
        local stamp = type(entry.timestamp) == "number"
            and date("%Y-%m-%d %H:%M:%S", entry.timestamp) or "unknown"
        lines[#lines + 1] = "    [" .. table.concat({
            jsonString(stamp),
            jsonString(entry.unit),
            jsonString(entry.button),
            jsonString(entry.kind),
            tostring(tonumber(entry.spellID) or "null"),
            jsonString(entry.spellName),
        }, ",") .. (index < #entries and "]," or "]")
    end
    lines[#lines + 1] = "  ]"
    lines[#lines + 1] = "}"
    return table.concat(lines, "\n")
end
