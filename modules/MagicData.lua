local p = {}

local magicData = mw.loadJsonData('Module:MagicData/json')
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

-- ============================================================
-- Public Methods
-- ============================================================

-- Master table of all 8 Transmutation conversions
function p.renderTransmutationTable(frame)
    local out = '{| class="wikitable sortable" style="width: 100%;"\n'
    out = out .. '|- style="background-color: #2e2e2e; color: white;"\n'
    out = out .. '! Magic School !! Required Level !! Input Material !! Output Material !! Exchange Ratio\n'

    for _, t in ipairs(magicData.transmutations or {}) do
        local schoolName = (t.school == "good" and "[[Light Magic]]") or "[[Dark Magic]]"
        local fromEssence = capitalize(t.from) .. " Essence"
        local toEssence = capitalize(t.to) .. " Essence"
        local ratio = tostring(t.inputQuantity) .. " : " .. tostring(t.outputQuantity)

        out = out .. '|-\n'
        out = out .. '| ' .. schoolName .. '\n'
        out = out .. '| style="text-align: center;" | ' .. tostring(t.levelRequired) .. '\n'
        out = out .. '| ' .. tostring(t.inputQuantity) .. 'x [[' .. fromEssence .. ']]\n'
        out = out .. '| \'\'\'' .. tostring(t.outputQuantity) .. 'x [[' .. toEssence .. ']]\'\'\'\n'
        out = out .. '| style="text-align: center;" | ' .. ratio .. '\n'
    end

    out = out .. '|}\n'
    return out
end

-- Master table of all 5 Enchanting Tiers
function p.renderEnchantingTable(frame)
    local out = '{| class="wikitable sortable" style="width: 100%;"\n'
    out = out .. '|- style="background-color: #2e2e2e; color: white;"\n'
    out = out .. '! Tier !! Essence Required !! Light Magic XP !! Compatible Relics & Artifacts\n'

    for _, t in ipairs(magicData.enchantingTiers or {}) do
        local relicLinks = {}
        for _, item in ipairs(t.items or {}) do
            table.insert(relicLinks, "[[" .. item.name .. "]]")
        end

        local essenceCost = tostring(t.elementalEssenceEach) .. " each of Air, Fire, Water, Earth"

        out = out .. '|-\n'
        out = out .. '| style="text-align: center; font-weight: bold;" | Tier ' .. tostring(t.tier) .. '\n'
        out = out .. '| ' .. essenceCost .. '\n'
        out = out .. '| style="text-align: center;" | ' .. tostring(t.goodMagicXp) .. ' XP\n'
        out = out .. '| ' .. table.concat(relicLinks, ", ") .. '\n'
    end

    out = out .. '|}\n'
    return out
end

-- Render recipe box in the =Sources= section of an item
function p.renderItemMagicSource(frame)
    local targetName = frame.args[1] or (frame:getParent() and frame:getParent().args['name']) or mw.title.getCurrentTitle().text
    local targetLower = targetName:lower()

    local sources = {}

    -- Check Transmutation outputs
    for _, t in ipairs(magicData.transmutations or {}) do
        local outName = (capitalize(t.to) .. " Essence"):lower()
        if targetLower == outName then
            local schoolName = (t.school == "good" and "Light Magic") or "Dark Magic"
            table.insert(sources, {
                type = "Transmutation",
                skill = schoolName,
                level = t.levelRequired,
                cost = tostring(t.inputQuantity) .. "x [[" .. capitalize(t.from) .. " Essence]]",
                product = tostring(t.outputQuantity) .. "x [[" .. capitalize(t.to) .. " Essence]]",
                notes = "Transmuted via " .. schoolName
            })
        end
    end

    -- Check Enchanting items
    for _, t in ipairs(magicData.enchantingTiers or {}) do
        for _, it in ipairs(t.items or {}) do
            if it.name:lower() == targetLower then
                table.insert(sources, {
                    type = "Enchanting (Tier " .. t.tier .. ")",
                    skill = "Light Magic",
                    level = 1,
                    cost = tostring(t.elementalEssenceEach) .. " each of Air, Fire, Water, Earth Essence",
                    product = "[[" .. it.name .. "]]",
                    notes = "+" .. tostring(t.goodMagicXp) .. " Light Magic XP"
                })
            end
        end
    end

    if #sources == 0 then
        return ""
    end

    local out = '==Magic Sources==\n'
    out = out .. '{| class="wikitable sortable" style="margin-top: 0.5em; width: 100%;"\n'
    out = out .. '|- style="background-color: #2e2e2e; color: white;"\n'
    out = out .. '! Method !! Skill !! Level !! Required Essence / Material !! Output !! Notes\n'

    for _, s in ipairs(sources) do
        out = out .. '|-\n'
        out = out .. '| ' .. s.type .. '\n'
        out = out .. '| [[' .. s.skill .. ']]\n'
        out = out .. '| style="text-align: center;" | ' .. tostring(s.level) .. '\n'
        out = out .. '| ' .. s.cost .. '\n'
        out = out .. '| ' .. s.product .. '\n'
        out = out .. '| ' .. s.notes .. '\n'
    end

    out = out .. '|}\n'
    return out
end

return p
