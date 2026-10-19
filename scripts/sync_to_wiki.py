import os
import sys
import time
import json
import requests

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")

try:
    from dotenv import load_dotenv
    load_dotenv(os.path.join(os.path.dirname(os.path.dirname(__file__)), '.env'))
except ImportError:
    pass

# 1. Capture Environment Variables from GitHub Secrets
WIKI_API_URL = os.environ.get("WIKI_API_URL")
BOT_USERNAME = os.environ.get("WIKI_BOT_USERNAME")
BOT_PASSWORD = os.environ.get("WIKI_BOT_PASSWORD")

if not all([WIKI_API_URL, BOT_USERNAME, BOT_PASSWORD]):
    print("❌ Critical configuration error: Missing required execution secrets.")
    sys.exit(1)

# 2. Define the Mapping Matrix matching local repository paths to active wiki pages
ASSET_SYNC_MATRIX = [
    {"file": "templates/drops/MobDropInventoryData.wikitext", "title": "Template:MobDropInventoryData", "model": "wikitext"},
    {"file": "templates/drops/MobDropItem.wikitext", "title": "Template:MobDropItem", "model": "wikitext"},
    {"file": "templates/drops/RareDropRoll.wikitext", "title": "Template:RareDropRoll", "model": "wikitext"},
    
    {"file": "modules/ItemData.lua", "title": "Module:ItemData", "model": "Scribunto"},
    {"file": "modules/NpcData.lua", "title": "Module:NPCData", "model": "Scribunto"},
    {"file": "modules/RareDropData.lua", "title": "Module:RareDropData", "model": "Scribunto"},
    {"file": "modules/ObjectData.lua", "title": "Module:ObjectData", "model": "Scribunto"},
    {"file": "modules/CraftingData.lua", "title": "Module:CraftingData", "model": "Scribunto"},
    {"file": "modules/CookingData.lua", "title": "Module:CookingData", "model": "Scribunto"},
    {"file": "modules/MagicData.lua", "title": "Module:MagicData", "model": "Scribunto"},
    {"file": "modules/AgilityData.lua", "title": "Module:AgilityData", "model": "Scribunto"},
    {"file": "modules/SkillData.lua", "title": "Module:SkillData", "model": "Scribunto"},
    {"file": "data/ItemData.json", "title": "Module:ItemData/json", "model": "json"},
    {"file": "data/NpcData.json", "title": "Module:NPCData/json", "model": "json"},
    {"file": "data/RareDropData.json", "title": "Module:RareDropData/json", "model": "json"},
    {"file": "data/ObjectData.json", "title": "Module:ObjectData/json", "model": "json"},
    {"file": "data/SkillData.json", "title": "Module:SkillData/json", "model": "json"},
    {"file": "data/CraftingData.json", "title": "Module:CraftingData/json", "model": "json"},
    {"file": "data/CookingData.json", "title": "Module:CookingData/json", "model": "json"},
    {"file": "data/MagicData.json", "title": "Module:MagicData/json", "model": "json"},
    {"file": "data/AgilityData.json", "title": "Module:AgilityData/json", "model": "json"},
    {"file": "data/WorldObjectMappingData.json", "title": "Module:WorldObjectMappingData/json", "model": "json"},
    {"file": "data/NetworkProtocolData.json", "title": "Module:NetworkProtocolData/json", "model": "json"},
    {"file": "styles/Common.css", "title": "MediaWiki:Common.css", "model": "css"}
]

# Dynamically discover templates from subdirectories
for root, _, files in os.walk("templates"):
    # Skip templates in the root directory (so we ignore the old legacy files that haven't been deleted yet)
    if os.path.normpath(root) == "templates":
        continue
    
    for file in files:
        if file.endswith(".wikitext"):
            local_path = os.path.join(root, file).replace("\\", "/")
            base_name = file[:-9] # Remove .wikitext
            
            # Handle edge cases
            if base_name == "Wiki_Discord":
                title_name = "Wiki/Discord"
            elif base_name == "Infobox_Npc":
                title_name = "Infobox NPC"
            else:
                title_name = base_name.replace("_", " ")
            
            wiki_title = f"Template:{title_name}"
            ASSET_SYNC_MATRIX.append({
                "file": local_path,
                "title": wiki_title,
                "model": "wikitext"
            })

# Dynamically discover standard wiki articles/pages from pages/
if os.path.exists("pages"):
    for root, _, files in os.walk("pages"):
        for file in files:
            if file.endswith(".wikitext"):
                local_path = os.path.join(root, file).replace("\\", "/")
                base_name = file[:-9] # Remove .wikitext
                title_name = base_name.replace("_", " ")
                
                ASSET_SYNC_MATRIX.append({
                    "file": local_path,
                    "title": title_name,
                    "model": "wikitext"
                })

# Deduplicate asset matrix by target wiki title to prevent redundant API sync calls
seen_titles = set()
deduped_matrix = []
for asset in ASSET_SYNC_MATRIX:
    if asset["title"] not in seen_titles:
        seen_titles.add(asset["title"])
        deduped_matrix.append(asset)
ASSET_SYNC_MATRIX = deduped_matrix

