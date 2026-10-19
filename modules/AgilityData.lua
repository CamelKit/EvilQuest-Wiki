local p = {}

local agilityData = mw.loadJsonData('Module:AgilityData/json')

-- Helper to capitalize skill or text
local function capitalize(str)
    if not str or str == "" then return "" end
    return (str:gsub("^%l", string.upper))
end

-- ============================================================
-- Public Methods
-- ============================================================

-- Master table of all 15 Agility Obstacles
function p.renderObstacleTable(frame)
    local out = '{| class="wikitable sortable" style="width: 100%;"\n'
    out = out .. '|- style="background-color: #2e2e2e; color: white;"\n'
    out = out .. '! Obstacle Key !! Obstacle Name !! Action Label !! Failure Risk !! Single-User Exclusive\n'

    for _, o in ipairs(agilityData.obstacles or {}) do
        local failStatus = o.canFail and '<span style="color: #c44; font-weight: bold;">Yes (Can Fail)</span>' or '<span style="color: #4a4;">Safe (No Fail)</span>'
        local exclusiveStatus = o.exclusive and 'Yes (Exclusive)' or 'No (Shared)'

        out = out .. '|-\n'
        out = out .. '| <code>' .. o.key .. '</code>\n'
        out = out .. '| \'\'\'' .. o.name .. '\'\'\'\n'
        out = out .. '| style="text-align: center;" | ' .. o.label .. '\n'
        out = out .. '| style="text-align: center;" | ' .. failStatus .. '\n'
        out = out .. '| style="text-align: center;" | ' .. exclusiveStatus .. '\n'
    end

    out = out .. '|}\n'
    return out
end

-- Fetch individual obstacle property
function p.fetchObstacle(frame)
    local key = frame.args[1] or frame.args['key']
    local field = frame.args['field']
    if not key or not field then return "" end

    for _, o in ipairs(agilityData.obstacles or {}) do
        if o.key:lower() == key:lower() or o.name:lower() == key:lower() then
            local val = o[field]
            if val ~= nil then
                if type(val) == "boolean" then
                    return val and "Yes" or "No"
                else
                    return tostring(val)
                end
            end
        end
    end
    return ""
end

return p
