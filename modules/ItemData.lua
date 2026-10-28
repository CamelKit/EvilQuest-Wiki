local p = {}

local items = mw.loadJsonData('Module:ItemData/json')

-- Helper to find an item definition by Name or ID, with fallback for tea base names
local function findItemDef(targetName, id)
    local targetIdNum = tonumber(id)
    if targetIdNum then
        for _, item in ipairs(items) do
            if item.id == targetIdNum then
                return item
            end
        end
    end
    if not targetName then return nil end
    local targetLower = targetName:lower()
    for _, item in ipairs(items) do
        if item.name and item.name:lower() == targetLower then
            return item
        end
    end
    -- Fallback for tea base names (e.g. "Kawaki Tea" -> "Kawaki Tea (2 doses)")
    local twoDoseLower = targetLower .. " (2 doses)"
    for _, item in ipairs(items) do
        if item.name and item.name:lower() == twoDoseLower then
            return item
        end
    end
    return nil
end

local cargoStored = {}

local function cleanArg(val)
    if val == nil then return nil end
    local trimmed = mw.text.trim(tostring(val))
    if trimmed == "" then return nil end
    return trimmed
end

local function getEffectiveValue(targetField, item, parentArgs, frameArgs)
    local override = cleanArg(frameArgs and frameArgs['override'])
    if override then return override end

    if targetField == "examine" then
        local ex = cleanArg(frameArgs and frameArgs['examine']) or cleanArg(parentArgs and parentArgs['examine'])
        if ex then return ex end
        local desc = cleanArg(frameArgs and frameArgs['description']) or cleanArg(parentArgs and parentArgs['description'])
        if desc then return desc end
        if item then return item.examine or item.description end
        return nil
    end

    if targetField == "description" then
        local desc = cleanArg(frameArgs and frameArgs['description']) or cleanArg(parentArgs and parentArgs['description'])
        if desc then return desc end
        local ex = cleanArg(frameArgs and frameArgs['examine']) or cleanArg(parentArgs and parentArgs['examine'])
        if ex then return ex end
        if item then return item.description or item.examine end
        return nil
    end

    local fVal = cleanArg(frameArgs and frameArgs[targetField])
    if fVal then return fVal end

    local pVal = cleanArg(parentArgs and parentArgs[targetField])
    if pVal then return pVal end

    if item and item[targetField] ~= nil then
        return item[targetField]
    end
    return nil
end

function p.fetchItemData(frame)
    local parentArgs = (frame:getParent() and frame:getParent().args) or {}
    local targetName = cleanArg(frame.args[1]) or cleanArg(parentArgs['name']) or mw.title.getCurrentTitle().text
    local targetId = cleanArg(frame.args['id']) or cleanArg(parentArgs['id'])
    local targetField = cleanArg(frame.args['field'])
    if not targetField then return "Error: Missing 'field' parameter." end

    local item = findItemDef(targetName, targetId)

    -- Store effective values into Cargo table once per item per page render
    local storeKey = targetName or (item and tostring(item.id)) or ""
    if storeKey ~= "" and not cargoStored[storeKey] and mw.ext and mw.ext.cargo then
        cargoStored[storeKey] = true
        mw.ext.cargo.store('Items', {
            id          = getEffectiveValue('id', item, parentArgs, frame.args),
            name        = targetName,
            equipSlot   = getEffectiveValue('equipSlot', item, parentArgs, frame.args),
            value       = getEffectiveValue('value', item, parentArgs, frame.args),
            stabAttack  = getEffectiveValue('stabAttack', item, parentArgs, frame.args),
            slashAttack = getEffectiveValue('slashAttack', item, parentArgs, frame.args),
            crushAttack = getEffectiveValue('crushAttack', item, parentArgs, frame.args)
        })
    end

    local value = getEffectiveValue(targetField, item, parentArgs, frame.args)
    if value == nil then
        return ""
    elseif type(value) == "boolean" then
        return value and "Yes" or "No"
    else
        local str = tostring(value)
        local lower = str:lower()
        if lower == "true" or lower == "yes" then
            return "Yes"
        elseif lower == "false" or lower == "no" then
            return "No"
        end
        return str
    end
end

-- ================================
-- ===========AUTO TEXT===========
-- ================================

