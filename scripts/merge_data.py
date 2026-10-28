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


def classify_object_region(map_name, world_x, world_z):
    if map_name == "underground":
        return "The Sultan's Mine"
    if world_z > 350:
        return "Southern Desert Coast"
    if world_z > 170:
        if world_x > 250 and world_z < 260:
            return "Desert North (Sultan's Mine Entrance)"
        return "Great Desert"
    if world_x > 290 and world_z > 80:
        return "Graveyard & Eastern Ridge"
    if world_x > 220 and world_z > 100:
        return "Castle Mud Outskirts"
    if world_x > 200 and world_z <= 80:
        return "Gloomweb Swamp"
    if world_x <= 200 and world_z <= 100:
        return "Wibergis & Farmlands"
    return "Overworld Wilderness"


def enrich_objects(objects):
    base_dir = os.path.dirname(os.path.dirname(__file__))
    repo_root = os.path.dirname(base_dir)
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

    # Location enrichment from nodes.json
    nodes_map = os.path.join(repo_root, "Wiki-Map", "static", "data", "nodes.json")
    raw_nodes = []
    if os.path.exists(nodes_map):
        try:
            with open(nodes_map, "r", encoding="utf-8") as f:
                data = json.load(f)
                raw_nodes = data.get("nodes", [])
        except Exception as e:
            print(f"⚠️ Could not load {nodes_map}: {e}")

    if not raw_nodes:
        print("ℹ️ No world map nodes found to enrich Objects.")
        return objects

    # Group nodes by defId or lowercase name
    nodes_by_def = {}
    nodes_by_name = {}
    for n in raw_nodes:
        def_id = n.get("defId")
        if def_id is not None:
            nodes_by_def.setdefault(def_id, []).append(n)
        name = n.get("name")
        if name:
            nodes_by_name.setdefault(name.strip().lower(), []).append(n)

    enriched_count = 0
    for obj in objects:
        oid = obj.get("id")
        oname = (obj.get("name") or "").strip().lower()

        matched = nodes_by_def.get(oid) or nodes_by_name.get(oname)
        if not matched:
            obj.pop("locations", None)
            obj.pop("clusters", None)
            continue

        locations = []
        clusters_map = {}

        for node in matched:
            nmap = node.get("map", "surface")
            if nmap == "underground":
                wx = round(node.get("x", 0), 1)
                wz = round(node.get("z", 0), 1)
            else:
                wx = round(node.get("x", 0) - 192, 1)
                wz = round(node.get("z", 0) - 448, 1)

            reg = classify_object_region(nmap, wx, wz)
            loc_entry = {
                "id": node.get("id"),
                "map": nmap,
                "x": wx,
                "z": wz,
                "tileX": round(node.get("x", 0), 1),
                "tileZ": round(node.get("z", 0), 1),
                "region": reg
            }
            locations.append(loc_entry)

            key = (nmap, reg)
            clusters_map.setdefault(key, []).append(loc_entry)

        clusters = []
        for (m, reg), group in clusters_map.items():
            avg_x = round(sum(g["x"] for g in group) / len(group), 1)
            avg_z = round(sum(g["z"] for g in group) / len(group), 1)
            clusters.append({
                "map": m,
                "region": reg,
                "count": len(group),
                "x": avg_x,
                "z": avg_z,
                "sampleNodeId": group[0]["id"]
            })

        clusters.sort(key=lambda c: -c["count"])

        obj["locations"] = locations
        obj["clusters"] = clusters
        enriched_count += 1

    print(f"Enriched {enriched_count} Objects with world map locations and clusters.")
    return objects


def enrich_npcs(npcs):
    base_dir = os.path.dirname(os.path.dirname(__file__))
    repo_root = os.path.dirname(base_dir)
    staging_map = os.path.join(base_dir, "staging", "world-map.json")
    nodes_map = os.path.join(repo_root, "Wiki-Map", "static", "data", "nodes.json")

    raw_spawns = []
    if os.path.exists(staging_map):
        try:
            with open(staging_map, "r", encoding="utf-8") as f:
                data = json.load(f)
                raw_spawns = data.get("map", {}).get("npcSpawns", [])
        except Exception as e:
            print(f"⚠️ Could not load {staging_map}: {e}")

    if not raw_spawns and os.path.exists(nodes_map):
        try:
            with open(nodes_map, "r", encoding="utf-8") as f:
                data = json.load(f)
                raw_spawns = data.get("npcs", [])
        except Exception as e:
            print(f"⚠️ Could not load {nodes_map}: {e}")

    if not raw_spawns:
        print("ℹ️ No world map spawns found to enrich NPCs.")
        return npcs

    spawns_by_id = {}
    for s in raw_spawns:
        nid = s.get("npcId")
        if nid is not None:
            spawn_entry = {
                "name": s.get("name"),
                "x": round(s.get("x", 0), 1),
                "z": round(s.get("z", 0), 1),
                "floor": s.get("floor", 0),
                "wanderRange": s.get("wanderRange", 0),
            }
            if s.get("map"):
                spawn_entry["map"] = s.get("map")
            spawns_by_id.setdefault(nid, []).append(spawn_entry)

    enriched_count = 0
    for npc in npcs:
        nid = npc.get("id")
        if nid in spawns_by_id:
            npc["spawns"] = spawns_by_id[nid]
            enriched_count += 1
        else:
            npc.pop("spawns", None)

    print(f"Enriched {enriched_count} NPCs with world spawn coordinates and instance names.")
    return npcs


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
        post_processor=enrich_npcs,
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
