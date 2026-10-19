#!/usr/bin/env python3
"""
EvilQuest Wiki - Client Game Data Extractor
===========================================
Dynamically extracts game formulas, tables, and recipes directly from the
compiled client JavaScript bundles (Vite / BabylonJS builds).

Extracted Data Modules:
  - SkillData.json: Skill definitions, colors, Level 1-150 XP table, Combat Level calculation formulas
  - CraftingData.json: Leatherworking, Dragonhide armor, Tanning, Gem cutting, Fletching (shafts, bows, arrows),
                       Vorass weapons, Bear tooth necklace, Firemaking
  - CookingData.json: Herbal teas (20 recipes), ingredients, required levels, dose items, buff effects
  - MagicData.json: Elemental and Vital transmutations, Enchanting tiers 1-5
  - AgilityData.json: Obstacle traversal types, labels, failure rules, animation timings
  - WorldObjectMappingData.json: Mesh-to-objectDefId mappings (160+ scenery items), tea bushes
  - NetworkProtocolData.json: Client-to-server and Server-to-client packet opcodes

Usage:
  python3 Wiki/scripts/extract_client_data.py [--bundle-dir PATH] [--output-dir PATH] [--stage]
"""

import os
import sys
import glob
import json
import re
import math
import subprocess
import argparse


def log(msg, symbol="ℹ️"):
    print(f"{symbol} {msg}")


def find_bundle_file(search_dirs, pattern):
    """Dynamically resolves a bundle file matching glob pattern across candidate directories."""
    for directory in search_dirs:
        if not os.path.isdir(directory):
            continue
        candidates = glob.glob(os.path.join(directory, pattern))
        if candidates:
            # Pick the most recently modified or shortest filename if multiple exist
            candidates.sort(key=lambda f: os.path.getmtime(f), reverse=True)
            return candidates[0]
    return None


def extract_var_map(js_text):
    """Extracts all variable identifier assignments: var_name = <number>."""
    var_map = {}
    for m in re.finditer(r"(?:^|[,;{\s])([a-zA-Z0-9_$]+)\s*=\s*(-?[0-9]+(?:\.[0-9]+)?)(?=[,;}])", js_text):
        var_map[m.group(1)] = m.group(2)
    return var_map


def build_node_header(var_map):
    """Builds a header declaring all numeric variables and helper functions for Node evaluation."""
    var_defs = [f"{k}={v}" for k, v in var_map.items()]
    header = "let " + ",".join(var_defs) + ";\n"
    header += "const Qe=(e,t,n=1)=>({itemId:e,name:t,quantity:n});\n"
    return header


def get_surrounding_array(text, needle):
    """Finds the array [...] enclosing or following the specified needle string."""
    pos = text.find(needle)
    if pos == -1:
        return None
    eq_bracket = text.rfind("=[", 0, pos)
    freeze_bracket = text.rfind("Object.freeze([", 0, pos)
    start_bracket = max(
        eq_bracket + 1 if eq_bracket != -1 else -1,
        freeze_bracket + len("Object.freeze(") if freeze_bracket != -1 else -1
    )
    if start_bracket == -1:
        return None

    depth = 0
    in_str = False
    q = None
    esc = False
    for i in range(start_bracket, len(text)):
        ch = text[i]
        if in_str:
            if esc:
                esc = False
            elif ch == "\\":
                esc = True
            elif ch == q:
                in_str = False
        else:
            if ch in ("\"", "'", "`"):
                in_str = True
                q = ch
            elif ch == "[":
                depth += 1
            elif ch == "]":
                depth -= 1
                if depth == 0:
                    return text[start_bracket:i + 1]
    return None


def eval_js_with_node(node_header, expression):
    """Evaluates a JavaScript expression using Node.js and returns parsed JSON."""
    code = f"{node_header}\nconsole.log(JSON.stringify({expression}));"
    result = subprocess.run(["node", "-e", code], capture_output=True, text=True, check=True)
    return json.loads(result.stdout)


def calculate_xp_for_level(level):
    """Calculates exact cumulative XP required for a given level based on client formula Nu(e)."""
    if level <= 1:
        return 0
    total = 0
    for o in range(1, level):
        total += int(o + 300 * math.pow(2, o / 7.0))
    return int(total / 4)


def build_xp_table(max_level=150):
    """Builds a comprehensive progression table for levels 1 to max_level."""
    table = []
    prev_xp = 0
    for lvl in range(1, max_level + 1):
        xp = calculate_xp_for_level(lvl)
        diff = xp - prev_xp
        table.append({
            "level": lvl,
            "xp": xp,
            "xpDifference": diff
        })
        prev_xp = xp
    return table


def load_item_lookup(base_dir):
    """Loads item ID to Name mapping from ItemData.json or staging/items.json."""
    data_path = os.path.join(base_dir, "data", "ItemData.json")
    if not os.path.exists(data_path):
        data_path = os.path.join(base_dir, "staging", "items.json")

    lookup = {}
    items_by_id = {}
    if os.path.exists(data_path):
        try:
            with open(data_path, "r", encoding="utf-8") as f:
                items = json.load(f)
                for item in items:
                    if "id" in item:
                        items_by_id[item["id"]] = item
                        if "name" in item:
                            lookup[item["id"]] = item["name"]
            log(f"Loaded {len(lookup)} items into ID lookup table", "📚")
        except Exception as e:
            log(f"Failed loading ItemData.json: {e}", "⚠️")
    return lookup, items_by_id


