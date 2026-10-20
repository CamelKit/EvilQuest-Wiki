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
    -- Fallback for tea base names (e.g. "Kawaki Tea" -> "Kawaki Tea (2 doses)")
    local twoDoseStr = tostring(nameOrId):lower() .. " (2 doses)"
    for _, it in ipairs(items) do
        if it.name and it.name:lower() == twoDoseStr then
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
    local rawName = tostring(nameOrId)
    local targetName = item and item.name or rawName
    local targetLower = targetName:lower()
    local rawLower = rawName:lower()

    local matched = {}
    for _, tea in ipairs(cookingData.herbalTeas or {}) do
        local isMatch = false
        local role = "output"

        -- Match base tea name
        if tea.name:lower() == rawLower or tea.name:lower() == targetLower then
            isMatch = true
            role = "output"
        -- Match 2-dose item
        elseif targetId and tea.twoDoseItemId == targetId then
            isMatch = true
            role = "dose"
        elseif tea.twoDoseItemName and (tea.twoDoseItemName:lower() == targetLower or tea.twoDoseItemName:lower() == rawLower) then
            isMatch = true
            role = "dose"
        -- Match 1-dose item
        elseif targetId and tea.oneDoseItemId == targetId then
            isMatch = true
            role = "dose"
        elseif tea.oneDoseItemName and (tea.oneDoseItemName:lower() == targetLower or tea.oneDoseItemName:lower() == rawLower) then
            isMatch = true
            role = "dose"
        -- Match leaf ingredient
        elseif targetId and tea.leafItemId == targetId then
            isMatch = true
            role = "leaf"
        elseif tea.leafItemName and (tea.leafItemName:lower() == targetLower or tea.leafItemName:lower() == rawLower) then
            isMatch = true
            role = "leaf"
        -- Match secondary ingredient
        elseif tea.ingredient and ((targetId and tea.ingredient.itemId == targetId) or (tea.ingredient.name and (tea.ingredient.name:lower() == targetLower or tea.ingredient.name:lower() == rawLower))) then
            isMatch = true
            role = "ingredient"
        end

        if isMatch then
            table.insert(matched, { tea = tea, role = role })
        end
    end
    return matched
end

-- Helper to find food matching an item name or ID
local function findFoodMatch(nameOrId)
    local item = findItem(nameOrId)
    local targetId = item and item.id or tonumber(nameOrId)
    local targetName = item and item.name or tostring(nameOrId)
    local targetLower = targetName:lower()

    local matched = {}
    for _, f in ipairs(cookingData.foods or {}) do
        local isMatch = false
        local role = "output"

        if targetId and f.cookedItemId == targetId then
            isMatch = true
            role = "output"
        elseif f.cookedItemName and f.cookedItemName:lower() == targetLower then
            isMatch = true
            role = "output"
        elseif targetId and f.rawItemId == targetId then
            isMatch = true
            role = "raw"
        elseif f.rawItemName and f.rawItemName:lower() == targetLower then
            isMatch = true
            role = "raw"
        elseif targetId and f.burntItemId and f.burntItemId == targetId then
            isMatch = true
            role = "burnt"
        elseif f.burntItemName and f.burntItemName:lower() == targetLower then
            isMatch = true
            role = "burnt"
        end

        if isMatch then
            table.insert(matched, { food = f, role = role })
        end
    end
    return matched
end

-- ============================================================
-- Public Methods
-- ============================================================

