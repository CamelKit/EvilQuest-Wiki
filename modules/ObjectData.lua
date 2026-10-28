local p = {}

local objects = mw.loadJsonData('Module:ObjectData/json')
local items = mw.loadJsonData('Module:ItemData/json')

-- Helper to find an item definition by Name or ID
local function findItem(nameOrId)
    if not nameOrId then return nil end
    local num = tonumber(nameOrId)
    for _, it in ipairs(items) do
        if num and it.id == num then
            return it
        elseif it.name and it.name:lower() == tostring(nameOrId):lower() then
            return it
        end
    end
    return nil
end

-- Helper to find an object definition by Name or ID
local function findObject(nameOrId)
    if not nameOrId then return nil end
    local num = tonumber(nameOrId)
    local cleanStr = tostring(nameOrId):gsub("_", " "):lower():match("^%s*(.-)%s*$")
    for _, obj in ipairs(objects) do
        if num and obj.id == num then
            return obj
        elseif obj.name then
            local objClean = obj.name:gsub("_", " "):lower():match("^%s*(.-)%s*$")
            if objClean == cleanStr then
                return obj
            end
        end
    end
    return nil
end

-- Helper to find all objects whose harvest output matches an item
local function findGatheringSourcesForItem(nameOrId)
    local item = findItem(nameOrId)
    local targetId = item and item.id or tonumber(nameOrId)
    local targetName = item and item.name or tostring(nameOrId)
    local targetNameLower = targetName:lower()

    local sources = {}
    for _, obj in ipairs(objects) do
        if obj.harvest then
            local matched = false
            if targetId and obj.harvest.outputItemId == targetId then
                matched = true
            elseif obj.harvest.outputItemName and obj.harvest.outputItemName:lower() == targetNameLower then
                matched = true
            end
            if matched then
                table.insert(sources, obj)
            end
        end
    end
    return sources, item
end

-- Helper to format tools into wiki links
local function formatTool(harvest)
    if harvest.toolName then
        if harvest.toolType == "axe" then
            return "[[Axes|" .. harvest.toolName .. "]]"
        elseif harvest.toolType == "pickaxe" then
            return "[[Pickaxes|" .. harvest.toolName .. "]]"
        else
            return "[[" .. harvest.toolName .. "]]"
        end
    elseif harvest.toolItemId then
        local toolItem = findItem(harvest.toolItemId)
        if toolItem and toolItem.name then
            return "[[" .. toolItem.name .. "]]"
        end
        return "Item " .. tostring(harvest.toolItemId)
    end
    return "None"
end

-- Helper to format required consumables / items
local function formatRequiredItems(harvest)
    if harvest.requiredItemName then
        local qty = harvest.requiredItemQuantity or 1
        local qtyPrefix = qty > 1 and (tostring(qty) .. "x ") or ""
        return qtyPrefix .. "[[" .. harvest.requiredItemName .. "]]"
    elseif harvest.requiredItemId then
        local reqItem = findItem(harvest.requiredItemId)
        local qty = harvest.requiredItemQuantity or 1
        local qtyPrefix = qty > 1 and (tostring(qty) .. "x ") or ""
        if reqItem and reqItem.name then
            return qtyPrefix .. "[[" .. reqItem.name .. "]]"
        end
        return qtyPrefix .. "Item " .. tostring(harvest.requiredItemId)
    end
    return "None"
end

-- Helper to capitalize skill or text
local function capitalize(str)
    if not str or str == "" then return "" end
    return (str:gsub("^%l", string.upper))
end

-- Helper to count elements in array or proxy table (safe for mw.loadJsonData proxies)
local function getLength(t)
    if not t or type(t) ~= "table" then return 0 end
    local count = 0
    for _ in pairs(t) do
        count = count + 1
    end
    return count
end

-- ============================================================
-- Public Methods
-- ============================================================