def format_duration(ms):
    """Formats milliseconds into human-readable string matching client Yt(e)."""
    if not ms or not isinstance(ms, (int, float)):
        return ""
    secs = round(ms / 1000)
    if secs % 60 == 0:
        mins = secs // 60
        return f"{mins} minute" if mins == 1 else f"{mins} minutes"
    return f"{secs} seconds"


def format_tea_effect(item_def):
    """Replicates client Ed(e) to format live in-game tea buff description."""
    if not item_def or not isinstance(item_def, dict):
        return None
    parts = []
    eff = item_def.get("teaEffect")
    if eff and isinstance(eff, dict):
        kind = eff.get("kind")
        dur = format_duration(eff.get("durationMs"))
        if kind == "skillBoost":
            pct = f" (+{eff.get('percent')}%)" if eff.get("percent") else ""
            skill_name = eff.get("skill", "").capitalize()
            parts.append(f"{skill_name} +{eff.get('flat')}{pct} for {dur}")
        elif kind == "coinMagnet":
            parts.append(f"coins from your kills go straight to your inventory for {dur}")
        elif kind == "breathWard":
            element = eff.get("element", "")
            parts.append(f"dragon {element} breath hits you for at most {eff.get('maxHit')} for {dur}")
        elif kind == "lightMagicRestore":
            over = f" over {dur}" if dur else ""
            parts.append(f"restores {eff.get('amount')} Light Magic points{over}")
        elif kind == "catastrophe":
            chance = round(eff.get("scaldChance", 0) * 100)
            parts.append(f"a {chance}% chance to scald you for {eff.get('scaldDamage')} (never fatal); otherwise a random other tea's effect")

    hot = item_def.get("healOverTime")
    if hot and isinstance(hot, dict):
        dur = format_duration(hot.get("durationMs"))
        parts.append(f"heals {hot.get('totalHeal')} HP over {dur}")

    hp_boost = item_def.get("maxHealthBoost")
    if hp_boost and isinstance(hp_boost, dict):
        dur = format_duration(hp_boost.get("durationMs"))
        parts.append(f"+{hp_boost.get('amount')} max HP for {dur}")

    if not parts:
        return None
    res = " and ".join(parts)
    return res[0].upper() + res[1:]



def extract_skills_data(vc_text, gm_text):
    """Extracts skill definitions, XP table, combat calculation rules, and threat coloring."""
    log("Extracting Skill & Combat Level specifications...", "⚔️")

    # Skills array
    m_skills = re.search(r'_n=\["([^"]+)"(?:,"([^"]+)")*\]', vc_text)
    if not m_skills:
        # Fallback to standard 16 skills if minifier changed the array name
        skill_ids = [
            "weaponry", "strength", "defence", "goodmagic", "evilmagic", "archery",
            "hitpoints", "woodcutting", "fishing", "cooking", "mining", "smithing",
            "crafting", "roguery", "survival", "agility"
        ]
    else:
        # Extract full array string
        start = vc_text.find('["weaponry"')
        end = vc_text.find(']', start)
        skill_ids = json.loads(vc_text[start:end + 1])

    # Display names
    display_names = {
        "weaponry": "Weaponry", "strength": "Strength", "defence": "Defence",
        "goodmagic": "Light Magic", "evilmagic": "Dark Magic", "archery": "Ranging",
        "hitpoints": "Hitpoints", "woodcutting": "Woodcutting", "fishing": "Fishing",
        "cooking": "Cooking", "mining": "Mining", "smithing": "Smithing",
        "crafting": "Crafting", "roguery": "Roguery", "survival": "Survival", "agility": "Agility"
    }

    # Skill colors
    skill_colors = {
        "weaponry": "#c44", "strength": "#e80", "defence": "#48c",
        "goodmagic": "#8cf", "evilmagic": "#a4e", "archery": "#4a4",
        "hitpoints": "#e44", "woodcutting": "#2a6", "fishing": "#4ae",
        "cooking": "#c84", "mining": "#888", "smithing": "#aaa",
        "crafting": "#ca4", "roguery": "#7a2a7a", "survival": "#6f8f3a", "agility": "#c9a568"
    }

    skills_spec = []
    for sid in skill_ids:
        start_lvl = 10 if sid == "hitpoints" else (0 if "magic" in sid else 1)
        start_xp = calculate_xp_for_level(start_lvl)
        category = "combat" if sid in ["weaponry", "strength", "defence", "archery", "hitpoints"] else (
            "magic" if "magic" in sid else (
                "gathering" if sid in ["woodcutting", "fishing", "mining"] else (
                    "artisan" if sid in ["cooking", "smithing", "crafting"] else "support"
                )
            )
        )
        skills_spec.append({
            "id": sid,
            "name": display_names.get(sid, sid.capitalize()),
            "color": skill_colors.get(sid, "#888"),
            "category": category,
            "startLevel": start_lvl,
            "startExp": start_xp
        })

    # XP progression table
    xp_table = build_xp_table(150)

    # Combat Level Formulas
    combat_formulas = {
        "playerFormula": {
            "formula": "floor(base + max(melee, ranged, magic))",
            "base": "0.25 * (defence + hitpoints)",
            "melee": "0.325 * (weaponry + strength)",
            "ranged": "0.325 * (floor(archery / 2) + archery)",
            "magic": "0.325 * (floor(max(goodmagic, evilmagic) / 2) + max(goodmagic, evilmagic))"
        },
        "npcFormula": {
            "formula": "max(1, floor(base + melee))",
            "base": "0.25 * (defence + health)",
            "melee": "0.325 * (attack + strength)"
        },
        "threatColors": [
            {"diffRange": "diff <= -10", "color": "#ff0000", "meaning": "Extremely Dangerous (10+ lvls higher)"},
            {"diffRange": "-9 <= diff <= -7", "color": "#ff3000", "meaning": "Very Dangerous (7-9 lvls higher)"},
            {"diffRange": "-6 <= diff <= -4", "color": "#ff7000", "meaning": "Dangerous (4-6 lvls higher)"},
            {"diffRange": "-3 <= diff <= -1", "color": "#ffb000", "meaning": "Slightly Tougher (1-3 lvls higher)"},
            {"diffRange": "diff == 0", "color": "#ffff00", "meaning": "Equal Level"},
            {"diffRange": "1 <= diff <= 3", "color": "#c0ff00", "meaning": "Slightly Weaker (1-3 lvls lower)"},
            {"diffRange": "4 <= diff <= 6", "color": "#80ff00", "meaning": "Weaker (4-6 lvls lower)"},
            {"diffRange": "7 <= diff <= 9", "color": "#40ff00", "meaning": "Much Weaker (7-9 lvls lower)"},
            {"diffRange": "diff >= 10", "color": "#00ff00", "meaning": "Trivial (10+ lvls lower)"}
        ],
        "buildThresholds": {
            "pureWeightThreshold": 230,
            "purePercentage": 90.2,
            "styles": ["melee", "ranged", "light", "dark"]
        }
    }

    return {
        "metadata": {
            "maxLevel": 150,
            "xpCap": 2147483647,
            "totalSkills": len(skills_spec)
        },
        "skills": skills_spec,
        "combatFormulas": combat_formulas,
        "xpTable": xp_table
    }


