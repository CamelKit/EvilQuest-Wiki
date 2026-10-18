import os
import json

HARVEST_DEFINITIONS = {
    # --- Fishing Spots ---
    5: {
        "skill": "fishing",
        "action": "Fish",
        "toolItemId": 552,
        "outputItemId": 27,
    },
    67: {
        "skill": "fishing",
        "action": "Fish",
        "toolItemId": 557,
        "outputItemId": 501,
    },
    46: {
        "skill": "fishing",
        "action": "Fish",
        "toolItemId": 553,
        "requiredItemId": 564,
        "requiredItemQuantity": 1,
        "consumeRequiredItem": True,
        "outputItemId": 560,
    },
    47: {
        "skill": "fishing",
        "action": "Fish",
        "toolItemId": 554,
        "outputItemId": 510,
    },
    68: {
        "skill": "fishing",
        "action": "Fish",
        "toolItemId": 557,
        "outputItemId": 558,
    },
    48: {
        "skill": "fishing",
        "action": "Fish",
        "toolItemId": 554,
        "outputItemId": 562,
    },
    69: {
        "skill": "fishing",
        "action": "Fish",
        "toolItemId": 553,
        "requiredItemId": 564,
        "requiredItemQuantity": 1,
        "consumeRequiredItem": True,
        "outputItemId": 523,
    },

    # --- Trees (Woodcutting) ---
    1: {"skill": "woodcutting", "action": "Chop", "toolType": "axe", "toolName": "Axe", "outputItemId": 23},
    2: {"skill": "woodcutting", "action": "Chop", "toolType": "axe", "toolName": "Axe", "outputItemId": 24},
    9: {"skill": "woodcutting", "action": "Chop", "toolType": "axe", "toolName": "Axe", "outputItemId": 235},
    10: {"skill": "woodcutting", "action": "Chop", "toolType": "axe", "toolName": "Axe", "outputItemId": 23},
    14: {"skill": "woodcutting", "action": "Chop", "toolType": "axe", "toolName": "Axe", "outputItemId": 39},
    38: {"skill": "woodcutting", "action": "Chop", "toolType": "axe", "toolName": "Axe", "outputItemId": 40},
    89: {"skill": "woodcutting", "action": "Chop", "toolType": "axe", "toolName": "Axe", "outputItemId": 271},

    # --- Mining Rocks ---
    3: {"skill": "mining", "action": "Mine", "toolType": "pickaxe", "toolName": "Pickaxe", "outputItemId": 25},
    4: {"skill": "mining", "action": "Mine", "toolType": "pickaxe", "toolName": "Pickaxe", "outputItemId": 26},
    11: {"skill": "mining", "action": "Mine", "toolType": "pickaxe", "toolName": "Pickaxe", "outputItemId": 34},
    12: {"skill": "mining", "action": "Mine", "toolType": "pickaxe", "toolName": "Pickaxe", "outputItemId": 35},
    16: {"skill": "mining", "action": "Mine", "toolType": "pickaxe", "toolName": "Pickaxe", "outputItemId": 45},
    25: {"skill": "mining", "action": "Mine", "toolType": "pickaxe", "toolName": "Pickaxe", "outputItemId": 142},
    70: {"skill": "mining", "action": "Mine", "toolType": "pickaxe", "toolName": "Pickaxe", "outputItemId": 597},
    33: {"skill": "mining", "action": "Mine", "toolType": "pickaxe", "toolName": "Pickaxe", "outputItemId": 242},
    41: {"skill": "mining", "action": "Mine", "toolType": "pickaxe", "toolName": "Pickaxe", "outputItemId": 407},
    42: {"skill": "mining", "action": "Mine", "toolType": "pickaxe", "toolName": "Pickaxe", "outputItemId": 408},
    44: {"skill": "mining", "action": "Mine", "toolType": "pickaxe", "toolName": "Pickaxe", "outputItemId": 442},

    # --- Crops (Farming) ---
    22: {"skill": "farming", "action": "Pick", "outputItemId": 230},
    28: {"skill": "farming", "action": "Pick", "outputItemId": 238},
    29: {"skill": "farming", "action": "Pick", "outputItemId": 239},
    30: {"skill": "farming", "action": "Pick", "outputItemId": 241},
    71: {"skill": "crafting", "action": "Harvest", "outputItemId": 598},

    # --- Tea Bushes ---
    73: {"skill": "foraging", "action": "Forage", "outputItemId": 671},
    74: {"skill": "foraging", "action": "Forage", "outputItemId": 676},
    75: {"skill": "foraging", "action": "Forage", "outputItemId": 677},
    77: {"skill": "foraging", "action": "Forage", "outputItemId": 691},
    78: {"skill": "foraging", "action": "Forage", "outputItemId": 692},
    79: {"skill": "foraging", "action": "Forage", "outputItemId": 693},
    80: {"skill": "foraging", "action": "Forage", "outputItemId": 694},
    81: {"skill": "foraging", "action": "Forage", "outputItemId": 695},
    82: {"skill": "foraging", "action": "Forage", "outputItemId": 696},
    83: {"skill": "foraging", "action": "Forage", "outputItemId": 697},
    84: {"skill": "foraging", "action": "Forage", "outputItemId": 698},

    # --- Scenery Harvesting ---
    85: {"skill": "crafting", "action": "Cut", "requiredItemId": 251, "requiredItemQuantity": 1, "outputItemId": 699},
    86: {"skill": "crafting", "action": "Dig", "toolItemId": 775, "requiredItemId": 247, "requiredItemQuantity": 1, "outputItemId": 723},
}