function p.generateDescription(frame)
    local parentArgs = (frame:getParent() and frame:getParent().args) or {}

    -- 1. Check for on-page description / overview overrides
    local override = cleanArg(frame.args['overview'])
        or cleanArg(frame.args['customDescription'])
        or cleanArg(frame.args['text'])
        or cleanArg(frame.args['summary'])
        or cleanArg(parentArgs['overview'])
        or cleanArg(parentArgs['customDescription'])
        or cleanArg(parentArgs['text'])
        or cleanArg(parentArgs['summary'])

    -- 2. If both examine and description are provided on the page, description acts as article overview
    if not override then
        local examineArg = cleanArg(frame.args['examine']) or cleanArg(parentArgs['examine'])
        local descArg = cleanArg(frame.args['description']) or cleanArg(parentArgs['description'])
        if examineArg and descArg and descArg ~= examineArg then
            override = descArg
        end
    end

    -- 3. If override is set, handle suppression keywords or return custom text
    if override then
        local lower = override:lower()
        if lower == "none" or lower == "hide" or lower == "off" or lower == "false" or lower == "no" then
            return ""
        end
        return override
    end

    local name = cleanArg(frame.args['name'])
        or cleanArg(parentArgs['name'])
        or cleanArg(frame.args[1])
        or mw.title.getCurrentTitle().text

    local item = findItemDef(name)
    if not item then return "" end

    local parts = {}
    local function add(s) table.insert(parts, s) end

    -- =====================
    -- HERBAL TEAS
    -- =====================
    local cookingData = nil
    pcall(function() cookingData = mw.loadJsonData('Module:CookingData/json') end)
    if cookingData and cookingData.herbalTeas then
        for _, tea in ipairs(cookingData.herbalTeas) do
            if tea.name:lower() == name:lower() or (tea.twoDoseItemName and tea.twoDoseItemName:lower() == name:lower()) then
                add("'''" .. tea.name .. "''' is an artisan herbal brew in EvilQuest crafted through the [[Cooking]] skill.")
                if tea.cookingLevel then
                    add("It requires level " .. tea.cookingLevel .. " Cooking to steep.")
                end
                if tea.leafItemName then
                    if tea.ingredient and tea.ingredient.name then
                        local qty = tea.ingredient.quantity or 1
                        local qtyStr = qty > 1 and (qty .. "x ") or ""
                        add("It is brewed by combining [[" .. tea.leafItemName .. "]] with " .. qtyStr .. "[[" .. tea.ingredient.name .. "]] in a [[Steaming Cup of Water]].")
                    else
                        add("It is brewed by steeping [[" .. tea.leafItemName .. "]] in a [[Steaming Cup of Water]].")
                    end
                elseif tea.special then
                    add("It can be purchased from taverns or general stores.")
                end

                local effectDesc = tea.effectSummary or (tea.inGameDescription and ("''" .. tea.inGameDescription .. "''")) or "beneficial herbal properties"
                add("\n\nWhen freshly steeped or obtained, it comes as a 2-dose cup. Drinking a dose grants " .. effectDesc .. ".")
                add("Consuming the first dose leaves behind a 1-dose cup, and drinking the second dose finishes the brew, leaving an [[Empty Cup]] in the player's inventory.")

                return table.concat(parts, " ")
            end
        end
    end

    -- =====================
    -- HELPERS
    -- =====================
    local function getTier(level)
        if not level then return nil end
        if level <= 24 then return "low-level"
        elseif level <= 44 then return "mid-level"
        else return "high-level" end
    end

    local metalBarMap = {
        ["Bronze"] = "Bronze Bar",
        ["Iron"] = "Iron Bar",
        ["Steel"] = "Steel Bar",
        ["Black Bronze"] = "Black Bronze Bar",
        ["Mithril"] = "Mithril Bar",
        ["Crimson"] = "Crimson Bar",
        ["Malachor"] = "Malachor Bar",
        ["Silver"] = "Silver Bar",
    }

    local metalDescMap = {
        ["Bronze"] = "the most basic of metals, making it ideal for beginner smiths and new adventurers",
        ["Iron"] = "a sturdy early-game metal, commonly used by adventurers beginning to establish themselves",
        ["Black Bronze"] = "an alloy of bronze and silver, offering a noticeable step up from iron for mid-level adventurers",
        ["Steel"] = "a reliable mid-tier metal, widely used by experienced adventurers across the world",
        ["Mithril"] = "a lightweight yet strong metal, favoured by seasoned adventurers seeking better protection and power",
        ["Crimson"] = "a rare high-tier metal with a deep red sheen, forged only by the most skilled smiths",
        ["Malachor"] = "an exceptionally rare endgame metal, sought after by only the most powerful adventurers in EvilQuest",
    }

    local function getMetalPrefix(itemName)
        local metals = {"Black Bronze", "Mithril", "Crimson", "Malachor", "Silver", "Steel", "Bronze", "Iron"}
        for _, metal in ipairs(metals) do
            if itemName:sub(1, #metal) == metal then
                return metal
            end
        end
        return nil
    end

    -- =====================
    -- NAME CHECKS
    -- =====================
    local isHQ = name:find("%(HQ%)") ~= nil
    local hasRaw = name:sub(1, 3) == "Raw"
    local hasUnstrung = name:find("Unstrung") ~= nil
    local isShortbow = name:find("Shortbow") ~= nil and not hasUnstrung
    local isBar = name:find(" Bar$") ~= nil
    local isOre = name:find(" Ore$") ~= nil or name == "Coal"
    local isLog = name:find(" Log$") ~= nil or name == "Log"
    local isHide = name:find(" Hide$") ~= nil
    local isTannedHide = name:find("^Tanned ") ~= nil
    local isUnfired = name:find("^Unfired ") ~= nil
    local isRelic = name:find("%(tier %d+%)") ~= nil
    local hasBones = name:find("Bones") ~= nil
    local isArrowheads = name:find("Arrowheads$") ~= nil
    local isArrows = name:find("Arrows$") ~= nil and not isArrowheads and name ~= "Arrow Shafts" and name ~= "Headless Arrows"
    local metal = getMetalPrefix(name)

    -- =====================
    -- HQ ITEMS
    -- =====================
    if isHQ then
        local baseName = name:gsub(" %(HQ%)", "")
        local tier = getTier(item.levelRequired)
        local tierStr = tier and (tier .. " ") or ""
        add("The ''''" .. name .. "'''' is a superior version of the [[" .. baseName .. "]], offering slightly improved stats for those lucky or skilled enough to obtain one.")
        if item.levelRequired and item.equipSkill then
            local skill = item.equipSkill:sub(1,1):upper() .. item.equipSkill:sub(2)
            add("Like its standard counterpart, it requires level " .. item.levelRequired .. " [[" .. skill .. "]] to equip.")
        end
        if metal and metalBarMap[metal] then
            add("It is smithed from [[" .. metalBarMap[metal] .. "|" .. metal:lower() .. " bars]] at an [[Anvil]] using a [[Hammer]].")
        end
        return table.concat(parts, " ")
    end

    -- =====================
    -- SPECIFIC NAMED ITEMS
    -- =====================
    if name == "Glasswort" then
        add("[[Glasswort]] is a coastal gathering material harvested from [[Glasswort Bush|Glasswort Bushes]] using a [[Knife]] with the [[Crafting]] skill.")
        add("\n\nIt is the secondary ingredient required to brew [[Catastrophea]], an experimental herbal tea prepared alongside [[Lox Tea Leaves]] in a [[Steaming Cup of Water]] requiring level 55 [[Cooking]]. It can also be burned in a furnace to produce [[Rich Soda Ash]].")
        return table.concat(parts, " ")
    end

    if name == "Coins" then
        add("[[Coins]] are the primary currency of EvilQuest, used to buy and sell items at shops and between players.")
        add("Every adventurer will find themselves accumulating coins through combat, trade, and selling unwanted loot — and spending them just as fast.")
        return table.concat(parts, " ")
    end

    if name == "Hammer" then
        add("The [[Hammer]] is an essential tool for any aspiring smith. It is used at an [[Anvil]] to shape metal [[Bars]] into weapons, armour, and other equipment through the [[Smithing]] skill.")
        add("\n\nEvery smith keeps one close at hand — without it, no smithing can be done at all. Hammers can be purchased from most general stores and are commonly found across the world of EvilQuest.")
        return table.concat(parts, " ")
    end

    if name == "Knife" then
        add("The [[Knife]] is a versatile crafting tool used across a wide range of [[Crafting]] tasks. It can be used on any [[Log]] to carve [[Arrow Shafts]], craft [[Unstrung Shortbow|unstrung bows]], or fashion a [[Bucket]] from two logs.")
        add("\n\nDespite its simple appearance, the Knife is one of the most useful items an adventurer can carry, enabling a wide variety of crafting activities without requiring any special equipment or locations.")
        return table.concat(parts, " ")
    end

    if name == "Matchbox" then
        add("The [[Matchbox]] is a small but essential tool for any adventurer venturing into the wilderness. It is used alongside any [[Log]] to light fires, which grants [[Survival]] experience.")
        add("\n\nFires lit with a Matchbox are the backbone of the [[Survival]] skill, and experienced woodcutters often carry one to make use of the logs they gather.")
        return table.concat(parts, " ")
    end

    if name == "Tinderbox" then
        add("The [[Tinderbox]] is the predecessor to the [[Matchbox]], used to light fires in earlier times. It functions in the same way, used alongside any [[Log]] to light fires and train the [[Survival]] skill.")
        return table.concat(parts, " ")
    end

    if name == "Bowstring" then
        add("A [[Bowstring]] is a vital crafting material used to string unfinished bows. It is spun from [[Low Quality Sinew]], which is itself obtained by cooking [[Raw Beef]] at a [[Cooking Range]].")
        add("\n\nWithout a bowstring, no bow can be completed — making it an essential item for any aspiring archer training the [[Fletching]] skill.")
        return table.concat(parts, " ")
    end

    if name == "Arrow Shafts" then
        add("[[Arrow Shafts]] are the wooden core of every arrow in EvilQuest, carved from logs using a [[Knife]]. Higher tier logs yield more shafts per log, making them a worthwhile investment for dedicated archers.")
        add("\n\nOnce crafted, Arrow Shafts can be combined with a [[Feather]] to create [[Headless Arrows]], which can then be tipped with [[Arrowheads]] to produce finished arrows ready for combat.")
        return table.concat(parts, " ")
    end

    if name == "Headless Arrows" then
        add("[[Headless Arrows]] are an intermediate crafting material in the arrow-making process, created by combining [[Arrow Shafts]] with a [[Feather]].")
        add("\n\nThey are not yet ready for use in combat, but can be tipped with arrowheads to create finished arrows:")
        add('\n\n{| class="wikitable"\n! Arrowheads !! Arrows\n|-\n| [[Bronze Arrowheads]] || [[Bronze Arrows]]\n|-\n| [[Iron Arrowheads]] || [[Iron Arrows]]\n|-\n| [[Steel Arrowheads]] || [[Steel Arrows]]\n|-\n| [[Black Bronze Arrowheads]] || [[Black Bronze Arrows]]\n|-\n| [[Mithril Arrowheads]] || [[Mithril Arrows]]\n|}')
        return table.concat(parts, " ")
    end

    if name == "Feather" then
        add("[[Feather|Feathers]] are a lightweight crafting material used in the [[Fletching]] skill. They are combined with [[Arrow Shafts]] to create [[Headless Arrows]], which can then be tipped with arrowheads to produce finished arrows.")
        add("\n\nFeathers are a common drop from various creatures and are always in demand among archers and fletchers alike.")
        return table.concat(parts, " ")
    end

    if name == "Clay" then
        add("[[Clay]] is a raw material mined from [[Clay Rock|Clay Rocks]] using a [[Pickaxes|Pickaxe]] while training [[Mining]]. On its own it is dry and brittle, but it becomes far more useful when softened.")
        add("\n\nCombining Clay with a [[Bucket of Water]] produces [[Soft Clay]], which can then be shaped into various pottery items using a [[Pottery Wheel]].")
        return table.concat(parts, " ")
    end

    if name == "Soft Clay" then
        add("[[Soft Clay]] is [[Clay]] that has been softened by combining it with a [[Bucket of Water]], making it pliable and ready for shaping.")
        add("\n\nSoft Clay is the primary material used in pottery, and can be worked on a [[Pottery Wheel]] to create a variety of useful items including [[Pot|Pots]], [[Bowl|Bowls]], and [[Plate|Plates]].")
        return table.concat(parts, " ")
    end

    if name == "Bucket" then
        add("The [[Bucket]] is a simple but practical container, crafted by using a [[Knife]] on 2 [[Log|Logs]]. Once made, it can be filled from any water source to create a [[Bucket of Water]].")
        add("\n\nBuckets are primarily used to transport water, which is needed to soften [[Clay]] into [[Soft Clay]] for use in [[Pottery]].")
        return table.concat(parts, " ")
    end

    if name == "Bucket of Water" then
        add("A [[Bucket of Water]] is a [[Bucket]] that has been filled from any water source. It is a key ingredient in softening [[Clay]] into [[Soft Clay]], which is used in the [[Pottery]] skill on a [[Pottery Wheel]].")
        add("\n\nKeeping a bucket of water on hand is a good habit for any adventurer dabbling in [[Crafting]].")
        return table.concat(parts, " ")
    end

    if name == "Low Quality Sinew" then
        add("[[Low Quality Sinew]] is a raw crafting material obtained by cooking [[Raw Beef]] at a [[Cooking Range]]. Despite its humble name, it is an important step in the bow-making process.")
        add("\n\nSinew is spun into a [[Bowstring]], which is used to string unfinished bows in the [[Fletching]] skill. Without it, no bowstring can be made.")
        return table.concat(parts, " ")
    end

    if name == "Suspect sketch" then
        add("The [[Suspect sketch]] is a rough drawing of a suspect connected to a crime in EvilQuest. It appears to have been hastily made, but the details are just clear enough to be useful.")
        add("\n\nThis item is tied to a quest and has no use outside of it.")
        return table.concat(parts, " ")
    end

    if name == "Prisoner's Heart" then
        add("The [[Prisoner's Heart]] is a grim quest item, still faintly warm to the touch. According to the item description, Lord Mortrek himself requested it — though the reasons behind that request are best left unasked.")
        add("\n\nThis item has no use outside of its associated quest.")
        return table.concat(parts, " ")
    end

    if name == "Bank Note" then
        add("A [[Bank Note]] is a paper certificate used by banks across EvilQuest as a convenient way to store and transfer wealth. Rather than carrying heavy coin purses, adventurers can exchange coins for bank notes and back again at any bank.")
        add("\n\nBank notes are stackable, making them a practical tool for moving large amounts of value in a single inventory slot.")
        return table.concat(parts, " ")
    end

    if name == "Evil token (tier 1)" then
        add("Evil tokens are a currency tied to the dark arts of [[Evil Magic]]. They are earned by offering [[Bones]] at an [[Obelisk]], and are spent to cast Evil Magic spells.")
        add("\n\nFor those walking the path of Evil Magic, accumulating these tokens is an essential part of progression.")
        return table.concat(parts, " ")
    end

    if name == "Warding Charm" then
        add("The [[Warding Charm]] is a small protective trinket with a little protective magic still lingering inside it. While its power may have faded over time, it remains a curious and somewhat useful relic for adventurers who come across one.")
        return table.concat(parts, " ")
    end

    if name == "Charcoal" then
        add("[[Charcoal]] is a dark, burnt material produced from wood. It has various uses in crafting and is often required as a component in more advanced recipes.")
        return table.concat(parts, " ")
    end

    if name == "Sulphur" then
        add("[[Sulphur]] is a yellow mineral with a sharp, distinctive smell. It is a crafting material with uses in various recipes, particularly those involving fire or explosive properties.")
        return table.concat(parts, " ")
    end

    if name == "Camel Cape" then
        add("The [[Camel Cape]] is a unique cosmetic cape awarded to players who participated in the very first playtest of EvilQuest. It serves as a badge of honour for the earliest adventurers who helped shape the game.")
        add("\n\nIt is the favourite cape of [[Ali the Oasis-Born]], who is rarely seen without it draped across his shoulders.")
        return table.concat(parts, " ")
    end

    if name == "Knight's Cape" then
        add("The [[Knight's Cape]] is widely regarded as the most sought-after cape in EvilQuest, and for good reason. Beyond its stunning visual design, it provides a small but meaningful offensive boost, making it as practical as it is stylish.")
        add("\n\nAny adventurer seen wearing one has clearly earned their place among the elite.")
        return table.concat(parts, " ")
    end

    if name == "Amulet of Power" then
        add("The [[Amulet of Power]] is a magical amulet that provides balanced combat bonuses across melee, magic, and ranged — making it a versatile choice for adventurers who don't want to commit to a single combat style.")
        add("\n\nIts all-around bonuses make it a popular choice for newer adventurers, and it remains useful well into mid-game progression.")
        return table.concat(parts, " ")
    end

    if name == "Staff" then
        add("The [[Staff]] is a basic magical weapon, offering a modest [[Magic]] accuracy bonus alongside its melee capabilities. It is the entry point for adventurers looking to explore the [[Magic]] skill in combat.")
        add("\n\nWhile not the most powerful weapon available, its accessibility makes it a common sight among beginning mages.")
        return table.concat(parts, " ")
    end

    if name == "Crystal Staff" then
        add("The [[Crystal Staff]] is a powerful magical weapon crafted from pure crystal, humming with concentrated magical energy. It offers significantly higher [[Magic]] accuracy than the basic [[Staff]], making it a prized possession for dedicated mages.")
        add("\n\nIts striking appearance and raw magical power make it one of the most recognisable weapons carried by advanced magic users in EvilQuest.")
        return table.concat(parts, " ")
    end

    if name == "Vampire Dagger" then
        add("The [[Vampire Dagger]] is a sinister mid-level stab weapon with a dark, unmistakable design. It requires level 30 [[Weaponry]] to wield, placing it firmly in the mid-game arsenal of any melee adventurer.")
        add("\n\nIts origins are unclear, but its effectiveness in combat is not.")
        return table.concat(parts, " ")
    end

    if name == "Chainmail" then
        add("[[Chainmail]] is a classic piece of iron body armour constructed from interlocking metal rings. It offers solid defensive coverage and has been a staple of adventurers for generations.")
        add("\n\nIt is smithed from [[Iron Bar|iron bars]] at an [[Anvil]] using a [[Hammer]].")
        return table.concat(parts, " ")
    end

    -- Gems
    local gemDesc = {
        ["Sapphire"] = "a brilliant blue gemstone prized for its deep, vivid colour",
        ["Emerald"] = "a rich green gemstone known for its striking hue and clarity",
        ["Ruby"] = "a deep red gemstone, its colour reminiscent of fresh blood — fitting for adventurers who spend their days in combat",
        ["Diamond"] = "a clear, flawless gemstone cut to catch and refract light in dazzling ways",
        ["Amethyst"] = "a purple gemstone cluster with a naturally beautiful crystalline form",
        ["Topaz"] = "a golden gemstone with a warm, glowing inner light",
        ["Opal"] = "a pale gemstone that shifts colour as it catches the light, making each one uniquely beautiful",
        ["Onyx"] = "a dark, glassy gemstone with a smooth surface that seems to absorb light rather than reflect it",
    }
    if gemDesc[name] then
        add("The [[" .. name .. "]] is " .. gemDesc[name] .. ".")
        add("\n\nGemstones like the " .. name .. " are used in various [[Crafting]] recipes and are often sought after for their value and beauty.")
        return table.concat(parts, " ")
    end

    -- Party hats
    if name:find("Party Hat") then
        local colour = name:gsub(" Party Hat", "")
        add("The [[" .. name .. "]] is a festive paper hat in a striking shade of " .. colour:lower() .. ". It serves no practical purpose in combat or crafting, but more than makes up for it in pure celebratory spirit.")
        add("\n\nParty hats are purely cosmetic items, worn by adventurers who want to stand out — or simply enjoy a good party.")
        return table.concat(parts, " ")
    end

    -- Farmer's Hat
    if name == "Farmer's Hat" then
        add("The [[Farmer's Hat]] is a broad-brimmed hat designed for long days working in the fields. It offers no combat bonuses, but its practical design makes it a recognisable sight across the farmlands of EvilQuest.")
        return table.concat(parts, " ")
    end

    -- Pottery items
    local potteryDesc = {
        ["Pot"] = "a simple fired clay pot, commonly used as a container",
        ["Bowl"] = "a simple fired clay bowl, useful for holding various ingredients and items",
        ["Plate"] = "a simple fired clay plate",
        ["Pot of Water"] = "a clay pot filled with water, useful for various crafting and cooking tasks",
    }
    if potteryDesc[name] then
        add("The [[" .. name .. "]] is " .. potteryDesc[name] .. ".")
        add("It is created by firing an [[Unfired " .. name .. "]] in a [[Kiln]].")
        return table.concat(parts, " ")
    end

    -- Unfired pottery
    if isUnfired then
        local firedName = name:gsub("^Unfired ", "")
        add("The [[" .. name .. "]] is a shaped clay item that has yet to be hardened. It is crafted from [[Soft Clay]] on a [[Pottery Wheel]], and must be fired in a [[Kiln]] to produce a finished [[" .. firedName .. "]].")
        return table.concat(parts, " ")
    end

    -- Cooked foods with healAmount
    if item.healAmount and not hasRaw and not item.equippable then
        local variations = {
            "a food item that restores " .. item.healAmount .. " HP when eaten",
            "a cooked food that heals " .. item.healAmount .. " HP upon consumption",
            "an edible item that restores " .. item.healAmount .. " hit points when consumed",
        }
        local variation = variations[(item.id % #variations) + 1]
        add("[[" .. name .. "]] is " .. variation .. ".")
        if name:find("^Cooked") or name:find("^Baked") then
            local rawName = name:gsub("^Cooked ", "Raw "):gsub("^Baked Potato", "Raw Potato")
            if itemsByName[rawName] then
                add("It is made by cooking [[" .. rawName .. "]] at a [[Cooking Range]].")
            end
        end
        return table.concat(parts, " ")
    end

    -- =====================
    -- RAW FOOD
    -- =====================
    if hasRaw then
        local rawExceptions = {
            ["Raw Chicken"] = "Cooked Chicken",
            ["Raw Beef"] = "Cooked Meat",
            ["Raw Shrimp"] = "Cooked Shrimp",
            ["Raw Rice"] = "Cooked Rice",
            ["Raw Potato"] = "Baked Potato",
        }
        local cookedName = rawExceptions[name]
        if not cookedName then
            local stripped = name:gsub("^Raw ", "")
            if itemsByName[stripped] and itemsByName[stripped].healAmount then
                cookedName = stripped
            end
        end
        add("[[" .. name .. "]] is a raw ingredient that must be cooked before it can be eaten.")
        if cookedName then
            add("It can be cooked into [[" .. cookedName .. "]] at a [[Cooking Range]].")
        else
            add("It can be cooked at a [[Cooking Range]].")
        end
        if name == "Raw Beef" then
            add("\n\nInterestingly, [[Raw Beef]] can also be rendered into [[Low Quality Sinew]] at a [[Cooking Range]], which is then used to craft a [[Bowstring]] for the [[Fletching]] skill.")
        end
        return table.concat(parts, " ")
    end

    -- =====================
    -- ORES
    -- =====================
    if isOre then
        local rockName
        if name == "Coal" then rockName = "Coal Rock"
        else rockName = name:gsub(" Ore$", "") .. " Rock" end
        local oreName = name:gsub(" Ore$", ""):lower()
        add("[[" .. name .. "]] is a raw mineral obtained by mining [[" .. rockName .. "|" .. rockName .. "s]] using a [[Pickaxes|Pickaxe]] while training [[Mining]].")
        if name == "Coal" then
            add("\n\nCoal is a crucial smelting ingredient used in the production of several metal bars, including [[Iron Bar|Iron]], [[Steel Bar|Steel]], [[Silver Bar|Silver]], and [[Mithril Bar|Mithril]] bars. Without coal, many of the game's most important metals cannot be smelted.")
        else
            add("\n\nOnce mined, " .. name .. " can be smelted at a [[Furnace]] using the [[Smithing]] skill to produce usable metal bars.")
        end
        return table.concat(parts, " ")
    end

    -- =====================
    -- BARS
    -- =====================
    if isBar then
        local barRecipes = {
            ["Bronze Bar"] = {level=1, recipe="[[Copper Ore]] and [[Tin Ore]]", products="[[Bronze]] weapons and armour", note="As the most basic metal bar in EvilQuest, it is the first bar most players will smelt and forms the foundation of early smithing progression."},
            ["Iron Bar"] = {level=11, recipe="[[Iron Ore]] alone (with a 50% success rate) or combined with [[Coal]] for a guaranteed smelt", products="[[Iron]] weapons and armour", note="The addition of coal to guarantee a successful smelt is a lesson many new smiths learn the hard way."},
            ["Steel Bar"] = {level=21, recipe="2 [[Iron Ore]] and [[Coal]]", products="[[Steel]] weapons and armour", note="Steel marks a significant step up in quality and is widely used by mid-level adventurers across EvilQuest."},
            ["Silver Bar"] = {level=31, recipe="[[Silver Ore]] and [[Coal]]", products="various silver items", note="Silver has unique properties that make it useful beyond standard smithing."},
            ["Black Bronze Bar"] = {level=31, recipe="[[Bronze Bar]] and [[Silver Bar]]", products="[[Black Bronze]] weapons and armour", note="The combination of bronze and silver gives black bronze its distinctive dark sheen and places it between iron and steel in terms of power."},
            ["Mithril Bar"] = {level=39, recipe="[[Mithril Ore]] and 2 [[Coal]]", products="[[Mithril]] weapons and armour", note="Mithril is a prized metal among high-level smiths, offering excellent stats for its weight."},
            ["Crimson Bar"] = {level=nil, recipe=nil, products="[[Crimson]] weapons and armour", note="Crimson metal is rare and highly sought after, used exclusively in the crafting of high-tier equipment."},
            ["Malachor Bar"] = {level=nil, recipe=nil, products="[[Malachor]] weapons and armour", note="Malachor is the rarest and most powerful metal in EvilQuest, reserved for only the most dedicated and skilled adventurers."},
        }
        local r = barRecipes[name]
        if r then
            add("The [[" .. name .. "]] is a refined metal bar used in [[Smithing]] to create " .. r.products .. " at an [[Anvil]] using a [[Hammer]].")
            if r.recipe and r.level then
                add("It is smelted at a [[Furnace]] using " .. r.recipe .. ", requiring level " .. r.level .. " [[Smithing]].")
            else
                add("It is smelted at a [[Furnace]] using the [[Smithing]] skill.")
            end
            add("\n\n" .. r.note)
        else
            add("The [[" .. name .. "]] is a metal bar used in [[Smithing]] to create equipment at an [[Anvil]] using a [[Hammer]].")
            add("It is smelted at a [[Furnace]] using the [[Smithing]] skill.")
        end
        return table.concat(parts, " ")
    end

    -- =====================
    -- LOGS
    -- =====================
    if isLog then
        local treeName
        local logTier = {
            ["Log"] = {tree="Tree", note="As the most basic log available, it is the first resource new woodcutters will gather and the starting point for both the [[Fletching]] and [[Survival]] skills."},
            ["Oak Log"] = {tree="Oak Tree", note="Oak logs are a step up from regular logs and are commonly used by early-level crafters."},
            ["Willow Log"] = {tree="Willow Tree", note="Willow logs are a popular choice for mid-level woodcutters thanks to their relatively fast cut speed."},
            ["Maple Log"] = {tree="Maple Tree", note="Maple logs are favoured by experienced woodcutters looking to balance experience and yield."},
            ["Yew Log"] = {tree="Yew Tree", note="Yew logs are highly valued for both their crafting potential and the significant [[Woodcutting]] experience they provide."},
            ["Mystic Log"] = {tree="Mystic Tree", note="Mystic logs are rare and powerful, sought after by the most dedicated woodcutters in EvilQuest."},
        }
        local logData = logTier[name] or {tree=name:gsub(" Log$", "") .. " Tree", note=""}
        add("The [[" .. name .. "]] is a log obtained by cutting down a [[" .. logData.tree .. "]] using the [[Woodcutting]] skill.")
        add("Logs can be used in the [[Crafting]] skill by using a [[Knife]] on them to carve [[Arrow Shafts]], craft [[Unstrung Shortbow|unstrung bows]], or make a [[Bucket]].")
        add("They can also be burned with a [[Matchbox]] to light fires, granting [[Survival]] experience.")
        if logData.note ~= "" then
            add("\n\n" .. logData.note)
        end
        return table.concat(parts, " ")
    end

    -- =====================
    -- HIDES
    -- =====================
    if isHide then
        add("The [[" .. name .. "]] is a raw hide obtained as a drop from its respective creature. It can be tanned at a tanner to produce [[Tanned " .. name .. "]], which is used in the [[Crafting]] skill to create leather armour and other items.")
        return table.concat(parts, " ")
    end

    if isTannedHide then
        local rawName = name:gsub("^Tanned ", "")
        add("[[" .. name .. "]] is a cured hide produced by tanning a [[" .. rawName .. "]] at a tanner. It is a key material in the [[Crafting]] skill, used to produce leather armour and various other items.")
        return table.concat(parts, " ")
    end

    -- =====================
    -- RELICS
    -- =====================
    if isRelic then
        local tier_num = name:match("%(tier (%d+)%)")
        add("The [[" .. name .. "]] is a tier " .. tier_num .. " relic — a mysterious ancient artefact steeped in forgotten history.")
        add("Relics of this tier can be offered at a [[Tier " .. tier_num .. " Altar]] to gain [[Good Magic]] experience.")
        add("\n\nThe origins of most relics are unknown, but their connection to the world's ancient past makes them objects of great interest to scholars and adventurers alike.")
        return table.concat(parts, " ")
    end

    -- =====================
    -- BONES
    -- =====================
    if hasBones then
        add("[[" .. name .. "]] are the skeletal remains left behind by defeated creatures. While they have no practical use in combat or crafting, they play an important role in the [[Evil Magic]] skill.")
        add("They can be offered at an [[Obelisk]] to gain [[Evil Magic]] experience and earn Evil Tokens, which are used to cast powerful Evil Magic spells.")
        if name == "Big Bones" then
            add("\n\nBig Bones are dropped by larger and more powerful creatures than regular [[Bones]], and grant more experience when offered.")
        end
        return table.concat(parts, " ")
    end

    -- =====================
    -- ARROWHEADS
    -- =====================
    if isArrowheads then
        local metalName = name:gsub(" Arrowheads$", "")
        local arrowName = metalName .. " Arrows"
        add("[[" .. name .. "]] are " .. metalName:lower() .. " arrowheads used in the [[Fletching]] skill to create [[" .. arrowName .. "]].")
        add("They are combined with [[Headless Arrows]] to produce finished arrows ready for use in [[Archery]].")
        add("[[Headless Arrows]] themselves are made by combining [[Arrow Shafts]] with a [[Feather]].")
        if item.stackable then
            add("\n\nLike all arrowheads, they are stackable and can be carried in large quantities in a single inventory slot.")
        end
        return table.concat(parts, " ")
    end

    -- =====================
    -- ARROWS (ammo)
    -- =====================
    if isArrows then
        local metalName = name:gsub(" Arrows$", "")
        local arrowheadName = metalName .. " Arrowheads"
        add("[[" .. name .. "]] are " .. metalName:lower() .. " arrows used as ammunition with bows in the [[Archery]] skill.")
        add("They are crafted through the [[Fletching]] skill by combining [[Headless Arrows]] with [[" .. arrowheadName .. "]].")
        add("[[Headless Arrows]] are made by combining [[Arrow Shafts]] with a [[Feather]].")
        if item.rangedStrength then
            add("\n\nThey provide a ranged strength bonus of +" .. item.rangedStrength .. ", making them " .. (item.rangedStrength >= 20 and "a solid choice for experienced archers" or "a good starting point for budding archers") .. ".")
        end
        return table.concat(parts, " ")
    end

    -- =====================
    -- UNSTRUNG BOWS
    -- =====================
    if hasUnstrung then
        local logName = name:match("Unstrung (%a+) Shortbow")
        local log = logName and (logName .. " Log") or "Log"
        local strungName = name:gsub("Unstrung ", "")
        add("The [[" .. name .. "]] is an unfinished bow carved from a [[" .. log .. "]] using a [[Knife]] as part of the [[Fletching]] skill.")
        add("On its own it cannot be used in combat, but combining it with a [[Bowstring]] will produce a finished [[" .. strungName .. "]] ready for use in [[Archery]].")
        return table.concat(parts, " ")
    end

    -- =====================
    -- SHORTBOWS
    -- =====================
    if isShortbow then
        local prefix = name:gsub(" Shortbow$", "")
        local unstrungName = "Unstrung " .. name
        local tier = getTier(item.levelRequired)
        local tierStr = tier and (tier .. " ") or ""
        add("The [[" .. name .. "]] is a " .. tierStr .. "ranged weapon that fires arrows as ammunition, used in the [[Archery]] skill.")
        if item.levelRequired then
            add("It requires level " .. item.levelRequired .. " [[Archery]] to wield.")
        end
        add("It can be crafted through the [[Fletching]] skill by combining an [[" .. unstrungName .. "]] with a [[Bowstring]].")
        if item.rangedAccuracy then
            add("\n\nWith a ranged accuracy of +" .. item.rangedAccuracy .. ", it is " .. (item.rangedAccuracy >= 40 and "a powerful choice for experienced archers" or "a reliable option for adventurers building their ranged arsenal") .. ".")
        end
        return table.concat(parts, " ")
    end

    -- =====================
    -- WEAPONS
    -- =====================
    if item.equippable and item.equipSlot == "weapon" and item.weaponStyle ~= "bow" then
        local tier = getTier(item.levelRequired)
        local tierStr = tier and (tier .. " ") or ""
        local style = item.weaponStyle or "melee"
        local barLink = metal and metalBarMap[metal] and ("[[" .. metalBarMap[metal] .. "|" .. metal:lower() .. " bars]]") or nil
        local metalDesc = metal and metalDescMap[metal] or nil

        if item.toolType then
            -- Tool weapons (axes, pickaxes)
            local toolDesc = item.toolType == "axe" and "woodcutting axe" or "mining pickaxe"
            add("The [[" .. name .. "]] is a " .. tierStr .. toolDesc .. " used in the [[" .. (item.toolType == "axe" and "Woodcutting" or "Mining") .. "]] skill, and can also be wielded as a " .. style .. " weapon in combat.")
            if item.toolLevel then
                add("A skill level of " .. item.toolLevel .. " is required to use it as a tool, and it provides a +" .. (item.toolBonus or 0) .. " extraction efficiency bonus.")
            end
            if barLink then
                add("It is smithed from " .. barLink .. " at an [[Anvil]] using a [[Hammer]].")
            end
            if metalDesc then
                add("\n\n" .. (metal or "This") .. " is " .. metalDesc .. ".")
            end
        else
            -- Combat weapons
            local weaponTypeMap = {
                ["stab"] = "dagger",
                ["slash"] = "sword",
                ["crush"] = "mace",
            }
            local weaponType = weaponTypeMap[style] or "weapon"

            local openings = {
                "The [[" .. name .. "]] is a " .. tierStr .. style .. " weapon used in the [[Weaponry]] skill.",
                "The [[" .. name .. "]] is a " .. tierStr .. style .. "-based weapon for adventurers training [[Weaponry]].",
                "The [[" .. name .. "]] is a " .. tierStr .. "melee weapon favouring the " .. style .. " attack style.",
            }
            add(openings[(item.id % #openings) + 1])

            if item.levelRequired then
                add("It requires level " .. item.levelRequired .. " [[Weaponry]] to wield.")
            end

            if barLink then
                add("It is smithed from " .. barLink .. " at an [[Anvil]] using a [[Hammer]].")
            end

            if item.twoHanded then
                add("Being a two-handed weapon, it occupies both the weapon and shield slots but offers greater strength in return.")
            end

            if metalDesc then
                add("\n\n" .. (metal or "This") .. " is " .. metalDesc .. ", and this weapon reflects that — " .. (item.levelRequired and ("requiring level " .. item.levelRequired .. " to wield") or "accessible to adventurers of all levels") .. ".")
            end

            if item.meleeStrength and item.meleeStrength >= 50 then
                add("Its impressive melee strength bonus of +" .. item.meleeStrength .. " makes it a serious threat in the right hands.")
            end
        end
        return table.concat(parts, " ")
    end

    -- =====================
    -- ARMOUR
    -- =====================
    if item.equippable and item.equipSlot ~= "weapon" and item.equipSlot ~= "ammo" then
        local tier = getTier(item.levelRequired)
        local tierStr = tier and (tier .. " ") or ""
        local slot = item.equipSlot or "equipment"
        local barLink = metal and metalBarMap[metal] and ("[[" .. metalBarMap[metal] .. "|" .. metal:lower() .. " bars]]") or nil
        local metalDesc = metal and metalDescMap[metal] or nil

        local slotDesc = {
            ["head"] = "head",
            ["body"] = "body",
            ["legs"] = "leg",
            ["shield"] = "shield",
            ["feet"] = "foot",
            ["cape"] = "back",
            ["neck"] = "neck",
            ["ammo"] = "ammo",
        }
        local slotWord = slotDesc[slot] or slot

        local openings = {
            "The [[" .. name .. "]] is a piece of " .. tierStr .. slotWord .. " armour used in the [[Defence]] skill.",
            "The [[" .. name .. "]] is a " .. tierStr .. slotWord .. " armour piece for adventurers training [[Defence]].",
            "The [[" .. name .. "]] is a " .. tierStr .. "piece of " .. slotWord .. " protection.",
        }

        if slot == "cape" then
            add("The [[" .. name .. "]] is a cape that can be worn on the back, offering a touch of style to any adventurer's outfit.")
        elseif slot == "neck" then
            add("The [[" .. name .. "]] is an amulet worn around the neck, providing combat bonuses to the wearer.")
        else
            add(openings[(item.id % #openings) + 1])
            if item.levelRequired then
                add("It requires level " .. item.levelRequired .. " [[Defence]] to equip.")
            end
            if barLink then
                add("It is smithed from " .. barLink .. " at an [[Anvil]] using a [[Hammer]].")
            end
            if metalDesc then
                add("\n\n" .. (metal or "This") .. " is " .. metalDesc .. ", and this piece of armour is a solid choice for adventurers at that stage of progression.")
            end
        end
        return table.concat(parts, " ")
    end

    -- =====================
    -- AMMO SLOT (arrows equipped)
    -- =====================
    if item.equippable and item.equipSlot == "ammo" then
        add("[[" .. name .. "]] are a type of ammunition equipped in the ammo slot and used with bows in the [[Archery]] skill.")
        if item.rangedStrength then
            add("They provide a ranged strength bonus of +" .. item.rangedStrength .. ".")
        end
        return table.concat(parts, " ")
    end

    -- =====================
    -- FALLBACK
    -- =====================
    add("The [[" .. name .. "]] is an item in EvilQuest.")
    return table.concat(parts, " ")
end

return p
