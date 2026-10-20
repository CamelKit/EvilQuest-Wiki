import os
import sys
import time
import json
import requests

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", line_buffering=True)

env_file = os.path.join(os.path.dirname(os.path.dirname(__file__)), '.env')
if os.path.exists(env_file):
    try:
        from dotenv import load_dotenv
        load_dotenv(env_file)
    except ImportError:
        with open(env_file, 'r', encoding='utf-8') as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith('#') and '=' in line:
                    k, v = line.split('=', 1)
                    if k.strip() not in os.environ:
                        os.environ[k.strip()] = v.strip()

# 1. Capture Environment Variables
use_prod = "--prod" in sys.argv
if use_prod:
    sys.argv.remove("--prod")
    WIKI_API_URL = os.environ.get("PROD_WIKI_API_URL") or os.environ.get("WIKI_API_URL")
    BOT_USERNAME = os.environ.get("PROD_WIKI_BOT_USERNAME") or os.environ.get("WIKI_BOT_USERNAME")
    BOT_PASSWORD = os.environ.get("PROD_WIKI_BOT_PASSWORD") or os.environ.get("WIKI_BOT_PASSWORD")
else:
    WIKI_API_URL = os.environ.get("WIKI_API_URL")
    BOT_USERNAME = os.environ.get("WIKI_BOT_USERNAME")
    BOT_PASSWORD = os.environ.get("WIKI_BOT_PASSWORD")

filter_term = None
if "--only" in sys.argv:
    idx = sys.argv.index("--only")
    filter_term = sys.argv[idx + 1]
    del sys.argv[idx:idx + 2]
elif "--filter" in sys.argv:
    idx = sys.argv.index("--filter")
    filter_term = sys.argv[idx + 1]
    del sys.argv[idx:idx + 2]

skip_provision = "--no-provision" in sys.argv
if skip_provision:
    sys.argv.remove("--no-provision")

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
    {"file": "modules/FishingData.lua", "title": "Module:FishingData", "model": "Scribunto"},
    {"file": "data/FishingData.json", "title": "Module:FishingData/json", "model": "json"},
    {"file": "modules/DropData.lua", "title": "Module:DropData", "model": "Scribunto"},
    {"file": "data/DropData.json", "title": "Module:DropData/json", "model": "json"},
    {"file": "styles/Common.css", "title": "MediaWiki:Common.css", "model": "css"},
    {"file": "styles/Common.js", "title": "MediaWiki:Common.js", "model": "javascript"}
]

# Dynamically discover templates from subdirectories
for root, _, files in os.walk("templates"):
    # Skip templates in the root directory (so we ignore the old legacy files that haven't been deleted yet)
    if os.path.normpath(root) == "templates":
        continue
    
    # Community-managed templates are only seeded once (createonly: 1) to protect wiki edits
    norm_parts = os.path.normpath(root).split(os.sep)
    is_community = "community" in norm_parts

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
                "model": "wikitext",
                "createonly": is_community
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

def safe_api_post(session, payload, max_retries=4, backoff=1.5):
    """
    Executes an edit/action POST request to WIKI_API_URL with automatic retries for:
    - Transient HTTP status codes (429, 500, 502, 503, 504, 520-524)
    - Network timeouts / connection resets
    - Empty (0-byte) or non-JSON responses from Cloudflare / reverse proxy
    - MediaWiki 'ratelimited' or 'maxlag' errors
    Guarantees 'bot': True and 'format': 'json'.
    Returns the parsed JSON response dictionary, or a synthetic error dict.
    """
    if "format" not in payload:
        payload["format"] = "json"
    if "bot" not in payload:
        payload["bot"] = True

    for attempt in range(1, max_retries + 1):
        try:
            resp = session.post(WIKI_API_URL, data=payload, timeout=30)
            
            # Transient HTTP status codes
            if resp.status_code in (429, 500, 502, 503, 504, 520, 521, 522, 523, 524):
                if attempt < max_retries:
                    sleep_time = backoff * (2 ** (attempt - 1))
                    print(f"⚠️ HTTP {resp.status_code} received. Retrying in {sleep_time:.1f}s (attempt {attempt}/{max_retries})...")
                    time.sleep(sleep_time)
                    continue
                return {"error": {"code": f"http_{resp.status_code}", "info": f"HTTP {resp.status_code}: {resp.text[:200]}"}}

            # Empty response body check
            body = resp.text.strip() if resp.text else ""
            if not body:
                if attempt < max_retries:
                    sleep_time = backoff * (2 ** (attempt - 1))
                    print(f"⚠️ Empty response received (HTTP {resp.status_code}). Retrying in {sleep_time:.1f}s (attempt {attempt}/{max_retries})...")
                    time.sleep(sleep_time)
                    continue
                return {"error": {"code": "empty_response", "info": f"Server returned 0 bytes (HTTP {resp.status_code})"}}

            # JSON decode
            try:
                data = resp.json()
            except Exception as e:
                if attempt < max_retries:
                    sleep_time = backoff * (2 ** (attempt - 1))
                    print(f"⚠️ Non-JSON response received. Retrying in {sleep_time:.1f}s (attempt {attempt}/{max_retries})...")
                    time.sleep(sleep_time)
                    continue
                return {"error": {"code": "invalid_json", "info": f"Failed to parse response: {e} (Body snippet: {body[:150]})"}}

            # MediaWiki application rate limit / maxlag
            if "error" in data:
                err_code = data["error"].get("code")
                if err_code in ("ratelimited", "maxlag"):
                    if attempt < max_retries:
                        sleep_time = backoff * (2 ** attempt)
                        print(f"⚠️ MediaWiki '{err_code}' encountered. Retrying in {sleep_time:.1f}s (attempt {attempt}/{max_retries})...")
                        time.sleep(sleep_time)
                        continue

            return data

        except requests.RequestException as e:
            if attempt < max_retries:
                sleep_time = backoff * (2 ** (attempt - 1))
                print(f"⚠️ Network error ({type(e).__name__}): {e}. Retrying in {sleep_time:.1f}s (attempt {attempt}/{max_retries})...")
                time.sleep(sleep_time)
                continue
            return {"error": {"code": "network_exception", "info": str(e)}}

    return {"error": {"code": "max_retries_exceeded", "info": "Request exceeded max retries"}}