-- Master table of all cookable foods (with optional category filter)
function p.renderFoodTable(frame)
    local categoryFilter = frame and (frame.args.category or frame.args[1])
    if categoryFilter then
        categoryFilter = categoryFilter:lower():gsub("^%s*(.-)%s*$", "%1")
        if categoryFilter == "" or categoryFilter == "all" then
            categoryFilter = nil
        end
    end

    local out = '{| class="wikitable sortable" style="width: 100%; text-align: left;"\n'
    out = out .. '|- style="background-color: #2e2e2e; color: white;"\n'
    out = out .. '! style="width: 20%;" | Food !! style="width: 8%; text-align: center;" | Lvl !! style="width: 20%;" | Raw Ingredient !! style="width: 10%; text-align: center;" | Heals !! style="width: 10%; text-align: center;" | Cooking XP !! style="width: 14%;" | Burnt Variant !! style="width: 18%;" | Notes\n'

    for _, food in ipairs(cookingData.foods or {}) do
        local matchCat = true
        if categoryFilter then
            local cat = (food.category or ""):lower()
            if cat ~= categoryFilter then
                matchCat = false
            end
        end

        if matchCat then
            local cookedLink = "'''[[" .. food.cookedItemName .. "]]'''"
            local rawLink = "[[" .. food.rawItemName .. "]]"

            local healStr = food.healAmount and (tostring(food.healAmount) .. " HP") or "—"
            local xpStr = food.xpReward and (tostring(food.xpReward) .. " XP") or "—"

            local burntStr = "—"
            if food.burntItemName then
                burntStr = "[[" .. food.burntItemName .. "]]"
            end

            local notes = food.notes or ""

            out = out .. '|-\n'
            out = out .. '| ' .. cookedLink .. '\n'
            out = out .. '| style="text-align: center;" | ' .. tostring(food.cookingLevel or 1) .. '\n'
            out = out .. '| ' .. rawLink .. '\n'
            out = out .. '| style="text-align: center;" | ' .. healStr .. '\n'
            out = out .. '| style="text-align: center;" | ' .. xpStr .. '\n'
            out = out .. '| ' .. burntStr .. '\n'
            out = out .. '| ' .. notes .. '\n'
        end
    end

    out = out .. '|}\n'
    return out
end

-- Master table of all 21 Herbal Teas (for /w/Cooking or /w/Herbal_Tea)
function p.renderTeaTable(frame)
    local out = '{| class="wikitable sortable" style="width: 100%; text-align: left;"\n'
    out = out .. '|- style="background-color: #2e2e2e; color: white;"\n'
    out = out .. '! style="width: 18%;" | Tea Name !! style="width: 7%; text-align: center;" | Lvl !! style="width: 17%;" | Base Leaf !! style="width: 18%;" | Secondary Ingredient !! style="width: 16%;" | Resulting Doses !! style="width: 24%;" | In-Game Buff & Effects\n'

    for _, tea in ipairs(cookingData.herbalTeas or {}) do
        local teaNameLink = "'''[[" .. tea.name .. "]]'''"

        local leafLink = tea.leafItemName and ("[[" .. tea.leafItemName .. "]]") or "Steaming Water"

        local ingLink = "None"
        if tea.ingredient and tea.ingredient.name then
            local qty = tea.ingredient.quantity or 1
            local qtyStr = qty > 1 and (qty .. "x ") or ""
            ingLink = qtyStr .. "[[" .. tea.ingredient.name .. "]]"
        end

        local doses = {}
        if tea.twoDoseItemName then
            table.insert(doses, "[[" .. tea.twoDoseItemName .. "]]")
        end
        if tea.oneDoseItemName then
            table.insert(doses, "[[" .. tea.oneDoseItemName .. "]]")
        end
        local doseStr = table.concat(doses, "<br/>")

        local effectStr = formatTeaEffect(tea)

        out = out .. '|-\n'
        out = out .. '| ' .. teaNameLink .. '\n'
        out = out .. '| style="text-align: center;" | ' .. tostring(tea.cookingLevel) .. '\n'
        out = out .. '| ' .. leafLink .. '\n'
        out = out .. '| ' .. ingLink .. '\n'
        out = out .. '| ' .. doseStr .. '\n'
        out = out .. '| ' .. effectStr .. '\n'
    end

    out = out .. '|}\n'
    return out
end

