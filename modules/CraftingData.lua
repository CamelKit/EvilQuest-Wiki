local p = {}

local craftingData = mw.loadJsonData('Module:CraftingData/json')
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

-- Helper to capitalize skill or text
local function capitalize(str)
    if not str or str == "" then return "" end
    return (str:gsub("^%l", string.upper))
end

-- Helper to find all crafting recipes producing a specific item
local function findCraftingRecipes(nameOrId)
    local item = findItem(nameOrId)
    local targetId = item and item.id or tonumber(nameOrId)
    local targetName = item and item.name or tostring(nameOrId)
    local targetLower = targetName:lower()

    local recipes = {}

    -- 1. Leatherworking
    if craftingData.leatherworking then
        for _, r in ipairs(craftingData.leatherworking) do
            local matched = false
            if targetId and r.outputItemId == targetId then matched = true
            elseif r.outputItemName and r.outputItemName:lower() == targetLower then matched = true end
            if matched then
                table.insert(recipes, {
                    category = "Leatherworking",
                    skill = "Crafting",
                    level = r.levelRequired,
                    xp = r.xpReward,
                    materials = (r.hideQuantity or 1) .. "x [[" .. (r.tannedHideItemName or "Tanned Hide") .. "]], [[Needle]], [[Thread]]",
                    product = "[[" .. r.outputItemName .. "]]",
                    notes = "Slot: " .. capitalize(r.slot or "Armor")
                })
            end
        end
    end

    -- 2. Tanning
    if craftingData.tanning then
        for _, r in ipairs(craftingData.tanning) do
            local matched = false
            if targetId and r.tannedItemId == targetId then matched = true
            elseif r.tannedItemName and r.tannedItemName:lower() == targetLower then matched = true end
            if matched then
                table.insert(recipes, {
                    category = "Tanning",
                    skill = "Crafting",
                    level = 1,
                    xp = 0,
                    materials = "1x [[" .. (r.rawItemName or "Raw Hide") .. "]], " .. (r.coinCost or 0) .. " [[Coins]]",
                    product = "[[" .. r.tannedItemName .. "]]",
                    notes = "Tanned at a Tanner NPC"
                })
            end
        end
    end

    -- 3. Gem Cutting
    if craftingData.gemCutting then
        for _, r in ipairs(craftingData.gemCutting) do
            local matched = false
            if targetId and r.cutItemId == targetId then matched = true
            elseif r.cutItemName and r.cutItemName:lower() == targetLower then matched = true end
            if matched then
                table.insert(recipes, {
                    category = "Gem Cutting",
                    skill = "Crafting",
                    level = r.levelRequired,
                    xp = r.xpReward,
                    materials = "1x [[" .. (r.uncutItemName or "Uncut Gem") .. "]], [[Chisel]]",
                    product = "[[" .. r.cutItemName .. "]]",
                    notes = "Used in Jewelry & Enchanting"
                })
            end
        end
    end

    -- 4. Arrow Shafts
    if craftingData.arrowShafts then
        for _, r in ipairs(craftingData.arrowShafts) do
            local matched = (targetLower == "arrow shafts" or targetLower == "arrow shaft")
            if matched then
                table.insert(recipes, {
                    category = "Fletching",
                    skill = "Crafting",
                    level = r.levelRequired,
                    xp = r.xpReward,
                    materials = "1x [[" .. (r.logItemName or "Log") .. "]], [[Knife]]",
                    product = (r.shaftQuantity or 5) .. "x [[Arrow Shafts]]",
                    notes = "Carved from " .. (r.logItemName or "Log")
                })
            end
        end
    end

    -- 5. Bow Fletching
    if craftingData.bowFletching then
        for _, r in ipairs(craftingData.bowFletching) do
            -- Unstrung bow match
            if (targetId and r.unstrungItemId == targetId) or (r.unstrungItemName and r.unstrungItemName:lower() == targetLower) then
                table.insert(recipes, {
                    category = "Fletching",
                    skill = "Crafting",
                    level = r.levelRequired,
                    xp = r.carveXpReward or 0,
                    materials = "1x [[" .. (r.logItemName or "Log") .. "]], [[Knife]]",
                    product = "[[" .. r.unstrungItemName .. "]]",
                    notes = "Carving stage"
                })
            end
            -- Strung bow match
            if (targetId and r.strungItemId == targetId) or (r.strungItemName and r.strungItemName:lower() == targetLower) then
                table.insert(recipes, {
                    category = "Fletching",
                    skill = "Crafting",
                    level = r.levelRequired,
                    xp = r.stringXpReward or 0,
                    materials = "1x [[" .. (r.unstrungItemName or "Unstrung Bow") .. "]], 1x [[Bowstring]]",
                    product = "[[" .. r.strungItemName .. "]]",
                    notes = "Stringing stage"
                })
            end
            -- HQ Strung bow match
            if (targetId and r.hqStrungItemId == targetId) or (r.hqStrungItemName and r.hqStrungItemName:lower() == targetLower) then
                table.insert(recipes, {
                    category = "Fletching",
                    skill = "Crafting",
                    level = r.levelRequired,
                    xp = r.stringXpReward or 0,
                    materials = "1x [[" .. (r.unstrungItemName or "Unstrung Bow") .. "]], 1x [[Bowstring]]",
                    product = "[[" .. r.hqStrungItemName .. "]]",
                    notes = "High Quality proc during stringing"
                })
            end
        end
    end

    -- 6. Arrow Fletching
    if craftingData.arrowFletching then
        for _, r in ipairs(craftingData.arrowFletching) do
            if (targetId and r.arrowItemId == targetId) or (r.arrowItemName and r.arrowItemName:lower() == targetLower) then
                table.insert(recipes, {
                    category = "Fletching",
                    skill = "Crafting",
                    level = r.levelRequired,
                    xp = r.xpReward,
                    materials = "1x [[Headless Arrows]], 1x [[" .. (r.arrowheadItemName or "Arrowheads") .. "]]",
                    product = "[[" .. r.arrowItemName .. "]]",
                    notes = "Fletched ammunition"
                })
            end
        end
    end

    -- 7. Vorass Weapons
    if craftingData.vorassWeapons then
        for _, r in ipairs(craftingData.vorassWeapons) do
            if (targetId and r.outputItemId == targetId) or (r.outputItemName and r.outputItemName:lower() == targetLower) then
                local matList = {}
                if r.consume then
                    for _, c in ipairs(r.consume) do
                        table.insert(matList, (c.quantity or 1) .. "x [[" .. (c.itemName or "Material") .. "]]")
                    end
                end
                local notes = ""
                if r.firstCraftReward then
                    notes = notes .. "First Craft: +" .. (r.firstCraftReward.quantity or 0) .. " " .. capitalize(r.firstCraftReward.essence or "") .. " Essence. "
                end
                if r.essenceRewardChance then
                    local pct = math.floor((r.essenceRewardChance.chance or 0) * 100)
                    notes = notes .. pct .. "% chance of " .. (r.essenceRewardChance.quantity or 1) .. " " .. capitalize(r.essenceRewardChance.essence or "") .. " Essence."
                end
                table.insert(recipes, {
                    category = "Vorass Crafting",
                    skill = capitalize(r.skill or "Crafting"),
                    level = r.levelRequired,
                    xp = r.xpReward,
                    materials = table.concat(matList, ", "),
                    product = "[[" .. r.outputItemName .. "]]",
                    notes = notes
                })
            end
        end
    end

    -- 8. Bear Tooth Necklace
    if craftingData.bearToothNecklace then
        local r = craftingData.bearToothNecklace
        if (targetId and r.outputItemId == targetId) or (r.outputItemName and r.outputItemName:lower() == targetLower) then
            local matList = {}
            if r.consumed then
                for _, c in ipairs(r.consumed) do
                    table.insert(matList, (c.quantity or 1) .. "x [[" .. (c.itemName or "Material") .. "]]")
                end
            end
            table.insert(recipes, {
                category = "Jewelry Crafting",
                skill = "Crafting",
                level = r.levelRequired,
                xp = 0,
                materials = table.concat(matList, ", "),
                product = "[[" .. r.outputItemName .. "]]",
                notes = "Threaded necklace"
            })
        end
    end

    return recipes
