local p = {}

local fishingData = mw.loadJsonData('Module:FishingData/json')
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

-- Helper to get direct edit URL for the community Catch XP template
local function getEditUrl()
    return "https://evilquest.wiki/index.php?title=Template:FishingXP&action=edit"
end

-- Helper to clean and format an XP input value
local function formatCatchXp(rawInput, defaultXp)
    local val = rawInput
    if val then
        val = tostring(val):gsub("^%s*(.-)%s*$", "%1")
    end

    local editUrl = getEditUrl()
    local unknownLink = '<span style="color: #e6a23c; font-style: italic;">Unknown</span> <small>([' .. editUrl .. ' contribute])</small>'

    if val and val ~= "" then
        if val:lower() == "unknown" or val == "?" or val == "-" then
            return unknownLink
        end
        -- If user just typed a number like "90", append " XP"
        if tonumber(val) then
            return "'''" .. val .. " XP'''"
        end
        if not val:lower():find("xp") then
            return "'''" .. val .. " XP'''"
        end
        return "'''" .. val .. "'''"
    end

    if defaultXp ~= nil then
        return "'''" .. tostring(defaultXp) .. " XP'''"
    end

    return unknownLink
end

-- Helper to look up Catch XP for a fish from:
-- 1. Direct frame args (| shrimp_xp = ...)
-- 2. Community Template:FishingXP (via frame:expandTemplate)
-- 3. Static FishingData.json baseline
local function getFishCatchXp(frame, fish)
    if not fish then return nil end
    local fishId = fish.id or fish.name:lower()

    -- 1. Check direct frame/parent args if explicitly passed
    local args = frame and frame.args or {}
    local parentArgs = (frame and frame.getParent and frame:getParent()) and frame:getParent().args or {}
    local userArg = args[fishId .. "_xp"] or args[fishId] or args[fish.name:lower() .. "_xp"] or
                    parentArgs[fishId .. "_xp"] or parentArgs[fishId] or parentArgs[fish.name:lower() .. "_xp"]
    if userArg and tostring(userArg):match("%S") then
        local trimmed = tostring(userArg):gsub("^%s*(.-)%s*$", "%1")
        if trimmed ~= "" then return trimmed end
    end

    -- 2. Check community Template:FishingXP
    if frame and frame.expandTemplate then
        local ok, val = pcall(function()
            return frame:expandTemplate{ title = 'FishingXP', args = { fishId } }
        end)
        if ok and val and tostring(val):match("%S") then
            local trimmed = tostring(val):gsub("^%s*(.-)%s*$", "%1")
            if trimmed ~= "" then return trimmed end
        end
    end

    -- 3. Fallback to datamined JSON baseline
    if fish.catchXp ~= nil then
        return tostring(fish.catchXp)
    end

    return nil
end

-- ============================================================
-- Public Methods
-- ============================================================