-- Render recipe box in the =Sources= section of an item for Cooking (Food)
function p.renderItemCooking(frame)
    local targetName = frame.args[1] or (frame:getParent() and frame:getParent().args['name']) or mw.title.getCurrentTitle().text
    local matches = findFoodMatch(targetName)

    if not matches or #matches == 0 then
        return ""
    end

    local out = '==Cooked from==\n'
    out = out .. '{| class="wikitable sortable" style="margin-top: 0.5em; width: 100%; text-align: left;"\n'
    out = out .. '|- style="background-color: #2e2e2e; color: white;"\n'
    out = out .. '! Skill !! Level !! Raw Food !! Station !! Cooked Output !! Healing !! Cooking XP !! Burnt Variant\n'

    for _, m in ipairs(matches) do
        local f = m.food
        local rawLink = "[[" .. f.rawItemName .. "]]"
        local outLink = "'''[[" .. f.cookedItemName .. "]]'''"

        local healStr = f.healAmount and (tostring(f.healAmount) .. " HP") or "—"
        local xpStr = f.xpReward and (tostring(f.xpReward) .. " XP") or "—"

        local burntStr = f.burntItemName and ("[[" .. f.burntItemName .. "]]") or "—"

        out = out .. '|-\n'
        out = out .. '| [[Cooking]]\n'
        out = out .. '| style="text-align: center;" | ' .. tostring(f.cookingLevel or 1) .. '\n'
        out = out .. '| ' .. rawLink .. '\n'
        out = out .. '| ' .. (f.station or "[[Cooking Range]] or [[Fire]]") .. '\n'
        out = out .. '| ' .. outLink .. '\n'
        out = out .. '| style="text-align: center;" | ' .. healStr .. '\n'
        out = out .. '| style="text-align: center;" | ' .. xpStr .. '\n'
        out = out .. '| ' .. burntStr .. '\n'
    end

    out = out .. '|}\n'
    return out
end

-- Render recipe box in the =Sources= section of an item for Herbal Teas
function p.renderItemTeaBrewing(frame)
    local targetName = frame.args[1] or (frame:getParent() and frame:getParent().args['name']) or mw.title.getCurrentTitle().text
    local matches = findTeaMatch(targetName)

    if not matches or #matches == 0 then
        return ""
    end

    local out = '==Brewed from==\n'
    out = out .. '{| class="wikitable sortable" style="margin-top: 0.5em; width: 100%; text-align: left;"\n'
    out = out .. '|- style="background-color: #2e2e2e; color: white;"\n'
    out = out .. '! Skill !! Level !! Base Leaf !! Secondary Ingredient !! Brew Output !! Effects\n'

    for _, m in ipairs(matches) do
        local tea = m.tea
        local leafLink = tea.leafItemName and ("[[" .. tea.leafItemName .. "]]") or "Steaming Water"

        local ingLink = "None"
        if tea.ingredient and tea.ingredient.name then
            local qty = tea.ingredient.quantity or 1
            local qtyStr = qty > 1 and (qty .. "x ") or ""
            ingLink = qtyStr .. "[[" .. tea.ingredient.name .. "]]"
        end

        local doseStr = "'''[[" .. tea.name .. "]]''' (2 doses)"

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

-- Infobox helper: Render Tea Effect for Consumable Properties
function p.renderTeaEffect(frame)
    local targetName = frame.args[1] or (frame:getParent() and frame:getParent().args['name']) or mw.title.getCurrentTitle().text
    local matches = findTeaMatch(targetName)
    if matches and #matches > 0 then
        local tea = matches[1].tea
        -- If tea only has hitpoints healOverTime / maxHealthBoost, let those dedicated infobox rows display it
        if tea.targetSkill and tea.targetSkill ~= "hitpoints" and tea.effectSummary and tea.effectSummary ~= "" then
            return tea.effectSummary
        elseif not tea.healOverTime and not tea.maxHealthBoost and tea.effectSummary and tea.effectSummary ~= "" then
            return tea.effectSummary
        elseif not tea.healOverTime and not tea.maxHealthBoost and tea.formattedEffect and tea.formattedEffect ~= "" then
            return tea.formattedEffect
        end
    end
    return ""
