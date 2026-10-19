#!/usr/bin/env python3
"""
EvilQuest Wiki - Skill Icons Synchronizer
=========================================
Extracts and synchronizes skill icons to MediaWiki storage bucket.
"""

import os
import sys
import time
import requests

def load_env(env_path):
    env_vars = {}
    if os.path.exists(env_path):
        with open(env_path, 'r', encoding='utf-8') as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith('#') and '=' in line:
                    k, v = line.split('=', 1)
                    env_vars[k.strip()] = v.strip()
    return env_vars

ROOT_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ENV_PATH = os.path.join(ROOT_DIR, '.env')
env = load_env(ENV_PATH)

WIKI_API_URL = env.get("PROD_WIKI_API_URL") or os.environ.get("WIKI_API_URL")
BOT_USERNAME = env.get("PROD_WIKI_BOT_USERNAME") or os.environ.get("WIKI_BOT_USERNAME")
BOT_PASSWORD = env.get("PROD_WIKI_BOT_PASSWORD") or os.environ.get("WIKI_BOT_PASSWORD")

ASSETS_DIR = os.path.join(ROOT_DIR, "assets", "skills")

SKILL_ICON_SPECS = [
    {"name": "Weaponry", "filename": "Weaponry.png", "remote_path": "/ui/skills/weaponry-v2.png"},
    {"name": "Strength", "filename": "Strength.png", "remote_path": "/ui/skills/strength-v2.png"},
    {"name": "Defence", "filename": "Defence.png", "remote_path": "/ui/skills/defence-v2.png"},
    {"name": "Light Magic", "filename": "Light_Magic.png", "remote_path": "/ui/skills/goodmagic-v2.png"},
    {"name": "Dark Magic", "filename": "Dark_Magic.png", "remote_path": "/ui/skills/evilmagic-v2.png"},
    {"name": "Ranging", "filename": "Ranging.png", "remote_path": "/ui/skills/archery-v2.png"},
    {"name": "Hitpoints", "filename": "Hitpoints.png", "remote_path": "/ui/skills/hitpoints-v2.png"},
    {"name": "Woodcutting", "filename": "Woodcutting.png", "remote_path": "/ui/skills/woodcutting-v2.png"},
    {"name": "Fishing", "filename": "Fishing.png", "remote_path": "/ui/skills/fishing-v2.png"},
    {"name": "Mining", "filename": "Mining.png", "remote_path": "/ui/skills/mining-v2.png"},
    {"name": "Smithing", "filename": "Smithing.png", "remote_path": "/ui/skills/smithing-v2.png"},
    {"name": "Cooking", "filename": "Cooking.png", "remote_path": "/ui/skills/cooking-v2.png"},
    {"name": "Crafting", "filename": "Crafting.png", "remote_path": "/ui/skills/crafting-v2.png"},
    {"name": "Roguery", "filename": "Roguery.png", "remote_path": "/ui/skills/roguery-v2.png"},
    {"name": "Survival", "filename": "Survival.png", "remote_path": "/ui/skills/survival-v7.png"},
    {"name": "Agility", "filename": "Agility.png", "remote_path": "/ui/skills/agility-v3.png"},
    # Convenience aliases
    {"name": "Archery", "filename": "Archery.png", "source_file": "Ranging.png"},
    {"name": "Goodmagic", "filename": "Goodmagic.png", "source_file": "Light_Magic.png"},
    {"name": "Evilmagic", "filename": "Evilmagic.png", "source_file": "Dark_Magic.png"},
]

session = requests.Session()

def login_wiki():
    params_token = {"action": "query", "meta": "tokens", "type": "login", "format": "json"}
    r = session.get(WIKI_API_URL, params=params_token).json()
    login_token = r['query']['tokens']['logintoken']

    params_login = {
        "action": "login",
        "lgname": BOT_USERNAME,
        "lgpassword": BOT_PASSWORD,
        "lgtoken": login_token,
        "format": "json"
    }
    res = session.post(WIKI_API_URL, data=params_login).json()
    if res.get('login', {}).get('result') != 'Success':
        raise RuntimeError(f"Wiki login failed: {res}")
    print("✅ Authenticated with MediaWiki successfully.")

def get_csrf_token():
    params = {"action": "query", "meta": "tokens", "type": "csrf", "format": "json"}
    r = session.get(WIKI_API_URL, params=params).json()
    return r['query']['tokens']['csrftoken']

def upload_file(local_path, filename, csrf_token):
    with open(local_path, 'rb') as f:
        file_data = {
            'action': 'upload',
            'filename': filename,
            'token': csrf_token,
            'ignorewarnings': '1',
            'format': 'json'
        }
        files = {'file': (filename, f, 'image/png')}
        res = session.post(WIKI_API_URL, data=file_data, files=files).json()
        if 'error' in res:
            print(f"❌ Upload failed for {filename}: {res['error']['info']}")
            return False
        else:
            print(f"✅ Successfully uploaded {filename}.")
            return True

def ensure_local_icons():
    os.makedirs(ASSETS_DIR, exist_ok=True)
    for spec in SKILL_ICON_SPECS:
        target_path = os.path.join(ASSETS_DIR, spec["filename"])
        if os.path.exists(target_path):
            continue

        if "source_file" in spec:
            src_path = os.path.join(ASSETS_DIR, spec["source_file"])
            if os.path.exists(src_path):
                with open(src_path, 'rb') as sf, open(target_path, 'wb') as df:
                    df.write(sf.read())
                print(f"📁 Created alias file {spec['filename']} from {spec['source_file']}.")
                continue

        remote = spec.get("remote_path")
        if remote:
            url = f"https://memoriesofmagic.com{remote}"
            print(f"⬇️ Downloading {spec['name']} icon from {url}...")
            r = requests.get(url, timeout=10)
            if r.status_code == 200:
                with open(target_path, 'wb') as f:
                    f.write(r.content)
                print(f"💾 Saved {spec['filename']} ({len(r.content)} bytes).")
            else:
                print(f"❌ Failed to download {url}: Status {r.status_code}")

def main():
    print("🚀 Initializing Skill Icon Synchronizer...")
    ensure_local_icons()
    login_wiki()
    csrf_token = get_csrf_token()

    for spec in SKILL_ICON_SPECS:
        local_path = os.path.join(ASSETS_DIR, spec["filename"])
        if not os.path.exists(local_path):
            if "source_file" in spec:
                src_path = os.path.join(ASSETS_DIR, spec["source_file"])
                if os.path.exists(src_path):
                    with open(src_path, 'rb') as sf, open(local_path, 'wb') as df:
                        df.write(sf.read())
            if not os.path.exists(local_path):
                print(f"⚠️ Missing local file: {local_path}")
                continue

        print(f"📤 Uploading {spec['filename']} ({spec['name']})...")
        upload_file(local_path, spec["filename"], csrf_token)
        time.sleep(0.3)

    print("🏁 All skill icons synchronized!")

if __name__ == "__main__":
    main()