end

-- ============================================================
-- Public Methods
-- ============================================================

-- Render recipe box in the =Sources= section of an item
function p.renderItemCraftingSource(frame)
    local targetName = frame.args[1] or (frame:getParent() and frame:getParent().args['name']) or mw.title.getCurrentTitle().text
    local recipes = findCraftingRecipes(targetName)

    if not recipes or #recipes == 0 then
        return ""
    end

    local out = '==Crafted from==\n'
    out = out .. '{| class="wikitable sortable" style="margin-top: 0.5em; width: 100%;"\n'
    out = out .. '|- style="background-color: #2e2e2e; color: white;"\n'
    out = out .. '! Skill !! Category !! Level Required !! Experience !! Materials Required !! Notes\n'

    for _, r in ipairs(recipes) do
        local xpStr = (r.xp and r.xp > 0) and tostring(r.xp) or "—"
        out = out .. '|-\n'
        out = out .. '| [[' .. r.skill .. ']]\n'
        out = out .. '| ' .. r.category .. '\n'
        out = out .. '| style="text-align: center;" | ' .. tostring(r.level) .. '\n'
        out = out .. '| style="text-align: center;" | ' .. xpStr .. '\n'
        out = out .. '| ' .. r.materials .. '\n'
        out = out .. '| ' .. (r.notes ~= "" and r.notes or "—") .. '\n'
    end

    out = out .. '|}\n'
    return out
end