-- Master table of all Fishing Catches & Spots
function p.renderFishingTable(frame)
    local args = frame and frame.args or {}
    local parentArgs = (frame and frame.getParent and frame:getParent()) and frame:getParent().args or {}

    -- Helper to get argument from either direct args or parent args
    local function getArg(key)
        return args[key] or parentArgs[key]
    end

    local out = '{| class="wikitable sortable" style="width: 100%; text-align: left;"\n'
    out = out .. '|- style="background-color: #2e2e2e; color: white;"\n'
    out = out .. '! style="width: 6%; text-align: center;" | Lvl\n'
    out = out .. '! style="width: 16%;" | Fish / Catch\n'
    out = out .. '! style="width: 18%;" | Fishing Spot\n'
    out = out .. '! style="width: 13%;" | Required Tool\n'
    out = out .. '! style="width: 13%;" | Bait / Consumable\n'
    out = out .. '! style="width: 11%; text-align: center;" | Catch XP\n'
    out = out .. '! style="width: 14%;" | Cooked Food\n'
    out = out .. '! style="width: 9%;" | Notes\n'

    for _, fish in ipairs(fishingData.fishes or {}) do
        local xpVal = getFishCatchXp(frame, fish)
        local catchXpStr = formatCatchXp(xpVal, nil)

        local rawIcon = fish.rawItemId and ("[[File:Item_" .. fish.rawItemId .. ".png|21x21px|middle|link=" .. fish.rawItemName .. "]] ") or ""
        local rawLink = rawIcon .. "'''[[" .. fish.rawItemName .. "]]'''"

        local spotLink = fish.spotName and ("[[" .. fish.spotName .. "]]") or "Unknown"

        local toolIcon = fish.toolItemId and ("[[File:Item_" .. fish.toolItemId .. ".png|21x21px|middle|link=" .. fish.toolName .. "]] ") or ""
        local toolLink = toolIcon .. "[[" .. fish.toolName .. "]]"

        local baitLink = "None"
        if fish.requiredItemName then
            local baitIcon = fish.requiredItemId and ("[[File:Item_" .. fish.requiredItemId .. ".png|21x21px|middle|link=" .. fish.requiredItemName .. "]] ") or ""
            local qtyPrefix = (fish.requiredItemQuantity and fish.requiredItemQuantity > 1) and (fish.requiredItemQuantity .. "x ") or ""
            baitLink = baitIcon .. qtyPrefix .. "[[" .. fish.requiredItemName .. "]]"
        end

        local cookedCell = "—"
        if fish.cookedItemName then
            local cookedIcon = fish.cookedItemId and ("[[File:Item_" .. fish.cookedItemId .. ".png|21x21px|middle|link=" .. fish.cookedItemName .. "]] ") or ""
            local healStr = fish.healAmount and (" (" .. fish.healAmount .. " HP)") or ""
            local cookLvlStr = fish.cookingLevel and ("<br /><small>Lvl " .. fish.cookingLevel .. " Cook</small>") or ""
            cookedCell = cookedIcon .. "[[" .. fish.cookedItemName .. "]]" .. healStr .. cookLvlStr
        end

        local notes = fish.notes or ""

        out = out .. '|-\n'
        out = out .. '| style="text-align: center; font-weight: bold;" | ' .. tostring(fish.levelRequired or 1) .. '\n'
        out = out .. '| ' .. rawLink .. '\n'
        out = out .. '| ' .. spotLink .. '\n'
        out = out .. '| ' .. toolLink .. '\n'
        out = out .. '| ' .. baitLink .. '\n'
        out = out .. '| style="text-align: center;" | ' .. catchXpStr .. '\n'
        out = out .. '| ' .. cookedCell .. '\n'
        out = out .. '| ' .. notes .. '\n'
    end

    out = out .. '|}\n'
    return out
end

-- Directory of Fishing Equipment, Tools, and Consumables
function p.renderEquipmentTable(frame)
    local out = '{| class="wikitable sortable" style="width: 100%; text-align: left;"\n'
    out = out .. '|- style="background-color: #2e2e2e; color: white;"\n'
    out = out .. '! style="width: 6%; text-align: center;" | Lvl\n'
    out = out .. '! style="width: 22%;" | Equipment / Item\n'
    out = out .. '! style="width: 14%; text-align: center;" | Type\n'
    out = out .. '! style="width: 22%;" | Target Catches\n'
    out = out .. '! style="width: 36%;" | Description & Utility\n'

    for _, eq in ipairs(fishingData.equipment or {}) do
        local icon = eq.itemId and ("[[File:Item_" .. eq.itemId .. ".png|21x21px|middle|link=" .. eq.name .. "]] ") or ""
        local itemLink = icon .. "'''[[" .. eq.name .. "]]'''"

        local typeLabel = eq.type == "consumable" and '<span style="color: #e6a23c;">Consumable</span>' or '<span style="color: #64b5f6;">Gathering Tool</span>'

        local targets = {}
        for _, t in ipairs(eq.targets or {}) do
            table.insert(targets, "[[" .. t .. "]]")
        end
        local targetsStr = #targets > 0 and table.concat(targets, ", ") or "—"

        local desc = eq.description or ""
        if eq.consumedOnCatch then
            desc = desc .. " ''(Consumed upon successfully catching a fish.)''"
        end

        out = out .. '|-\n'
        out = out .. '| style="text-align: center; font-weight: bold;" | ' .. tostring(eq.levelRequired or 1) .. '\n'
        out = out .. '| ' .. itemLink .. '\n'
        out = out .. '| style="text-align: center;" | ' .. typeLabel .. '\n'
        out = out .. '| ' .. targetsStr .. '\n'
        out = out .. '| ' .. desc .. '\n'
    end

    out = out .. '|}\n'
    return out
end

