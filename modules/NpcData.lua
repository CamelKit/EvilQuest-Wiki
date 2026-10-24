local p = {}

-- Natively load and decode the NPC JSON subpage
local npcs = mw.loadJsonData('Module:NPCData/json')

-- Build lookup caches for base definitions and named instances
local defByName = {}
local instanceToDef = {}
local genericNames = { ["man"] = true, ["Man"] = true, ["Woman"] = true, ["woman"] = true }

for _, npc in ipairs(npcs) do
    if npc.name then
        defByName[npc.name] = npc
        defByName[string.lower(npc.name)] = npc
    end
    if npc.spawns then
        for _, spawn in ipairs(npc.spawns) do
            local sname = spawn.name
            if sname and sname ~= npc.name and not genericNames[sname] then
                if not instanceToDef[sname] then
                    instanceToDef[sname] = {
                        base = npc,
                        spawns = { spawn }
                    }
                    instanceToDef[string.lower(sname)] = instanceToDef[sname]
                else
                    table.insert(instanceToDef[sname].spawns, spawn)
                end
            end
        end
    end
end

-- Helper function to sanitize types for MediaWiki templates
function p.formatValue(value)
    if value == nil then
        return "" 
    elseif type(value) == "boolean" then
        return value and "Yes" or "No" 
    else
        return tostring(value)
    end
end

-- Resolves the canonical Base Definition page name for any NPC or Instance
function p.getBaseDef(frame)
    local rawTitle = (frame and frame.args and frame.args[1])
    if (not rawTitle or rawTitle == "") and frame and frame.getParent then
        local parent = frame:getParent()
        if parent and parent.args then
            rawTitle = parent.args['shop'] or parent.args['baseDef'] or parent.args['name']
        end
    end
    if not rawTitle or rawTitle == "" then
        rawTitle = mw.title.getCurrentTitle().text
    end

    local baseName = string.match(rawTitle, "^(.-)%s*%(Lvl (.-)%)$") or rawTitle

    local inst = instanceToDef[baseName] or instanceToDef[string.lower(baseName)]
    if inst and inst.base and inst.base.name then
        return inst.base.name
    end

    local def = defByName[baseName] or defByName[string.lower(baseName)]
    if def and def.name then
        return def.name
    end

    return baseName
end

-- Checks if a given page represents a specific instance of a base definition
function p.isInstance(frame)
    local rawTitle = (frame and frame.args and frame.args[1]) or mw.title.getCurrentTitle().text
    local baseName = string.match(rawTitle, "^(.-)%s*%(Lvl (.-)%)$") or rawTitle
    if instanceToDef[baseName] or instanceToDef[string.lower(baseName)] then
        return "Yes"
    end
    return "No"
end

-- Primary property fetcher with automatic instance -> base definition inheritance
function p.fetchNpcData(frame)
    local rawTitle = frame.args[1] or frame:getParent().args['name'] or mw.title.getCurrentTitle().text
    local explicitBase = frame:getParent().args['baseDef']
    local targetField = frame.args['field']

    if not targetField then
        return "Error: Missing 'field' parameter."
    end

    -- Use Lua Pattern Matching to extract "Skeleton Warrior" and "28" from "Skeleton Warrior (Lvl 28)"
    local baseName, targetLevel = string.match(rawTitle, "^(.-)%s*%(Lvl (.-)%)$")
    if not baseName then
        baseName = rawTitle
    end

    -- 1. Check if queried NPC is a known named instance (e.g. Nayla, Nim, Renn)
    local inst = instanceToDef[baseName] or instanceToDef[string.lower(baseName)]
    if not inst and explicitBase then
        local parentBase = defByName[explicitBase] or defByName[string.lower(explicitBase)]
        if parentBase then
            inst = { base = parentBase, spawns = parentBase.spawns or {} }
        end
    end

    if inst then
        if targetField == "baseDef" then
            return inst.base.name or ""
        elseif targetField == "isInstance" then
            return "Yes"
        elseif targetField == "coordinates" then
            local coords = {}
            for _, s in ipairs(inst.spawns) do
                if s.x and s.z then
                    table.insert(coords, string.format("%.1f, %.1f", s.x, s.z))
                end
            end
            return table.concat(coords, "<br/>")
        elseif targetField == "wanderRange" then
            if inst.spawns and inst.spawns[1] and inst.spawns[1].wanderRange ~= nil then
                return tostring(inst.spawns[1].wanderRange)
            end
            return tostring(inst.base.wanderRange or 0)
        elseif targetField == "location" then
            if inst.spawns and inst.spawns[1] and inst.spawns[1].map then
                local m = inst.spawns[1].map
                return string.upper(string.sub(m, 1, 1)) .. string.sub(m, 2)
            end
            return "Surface"
        else
            -- Check if spawn overrides field, otherwise fall back to base definition
            if inst.spawns and inst.spawns[1] and inst.spawns[1][targetField] ~= nil then
                return p.formatValue(inst.spawns[1][targetField])
            elseif inst.base[targetField] ~= nil then
                return p.formatValue(inst.base[targetField])
            end
        end
        return ""
    end

    -- 2. Normal base definition lookup
    for _, npc in ipairs(npcs) do
        if npc.name == baseName then
            if targetLevel then
                if tostring(npc.combatLevel or "??") == targetLevel then
                    if targetField == "baseDef" then
                        return ""
                    elseif targetField == "isInstance" then
                        return "No"
                    elseif targetField == "coordinates" then
                        if npc.spawns and #npc.spawns > 0 then
                            local coords = {}
                            for _, s in ipairs(npc.spawns) do
                                if s.x and s.z then
                                    table.insert(coords, string.format("%.1f, %.1f", s.x, s.z))
                                end
                            end
                            return table.concat(coords, "<br/>")
                        end
                        return ""
                    end
                    return p.formatValue(npc[targetField])
                end
            else
                if targetField == "baseDef" then
                    return ""
                elseif targetField == "isInstance" then
                    return "No"
                elseif targetField == "coordinates" then
                    if npc.spawns and #npc.spawns > 0 then
                        local coords = {}
                        for _, s in ipairs(npc.spawns) do
                            if s.x and s.z then
                                table.insert(coords, string.format("%.1f, %.1f", s.x, s.z))
                            end
                        end
                        return table.concat(coords, "<br/>")
                    end
                    return ""
                end
                return p.formatValue(npc[targetField])
            end
        end
    end
    
    return "" 
