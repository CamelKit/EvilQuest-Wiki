local p = {}

local cookingData = mw.loadJsonData('Module:CookingData/json')
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

-- Helper to format effect description from a tea entry
local function formatTeaEffect(tea)
    local parts = {}

    if tea.healOverTime then
        local durSec = (tea.healOverTime.durationMs or 0) / 1000
        local tickSec = (tea.healOverTime.tickIntervalMs or 0) / 1000
        local totalHeal = tea.healOverTime.totalHeal or 0
        table.insert(parts, "Heals " .. totalHeal .. " HP over " .. durSec .. "s (every " .. tickSec .. "s)")
    end

    if tea.maxHealthBoost then
        local durSec = (tea.maxHealthBoost.durationMs or 0) / 1000
        local amt = tea.maxHealthBoost.amount or 0
        table.insert(parts, "+" .. amt .. " Max HP (" .. durSec .. "s)")
    end

    if tea.effectSummary and tea.effectSummary ~= "" then
        table.insert(parts, tea.effectSummary)
    elseif tea.inGameDescription and tea.inGameDescription ~= "" then
        table.insert(parts, "''" .. tea.inGameDescription .. "''")
    end

    if #parts == 0 then
        return "Nourishing Herbal Brew"
    end
    return table.concat(parts, " &bull; ")
end

-- Helper to find tea matching an item name or ID
local function findTeaMatch(nameOrId)
    local item = findItem(nameOrId)
    local targetId = item and item.id or tonumber(nameOrId)
    local targetName = item and item.name or tostring(nameOrId)
    local targetLower = targetName:lower()

    local matched = {}
    for _, tea in ipairs(cookingData.herbalTeas or {}) do
        local isMatch = false
        local role = "output"

        -- Match base tea name
        if tea.name:lower() == targetLower then
            isMatch = true
            role = "output"
        -- Match 2-dose item
        elseif targetId and tea.twoDoseItemId == targetId then
            isMatch = true
            role = "dose"
        elseif tea.twoDoseItemName and tea.twoDoseItemName:lower() == targetLower then
            isMatch = true
            role = "dose"
        -- Match 1-dose item
        elseif targetId and tea.oneDoseItemId == targetId then
            isMatch = true
            role = "dose"
        elseif tea.oneDoseItemName and tea.oneDoseItemName:lower() == targetLower then
            isMatch = true
            role = "dose"
        -- Match leaf ingredient
        elseif targetId and tea.leafItemId == targetId then
            isMatch = true
            role = "leaf"
        elseif tea.leafItemName and tea.leafItemName:lower() == targetLower then
            isMatch = true
            role = "leaf"
        -- Match secondary ingredient
        elseif tea.ingredient and ((targetId and tea.ingredient.itemId == targetId) or (tea.ingredient.name and tea.ingredient.name:lower() == targetLower)) then
            isMatch = true
            role = "ingredient"
        end

        if isMatch then
            table.insert(matched, { tea = tea, role = role })
        end
    end
    return matched
end

-- ============================================================
-- Public Methods
-- ============================================================

-- Master table of all 21 Herbal Teas (for /w/Cooking or /w/Herbal_Tea)
function p.renderTeaTable(frame)
    local out = '{| class="wikitable sortable" style="width: 100%;"\n'
    out = out .. '|- style="background-color: #2e2e2e; color: white;"\n'
    out = out .. '! Tea Name !! Lvl !! Tea Leaf !! Secondary Ingredient !! Resulting Doses !! In-Game Effects\n'

    for _, tea in ipairs(cookingData.herbalTeas or {}) do
        local leafLink = tea.leafItemName and ("[[" .. tea.leafItemName .. "]]") or "Tea Leaves"
        local ingLink = "None"
        if tea.ingredient and tea.ingredient.name then
            local qty = tea.ingredient.quantity or 1
            local qtyStr = qty > 1 and (qty .. "x ") or ""
            ingLink = qtyStr .. "[[" .. tea.ingredient.name .. "]]"
        end

        local doses = {}
        if tea.twoDoseItemName then table.insert(doses, "[[" .. tea.twoDoseItemName .. "]]") end
        if tea.oneDoseItemName then table.insert(doses, "[[" .. tea.oneDoseItemName .. "]]") end
        local doseStr = table.concat(doses, ", ")

        local effectStr = formatTeaEffect(tea)

        out = out .. '|-\n'
        out = out .. '| \'\'\'[[' .. tea.name .. ']]\'\'\'\n'
        out = out .. '| style="text-align: center;" | ' .. tostring(tea.cookingLevel) .. '\n'
        out = out .. '| ' .. leafLink .. '\n'
        out = out .. '| ' .. ingLink .. '\n'
        out = out .. '| ' .. doseStr .. '\n'
        out = out .. '| ' .. effectStr .. '\n'
    end

    out = out .. '|}\n'
    return out