-- Table of extended unreleased fish species from client files
function p.renderUnreleasedTable(frame)
    local out = '{| class="wikitable sortable" style="width: 100%; text-align: left;"\n'
    out = out .. '|- style="background-color: #2e2e2e; color: white;"\n'
    out = out .. '! style="width: 25%;" | Raw Catch\n'
    out = out .. '! style="width: 25%;" | Cooked Food\n'
    out = out .. '! style="width: 15%; text-align: center;" | Healing Amount\n'
    out = out .. '! style="width: 35%;" | Development Status & Notes\n'

    for _, u in ipairs(fishingData.unreleased or {}) do
        local rawIcon = u.rawItemId and ("[[File:Item_" .. u.rawItemId .. ".png|21x21px|middle|link=Raw " .. u.name .. "]] ") or ""
        local rawLink = rawIcon .. "[[Raw " .. u.name .. "]]"

        local cookedIcon = u.cookedItemId and ("[[File:Item_" .. u.cookedItemId .. ".png|21x21px|middle|link=" .. u.name .. "]] ") or ""
        local cookedLink = cookedIcon .. "'''[[" .. u.name .. "]]'''"

        local healStr = u.healAmount and (tostring(u.healAmount) .. " HP") or "—"

        local notes = "In game files; no active fishing spot."

        out = out .. '|-\n'
        out = out .. '| ' .. rawLink .. '\n'
        out = out .. '| ' .. cookedLink .. '\n'
        out = out .. '| style="text-align: center; font-weight: bold; color: #4ade80;" | ' .. healStr .. '\n'
        out = out .. '| ' .. notes .. '\n'
    end

    out = out .. '|}\n'
    return out
end

-- Render individual Catch XP value for a fish (used in tables and guides)
function p.renderCatchXp(frame)
    local target = frame.args[1] or (frame:getParent() and frame:getParent().args[1])
    if not target then return '<span style="color: #e6a23c; font-style: italic;">Unknown</span>' end
    local targetLower = target:lower()
    local matchedFish = nil
    for _, f in ipairs(fishingData.fishes or {}) do
        if (f.id and f.id:lower() == targetLower) or
           (f.name and f.name:lower() == targetLower) or
           (f.rawItemName and f.rawItemName:lower() == targetLower) or
           (f.cookedItemName and f.cookedItemName:lower() == targetLower) then
            matchedFish = f
            break
        end
    end
    if not matchedFish then
        return '<span style="color: #e6a23c; font-style: italic;">Unknown</span>'
    end
    local xpVal = getFishCatchXp(frame, matchedFish)
    return formatCatchXp(xpVal, nil)
end

-- Render fishing information on individual item pages
function p.renderItemFishing(frame)
    local targetName = frame.args[1] or (frame:getParent() and frame:getParent().args['name']) or mw.title.getCurrentTitle().text
    local targetLower = targetName:lower()

    local matchedFish = nil
    for _, f in ipairs(fishingData.fishes or {}) do
        if f.name:lower() == targetLower or f.rawItemName:lower() == targetLower or f.cookedItemName:lower() == targetLower then
            matchedFish = f
            break
        end
    end

    if not matchedFish then
        return ""
    end

    local out = '==Fishing Information==\n'
    out = out .. '{| class="wikitable" style="width: 100%; max-width: 600px;"\n'
    out = out .. '|- style="background-color: #2e2e2e; color: white;"\n'
    out = out .. '! Attribute !! Value\n'
    out = out .. '|-\n| Fishing Level Required || \'\'\'Lvl ' .. tostring(matchedFish.levelRequired) .. '\'\'\'\n'
    out = out .. '|-\n| Fishing Spot || [[' .. matchedFish.spotName .. ']]\n'
    out = out .. '|-\n| Required Tool || [[' .. matchedFish.toolName .. ']]\n'
    if matchedFish.requiredItemName then
        local qty = matchedFish.requiredItemQuantity or 1
        out = out .. '|-\n| Required Bait || ' .. (qty > 1 and (qty .. "x ") or "") .. '[[' .. matchedFish.requiredItemName .. ']]\n'
    end
    local xpVal = getFishCatchXp(frame, matchedFish)
    local xpDisplay = formatCatchXp(xpVal, nil)
    out = out .. '|-\n| Catch Experience || ' .. xpDisplay .. '\n'
    out = out .. '|}\n'
    return out
end

return p