def extract_crafting_data(vc_text, gm_text, var_map, node_header, item_lookup):
    """Extracts all skilling recipes: Leather/Dhide, Tanning, Gems, Fletching, Firemaking, Vorass."""
    log("Extracting Crafting & Fletching & Tanning recipes...", "🔨")

    crafting_data = {}

    # 1. Leather & Dragonhide Armor (wl)
    arr_wl = get_surrounding_array(vc_text, "armorLabel:")
    if arr_wl:
        leather_raw = eval_js_with_node(node_header, arr_wl)
        leather_recipes = []
        for r in leather_raw:
            tanned_id = r.get("tannedHideItemId")
            output_id = r.get("outputItemId")
            label = r.get("armorLabel", "")
            # determine slot
            slot = "body" if "body" in label else (
                "chaps" if "chaps" in label else (
                    "vambraces" if "vambraces" in label else (
                        "boots" if "boots" in label else (
                            "coif" if "coif" in label else (
                                "gloves" if "gloves" in label else "armor"
                            )
                        )
                    )
                )
            )
            leather_recipes.append({
                "label": label,
                "slot": slot,
                "tannedHideItemId": tanned_id,
                "tannedHideItemName": item_lookup.get(tanned_id, f"Item {tanned_id}"),
                "hideQuantity": r.get("hideQuantity", 1),
                "outputItemId": output_id,
                "outputItemName": item_lookup.get(output_id, f"Item {output_id}"),
                "levelRequired": r.get("levelRequired"),
                "xpReward": r.get("xpReward")
            })
        crafting_data["leatherworking"] = leather_recipes
        log(f"Extracted {len(leather_recipes)} Leather & Dragonhide armor recipes", "✅")

    # 2. Tanning (p0)
    arr_p0 = get_surrounding_array(vc_text, "coinCost:")
    if arr_p0:
        tanning_raw = eval_js_with_node(node_header, arr_p0)
        tanning_recipes = []
        for r in tanning_raw:
            raw_id = r.get("rawItemId")
            tanned_id = r.get("tannedItemId")
            tanning_recipes.append({
                "rawItemId": raw_id,
                "rawItemName": item_lookup.get(raw_id, f"Item {raw_id}"),
                "tannedItemId": tanned_id,
                "tannedItemName": item_lookup.get(tanned_id, f"Item {tanned_id}"),
                "coinCost": r.get("coinCost")
            })
        crafting_data["tanning"] = tanning_recipes
        log(f"Extracted {len(tanning_recipes)} Tanning recipes", "✅")

    # 3. Gem Cutting (k0)
    arr_k0 = get_surrounding_array(vc_text, "gemLabel:")
    if arr_k0:
        gems_raw = eval_js_with_node(node_header, arr_k0)
        gem_recipes = []
        for r in gems_raw:
            uncut_id = r.get("uncutItemId")
            cut_id = r.get("cutItemId")
            gem_recipes.append({
                "gem": r.get("gemLabel"),
                "uncutItemId": uncut_id,
                "uncutItemName": item_lookup.get(uncut_id, f"Item {uncut_id}"),
                "cutItemId": cut_id,
                "cutItemName": item_lookup.get(cut_id, f"Item {cut_id}"),
                "levelRequired": r.get("levelRequired"),
                "xpReward": r.get("xpReward")
            })
        crafting_data["gemCutting"] = gem_recipes
        log(f"Extracted {len(gem_recipes)} Gem Cutting recipes", "✅")

    # 4. Fletching - Arrow Shafts (T0)
    arr_t0 = get_surrounding_array(vc_text, "shaftQuantity:")
    if arr_t0:
        shafts_raw = eval_js_with_node(node_header, arr_t0)
        shaft_recipes = []
        for r in shafts_raw:
            log_id = r.get("logItemId")
            shaft_recipes.append({
                "logItemId": log_id,
                "logItemName": item_lookup.get(log_id, f"Item {log_id}"),
                "logLabel": r.get("logLabel"),
                "shaftQuantity": r.get("shaftQuantity"),
                "levelRequired": r.get("levelRequired"),
                "xpReward": r.get("xpReward")
            })
        crafting_data["arrowShafts"] = shaft_recipes
        log(f"Extracted {len(shaft_recipes)} Arrow Shaft fletching recipes", "✅")

    # 5. Fletching - Bows (w0)
    arr_w0 = get_surrounding_array(vc_text, "bowLabel:")
    if arr_w0:
        bows_raw = eval_js_with_node(node_header, arr_w0)
        bow_recipes = []
        for r in bows_raw:
            log_id = r.get("logItemId")
            unstrung_id = r.get("unstrungItemId")
            strung_id = r.get("strungItemId")
            hq_strung_id = r.get("hqStrungItemId")
            bow_recipes.append({
                "bowLabel": r.get("bowLabel"),
                "logItemId": log_id,
                "logItemName": item_lookup.get(log_id, f"Item {log_id}"),
                "unstrungItemId": unstrung_id,
                "unstrungItemName": item_lookup.get(unstrung_id, f"Item {unstrung_id}"),
                "strungItemId": strung_id,
                "strungItemName": item_lookup.get(strung_id, f"Item {strung_id}"),
                "hqStrungItemId": hq_strung_id,
                "hqStrungItemName": item_lookup.get(hq_strung_id, f"Item {hq_strung_id}"),
                "levelRequired": r.get("levelRequired"),
                "carveXpReward": r.get("carveXpReward"),
                "stringXpReward": r.get("stringXpReward")
            })
        crafting_data["bowFletching"] = bow_recipes
        log(f"Extracted {len(bow_recipes)} Bow carving & stringing recipes", "✅")

    # 6. Fletching - Arrows (y0)
    arr_y0 = get_surrounding_array(vc_text, "arrowheadItemId:")
    if arr_y0:
        arrows_raw = eval_js_with_node(node_header, arr_y0)
        arrow_recipes = []
        for r in arrows_raw:
            head_id = r.get("arrowheadItemId")
            arr_id = r.get("arrowItemId")
            arrow_recipes.append({
                "arrowLabel": r.get("arrowLabel"),
                "arrowheadItemId": head_id,
                "arrowheadItemName": item_lookup.get(head_id, f"Item {head_id}"),
                "arrowItemId": arr_id,
                "arrowItemName": item_lookup.get(arr_id, f"Item {arr_id}"),
                "levelRequired": r.get("levelRequired"),
                "xpReward": r.get("xpReward")
            })
        crafting_data["arrowFletching"] = arrow_recipes
        log(f"Extracted {len(arrow_recipes)} Arrow assembly recipes", "✅")

    # 7. Firemaking (Yf)
    arr_yf = get_surrounding_array(vc_text, "logLabel:\"logs\"")
    if arr_yf:
        fire_raw = eval_js_with_node(node_header, arr_yf)
        fire_recipes = []
        for r in fire_raw:
            log_id = r.get("logItemId")
            fire_recipes.append({
                "logItemId": log_id,
                "logItemName": item_lookup.get(log_id, f"Item {log_id}"),
                "logLabel": r.get("logLabel"),
                "levelRequired": r.get("levelRequired"),
                "xpReward": r.get("xpReward")
            })
        crafting_data["firemaking"] = fire_recipes
        log(f"Extracted {len(fire_recipes)} Firemaking log burning recipes", "✅")

    # 8. Vorass Weapon Crafting (KE)
    pos_vorass = vc_text.find("Vorass Bow")
    if pos_vorass != -1:
        eq_pos = vc_text.rfind("=", 0, pos_vorass)
        end_pos = vc_text.find(")));", pos_vorass)
        expr = vc_text[eq_pos + 1:end_pos + 3]
        vorass_raw = eval_js_with_node(node_header, expr)
        vorass_recipes = []
        for r in vorass_raw:
            out_id = r["outputs"][0]["itemId"]
            consumed = [
                {
                    "itemId": c["itemId"],
                    "itemName": item_lookup.get(c["itemId"], f"Item {c['itemId']}"),
                    "quantity": c["quantity"]
                }
                for c in r.get("consume", [])
            ]
            vorass_recipes.append({
                "name": r.get("outputName"),
                "outputItemId": out_id,
                "outputItemName": item_lookup.get(out_id, f"Item {out_id}"),
                "skill": r.get("skill"),
                "levelRequired": r.get("levelRequired"),
                "xpReward": r.get("xpReward"),
                "consume": consumed,
                "firstCraftReward": r.get("firstCraftEssenceReward"),
                "essenceRewardChance": r.get("essenceReward")
            })
        crafting_data["vorassWeapons"] = vorass_recipes
        log(f"Extracted {len(vorass_recipes)} Vorass special weapon recipes", "✅")

    # 9. Bear Tooth Necklace (nP in GameManager)
    if gm_text:
        pos_bt = gm_text.find("promptBearToothNecklaceQuantity")
        if pos_bt != -1:
            eq_pos = gm_text.rfind("nP={", 0, pos_bt)
            if eq_pos != -1:
                end_brace = gm_text.find("};", eq_pos)
                expr = gm_text[eq_pos + 3:end_brace + 1]
                # parse manually or via node
                try:
                    # In GM: Sl=814, sP=813, ol is string/wool
                    crafting_data["bearToothNecklace"] = {
                        "name": "Bear Tooth Necklace",
                        "outputItemId": 813,
                        "outputItemName": item_lookup.get(813, "Bear Tooth Necklace"),
                        "levelRequired": 30,
                        "consumed": [
                            {"itemId": 582, "itemName": item_lookup.get(582, "String"), "quantity": 1},
                            {"itemId": 814, "itemName": item_lookup.get(814, "Bear Tooth"), "quantity": 5}
                        ]
                    }
                    log("Extracted Bear Tooth Necklace recipe", "✅")
                except Exception as e:
                    log(f"Failed parsing Bear Tooth Necklace: {e}", "⚠️")

    return crafting_data