end

-- Renders a wikitable of specific named merchants / instances on a Base Definition page
function p.renderSpawns(frame)
    local rawTitle = (frame and frame.args and frame.args[1])
    if (not rawTitle or rawTitle == "") and frame and frame.getParent then
        local parent = frame:getParent()
        if parent and parent.args then
            rawTitle = parent.args['name']
        end
    end
    if not rawTitle or rawTitle == "" then
        rawTitle = mw.title.getCurrentTitle().text
    end

    local baseName = string.match(rawTitle, "^(.-)%s*%(Lvl (.-)%)$") or rawTitle
    local npc = defByName[baseName] or defByName[string.lower(baseName)]

    if not npc or not npc.spawns or #npc.spawns == 0 then
        return "''No specific world spawn locations recorded.''"
    end

    local isShop = npc.hasShop
    local headerTitle = isShop and "Merchant Name" or "NPC Instance"

    local html = '<table class="wikitable sortable" style="width: 100%; border-collapse: collapse; margin-top: 0.5em;">\n'
    html = html .. '<tr style="background-color: #5c1d1d; color: white;">'
    html = html .. '<th>' .. headerTitle .. '</th>'
    html = html .. '<th>Map Location</th>'
    html = html .. '<th>Coordinates</th>'
    html = html .. '<th style="width: 120px;">Wander Range</th>'
    html = html .. '</tr>\n'

    for _, s in ipairs(npc.spawns) do
        local sname = s.name or npc.name
        local link = (sname ~= npc.name and not genericNames[sname]) and ('[[' .. sname .. ']]') or sname
        local mapName = "Surface"
        if s.map and s.map ~= "" then
            mapName = string.upper(string.sub(s.map, 1, 1)) .. string.sub(s.map, 2)
        end
        local coordStr = string.format("%.1f, %.1f", s.x or 0, s.z or 0)
        local rangeVal = s.wanderRange or 0
        local wanderStr = tostring(rangeVal) .. (rangeVal == 0 and " (Stationary)" or " tiles")

        html = html .. '<tr>'
        html = html .. '<td style="font-weight: bold;">' .. link .. '</td>'
        html = html .. '<td>' .. mapName .. '</td>'
        html = html .. '<td>' .. coordStr .. '</td>'
        html = html .. '<td>' .. wanderStr .. '</td>'
        html = html .. '</tr>\n'
    end

    html = html .. '</table>'
    return html
end

-- Master Index Table (Automatically handles Disambiguation Links!)
function p.renderNPCTable(frame)
    local nameCounts = {}
    for _, npc in ipairs(npcs) do
        nameCounts[npc.name] = (nameCounts[npc.name] or 0) + 1
    end

    local html = '<table class="wikitable sortable" style="width: 100%; border-collapse: collapse; margin-top: 1em;">\n'
    html = html .. '<tr style="background-color: #5c1d1d; color: white;">'
    html = html .. '<th style="width: 80px;">ID</th>'
    html = html .. '<th>Name</th>'
    html = html .. '<th>Examine</th>'
    html = html .. '<th style="width: 100px;">Combat Lvl</th>'
    html = html .. '</tr>\n'
    
    for _, npc in ipairs(npcs) do
        local linkTitle = npc.name
        if nameCounts[npc.name] > 1 then
            linkTitle = npc.name .. " (Lvl " .. tostring(npc.combatLevel or '??') .. ")"
        end
        
        html = html .. '<tr>'
        html = html .. '<td>' .. npc.id .. '</td>'
        html = html .. '<td style="font-weight: bold;">[[' .. linkTitle .. '|' .. npc.name .. ']]</td>'
        html = html .. '<td style="font-style: italic; color: #555;">"' .. (npc.examineText or "") .. '"</td>'
        html = html .. '<td data-sort-value="' .. (npc.combatLevel or 0) .. '">' .. (npc.combatLevel or '—') .. '</td>'
        html = html .. '</tr>\n'
    end
    
    html = html .. '</table>'
    return html
end

return p