def get_existing_pages(session, titles):
    """
    Batch queries the wiki in chunks of 50 to find existing articles.
    Returns a set of normalized and raw titles that already exist on the wiki.
    """
    existing = set()
    title_list = [t.strip() for t in titles if t and t.strip()]
    chunk_size = 50

    for i in range(0, len(title_list), chunk_size):
        chunk = title_list[i:i + chunk_size]
        params = {
            "action": "query",
            "titles": "|".join(chunk),
            "format": "json"
        }
        for attempt in range(3):
            try:
                resp = session.get(WIKI_API_URL, params=params, timeout=20)
                if resp.status_code == 200 and resp.text.strip():
                    data = resp.json()
                    pages = data.get("query", {}).get("pages", {})
                    for p in pages.values():
                        if "missing" not in p and "title" in p:
                            existing.add(p["title"])
                            existing.add(p["title"].lower())
                    break
            except Exception:
                time.sleep(1)
        time.sleep(0.05)
    return existing

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
    auth_data = login_auth.json()
    if auth_data.get("login", {}).get("result") != "Success":
        print(f"❌ Authentication denied: {auth_data.get('login', {}).get('reason', 'Unknown failure')}")
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

        if filter_term and filter_term.lower() not in local_path.lower() and filter_term.lower() not in wiki_title.lower():
            continue

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

        if asset.get("createonly"):
            edit_payload["createonly"] = 1

        # Force structural assignment if updating raw data structures
        if content_model == "json":
            edit_payload["contentmodel"] = "json"

        response_data = safe_api_post(session, edit_payload)
        if "error" in response_data:
            err = response_data["error"]
            if err.get("code") == "articleexists":
                print(f"⏩ Preserved [[{wiki_title}]]: Page already exists (community-managed data preserved).")
            else:
                print(f"❌ Sync failed for [[{wiki_title}]]: {err.get('info')}")
        else:
            revid = response_data.get('edit', {}).get('newrevid')
            print(f"✨ Successfully deployed [[{wiki_title}]]! Revision ID: {revid}")

    # Provision Articles
    if not skip_provision and not filter_term:
        print("\n🍵 Provisioning Herbal Tea Articles & Redirects...")
        provision_tea_articles(session, csrf_token)
        print("\n📦 Provisioning Missing Item Articles...")
        provision_item_articles(session, csrf_token)
        print("\n📦 Provisioning Missing NPC Articles...")
        provision_npc_articles(session, csrf_token)