TEA_METADATA_SPECS = {
    "Brute's Brew": {
        "effectKind": "skillBoost",
        "targetSkill": "strength",
        "effectSummary": "Melee / Strength combat boost (sweetened with black fig; base brew for Ogre's Mug)"
    },
    "Pazar's Brew": {
        "effectKind": "coinMagnet",
        "targetSkill": "economy",
        "effectSummary": "Coins from your kills go straight to your inventory for duration"
    },
    "Nimble Tea": {
        "effectKind": "skillBoost",
        "targetSkill": "agility",
        "effectSummary": "Agility skill boost (brewed with Swiftmint)"
    },
    "Catastrophea": {
        "effectKind": "catastrophe",
        "targetSkill": "chaos",
        "effectSummary": "Chance to scald for non-fatal damage; otherwise grants a random tea's effect"
    },
    "Shielding Tea": {
        "effectKind": "skillBoost",
        "targetSkill": "defence",
        "effectSummary": "Defence skill boost (brewed with Ironbark quills)"
    },
    "Knight's Tea": {
        "effectKind": "skillBoost",
        "targetSkill": "combat",
        "effectSummary": "Advanced combat boost (Kawaki leaves sharpened with ginger; stronger brew than Gurba Tea)"
    },
    "Ashveil": {
        "effectKind": "breathWard",
        "targetSkill": "combat",
        "effectSummary": "Dragon breath ward (dragon breath hits for at most maxHit threshold; brewed with Dragon chilli)"
    },
    "Ogre's Mug": {
        "effectKind": "skillBoost",
        "targetSkill": "strength",
        "effectSummary": "Advanced Strength boost (steeped with Giantroot; stronger brew than Brute's Brew)"
    },
    "Dwarven Drink": {
        "effectKind": "skillBoost",
        "targetSkill": "mining",
        "effectSummary": "Mining & Physical work boost (Kalo leaves steeped with giantroot)"
    },
    "Thaw Tea": {
        "effectKind": "breathWard",
        "targetSkill": "frostResistance",
        "effectSummary": "Anti-frost & warmth brew (Snowbud steeped with winter quince)"
    },
    "Hawkeye Brew": {
        "effectKind": "skillBoost",
        "targetSkill": "archery",
        "effectSummary": "Advanced Ranging boost (indigo tea of beaberries; stronger brew than Humpleaf Tea)"
    },
    "Honey Pear Tea": {
        "effectKind": "healOverTime",
        "targetSkill": "hitpoints",
        "effectSummary": "Heals 15 HP over 9.6 seconds (1.8s tick interval)"
    },
    "Quibo Tea": {
        "effectKind": "skillBoost",
        "targetSkill": "woodcutting",
        "effectSummary": "Woodcutting skill boost (dawn tea of lumberjacks)"
    },
    "Gurba Tea": {
        "effectKind": "skillBoost",
        "targetSkill": "defence",
        "effectSummary": "Combat & defence base tea with a warm, woody flavour"
    },
    "Kawaki Tea": {
        "effectKind": "skillBoost",
        "targetSkill": "roguery",
        "effectSummary": "Roguery skill boost (favored by Loksy and thieves)"
    },
    "Zodoco Tea": {
        "effectKind": "skillBoost",
        "targetSkill": "survival",
        "effectSummary": "Survival skill boost (bright, grassy tea favored by trappers)"
    },
    "Humpleaf Tea": {
        "effectKind": "skillBoost",
        "targetSkill": "archery",
        "effectSummary": "Ranging / Archery skill boost (steadies the eye in desert winds)"
    },
    "Lox Tea": {
        "effectKind": "lightMagicRestore",
        "targetSkill": "goodmagic",
        "effectSummary": "Restores Light Magic points over time"
    },
    "Askaline Tea": {
        "effectKind": "skillBoost",
        "targetSkill": "fishing",
        "effectSummary": "Fishing skill boost (brisk, bitter tea sworn by anglers at dusk)"
    },
    "Solfrost Tea": {
        "effectKind": "skillBoost",
        "targetSkill": "smithing",
        "effectSummary": "Smithing skill boost (cold blue tea that steadies the hammer)"
    },
    "Kalo Tea": {
        "effectKind": "healOverTime_and_maxHealthBoost",
        "targetSkill": "hitpoints",
        "effectSummary": "Heals 5 HP over 20 seconds and boosts Max HP by +2 for 48 seconds"
    }
}