-- Render full category tables for guide pages (e.g. /w/Crafting, /w/Fletching, /w/Tanning)
function p.renderCraftingTable(frame)
    local cat = frame.args['category'] or frame.args[1] or "leatherworking"
    cat = cat:lower()

    if cat == "leatherworking" or cat == "leather" then
        local out = '{| class="wikitable sortable" style="width: 100%;"\n'
        out = out .. '|- style="background-color: #2e2e2e; color: white;"\n'
        out = out .. '! Item !! Slot !! Level !! XP !! Materials Required\n'
        for _, r in ipairs(craftingData.leatherworking or {}) do
            out = out .. '|-\n'
            out = out .. '| [[' .. r.outputItemName .. ']]\n'
            out = out .. '| ' .. capitalize(r.slot or "") .. '\n'
            out = out .. '| style="text-align: center;" | ' .. tostring(r.levelRequired) .. '\n'
            out = out .. '| style="text-align: center;" | ' .. tostring(r.xpReward) .. '\n'
            out = out .. '| ' .. (r.hideQuantity or 1) .. 'x [[' .. (r.tannedHideItemName or "Tanned Hide") .. ']], [[Needle]], [[Thread]]\n'
        end
        out = out .. '|}\n'
        return out

    elseif cat == "tanning" then
        local out = '{| class="wikitable sortable" style="width: 100%;"\n'
        out = out .. '|- style="background-color: #2e2e2e; color: white;"\n'
        out = out .. '! Raw Material !! Tanned Leather !! Coin Cost\n'
        for _, r in ipairs(craftingData.tanning or {}) do
            out = out .. '|-\n'
            out = out .. '| [[' .. r.rawItemName .. ']]\n'
            out = out .. '| [[' .. r.tannedItemName .. ']]\n'
            out = out .. '| style="text-align: center;" | ' .. tostring(r.coinCost) .. ' [[Coins]]\n'
        end
        out = out .. '|}\n'
        return out

    elseif cat == "gemcutting" or cat == "gems" then
        local out = '{| class="wikitable sortable" style="width: 100%;"\n'
        out = out .. '|- style="background-color: #2e2e2e; color: white;"\n'
        out = out .. '! Uncut Gem !! Cut Gem !! Level Required !! XP Reward !! Tool\n'
        for _, r in ipairs(craftingData.gemCutting or {}) do
            out = out .. '|-\n'
            out = out .. '| [[' .. r.uncutItemName .. ']]\n'
            out = out .. '| [[' .. r.cutItemName .. ']]\n'
            out = out .. '| style="text-align: center;" | ' .. tostring(r.levelRequired) .. '\n'
            out = out .. '| style="text-align: center;" | ' .. tostring(r.xpReward) .. '\n'
            out = out .. '| [[Chisel]]\n'
        end
        out = out .. '|}\n'
        return out

    elseif cat == "bowfletching" or cat == "bows" then
        local out = '{| class="wikitable sortable" style="width: 100%;"\n'
        out = out .. '|- style="background-color: #2e2e2e; color: white;"\n'
        out = out .. '! Bow !! Log !! Level !! Carve XP !! Unstrung Bow !! String XP !! Finished Bow\n'
        for _, r in ipairs(craftingData.bowFletching or {}) do
            out = out .. '|-\n'
            out = out .. '| ' .. capitalize(r.bowLabel or "") .. '\n'
            out = out .. '| [[' .. r.logItemName .. ']]\n'
            out = out .. '| style="text-align: center;" | ' .. tostring(r.levelRequired) .. '\n'
            out = out .. '| style="text-align: center;" | ' .. tostring(r.carveXpReward or 0) .. '\n'
            out = out .. '| [[' .. r.unstrungItemName .. ']]\n'
            out = out .. '| style="text-align: center;" | ' .. tostring(r.stringXpReward or 0) .. '\n'
            out = out .. '| [[' .. r.strungItemName .. ']]\n'
        end
        out = out .. '|}\n'
        return out

    elseif cat == "vorass" or cat == "vorassweapons" then
        local out = '{| class="wikitable sortable" style="width: 100%;"\n'
        out = out .. '|- style="background-color: #2e2e2e; color: white;"\n'
        out = out .. '! Weapon !! Level !! XP !! Materials !! Rewards\n'
        for _, r in ipairs(craftingData.vorassWeapons or {}) do
            local matList = {}
            for _, c in ipairs(r.consume or {}) do
                table.insert(matList, (c.quantity or 1) .. 'x [[' .. (c.itemName or "Material") .. ']]')
            end
            local notes = ""
            if r.firstCraftReward then
                notes = notes .. "First Craft: +" .. tostring(r.firstCraftReward.quantity) .. " " .. capitalize(r.firstCraftReward.essence or "") .. " Essence. "
            end
            if r.essenceRewardChance then
                local pct = math.floor((r.essenceRewardChance.chance or 0) * 100)
                notes = notes .. pct .. "% chance of " .. tostring(r.essenceRewardChance.quantity) .. " " .. capitalize(r.essenceRewardChance.essence or "") .. " Essence."
            end
            out = out .. '|-\n'
            out = out .. '| [[' .. r.outputItemName .. ']]\n'
            out = out .. '| style="text-align: center;" | ' .. tostring(r.levelRequired) .. '\n'
            out = out .. '| style="text-align: center;" | ' .. tostring(r.xpReward) .. '\n'
            out = out .. '| ' .. table.concat(matList, ", ") .. '\n'
            out = out .. '| ' .. notes .. '\n'
        end
        out = out .. '|}\n'
        return out
    end

    return "Unknown crafting category: " .. cat
end

return p