def execute_wiki_sync():
    session = requests.Session()
    session.headers.update({"User-Agent": "EvilQuestWikiSyncBot/1.0 (CI/CD Deployment)"})

    print("🔑 Commencing secure authorization sequence...")
    
    # Sequence A: Retrieve unique login token payload
    token_req = session.get(WIKI_API_URL, params={
        "action": "query", "meta": "tokens", "type": "login", "format": "json"
    })
    token_req.raise_for_status()
    login_token = token_req.json()["query"]["tokens"]["logintoken"]

    # Sequence B: Log in using Bot Password credentials
    login_auth = session.post(WIKI_API_URL, data={
        "action": "login", "lgname": BOT_USERNAME, "lgpassword": BOT_PASSWORD, "lgtoken": login_token, "format": "json"
    })
    if login_auth.json()["login"]["result"] != "Success":
        print(f"❌ Authentication denied: {login_auth.json()['login'].get('reason', 'Unknown failure')}")
        sys.exit(1)

    # Sequence C: Acquire the mandatory runtime CSRF token for page modification
    csrf_req = session.get(WIKI_API_URL, params={
        "action": "query", "meta": "tokens", "type": "csrf", "format": "json"
    })
    csrf_token = csrf_req.json()["query"]["tokens"]["csrftoken"]
    print("✅ Session established. Processing files...")

    # 3. Iterate through mapping matrix and push changes
    for asset in ASSET_SYNC_MATRIX:
        local_path = asset["file"]
        wiki_title = asset["title"]
        content_model = asset["model"]

        if not os.path.exists(local_path):
            print(f"⚠️ Skipping tracking target: Local file '{local_path}' was not found.")
            continue

        with open(local_path, "r", encoding="utf-8") as file_stream:
            raw_content = file_stream.read()

        print(f"📤 Syncing '{local_path}' ──> [[{wiki_title}]]...")
        
        edit_payload = {
            "action": "edit",
            "title": wiki_title,
            "text": raw_content,
            "token": csrf_token,
            "bot": True,
            "summary": "🔄 Automated Git-to-Wiki synchronization update [CI Pipeline]",
            "format": "json"
        }

        # Force structural assignment if updating raw data structures
        if content_model == "json":
            edit_payload["contentmodel"] = "json"

        response = session.post(WIKI_API_URL, data=edit_payload)
        response_data = response.json()

        if "error" in response_data:
            print(f"❌ Sync failed for [[{wiki_title}]]: {response_data['error'].get('info')}")
        else:
            print(f"✨ Successfully deployed [[{wiki_title}]]! Revision ID: {response_data['edit'].get('newrevid')}")

    # Provision Articles
    print("\n📦 Provisioning Missing Item Articles...")
    provision_item_articles(session, csrf_token)
    print("\n📦 Provisioning Missing NPC Articles...")
    provision_npc_articles(session, csrf_token)

def provision_item_articles(session, csrf_token):
    data_path = os.path.join(os.path.dirname(os.path.dirname(__file__)), "data", "ItemData.json")
    if not os.path.exists(data_path):
        return
    with open(data_path, "r", encoding="utf-8") as f:
        items = json.load(f)
    
    created, skipped = 0, 0
    for item in items:
        name = item.get("name")
        if not name:
            continue
        
        params = {
            "action": "edit", "title": name, "text": "{{Item}}",
            "summary": "Automated pipeline provisioning: Initialized structural item placeholder.",
            "token": csrf_token, "format": "json", "createonly": 1,
        }
        res = session.post(WIKI_API_URL, data=params).json()
        if "edit" in res and res["edit"]["result"] == "Success":
            print(f"[CREATED] {name}")
            created += 1
        elif "error" in res and res["error"]["code"] == "articleexists":
            skipped += 1
        else:
            print(f"[FAILED] {name}: {res.get('error', res)}")
        time.sleep(0.1)
    print(f"Items Provisioning Complete. Created: {created} | Skipped: {skipped}")

def provision_npc_articles(session, csrf_token):
    data_path = os.path.join(os.path.dirname(os.path.dirname(__file__)), "data", "NpcData.json")
    if not os.path.exists(data_path):
        return
    with open(data_path, "r", encoding="utf-8") as f:
        npcs = json.load(f)
    
    name_counts = {}
    for npc in npcs:
        name = npc.get("name")
        if name:
            name_counts[name] = name_counts.get(name, 0) + 1

    created, skipped = 0, 0
    unique_titles = set()
    for npc in npcs:
        name = npc.get("name")
        if not name:
            continue
        
        if name_counts[name] > 1:
            title = f"{name} (Lvl {npc.get('combatLevel', '??')})"
        else:
            title = name
        
        if title in unique_titles:
            continue
        unique_titles.add(title)
        
        params = {
            "action": "edit", "title": title, "text": "{{Infobox NPC}}",
            "summary": "Provisioned disambiguated NPC placeholder.",
            "token": csrf_token, "format": "json", "createonly": 1,
        }
        res = session.post(WIKI_API_URL, data=params).json()
        if "edit" in res and res["edit"]["result"] == "Success":
            print(f"[CREATED] {title}")
            created += 1
        elif "error" in res and res["error"]["code"] == "articleexists":
            skipped += 1
        else:
            print(f"[FAILED] {title}: {res.get('error', res)}")
        time.sleep(0.1)
    print(f"NPCs Provisioning Complete. Created: {created} | Skipped: {skipped}")

if __name__ == "__main__":
    execute_wiki_sync()