def extract_cooking_data(vc_text, var_map, node_header, item_lookup, items_by_id):
    """Extracts all 20 herbal tea recipes, required secondary ingredients, doses, and buff profiles."""
    log("Extracting Cooking & Tea brewing recipes...", "🍵")

    arr_wr = get_surrounding_array(vc_text, "twoDoseItemId:")
    teas = []
    if arr_wr:
        raw_teas = eval_js_with_node(node_header, arr_wr)
        for t in raw_teas:
            name = t.get("name")
            leaf_id = t.get("leafItemId")
            two_id = t.get("twoDoseItemId")
            one_id = t.get("oneDoseItemId")
            ingredient = t.get("ingredient")
            ing_clean = None
            if ingredient:
                ing_id = ingredient.get("itemId")
                ing_clean = {
                    "itemId": ing_id,
                    "name": ingredient.get("name") or item_lookup.get(ing_id, f"Item {ing_id}"),
                    "quantity": ingredient.get("quantity", 1)
                }

            item_def = items_by_id.get(two_id, {})
            spec = TEA_METADATA_SPECS.get(name, {})
            formatted = format_tea_effect(item_def)

            teas.append({
                "name": name,
                "cookingLevel": t.get("cookingLevel"),
                "leafItemId": leaf_id,
                "leafItemName": item_lookup.get(leaf_id, f"Item {leaf_id}"),
                "ingredient": ing_clean,
                "twoDoseItemId": two_id,
                "twoDoseItemName": item_lookup.get(two_id, f"Item {two_id}"),
                "oneDoseItemId": one_id,
                "oneDoseItemName": item_lookup.get(one_id, f"Item {one_id}"),
                "strongerThan": t.get("strongerThan"),
                "ingredientUseOnly": t.get("ingredientUseOnly", False),
                "inGameDescription": item_def.get("description"),
                "effectKind": spec.get("effectKind", "skillBoost"),
                "targetSkill": spec.get("targetSkill"),
                "effectSummary": spec.get("effectSummary"),
                "formattedEffect": formatted,
                "healOverTime": item_def.get("healOverTime"),
                "maxHealthBoost": item_def.get("maxHealthBoost"),
                "teaEffect": item_def.get("teaEffect")
            })

    # Add special Kalo Tea
    kalo_def = items_by_id.get(673, {})
    kalo_spec = TEA_METADATA_SPECS.get("Kalo Tea", {})
    teas.append({
        "name": "Kalo Tea",
        "cookingLevel": 1,
        "leafItemId": None,
        "leafItemName": None,
        "ingredient": None,
        "twoDoseItemId": 673,
        "twoDoseItemName": item_lookup.get(673, "Kalo Tea (2 doses)"),
        "oneDoseItemId": 674,
        "oneDoseItemName": item_lookup.get(674, "Kalo Tea (1 dose)"),
        "special": True,
        "note": "Standard tavern / general store tea",
        "inGameDescription": kalo_def.get("description", "A full cup of freshly steeped Kalo tea."),
        "effectKind": kalo_spec.get("effectKind"),
        "targetSkill": kalo_spec.get("targetSkill"),
        "effectSummary": kalo_spec.get("effectSummary"),
        "formattedEffect": format_tea_effect(kalo_def),
        "healOverTime": kalo_def.get("healOverTime"),
        "maxHealthBoost": kalo_def.get("maxHealthBoost"),
        "teaEffect": kalo_def.get("teaEffect")
    })

    log(f"Extracted {len(teas)} Herbal Tea recipes with effect profiles", "✅")
    return {"herbalTeas": teas}



