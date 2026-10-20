#!/usr/bin/env python3
"""
EvilQuest Wiki - Crowdsourced Drops Synchronizer
================================================
Fetches validated crowdsourced drop statistics and kill counts from the
Cloudflare Worker D1 backend (api.camelkit.dev), formats statistical drop tables,
updates Wiki/data/DropData.json, and pushes the data to Module:DropData/json.

Usage:
  python3 Wiki/scripts/sync_crowdsourced_drops.py [--api-url URL] [--include-unconfirmed] [--deploy] [--prod]
"""

import os
import sys
import json
import time
import argparse
import requests
from datetime import datetime, timezone

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", line_buffering=True)

BASE_DIR = os.path.dirname(os.path.dirname(__file__))
DATA_DIR = os.path.join(BASE_DIR, "data")
DROP_DATA_FILE = os.path.join(DATA_DIR, "DropData.json")
ITEM_DATA_FILE = os.path.join(DATA_DIR, "ItemData.json")
NPC_DATA_FILE = os.path.join(DATA_DIR, "NpcData.json")

# Load Wiki environment variables
env_file = os.path.join(BASE_DIR, ".env")
if os.path.exists(env_file):
    try:
        from dotenv import load_dotenv
        load_dotenv(env_file)
    except ImportError:
        with open(env_file, "r", encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith("#") and "=" in line:
                    k, v = line.split("=", 1)
                    if k.strip() not in os.environ:
                        os.environ[k.strip()] = v.strip()


def calculate_rarity(drop_rate):
    """Categorizes drop rate into standard RuneScape/RPG wiki tiers."""
    if drop_rate >= 0.999:
        return "Always"
    elif drop_rate >= 0.10:
        return "Common"
    elif drop_rate >= 0.02:
        return "Uncommon"
    elif drop_rate >= 0.004:
        return "Rare"
    else:
        return "Very rare"


def fetch_drops_from_api(api_base_url, include_unconfirmed=False, min_kills=0):
    url = f"{api_base_url.rstrip('/')}/wiki/drops"
    params = {}
    if include_unconfirmed:
        params["all"] = "1"
    if min_kills > 0:
        params["min_kills"] = str(min_kills)

    print(f"📡 Fetching crowdsourced drops from {url}...")
    try:
        resp = requests.get(url, params=params, timeout=20)
        resp.raise_for_status()
        data = resp.json()
        if not data.get("success"):
            print(f"❌ API returned failure response: {data}")
            return []
        return data.get("drops", [])
    except Exception as e:
        print(f"❌ Failed to reach Drops API at {url}: {e}")
        return []


def fetch_npc_kills_from_api(api_base_url):
    url = f"{api_base_url.rstrip('/')}/wiki/npc-kills"
    try:
        resp = requests.get(url, timeout=20)
        resp.raise_for_status()
        data = resp.json()
        if data.get("success"):
            return {npc["npc_def_id"]: npc for npc in data.get("npcs", [])}
    except Exception as e:
        print(f"⚠️ Could not fetch NPC kill stats: {e}")
    return {}


def build_drop_data(api_base_url, include_unconfirmed=False, min_kills=0):
    drops = fetch_drops_from_api(api_base_url, include_unconfirmed, min_kills)
    npc_kills = fetch_npc_kills_from_api(api_base_url)

    # Load local ItemData definitions for item names
    item_names = {}
    if os.path.exists(ITEM_DATA_FILE):
        with open(ITEM_DATA_FILE, "r", encoding="utf-8") as f:
            for item in json.load(f):
                item_names[item["id"]] = item.get("name", f"Item #{item['id']}")

    # Load local NpcData definitions
    npc_defs = {}
    if os.path.exists(NPC_DATA_FILE):
        with open(NPC_DATA_FILE, "r", encoding="utf-8") as f:
            for npc in json.load(f):
                npc_defs[npc["id"]] = npc

    monsters = {}
    total_kills_sum = sum(n.get("total_kills", 0) for n in npc_kills.values())

    for drop in drops:
        npc_def_id = drop["npc_def_id"]
        npc_name = drop.get("npc_name") or npc_defs.get(npc_def_id, {}).get("name") or f"NPC #{npc_def_id}"
        combat_level = drop.get("combat_level") or npc_defs.get(npc_def_id, {}).get("combatLevel", 0)
        total_kills = drop.get("total_kills") or npc_kills.get(npc_def_id, {}).get("total_kills", 1)

        item_id = drop["item_id"]
        item_name = item_names.get(item_id) or f"Item #{item_id}"

        drop_rate = drop.get("drop_rate", 0)
        rate_pct = drop.get("drop_rate_pct", 0)
        formatted_rate = drop.get("formatted_rate", "~")
        rarity = calculate_rarity(drop_rate)

        min_q = drop.get("min_quantity", 1)
        max_q = drop.get("max_quantity", 1)
        q_range = f"{min_q}" if min_q == max_q else f"{min_q}–{max_q}"

        monster_entry = monsters.get(npc_name)
        if not monster_entry:
            monster_entry = {
                "npcDefId": npc_def_id,
                "name": npc_name,
                "combatLevel": combat_level,
                "totalKills": total_kills,
                "drops": [],
            }
            monsters[npc_name] = monster_entry

        monster_entry["drops"].append({
            "itemId": item_id,
            "name": item_name,
            "totalDrops": drop.get("total_drops", 0),
            "totalQuantity": drop.get("total_quantity", 0),
            "minQuantity": min_q,
            "maxQuantity": max_q,
            "quantityRange": q_range,
            "dropRate": drop_rate,
            "dropRatePct": rate_pct,
            "formattedRate": formatted_rate,
            "rarity": rarity,
            "uniqueReporters": drop.get("unique_reporters", 1),
            "status": drop.get("status", "unconfirmed"),
        })

    # Sort each monster's drops by total drops descending
    for monster in monsters.values():
        monster["drops"].sort(key=lambda d: d["totalDrops"], reverse=True)

    result = {
        "lastUpdated": datetime.now(timezone.utc).isoformat(),
        "totalMonsters": len(monsters),
        "totalKillsRecorded": total_kills_sum,
        "monsters": monsters,
    }

    with open(DROP_DATA_FILE, "w", encoding="utf-8") as f:
        json.dump(result, f, indent=2)

    print(f"✅ Successfully wrote {len(monsters)} monster drop tables to {DROP_DATA_FILE}")
    return result


def deploy_to_wiki(monster_names=None, use_prod=False):
    """Pushes DropData.json and DropData.lua directly to the wiki, and purges updated monster page caches."""
    if use_prod:
        wiki_api_url = os.environ.get("PROD_WIKI_API_URL") or os.environ.get("WIKI_API_URL")
        bot_user = os.environ.get("PROD_WIKI_BOT_USERNAME") or os.environ.get("WIKI_BOT_USERNAME")
        bot_pass = os.environ.get("PROD_WIKI_BOT_PASSWORD") or os.environ.get("WIKI_BOT_PASSWORD")
    else:
        wiki_api_url = os.environ.get("WIKI_API_URL")
        bot_user = os.environ.get("WIKI_BOT_USERNAME")
        bot_pass = os.environ.get("WIKI_BOT_PASSWORD")

    if not all([wiki_api_url, bot_user, bot_pass]):
        print("⚠️ Wiki credentials not set in .env. Skipping direct wiki deploy.")
        return

    session = requests.Session()
    session.headers.update({"User-Agent": "EvilQuestWikiDropBot/1.0"})

    # 1. Login
    login_token_res = session.get(wiki_api_url, params={
        "action": "query", "meta": "tokens", "type": "login", "format": "json"
    }).json()
    login_token = login_token_res["query"]["tokens"]["logintoken"]

    login_res = session.post(wiki_api_url, data={
        "action": "login", "lgname": bot_user, "lgpassword": bot_pass,
        "lgtoken": login_token, "format": "json"
    }).json()

    if login_res.get("login", {}).get("result") != "Success":
        print(f"❌ Wiki login failed: {login_res}")
        return

    # 2. CSRF Token
    csrf_res = session.get(wiki_api_url, params={
        "action": "query", "meta": "tokens", "type": "csrf", "format": "json"
    }).json()
    csrf_token = csrf_res["query"]["tokens"]["csrftoken"]

    # 3. Push DropData.json -> Module:DropData/json
    with open(DROP_DATA_FILE, "r", encoding="utf-8") as f:
        json_content = f.read()

    edit_res = session.post(wiki_api_url, data={
        "action": "edit",
        "title": "Module:DropData/json",
        "text": json_content,
        "contentmodel": "json",
        "summary": "🔄 Automated crowdsourced drops update [CamelKit Cloudflare D1]",
        "token": csrf_token,
        "bot": True,
        "format": "json"
    }).json()

    if "edit" in edit_res and edit_res["edit"].get("result") == "Success":
        print("✨ Successfully deployed Module:DropData/json to wiki!")
    else:
        print(f"⚠️ Wiki edit result for Module:DropData/json: {edit_res}")

    # 4. Instant Cache Invalidation: Purge updated monster articles so live pages refresh immediately
    if monster_names:
        title_list = list(monster_names)
        for i in range(0, len(title_list), 50):
            chunk = title_list[i:i + 50]
            try:
                session.post(wiki_api_url, data={
                    "action": "purge",
                    "titles": "|".join(chunk),
                    "format": "json"
                }, timeout=15)
            except Exception as e:
                print(f"⚠️ Could not purge cache for chunk: {e}")
        print(f"🧹 Purged page cache for {len(title_list)} monster article(s) (live counts updated).")


def run_sync_cycle(api_url, include_unconfirmed=True, min_kills=0, deploy=False, use_prod=False):
    result = build_drop_data(api_url, include_unconfirmed=include_unconfirmed, min_kills=min_kills)
    if deploy:
        monster_names = list(result.get("monsters", {}).keys())
        deploy_to_wiki(monster_names=monster_names, use_prod=use_prod)


def main():
    parser = argparse.ArgumentParser(description="Synchronize crowdsourced drops with Wiki.")
    parser.add_argument("--api-url", default=os.environ.get("DROPS_API_URL", "https://api.camelkit.dev"),
                        help="Backend drops API URL")
    parser.add_argument("--confirmed-only", action="store_true",
                        help="Only include drops that reached quorum consensus (K >= 3 unique players)")
    parser.add_argument("--min-kills", type=int, default=0,
                        help="Minimum kill count required for inclusion")
    parser.add_argument("--deploy", action="store_true",
                        help="Deploy Module:DropData/json to the wiki after generating")
    parser.add_argument("--prod", action="store_true",
                        help="Deploy to production wiki")
    parser.add_argument("--watch", type=int, nargs="?", const=60, default=None,
                        help="Run continuously in a loop every N seconds (default: 60)")

    args = parser.parse_args()
    include_unconfirmed = not args.confirmed_only

    if args.watch:
        print(f"👀 Starting crowdsourced drop sync loop (interval: {args.watch}s)...")
        while True:
            try:
                run_sync_cycle(args.api_url, include_unconfirmed=include_unconfirmed,
                               min_kills=args.min_kills, deploy=args.deploy, use_prod=args.prod)
            except Exception as e:
                print(f"⚠️ Error during sync cycle: {e}")
            time.sleep(args.watch)
    else:
        run_sync_cycle(args.api_url, include_unconfirmed=include_unconfirmed,
                       min_kills=args.min_kills, deploy=args.deploy, use_prod=args.prod)


if __name__ == "__main__":
    main()