end

-- Infobox helper: Render Tea Doses & Values
function p.renderTeaDosesInfoboxRows(frame)
    local targetName = frame.args[1] or (frame:getParent() and frame:getParent().args['name']) or mw.title.getCurrentTitle().text
    local matches = findTeaMatch(targetName)
    if not matches or #matches == 0 then return "" end

    local tea = matches[1].tea
    if not tea.twoDoseItemId and not tea.oneDoseItemId then return "" end

    local twoDoseItem = findItem(tea.twoDoseItemId)
    local oneDoseItem = findItem(tea.oneDoseItemId)

    local twoValStr = twoDoseItem and (twoDoseItem.value .. " coins") or "—"
    local oneValStr = oneDoseItem and (oneDoseItem.value .. " coins") or "—"

    local out = '<tr><th colspan="2" style="background: #2e2e2e; color: white; text-align: center; font-weight: bold; padding: 4px;">Dose Profiles</th></tr>\n'
    if tea.twoDoseItemId then
        out = out .. '<tr><th style="text-align: left; padding: 4px;">2 Doses (Default)</th><td style="padding: 4px;">ID: ' .. tea.twoDoseItemId .. ' &bull; ' .. twoValStr .. '</td></tr>\n'
    end
    if tea.oneDoseItemId then
        out = out .. '<tr><th style="text-align: left; padding: 4px;">1 Dose</th><td style="padding: 4px;">ID: ' .. tea.oneDoseItemId .. ' &bull; ' .. oneValStr .. '</td></tr>\n'
    end
    out = out .. '<tr><th style="text-align: left; padding: 4px;">Empty Vessel</th><td style="padding: 4px;">[[Empty Cup]] (ID: 669)</td></tr>\n'
    return out
end

-- Render Doses & Consumption Table on tea pages
function p.renderItemDosesTable(frame)
    local targetName = frame.args[1] or (frame:getParent() and frame:getParent().args['name']) or mw.title.getCurrentTitle().text
    local matches = findTeaMatch(targetName)
    if not matches or #matches == 0 then return "" end

    local tea = matches[1].tea
    if not tea.twoDoseItemId and not tea.oneDoseItemId then return "" end

    local twoDoseItem = findItem(tea.twoDoseItemId)
    local oneDoseItem = findItem(tea.oneDoseItemId)

    local twoVal = twoDoseItem and (twoDoseItem.value .. " coins") or "—"
    local oneVal = oneDoseItem and (oneDoseItem.value .. " coins") or "—"

    local out = '==Doses & Consumption==\n'
    out = out .. 'A brewed cup of \'\'\'' .. tea.name .. '\'\'\' holds \'\'\'2 doses\'\'\'. Drinking a dose consumes liquid, applies its effects, and reduces the cup to the next dose stage:\n'
    out = out .. '{| class="wikitable sortable" style="margin-top: 0.5em; width: 100%; text-align: left;"\n'
    out = out .. '|- style="background-color: #2e2e2e; color: white;"\n'
    out = out .. '! State !! Item ID !! Shop Value !! Action !! Remaining Container\n'
    out = out .. '|-\n'
    out = out .. '| \'\'\'2 doses\'\'\' (Full Cup) || ' .. tostring(tea.twoDoseItemId) .. ' || ' .. twoVal .. ' || Drink (1 dose) || [[' .. (tea.oneDoseItemName or (tea.name .. " (1 dose)")) .. '|1 dose]] (ID: ' .. tostring(tea.oneDoseItemId) .. ')\n'
    out = out .. '|-\n'
    out = out .. '| \'\'\'1 dose\'\'\' (Half Cup) || ' .. tostring(tea.oneDoseItemId) .. ' || ' .. oneVal .. ' || Drink (1 dose) || [[Empty Cup]] (ID: 669)\n'
    out = out .. '|}\n'

    return out
end

return p