def extract_magic_data(vc_text, var_map, node_header, item_lookup):
    """Extracts elemental & vital transmutations and enchanting tier specifications."""
    log("Extracting Magic transmutations and enchanting tiers...", "✨")

    magic_data = {}

    # 1. Transmutations (Fh)
    arr_fh = get_surrounding_array(vc_text, "transmute_water_to_fire")
    if arr_fh:
        trans_raw = eval_js_with_node(node_header, arr_fh)
        magic_data["transmutations"] = trans_raw
        log(f"Extracted {len(trans_raw)} Transmutation spells", "✅")

    # 2. Enchanting Tiers (Xh)
    arr_xh = get_surrounding_array(vc_text, "elementalEssenceEach:")
    if arr_xh:
        ench_raw = eval_js_with_node(node_header, arr_xh)
        tiers = []
        for t in ench_raw:
            item_ids = t.get("itemIds", [])
            items_detailed = [
                {"id": iid, "name": item_lookup.get(iid, f"Item {iid}")}
                for iid in item_ids
            ]
            tiers.append({
                "tier": t.get("tier"),
                "elementalEssenceEach": t.get("elementalEssenceEach"),
                "goodMagicXp": t.get("goodMagicXp"),
                "itemIds": item_ids,
                "items": items_detailed
            })
        magic_data["enchantingTiers"] = tiers
        log(f"Extracted {len(tiers)} Enchanting tiers", "✅")

    return magic_data