def enrich_objects(objects):
    base_dir = os.path.dirname(os.path.dirname(__file__))
    items_path = os.path.join(base_dir, "data", "ItemData.json")
    if not os.path.exists(items_path):
        items_path = os.path.join(base_dir, "staging", "items.json")

    items_by_id = {}
    if os.path.exists(items_path):
        with open(items_path, "r", encoding="utf-8") as f:
            items_by_id = {it["id"]: it["name"] for it in json.load(f)}

    for obj in objects:
        obj_id = obj["id"]
        if obj_id in HARVEST_DEFINITIONS:
            harvest = dict(HARVEST_DEFINITIONS[obj_id])
            if "toolItemId" in harvest and "toolName" not in harvest:
                harvest["toolName"] = items_by_id.get(harvest["toolItemId"], f"Item {harvest['toolItemId']}")
            if "requiredItemId" in harvest and "requiredItemName" not in harvest:
                harvest["requiredItemName"] = items_by_id.get(harvest["requiredItemId"], f"Item {harvest['requiredItemId']}")
            if "outputItemId" in harvest and "outputItemName" not in harvest:
                harvest["outputItemName"] = items_by_id.get(harvest["outputItemId"], f"Item {harvest['outputItemId']}")
            obj["harvest"] = harvest

    return objects


def merge_entities(entity_name, data_path, staging_path, post_processor=None):
    print(f"\n--- Merging {entity_name} ---")
    if not os.path.exists(staging_path):
        print(f"Staging file not found: {staging_path} (Skipping...)")
        return

    # Load your historical data and the new update data
    old_entities = {}
    if os.path.exists(data_path):
        with open(data_path, "r", encoding="utf-8") as f:
            old_entities = {item["id"]: item for item in json.load(f)}

    with open(staging_path, "r", encoding="utf-8") as f:
        new_entities = {item["id"]: item for item in json.load(f)}

    merged_entities = []

    # Process all old items
    for entity_id, old_data in old_entities.items():
        if entity_id in new_entities:
            new_data = new_entities[entity_id]

            # DETECT RENAME: If the names don't match, save the old name
            if old_data.get("name") and new_data.get("name") and old_data["name"] != new_data["name"]:
                print(f"Rename detected (ID {entity_id}): '{old_data['name']}' is now '{new_data['name']}'")
                new_data["legacyName"] = old_data["name"]

            # Merge! new_data overwrites old_data, missing fields are preserved.
            merged_data = {**old_data, **new_data}
            merged_entities.append(merged_data)

            del new_entities[entity_id]
        else:
            # Item was removed from the game! Flag it as discontinued.
            old_data["discontinued"] = True
            merged_entities.append(old_data)
            print(f"Flagged as discontinued: {old_data.get('name', 'Unknown')} (ID: {entity_id})")

    # Any items left in new_items are brand new to the game
    for entity_id, new_data in new_entities.items():
        merged_entities.append(new_data)
        print(f"Added new {entity_name[:-1].lower()}: {new_data.get('name', 'Unknown')} (ID: {entity_id})")

    # Apply optional enrichment or post-processing
    if post_processor:
        merged_entities = post_processor(merged_entities)

    # Output the final JSON
    with open(data_path, "w", encoding="utf-8") as f:
        json.dump(merged_entities, f, indent=2)
    print(f"Successfully updated {os.path.basename(data_path)}")


def merge_game_data():
    base_dir = os.path.dirname(os.path.dirname(__file__))

    # Merge Items
    merge_entities(
        "Items",
        os.path.join(base_dir, "data", "ItemData.json"),
        os.path.join(base_dir, "staging", "items.json"),
    )

    # Merge NPCs
    merge_entities(
        "NPCs",
        os.path.join(base_dir, "data", "NpcData.json"),
        os.path.join(base_dir, "staging", "npcs.json"),
    )

    # Merge Rare Drop Tables
    merge_entities(
        "Rare Drop Tables",
        os.path.join(base_dir, "data", "RareDropData.json"),
        os.path.join(base_dir, "staging", "rare-drop-tables.json"),
    )

    # Merge Objects with Harvest/Gathering Enrichment
    merge_entities(
        "Objects",
        os.path.join(base_dir, "data", "ObjectData.json"),
        os.path.join(base_dir, "staging", "objects.json"),
        post_processor=enrich_objects,
    )


if __name__ == "__main__":
    merge_game_data()