-- Fetch field from an object
function p.fetchObjectData(frame)
    local targetName = frame.args[1] or (frame.getParent and frame:getParent() and frame:getParent().args['name']) or mw.title.getCurrentTitle().text
    local targetField = frame.args['field']
    if not targetField then return "Error: Missing 'field' parameter." end

    local obj = findObject(targetName)
    if not obj then return "" end

    if targetField == "nodeCount" or targetField == "totalNodes" then
        return tostring(getLength(obj.locations))
    elseif targetField == "categoryName" then
        if obj.category == "rock" then return "Mining Rock"
        elseif obj.category == "tree" then return "Tree"
        elseif obj.category == "tea" then return "Tea Bush"
        elseif obj.category == "fishingspot" then return "Fishing Spot"
        elseif obj.category == "crop" then return "Crop / Plant"
        elseif obj.category == "scenery" and obj.harvestable then return "Forageable Bush / Scenery"
        elseif obj.category == "chest" then return "Chest"
        elseif obj.category == "station" or obj.category == "craftingstation" then return "Crafting Station"
        else return capitalize(obj.category or "Object") end
    elseif targetField == "skill" or targetField == "requiredSkill" then
        return obj.harvest and capitalize(obj.harvest.skill) or "None"
    elseif targetField == "action" then
        return obj.harvest and (obj.harvest.action or "Gather") or ""
    elseif targetField == "outputItem" or targetField == "outputItemName" then
        return obj.harvest and obj.harvest.outputItemName or ""
    elseif targetField == "tool" or targetField == "toolName" then
        return obj.harvest and formatTool(obj.harvest) or "None"
    elseif targetField == "requiredItems" then
        return obj.harvest and formatRequiredItems(obj.harvest) or "None"
    elseif targetField == "mapLink" then
        return "https://map.memoriesofmagic.wiki/?object=" .. mw.uri.encode(obj.name)
    end

    local val = obj[targetField]
    if val == nil then return ""
    elseif type(val) == "boolean" then return val and "Yes" or "No"
    else return tostring(val) end
end

-- Render Infobox rows for raw resource pages (inside Infobox_Item)
function p.renderGatheringInfoboxRows(frame)
    local targetName = frame.args[1] or (frame:getParent() and frame:getParent().args['name']) or mw.title.getCurrentTitle().text
    local sources = findGatheringSourcesForItem(targetName)
    if not sources or #sources == 0 then
        return ""
    end

    local out = '<tr><th colspan="2" style="background: #2e2e2e; color: white; text-align: center; font-weight: bold; padding: 4px;">Gathering Information</th></tr>\n'

    -- List sources
    local sourceLinks = {}
    local skills = {}
    local tools = {}
    local reqItems = {}

    for _, obj in ipairs(sources) do
        table.insert(sourceLinks, "[[" .. obj.name .. "]]")
        local h = obj.harvest or {}
        if h.skill then
            skills[capitalize(h.skill)] = true
        end
        local t = formatTool(h)
        if t ~= "None" then
            tools[t] = true
        end
        local r = formatRequiredItems(h)
        if r ~= "None" then
            reqItems[r] = true
        end
    end

    out = out .. '<tr><th style="text-align: left; padding: 4px;">Gathered from</th><td style="padding: 4px;">' .. table.concat(sourceLinks, ", ") .. '</td></tr>\n'

    -- Skill
    local skillList = {}
    for sk in pairs(skills) do table.insert(skillList, "[[" .. sk .. "]]") end
    if #skillList > 0 then
        out = out .. '<tr><th style="text-align: left; padding: 4px;">Required Skill</th><td style="padding: 4px;">' .. table.concat(skillList, ", ") .. '</td></tr>\n'
    end

    -- Tools
    local toolList = {}
    for tl in pairs(tools) do table.insert(toolList, tl) end
    if #toolList > 0 then
        out = out .. '<tr><th style="text-align: left; padding: 4px;">Required Tool</th><td style="padding: 4px;">' .. table.concat(toolList, ", ") .. '</td></tr>\n'
    end

    -- Required items (e.g. bait, bucket)
    local reqList = {}
    for rq in pairs(reqItems) do table.insert(reqList, rq) end
    if #reqList > 0 then
        out = out .. '<tr><th style="text-align: left; padding: 4px;">Required Items</th><td style="padding: 4px;">' .. table.concat(reqList, ", ") .. '</td></tr>\n'
    end

    return out
end

-- Render full gathering table for the =Sources= section of an item
function p.renderGatheringSources(frame)
    local targetName = frame.args[1] or (frame:getParent() and frame:getParent().args['name']) or mw.title.getCurrentTitle().text
    local sources = findGatheringSourcesForItem(targetName)
    if not sources or #sources == 0 then
        return ""
    end

    local out = '==Gathered from==\n'
    out = out .. '{| class="wikitable sortable" style="margin-top: 0.5em;"\n'
    out = out .. '|- style="background-color: #2e2e2e; color: white;"\n'
    out = out .. '! Source Object !! Skill !! Action !! Required Tool !! Required Items\n'

    for _, obj in ipairs(sources) do
        local h = obj.harvest or {}
        local skillName = h.skill and ("[[" .. capitalize(h.skill) .. "]]") or "—"
        local actionName = h.action or "Gather"
        local toolName = formatTool(h)
        local reqItems = formatRequiredItems(h)

        out = out .. '|-\n'
        out = out .. '| [[' .. obj.name .. ']]\n'
        out = out .. '| ' .. skillName .. '\n'
        out = out .. '| ' .. actionName .. '\n'
        out = out .. '| ' .. toolName .. '\n'
        out = out .. '| ' .. reqItems .. '\n'
    end

    out = out .. '|}\n'
    return out
end