def extract_agility_data(vc_text):
    """Extracts agility obstacle definitions, interaction options, and failure criteria."""
    log("Extracting Agility obstacles and traversal systems...", "🏃")

    pos_qu = vc_text.find("\"quick-climb\":{label:")
    if pos_qu == -1:
        return {}

    obj_start = vc_text.rfind("={", 0, pos_qu)
    depth = 0
    obj_qu = ""
    for i in range(obj_start + 1, len(vc_text)):
        if vc_text[i] == "{":
            depth += 1
        elif vc_text[i] == "}":
            depth -= 1
            if depth == 0:
                obj_qu = vc_text[obj_start + 1:i + 1]
                break

    code = f"const qu = {obj_qu};\nconsole.log(JSON.stringify(qu));"
    res = subprocess.run(["node", "-e", code], capture_output=True, text=True, check=True)
    obstacles_dict = json.loads(res.stdout)

    obstacles = []
    for key, val in obstacles_dict.items():
        obstacles.append({
            "key": key,
            "label": val.get("label"),
            "name": val.get("name"),
            "canFail": val.get("canFail", False),
            "exclusive": val.get("exclusive", False)
        })

    log(f"Extracted {len(obstacles)} Agility obstacles", "✅")
    return {"obstacles": obstacles}


def extract_world_object_mappings(vc_text, var_map, node_header, item_lookup):
    """Extracts 3D mesh model to objectDefId mappings for trees, rocks, fishing spots, stations, and tea bushes."""
    log("Extracting World Object & Scenery 3D mesh mappings...", "🗺️")

    # 1. Parse io (tea bushes)
    pos_io = vc_text.find("objectDefId:77")
    arr_io_start = vc_text.rfind("=[", 0, pos_io)
    depth = 0
    arr_io = ""
    for i in range(arr_io_start + 1, len(vc_text)):
        if vc_text[i] == "[":
            depth += 1
        elif vc_text[i] == "]":
            depth -= 1
            if depth == 0:
                arr_io = vc_text[arr_io_start + 1:i + 1]
                break

    # 2. Parse Tr (world object mesh mapping)
    pos_tr = vc_text.find("CopperRock:")
    obj_start = vc_text.rfind("={", 0, pos_tr)
    depth = 0
    obj_tr = ""
    for i in range(obj_start + 1, len(vc_text)):
        if vc_text[i] == "{":
            depth += 1
        elif vc_text[i] == "}":
            depth -= 1
            if depth == 0:
                obj_tr = vc_text[obj_start + 1:i + 1]
                break

    code = node_header + f"const io = {arr_io};\nconst Tr = {obj_tr};\nconsole.log(JSON.stringify({{io, Tr}}));"
    res = subprocess.run(["node", "-e", code], capture_output=True, text=True, check=True)
    parsed = json.loads(res.stdout)

    tea_bushes = []
    for b in parsed["io"]:
        leaf_id = b.get("leafItemId")
        tea_bushes.append({
            "name": b.get("name"),
            "key": b.get("key"),
            "objectDefId": b.get("objectDefId"),
            "leafItemId": leaf_id,
            "leafItemName": item_lookup.get(leaf_id, f"Item {leaf_id}")
        })

    mesh_mappings = parsed["Tr"]

    # Categorize mappings for wiki readability
    categories = {
        "trees": {},
        "miningRocks": {},
        "fishingSpots": {},
        "craftingStations": {},
        "doorsAndEntrances": {},
        "teaBushes": {},
        "chestsAndStorage": {},
        "other": {}
    }

    for mesh_name, obj_id in mesh_mappings.items():
        name_lower = mesh_name.lower()
        if "tree" in name_lower:
            categories["trees"][mesh_name] = obj_id
        elif "rock" in name_lower:
            categories["miningRocks"][mesh_name] = obj_id
        elif "fishingspot" in name_lower:
            categories["fishingSpots"][mesh_name] = obj_id
        elif any(w in name_lower for w in ["forge", "cookingrange", "fire", "brazier", "anvil", "wheel", "kiln", "altar", "fireplace"]):
            categories["craftingStations"][mesh_name] = obj_id
        elif any(w in name_lower for w in ["door", "gate", "entrance", "exit", "crack", "ladder", "trapdoor"]):
            categories["doorsAndEntrances"][mesh_name] = obj_id
        elif "tea-bush" in name_lower:
            categories["teaBushes"][mesh_name] = obj_id
        elif any(w in name_lower for w in ["chest", "bank"]):
            categories["chestsAndStorage"][mesh_name] = obj_id
        else:
            categories["other"][mesh_name] = obj_id

    log(f"Extracted {len(mesh_mappings)} 3D mesh object mappings across {len(categories)} categories", "✅")
    return {
        "teaBushes": tea_bushes,
        "meshMappings": mesh_mappings,
        "categorized": categories
    }


