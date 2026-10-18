local p = {}

local rareDropTables = mw.loadJsonData('Module:RareDropData/json')
local itemsData = mw.loadJsonData('Module:ItemData/json')

-- Helper to quickly find an item's name by its ID
local function getItemName(itemId)
    for _, item in ipairs(itemsData) do
        if item.id == itemId then
            return item.name
        end
    end
    return "Unknown Item (" .. tostring(itemId) .. ")"
end

-- Helper to find a rare drop table by its ID
local function getTable(tableId)
    for _, t in ipairs(rareDropTables) do
        if t.id == tableId then
            return t
        end
    end
    return nil
end

-- Helper to find a rare drop table's name by its ID
local function getTableName(tableId)
    local t = getTable(tableId)
    if t and t.name then
        return t.name
    end
    return "Unknown Table (" .. tostring(tableId) .. ")"
end

-- Helper to render an individual table by ID
local function renderTableById(targetTableId)
    local t = getTable(targetTableId)
    if not t then
        return "''Error: Table not found (" .. tostring(targetTableId) .. ")''"
    end

    local out = '{| class="wikitable sortable"\n! Item\n! Amount\n! Rate\n'

    if t.entries then
        for _, entry in ipairs(t.entries) do
            if entry.type == "item" then
                local itemName = getItemName(entry.itemId)
                local amount = entry.amount or 1
                local rate = entry.rate or "Rare"

                out = out .. "|-\n"
                out = out .. "| [[" .. itemName .. "]]\n"
                out = out .. "| " .. tostring(amount) .. "\n"
                if tonumber(rate) then
                    out = out .. "| " .. tostring(rate) .. "%\n"
                else
                    out = out .. "| " .. tostring(rate) .. "\n"
                end
            elseif entry.type == "table" then
                local subTableName = getTableName(entry.tableId)
                local amount = entry.amount or "1 roll"
                local rate = entry.rate or "Rare"

                out = out .. "|-\n"
                out = out .. "| [[#" .. subTableName .. "|" .. subTableName .. "]] ''(sub-table)''\n"
                out = out .. "| " .. tostring(amount) .. "\n"
                if tonumber(rate) then
                    out = out .. "| " .. tostring(rate) .. "%\n"
                else
                    out = out .. "| " .. tostring(rate) .. "\n"
                end
            end
        end
    end

    out = out .. "|}"
    return out
end

-- Renders a single table by ID (can be called via {{#invoke:RareDropData|renderTable|universal}})
function p.renderTable(frame)
    local targetTableId
    if type(frame) == "table" then
        targetTableId = frame.args and frame.args[1]
        if (not targetTableId or targetTableId == "") and frame.getParent then
            local parent = frame:getParent()
            if parent and parent.args then
                targetTableId = parent.args[1]
            end
        end
    elseif type(frame) == "string" then
        targetTableId = frame
    end

    if not targetTableId or targetTableId == "" then
        return "Error: Missing table ID"
    end

    targetTableId = mw.text.trim(targetTableId)
    return renderTableById(targetTableId)
end

-- Renders all tables dynamically from JSON with section headers
function p.renderAll(frame)
    local out = {}
    for _, t in ipairs(rareDropTables) do
        local heading = t.name or t.id
        table.insert(out, "== " .. heading .. " ==")

        -- Preserve backwards-compatible anchor if legacyName exists and differs
        if t.legacyName and t.legacyName ~= heading then
            local anchor1 = string.gsub(t.legacyName, " ", "_")
            table.insert(out, '<span id="' .. anchor1 .. '"></span>')
            local anchor2 = string.gsub(t.legacyName:gsub("(%a)([%w_']*)", function(first, rest) return first:upper() .. rest end), " ", "_")
            if anchor2 ~= anchor1 then
                table.insert(out, '<span id="' .. anchor2 .. '"></span>')
            end
        end

        table.insert(out, renderTableById(t.id))
        table.insert(out, "")
    end
    return table.concat(out, "\n")
end

return p