def provision_tea_articles(session, csrf_token):
    cooking_path = os.path.join(os.path.dirname(os.path.dirname(__file__)), "data", "CookingData.json")
    if not os.path.exists(cooking_path):
        return
    with open(cooking_path, "r", encoding="utf-8") as f:
        teas = json.load(f).get("herbalTeas", [])

    created_base = 0
    redirected = 0
    for tea in teas:
        base_name = tea.get("name")
        if not base_name:
            continue

        # 1. Provision canonical base tea article with {{Item}}
        base_params = {
            "action": "edit", "title": base_name, "text": "{{Item}}",
            "summary": "Automated pipeline provisioning: Initialized canonical herbal tea article.",
            "token": csrf_token, "createonly": 1,
        }
        res = safe_api_post(session, base_params)
        if "edit" in res and res["edit"].get("result") == "Success":
            print(f"[CREATED TEA] {base_name}")
            created_base += 1
        elif "error" in res and res["error"].get("code") == "articleexists":
            pass
        else:
            print(f"[FAILED TEA] {base_name}: {res.get('error', res)}")
        time.sleep(0.15)

        # 2. Redirect 2-dose and 1-dose variant pages to base_name
        for dose_key in ["twoDoseItemName", "oneDoseItemName"]:
            dose_title = tea.get(dose_key)
            if not dose_title:
                continue

            redirect_text = f"#REDIRECT [[{base_name}]]"
            redirect_params = {
                "action": "edit", "title": dose_title, "text": redirect_text,
                "summary": f"Automated pipeline update: Redirected dose variant to canonical tea page [[{base_name}]].",
                "token": csrf_token,
            }
            res = safe_api_post(session, redirect_params)
            if "edit" in res and res["edit"].get("result") == "Success":
                print(f"[REDIRECTED] {dose_title} ──> [[{base_name}]]")
                redirected += 1
            elif "edit" in res and res["edit"].get("nochange") is not None:
                pass
            else:
                print(f"[FAILED REDIRECT] {dose_title}: {res.get('error', res)}")
            time.sleep(0.15)

    print(f"Herbal Teas Provisioning Complete. Base Created: {created_base} | Doses Redirected: {redirected}")

def provision_item_articles(session, csrf_token):
    data_path = os.path.join(os.path.dirname(os.path.dirname(__file__)), "data", "ItemData.json")
    cooking_path = os.path.join(os.path.dirname(os.path.dirname(__file__)), "data", "CookingData.json")
    if not os.path.exists(data_path):
        return

    tea_doses = set()
    if os.path.exists(cooking_path):
        with open(cooking_path, "r", encoding="utf-8") as f:
            for tea in json.load(f).get("herbalTeas", []):
                if tea.get("twoDoseItemName"):
                    tea_doses.add(tea["twoDoseItemName"])
                if tea.get("oneDoseItemName"):
                    tea_doses.add(tea["oneDoseItemName"])

    with open(data_path, "r", encoding="utf-8") as f:
        items = json.load(f)
    
    candidate_names = []
    for item in items:
        name = item.get("name")
        if name and name not in tea_doses:
            candidate_names.append(name)

    existing_pages = get_existing_pages(session, candidate_names)

    created, skipped = 0, 0
    for name in candidate_names:
        if name in existing_pages or name.lower() in existing_pages:
            skipped += 1
            continue
        
        params = {
            "action": "edit", "title": name, "text": "{{Item}}",
            "summary": "Automated pipeline provisioning: Initialized structural item placeholder.",
            "token": csrf_token, "createonly": 1,
        }
        res = safe_api_post(session, params)
        if "edit" in res and res["edit"].get("result") == "Success":
            print(f"[CREATED] {name}")
            created += 1
        elif "error" in res and res["error"].get("code") == "articleexists":
            skipped += 1
        else:
            print(f"[FAILED] {name}: {res.get('error', res)}")
        time.sleep(0.15)
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

    unique_titles = []
    seen = set()
    for npc in npcs:
        name = npc.get("name")
        if not name:
            continue
        
        if name_counts[name] > 1:
            title = f"{name} (Lvl {npc.get('combatLevel', '??')})"
        else:
            title = name
        
        if title not in seen:
            seen.add(title)
            unique_titles.append(title)

    existing_pages = get_existing_pages(session, unique_titles)

    created, skipped = 0, 0
    for title in unique_titles:
        if title in existing_pages or title.lower() in existing_pages:
            skipped += 1
            continue
        
        params = {
            "action": "edit", "title": title, "text": "{{Infobox NPC}}",
            "summary": "Provisioned disambiguated NPC placeholder.",
            "token": csrf_token, "createonly": 1,
        }
        res = safe_api_post(session, params)
        if "edit" in res and res["edit"].get("result") == "Success":
            print(f"[CREATED] {title}")
            created += 1
        elif "error" in res and res["error"].get("code") == "articleexists":
            skipped += 1
        else:
            print(f"[FAILED] {title}: {res.get('error', res)}")
        time.sleep(0.15)
    print(f"NPCs Provisioning Complete. Created: {created} | Skipped: {skipped}")

if __name__ == "__main__":
    execute_wiki_sync()