-- Master table of all Fishing Spots (for Fishing skill / guide page)
function p.renderFishingSpotsTable(frame)
    local out = '{| class="wikitable sortable" style="width: 100%; border-collapse: collapse; margin-top: 1em;"\n'
    out = out .. '|- style="background-color: #2e2e2e; color: white;"\n'
    out = out .. '! Fishing Spot !! Catch !! Tool Required !! Bait / Consumable !! Action\n'

    for _, obj in ipairs(objects) do
        if obj.category == "fishingspot" and obj.harvest then
            local h = obj.harvest
            local catchLink = h.outputItemName and ("[[" .. h.outputItemName .. "]]") or "Unknown"
            local toolLink = formatTool(h)
            local reqItems = formatRequiredItems(h)
            local actionName = h.action or "Fish"

            out = out .. '|-\n'
            out = out .. '| [[' .. obj.name .. ']]\n'
            out = out .. '| ' .. catchLink .. '\n'
            out = out .. '| ' .. toolLink .. '\n'
            out = out .. '| ' .. reqItems .. '\n'
            out = out .. '| ' .. actionName .. '\n'
        end
    end

    out = out .. '|}\n'
    return out
end

-- Renders a wikitable of known world map locations and clusters
function p.renderLocations(frame)
    local targetName = frame.args[1] or (frame.getParent and frame:getParent() and frame:getParent().args['name']) or mw.title.getCurrentTitle().text
    local obj = findObject(targetName)
    if not obj then
        return "''Object not found in world registry.''"
    end

    local clusters = obj.clusters or {}
    local totalNodes = getLength(obj.locations)
    local clusterCount = getLength(clusters)

    if totalNodes == 0 or clusterCount == 0 then
        return "''No specific world map locations recorded for this object.''"
    end

    local mapBase = "https://map.memoriesofmagic.wiki"
    local encodedName = mw.uri.encode(obj.name)

    local html = '<div style="margin-bottom: 0.75em; display: flex; align-items: center; justify-content: space-between; flex-wrap: wrap; gap: 8px;">\n'
    html = html .. '<span style="font-size: 1.05em; font-weight: bold;">Recorded Nodes: ' .. tostring(totalNodes) .. ' across ' .. tostring(clusterCount) .. ' region' .. (clusterCount == 1 and '' or 's') .. '</span>\n'
    html = html .. '<span class="plainlinks" style="display: inline-block; padding: 4px 10px; background: #2563eb; border-radius: 4px; font-size: 90%;">[' .. mapBase .. '/?object=' .. encodedName .. ' <span style="color: #ffffff; font-weight: bold; text-decoration: none;">🗺️ Open in Interactive World Map ↗</span>]</span>\n'
    html = html .. '</div>\n'

    html = html .. '{| class="wikitable sortable" style="width: 100%; border-collapse: collapse; margin-top: 0.5em;"\n'
    html = html .. '|- style="background-color: #2e2e2e; color: white;"\n'
    html = html .. '! Realm !! Region / Area !! Coordinates (X, Z) !! Node Count !! Interactive Map\n'

    for i = 1, clusterCount do
        local c = clusters[i] or clusters[tostring(i)]
        if c then
            local isUnderground = (c.map == "underground")
            local realmBadge = isUnderground and '<span style="display: inline-block; padding: 2px 6px; border-radius: 4px; background: #581c87; color: #f3e8ff; font-size: 85%; font-weight: bold;">⛏️ Underground</span>' or '<span style="display: inline-block; padding: 2px 6px; border-radius: 4px; background: #14532d; color: #dcfce7; font-size: 85%; font-weight: bold;">🌍 Surface</span>'
            local coordStr = string.format("%.1f, %.1f", c.x or 0, c.z or 0)
            local countStr = tostring(c.count) .. (c.count == 1 and " node" or " nodes")

            local deepLink
            if isUnderground then
                deepLink = mapBase .. '/?map=underground&x=' .. tostring(c.x) .. '&z=' .. tostring(c.z) .. '&zoom=4.5&object=' .. encodedName
            else
                deepLink = mapBase .. '/?x=' .. tostring(c.x) .. '&z=' .. tostring(c.z) .. '&zoom=4.5&object=' .. encodedName
            end

            html = html .. '|-\n'
            html = html .. '| style="text-align: center;" | ' .. realmBadge .. '\n'
            html = html .. '| style="font-weight: bold;" | ' .. (c.region or "Wilderness") .. '\n'
            html = html .. '| style="text-align: center; font-family: monospace;" | ' .. coordStr .. '\n'
            html = html .. '| style="text-align: center;" data-sort-value="' .. tostring(c.count) .. '" | ' .. countStr .. '\n'
            html = html .. '| style="text-align: center;" | [' .. deepLink .. ' View on Map ↗]\n'
        end
    end

    html = html .. '|}\n'
    return html
end

return p
