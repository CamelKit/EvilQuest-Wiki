local p = {}

-- Load crowdsourced drop JSON
local dropData = mw.loadJsonData('Module:DropData/json')

-- Helper to find monster entry by title or name
local function findMonster(rawTitle)
    if not dropData or not dropData.monsters then
        return nil
    end

    local baseName, targetLevel = string.match(rawTitle, "^(.-)%s*%(Lvl (.-)%)$")
    if not baseName then
        baseName = rawTitle
    end
    baseName = mw.text.trim(baseName)

    -- 1. Exact key match
    if dropData.monsters[rawTitle] then
        return dropData.monsters[rawTitle]
    end
    if dropData.monsters[baseName] then
        return dropData.monsters[baseName]
    end

    -- 2. Case-insensitive search
    local lowerRaw = rawTitle:lower()
    local lowerBase = baseName:lower()

    for key, monster in pairs(dropData.monsters) do
        local mKeyLower = key:lower()
        local mNameLower = (monster.name or ""):lower()

        if targetLevel and monster.combatLevel and tostring(monster.combatLevel) == targetLevel then
            if mNameLower == lowerBase or mKeyLower == lowerRaw then
                return monster
            end
        elseif mKeyLower == lowerBase or mNameLower == lowerBase or mKeyLower == lowerRaw then
            return monster
        end
    end

    return nil
end

-- Renders the drop table for an individual NPC page
function p.renderDrops(frame)
    local rawTitle = frame.args[1] or frame.args['name']
    if not rawTitle or rawTitle == "" then
        local parent = frame:getParent()
        if parent then
            rawTitle = parent.args[1] or parent.args['name']
        end
    end
    if not rawTitle or rawTitle == "" then
        rawTitle = mw.title.getCurrentTitle().text
    end
    local monster = findMonster(rawTitle)

    local dropCount = 0
    if monster and monster.drops then
        for _ in pairs(monster.drops) do
            dropCount = dropCount + 1
        end
    end

    local combatLvl = monster and monster.combatLevel
    if not combatLvl then
        local ok, npcJson = pcall(mw.loadJsonData, 'Module:NPCData/json')
        if ok and npcJson then
            for _, npc in pairs(npcJson) do
                if npc.name and npc.name:lower() == rawTitle:lower() then
                    combatLvl = npc.combatLevel
                    break
                end
            end
        end
    end

    if combatLvl and tonumber(combatLvl) ~= nil and tonumber(combatLvl) <= 0 then
        return ""
    end

    local html = {}
    table.insert(html, '<div style="clear: both;"></div>\n')
    table.insert(html, '== Drops ==\n')
    table.insert(html, '<div class="camelkit-drop-tracker" data-npc-name="' .. mw.text.encode(rawTitle) .. '" data-combat-level="' .. tostring(combatLvl or '') .. '">\n')

    if not monster or not monster.drops or dropCount == 0 then
        table.insert(html, '<div class="mw-message-box mw-message-box-notice camelkit-drops-empty" style="margin-top: 1em; font-style: italic;">No confirmed drops crowdsourced for this NPC yet. Slay this monster in <b>CamelKit</b> to automatically contribute drop rates!</div>\n')
    else
        -- Store into Cargo table MobDropInventory if Cargo extension is available
        if mw.ext and mw.ext.cargo then
            for _, drop in pairs(monster.drops) do
                local amount = drop.maxQuantity or drop.minQuantity or 1
                local rateVal = tonumber(drop.dropRatePct) or 0
                pcall(function()
                    mw.ext.cargo.store('MobDropInventory', {
                        Source = rawTitle,
                        Item = drop.name,
                        Amount = amount,
                        Rate = rateVal
                    })
                end)
            end
        end

        local killCount = monster.totalKills or 0
        local killsFormatted = mw.language.getContentLanguage():formatNum(killCount)

        table.insert(html, '<table class="wikitable sortable camelkit-drops-table" style="width: 100%; border-collapse: collapse; margin-top: 1em;">\n')
        table.insert(html, '<thead><tr style="background-color: #5c1d1d; color: white;">')
        table.insert(html, '<th>Item</th>')
        table.insert(html, '<th style="width: 100px;">Quantity</th>')
        table.insert(html, '<th style="width: 120px;">Rarity</th>')
        table.insert(html, '<th style="width: 140px;">Drop Rate</th>')
        table.insert(html, '<th style="width: 110px;">Reporters</th>')
        table.insert(html, '</tr></thead>\n')
        table.insert(html, '<tbody>\n')

        for _, drop in pairs(monster.drops) do
            local itemName = drop.name or ("Item #" .. tostring(drop.itemId))
            local qty = drop.quantityRange or tostring(drop.minQuantity or 1)
            local rarity = drop.rarity or "Common"
            local rateStr = drop.formattedRate or "~"
            local pctStr = string.format("%.2f%%", drop.dropRatePct or 0)
            local reporters = drop.uniqueReporters or 1

            -- Rarity color badge
            local rarityColor = "#4a5568"
            if rarity == "Always" then
                rarityColor = "#2b6cb0"
            elseif rarity == "Common" then
                rarityColor = "#2f855a"
            elseif rarity == "Uncommon" then
                rarityColor = "#d69e2e"
            elseif rarity == "Rare" then
                rarityColor = "#dd6b20"
            elseif rarity == "Very rare" then
                rarityColor = "#e53e3e"
            end

            table.insert(html, '<tr>')
            table.insert(html, '<td style="font-weight: bold;">[[' .. itemName .. ']]</td>')
            table.insert(html, '<td style="text-align: center;">' .. qty .. '</td>')
            table.insert(html, '<td style="text-align: center;"><span style="display: inline-block; padding: 2px 8px; border-radius: 4px; font-weight: bold; font-size: 85%; color: white; background-color: ' .. rarityColor .. ';">' .. rarity .. '</span></td>')
            table.insert(html, '<td style="text-align: center;" data-sort-value="' .. tostring(drop.dropRate or 0) .. '"><b>' .. rateStr .. '</b> <span style="font-size: 85%; color: #666;">(' .. pctStr .. ')</span></td>')
            table.insert(html, '<td style="text-align: center; color: #555;">' .. tostring(reporters) .. '</td>')
            table.insert(html, '</tr>\n')
        end

        table.insert(html, '</tbody>\n')
        table.insert(html, '</table>\n')
        table.insert(html, '<div class="camelkit-drop-footer" style="font-size: 85%; color: #666; margin-top: 4px; font-style: italic;">')
        table.insert(html, '<span style="display: inline-block; width: 7px; height: 7px; border-radius: 50%; background: #22c55e; margin-right: 5px;"></span>')
        table.insert(html, '🛡️ Crowdsourced via <b>CamelKit Drop Tracker</b> &mdash; based on ' .. killsFormatted .. ' recorded kills verified across multiple players.')
        table.insert(html, '</div>\n')
    end

    table.insert(html, '</div>\n')
    return table.concat(html)
end

return p