end

-- Render recipe box in the =Sources= section of an item
function p.renderItemTeaBrewing(frame)
    local targetName = frame.args[1] or (frame:getParent() and frame:getParent().args['name']) or mw.title.getCurrentTitle().text
    local matches = findTeaMatch(targetName)

    if not matches or #matches == 0 then
        return ""
    end

    local out = '==Brewed from==\n'
    out = out .. '{| class="wikitable sortable" style="margin-top: 0.5em; width: 100%;"\n'
    out = out .. '|- style="background-color: #2e2e2e; color: white;"\n'
    out = out .. '! Skill !! Level !! Base Leaf !! Secondary Ingredient !! Brew Output !! Effects\n'

    for _, m in ipairs(matches) do
        local tea = m.tea
        local leafLink = tea.leafItemName and ("[[" .. tea.leafItemName .. "]]") or "Tea Leaves"
        local ingLink = "None"
        if tea.ingredient and tea.ingredient.name then
            local qty = tea.ingredient.quantity or 1
            local qtyStr = qty > 1 and (qty .. "x ") or ""
            ingLink = qtyStr .. "[[" .. tea.ingredient.name .. "]]"
        end

        local doseStr = "[[" .. (tea.twoDoseItemName or tea.name) .. "]]"
        local effectStr = formatTeaEffect(tea)

        out = out .. '|-\n'
        out = out .. '| [[Cooking]]\n'
        out = out .. '| style="text-align: center;" | ' .. tostring(tea.cookingLevel) .. '\n'
        out = out .. '| ' .. leafLink .. '\n'
        out = out .. '| ' .. ingLink .. '\n'
        out = out .. '| ' .. doseStr .. '\n'
        out = out .. '| ' .. effectStr .. '\n'
    end

    out = out .. '|}\n'
    return out
end

-- Infobox helper: Render Heal Over Time
function p.renderHealOverTime(frame)
    local targetName = frame.args[1] or (frame:getParent() and frame:getParent().args['name']) or mw.title.getCurrentTitle().text
    local matches = findTeaMatch(targetName)
    if matches and #matches > 0 then
        local tea = matches[1].tea
        if tea.healOverTime then
            local durSec = (tea.healOverTime.durationMs or 0) / 1000
            local tickSec = (tea.healOverTime.tickIntervalMs or 0) / 1000
            local totalHeal = tea.healOverTime.totalHeal or 0
            return "+" .. totalHeal .. " HP over " .. durSec .. "s (" .. tickSec .. "s interval)"
        end
    end
    return ""
end

-- Infobox helper: Render Max Health Boost
function p.renderMaxHealthBoost(frame)
    local targetName = frame.args[1] or (frame:getParent() and frame:getParent().args['name']) or mw.title.getCurrentTitle().text
    local matches = findTeaMatch(targetName)
    if matches and #matches > 0 then
        local tea = matches[1].tea
        if tea.maxHealthBoost then
            local durSec = (tea.maxHealthBoost.durationMs or 0) / 1000
            local amt = tea.maxHealthBoost.amount or 0
            return "+" .. amt .. " Max HP (" .. durSec .. "s)"
        end
    end
    return ""
end

-- Fetch individual tea field
function p.fetchTeaField(frame)
    local teaName = frame.args[1] or frame.args['tea']
    local field = frame.args['field']
    if not teaName or not field then return "" end

    local matches = findTeaMatch(teaName)
    if matches and #matches > 0 then
        local tea = matches[1].tea
        local val = tea[field]
        if val ~= nil then return tostring(val) end
    end
    return ""
end

return p
