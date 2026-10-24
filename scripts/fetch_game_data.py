#!/usr/bin/env python3
"""
EvilQuest Wiki - Game Definition Watcher & Auto-Updater
======================================================
Monitors the official live game endpoints (memoriesofmagic.com/data/*.json)
for content updates. When a game patch adds new items or NPCs, it downloads
the updated staging definitions, runs merge_data.py, and can trigger
provisioning of new Wiki articles.

Usage:
  python3 Wiki/scripts/fetch_game_data.py [--check-only] [--force] [--sync] [--watch [SECONDS]]
"""

import os
import sys
import time
import json
import hashlib
import argparse
import requests
from merge_data import merge_game_data

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", line_buffering=True)

BASE_DIR = os.path.dirname(os.path.dirname(__file__))
STAGING_DIR = os.path.join(BASE_DIR, "staging")

DATA_ENDPOINTS = {
    "items.json": "https://memoriesofmagic.com/data/items.json",
    "npcs.json": "https://memoriesofmagic.com/data/npcs.json",
    "objects.json": "https://memoriesofmagic.com/data/objects.json",
    "rare-drop-tables.json": "https://memoriesofmagic.com/data/rare-drop-tables.json",
    "enchantments.json": "https://memoriesofmagic.com/data/enchantments.json",
    "quests.json": "https://memoriesofmagic.com/data/quests.json",
    "world-map.json": "https://memoriesofmagic.com/api/world-map",
}


def get_file_hash(filepath):
    if not os.path.exists(filepath):
        return None
    with open(filepath, "rb") as f:
        return hashlib.sha256(f.read()).hexdigest()


def check_and_update_definitions(force=False):
    os.makedirs(STAGING_DIR, exist_ok=True)
    session = requests.Session()
    session.headers.update({"User-Agent": "Mozilla/5.0 (EvilQuestWiki MapExtractor/1.0)"})

    changes_detected = False
    updated_files = []

    for filename, url in DATA_ENDPOINTS.items():
        staging_path = os.path.join(STAGING_DIR, filename)
        current_hash = get_file_hash(staging_path)

        try:
            resp = session.get(url, timeout=15)
            if resp.status_code != 200:
                print(f"⚠️ Failed to fetch {url} (HTTP {resp.status_code})")
                continue

            content = resp.content
            remote_hash = hashlib.sha256(content).hexdigest()

            if force or current_hash != remote_hash:
                print(f"🔄 Game update detected for {filename}!")
                # Validate JSON before overwriting
                try:
                    json.loads(content)
                except Exception as e:
                    print(f"❌ Invalid JSON received from {url}: {e}")
                    continue

                with open(staging_path, "wb") as f:
                    f.write(content)
                changes_detected = True
                updated_files.append(filename)
            else:
                pass
        except Exception as e:
            print(f"❌ Error checking {url}: {e}")

    if changes_detected:
        print(f"\n📦 Detected updates in: {', '.join(updated_files)}")
        print("⚡ Running merge_data.py to integrate new game entities...")
        merge_game_data()
        return True
    else:
        print("✅ All game definitions up to date.")
        return False


def main():
    parser = argparse.ArgumentParser(description="Monitor and update game definitions from live server.")
    parser.add_argument("--force", action="store_true", help="Force download even if hashes match")
    parser.add_argument("--sync", action="store_true", help="Trigger sync_to_wiki.py after merging updates")
    parser.add_argument("--prod", action="store_true", help="Sync to production wiki if --sync is passed")
    parser.add_argument("--watch", type=int, nargs="?", const=300, default=None,
                        help="Watch loop interval in seconds (default: 300)")

    args = parser.parse_args()

    if args.watch:
        print(f"👀 Starting game definition watcher (checking every {args.watch}s)...")
        while True:
            updated = check_and_update_definitions(force=args.force)
            if updated and args.sync:
                from sync_to_wiki import execute_wiki_sync
                execute_wiki_sync()
            time.sleep(args.watch)
    else:
        updated = check_and_update_definitions(force=args.force)
        if updated and args.sync:
            from sync_to_wiki import execute_wiki_sync
            execute_wiki_sync()


if __name__ == "__main__":
    main()