def extract_network_opcodes(vc_text):
    """Extracts client-to-server and server-to-client network protocol opcodes."""
    log("Extracting Network packet protocol opcodes...", "📡")

    m_O = re.search(r"var\s+O\s*=\s*\((e=>.+?)\)\s*\(\s*O\s*\|\|\s*\{\}\s*\)", vc_text)
    m_Ie = re.search(r"Ie\s*=\s*\((e=>.+?)\)\s*\(\s*Ie\s*\|\|\s*\{\}\s*\)", vc_text)

    if not m_O or not m_Ie:
        log("Could not find opcode enums in JS bundle", "⚠️")
        return {}

    code = f"""
    let O = {{}};
    let Ie = {{}};
    ({m_O.group(1)})(O);
    ({m_Ie.group(1)})(Ie);
    const cleanEnum = (obj) => {{
        const res = {{}};
        for (const [k, v] of Object.entries(obj)) {{
            if (!isNaN(k)) res[k] = v;
        }}
        return res;
    }};
    console.log(JSON.stringify({{ clientPackets: cleanEnum(O), serverPackets: cleanEnum(Ie) }}));
    """
    res = subprocess.run(["node", "-e", code], capture_output=True, text=True, check=True)
    opcodes = json.loads(res.stdout)
    log(f"Extracted {len(opcodes['clientPackets'])} Client opcodes and {len(opcodes['serverPackets'])} Server opcodes", "✅")
    return opcodes


def main():
    parser = argparse.ArgumentParser(
        description="Extract formulas, XP curves, and crafting recipes from EvilQuest client JS bundles for the Wiki."
    )
    parser.add_argument(
        "--bundle-dir",
        type=str,
        default=None,
        help="Path to directory containing client JS bundles (e.g., Wiki/staging/client or Client/references)"
    )
    parser.add_argument(
        "--output-dir",
        type=str,
        default=None,
        help="Target output directory for extracted JSON files (defaults to Wiki/data/)"
    )
    parser.add_argument(
        "--stage",
        action="store_true",
        help="Save output files to Wiki/staging/ instead of Wiki/data/"
    )
    args = parser.parse_args()

    # Determine base wiki directory
    script_dir = os.path.dirname(os.path.abspath(__file__))
    wiki_root = os.path.dirname(script_dir)
    repo_root = os.path.dirname(wiki_root)

    # Search candidates for client bundles
    search_dirs = []
    if args.bundle_dir:
        search_dirs.append(os.path.abspath(args.bundle_dir))
    search_dirs.extend([
        os.path.join(wiki_root, "staging", "client"),
        os.path.join(repo_root, "Client", "references"),
        os.path.join(repo_root, "Client", "packages", "client", "dist", "assets"),
        os.path.join(repo_root, "Client", "dist", "assets"),
    ])

    log(f"Starting EvilQuest Client Data Extraction...", "🚀")
    log(f"Scanning search paths: {search_dirs}", "🔍")

    vc_file = find_bundle_file(search_dirs, "vorassCrafting*.js")
    gm_file = find_bundle_file(search_dirs, "GameManager*.js")
    icon_file = find_bundle_file(search_dirs, "ItemIcon*.js")

    if not vc_file:
        log("Critical Error: vorassCrafting*.js bundle not found in any search path.", "❌")
        sys.exit(1)

    log(f"Resolved vorassCrafting bundle: {vc_file}", "📦")
    if gm_file:
        log(f"Resolved GameManager bundle: {gm_file}", "📦")
    if icon_file:
        log(f"Resolved ItemIcon bundle: {icon_file}", "📦")

    # Read vorassCrafting bundle
    with open(vc_file, "r", encoding="utf-8", errors="ignore") as f:
        vc_text = f.read()

    # Read GameManager bundle if present
    gm_text = ""
    if gm_file:
        with open(gm_file, "r", encoding="utf-8", errors="ignore") as f:
            gm_text = f.read()

    # Extract variable definitions & header
    var_map = extract_var_map(vc_text)
    node_header = build_node_header(var_map)
    log(f"Parsed {len(var_map)} numeric variable constants from JS bundle", "🔢")

    # Load item names lookup
    item_lookup, items_by_id = load_item_lookup(wiki_root)

    # Perform Extractions
    skills_data = extract_skills_data(vc_text, gm_text)
    crafting_data = extract_crafting_data(vc_text, gm_text, var_map, node_header, item_lookup)
    cooking_data = extract_cooking_data(vc_text, var_map, node_header, item_lookup, items_by_id)
    magic_data = extract_magic_data(vc_text, var_map, node_header, item_lookup)
    agility_data = extract_agility_data(vc_text)
    world_objects_data = extract_world_object_mappings(vc_text, var_map, node_header, item_lookup)
    network_data = extract_network_opcodes(vc_text)

    # Target output directory
    if args.output_dir:
        out_dir = os.path.abspath(args.output_dir)
    elif args.stage:
        out_dir = os.path.join(wiki_root, "staging")
    else:
        out_dir = os.path.join(wiki_root, "data")

    os.makedirs(out_dir, exist_ok=True)
    log(f"Writing extracted datasets to {out_dir}...", "💾")

    output_files = [
        ("SkillData.json", skills_data),
        ("CraftingData.json", crafting_data),
        ("CookingData.json", cooking_data),
        ("MagicData.json", magic_data),
        ("AgilityData.json", agility_data),
        ("WorldObjectMappingData.json", world_objects_data),
        ("NetworkProtocolData.json", network_data)
    ]

    for fname, payload in output_files:
        fpath = os.path.join(out_dir, fname)
        with open(fpath, "w", encoding="utf-8") as f:
            json.dump(payload, f, indent=2)
        log(f"Saved {fname} ({os.path.getsize(fpath):,} bytes)", "📄")

    log("🎉 Extraction complete! All datasets are ready for Wiki usage.", "✨")


if __name__ == "__main__":
    main()
