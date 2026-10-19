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
            local cookedIcon = food.cookedItemId and ("[[File:Item_" .. food.cookedItemId .. ".png|21x21px|middle|link=" .. food.cookedItemName .. "]] ") or ""
            local cookedLink = cookedIcon .. "'''[[" .. food.cookedItemName .. "]]'''"

            local rawIcon = food.rawItemId and ("[[File:Item_" .. food.rawItemId .. ".png|21x21px|middle|link=" .. food.rawItemName .. "]] ") or ""
            local rawLink = rawIcon .. "[[" .. food.rawItemName .. "]]"

            local healStr = food.healAmount and (tostring(food.healAmount) .. " HP") or "—"
            local xpStr = food.xpReward and (tostring(food.xpReward) .. " XP") or "—"

            local burntStr = "—"
            if food.burntItemName and food.burntItemId then
                burntStr = "[[File:Item_" .. food.burntItemId .. ".png|21x21px|middle|link=" .. food.burntItemName .. "]] [[" .. food.burntItemName .. "]]"
            elseif food.burntItemName then
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
        local teaIcon = tea.twoDoseItemId and ("[[File:Item_" .. tea.twoDoseItemId .. ".png|21x21px|middle|link=" .. (tea.twoDoseItemName or tea.name) .. "]] ") or ""
        local teaNameLink = teaIcon .. "'''[[" .. tea.name .. "]]'''"

        local leafLink = "Steaming Water"
        if tea.leafItemId and tea.leafItemName then
            leafLink = "[[File:Item_" .. tea.leafItemId .. ".png|21x21px|middle|link=" .. tea.leafItemName .. "]] [[" .. tea.leafItemName .. "]]"
        elseif tea.leafItemName then
            leafLink = "[[" .. tea.leafItemName .. "]]"
        end

        local ingLink = "None"
        if tea.ingredient and tea.ingredient.name then
            local qty = tea.ingredient.quantity or 1
            local qtyStr = qty > 1 and (qty .. "x ") or ""
            local ingIcon = tea.ingredient.itemId and ("[[File:Item_" .. tea.ingredient.itemId .. ".png|21x21px|middle|link=" .. tea.ingredient.name .. "]] ") or ""
            ingLink = qtyStr .. ingIcon .. "[[" .. tea.ingredient.name .. "]]"
        end

        local doses = {}
        if tea.twoDoseItemName and tea.twoDoseItemId then
            table.insert(doses, "[[File:Item_" .. tea.twoDoseItemId .. ".png|21x21px|middle|link=" .. tea.twoDoseItemName .. "]] [[" .. tea.twoDoseItemName .. "]]")
        elseif tea.twoDoseItemName then
            table.insert(doses, "[[" .. tea.twoDoseItemName .. "]]")
        end
        if tea.oneDoseItemName and tea.oneDoseItemId then
            table.insert(doses, "[[File:Item_" .. tea.oneDoseItemId .. ".png|21x21px|middle|link=" .. tea.oneDoseItemName .. "]] [[" .. tea.oneDoseItemName .. "]]")
        elseif tea.oneDoseItemName then
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
        local rawIcon = f.rawItemId and ("[[File:Item_" .. f.rawItemId .. ".png|21x21px|middle|link=" .. f.rawItemName .. "]] ") or ""
        local rawLink = rawIcon .. "[[" .. f.rawItemName .. "]]"

        local outIcon = f.cookedItemId and ("[[File:Item_" .. f.cookedItemId .. ".png|21x21px|middle|link=" .. f.cookedItemName .. "]] ") or ""
        local outLink = outIcon .. "'''[[" .. f.cookedItemName .. "]]'''"

        local healStr = f.healAmount and (tostring(f.healAmount) .. " HP") or "—"
        local xpStr = f.xpReward and (tostring(f.xpReward) .. " XP") or "—"

        local burntStr = "—"
        if f.burntItemName and f.burntItemId then
            burntStr = "[[File:Item_" .. f.burntItemId .. ".png|21x21px|middle|link=" .. f.burntItemName .. "]] [[" .. f.burntItemName .. "]]"
        elseif f.burntItemName then
            burntStr = "[[" .. f.burntItemName .. "]]"
        end

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
        if tea.leafItemId and tea.leafItemName then
            leafLink = "[[File:Item_" .. tea.leafItemId .. ".png|21x21px|middle|link=" .. tea.leafItemName .. "]] [[" .. tea.leafItemName .. "]]"
        end

        local ingLink = "None"
        if tea.ingredient and tea.ingredient.name then
            local qty = tea.ingredient.quantity or 1
            local qtyStr = qty > 1 and (qty .. "x ") or ""
            local ingIcon = tea.ingredient.itemId and ("[[File:Item_" .. tea.ingredient.itemId .. ".png|21x21px|middle|link=" .. tea.ingredient.name .. "]] ") or ""
            ingLink = qtyStr .. ingIcon .. "[[" .. tea.ingredient.name .. "]]"
        end

        local doseStr = "[[" .. (tea.twoDoseItemName or tea.name) .. "]]"
        if tea.twoDoseItemId then
            doseStr = "[[File:Item_" .. tea.twoDoseItemId .. ".png|21x21px|middle|link=" .. (tea.twoDoseItemName or tea.name) .. "]] " .. doseStr
        end

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
