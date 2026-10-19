local p = {}

local skillData = mw.loadJsonData('Module:SkillData/json')

-- Helper to find skill by ID or Name
local function findSkill(nameOrId)
    if not nameOrId then return nil end
    local query = tostring(nameOrId):lower()
    for _, s in ipairs(skillData.skills or {}) do
        if s.id:lower() == query or s.name:lower() == query then
            return s
        end
    end
    return nil
end

-- ============================================================
-- Public Methods
-- ============================================================

-- Returns the cumulative XP required for a given level
function p.getXpForLevel(frame)
    local lvl = tonumber(frame.args[1] or frame.args['level'])
    if not lvl or lvl < 1 then return "0" end
    if lvl > #skillData.xpTable then lvl = #skillData.xpTable end
    local entry = skillData.xpTable[lvl]
    return entry and tostring(entry.xp) or "0"
end

-- Returns the XP difference between level L-1 and level L
function p.getXpDifference(frame)
    local lvl = tonumber(frame.args[1] or frame.args['level'])
    if not lvl or lvl <= 1 then return "0" end
    if lvl > #skillData.xpTable then lvl = #skillData.xpTable end
    local entry = skillData.xpTable[lvl]
    return entry and tostring(entry.xpDifference) or "0"
end

-- Returns the level achieved for a given cumulative XP amount
function p.getLevelForXp(frame)
    local targetXp = tonumber(frame.args[1] or frame.args['xp'])
    if not targetXp or targetXp <= 0 then return "1" end

    local currentLvl = 1
    for _, entry in ipairs(skillData.xpTable or {}) do
        if targetXp >= entry.xp then
            currentLvl = entry.level
        else
            break
        end
    end
    return tostring(currentLvl)
end

-- Calculates player combat level from stats
-- Usage: {{#invoke:SkillData|calculateCombatLevel|defence=70|hitpoints=70|weaponry=60|strength=60|ranging=1|goodmagic=0|darkmagic=0}}
function p.calculateCombatLevel(frame)
    local args = frame.args
    local def = tonumber(args['defence'] or args['def'] or 1) or 1
    local hp = tonumber(args['hitpoints'] or args['hp'] or 10) or 10
    local weap = tonumber(args['weaponry'] or args['att'] or args['attack'] or 1) or 1
    local str = tonumber(args['strength'] or args['str'] or 1) or 1
    local rng = tonumber(args['ranging'] or args['archery'] or args['range'] or 1) or 1
    local good = tonumber(args['goodmagic'] or args['lightmagic'] or args['light'] or 0) or 0
    local dark = tonumber(args['darkmagic'] or args['evilmagic'] or args['dark'] or 0) or 0

    local base = 0.25 * (def + hp)
    local melee = 0.325 * (weap + str)
    local ranged = 0.325 * (math.floor(rng / 2) + rng)

    local maxMagic = math.max(good, dark)
    local magic = 0.325 * (math.floor(maxMagic / 2) + maxMagic)

    local dominantStyle = math.max(melee, math.max(ranged, magic))
    local combatLevel = math.floor(base + dominantStyle)

    return tostring(combatLevel)
end

-- Returns threat hex color based on combat level difference
-- diff = playerLevel - targetLevel (e.g. if enemy is 10 levels higher, diff = -10 -> #ff0000)
function p.getThreatColor(frame)
    local diff = tonumber(frame.args[1] or frame.args['diff'])
    if not diff then
        local playerLvl = tonumber(frame.args['player'] or frame.args['playerLevel'])
        local targetLvl = tonumber(frame.args['target'] or frame.args['targetLevel'])
        if playerLvl and targetLvl then
            diff = playerLvl - targetLvl
        else
            return "#ffff00"
        end
    end

    if diff <= -10 then return "#ff0000"
    elseif diff <= -7 then return "#ff3000"
    elseif diff <= -4 then return "#ff7000"
    elseif diff <= -1 then return "#ffb000"
    elseif diff == 0 then return "#ffff00"
    elseif diff <= 3 then return "#c0ff00"
    elseif diff <= 6 then return "#80ff00"
    elseif diff <= 9 then return "#40ff00"
    else return "#00ff00" end
end

-- Master table of Threat Colors
function p.renderThreatTable(frame)
    local out = '{| class="wikitable" style="width: 100%; text-align: center;"\n'
    out = out .. '|- style="background-color: #2e2e2e; color: white;"\n'
    out = out .. '! Level Difference (Diff) !! Hex Code !! Preview Swatch !! In-Game Threat Assessment\n'

    for _, t in ipairs(skillData.combatFormulas.threatColors or {}) do
        local textColor = (t.color == "#ffff00" or t.color == "#c0ff00" or t.color == "#ffb000") and "#000" or "#fff"
        out = out .. '|-\n'
        out = out .. '| \'\'\'' .. t.diffRange .. '\'\'\'\n'
        out = out .. '| <code>' .. t.color .. '</code>\n'
        out = out .. '| style="background: ' .. t.color .. '; color: ' .. textColor .. '; font-weight: bold;" | ' .. t.color .. '\n'
        out = out .. '| ' .. t.meaning .. '\n'
    end

    out = out .. '|}\n'
    return out
end

-- Query skill field (e.g. color, category, startLevel)
function p.fetchSkillField(frame)
    local skillName = frame.args[1] or frame.args['skill']
    local field = frame.args['field']
    if not skillName or not field then return "" end

    local s = findSkill(skillName)
    if s and s[field] ~= nil then
        return tostring(s[field])
    end
    return ""
end

return p
