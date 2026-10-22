import os
import sys
import time
import json
import re
import requests

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", line_buffering=True)

# 1. Load environment variables
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

dry_run = "--dry-run" in sys.argv
if dry_run:
    sys.argv.remove("--dry-run")

force = "--force" in sys.argv
if force:
    sys.argv.remove("--force")

filter_name = None
if "--only" in sys.argv:
    idx = sys.argv.index("--only")
    filter_name = sys.argv[idx + 1]
    del sys.argv[idx:idx + 2]

limit = None
if "--limit" in sys.argv:
    idx = sys.argv.index("--limit")
    limit = int(sys.argv[idx + 1])
    del sys.argv[idx:idx + 2]

if not all([WIKI_API_URL, BOT_USERNAME, BOT_PASSWORD]):
    print("❌ Critical configuration error: Missing required execution secrets.")
    sys.exit(1)

# Import generator from sync_to_wiki
from sync_to_wiki import generate_item_wikitext, safe_api_post

def populate_item_pages():
    print(f"🚀 Initializing item pages parameter population pipeline...")
    print(f"Target API: {WIKI_API_URL}")
    print(f"Execution Mode: {'DRY RUN (No edits)' if dry_run else 'LIVE EDIT'}")
    if filter_name:
        print(f"Filter: Only '{filter_name}'")
    if force:
        print("Force mode enabled: Overwriting existing template blocks.")

    # 1. Load data
    data_path = os.path.join(os.path.dirname(os.path.dirname(__file__)), "data", "ItemData.json")
    cooking_path = os.path.join(os.path.dirname(os.path.dirname(__file__)), "data", "CookingData.json")

    with open(data_path, "r", encoding="utf-8") as f:
        items = json.load(f)

    tea_doses = set()
    tea_canonical = {}
    if os.path.exists(cooking_path):
        with open(cooking_path, "r", encoding="utf-8") as f:
            for tea in json.load(f).get("herbalTeas", []):
                b_name = tea.get("name")
                if tea.get("twoDoseItemName"):
                    tea_doses.add(tea["twoDoseItemName"])
                    if b_name:
                        tea_canonical[tea["twoDoseItemName"]] = b_name
                if tea.get("oneDoseItemName"):
                    tea_doses.add(tea["oneDoseItemName"])

    item_map = {}
    for it in items:
        name = it.get("name")
        if not name:
            continue
        if name in tea_canonical:
            # Map canonical tea page
            canon_name = tea_canonical[name]
            canon_it = dict(it)
            canon_it["name"] = canon_name
            item_map[canon_name] = canon_it
        elif name not in tea_doses:
            item_map[name] = it

    candidate_names = list(item_map.keys())
    if filter_name:
        candidate_names = [n for n in candidate_names if filter_name.lower() in n.lower()]

    print(f"📦 Total candidate items to inspect: {len(candidate_names)}")

    session = requests.Session()
    session.headers.update({"User-Agent": "EvilQuestWikiSyncBot/1.0 (CI/CD Deployment)"})

    # Authentication
    print("🔑 Authenticating bot session...")
    login_token_req = session.get(WIKI_API_URL, params={
        "action": "query", "meta": "tokens", "type": "login", "format": "json"
    })
    login_token = login_token_req.json().get("query", {}).get("tokens", {}).get("logintoken")

    login_res = session.post(WIKI_API_URL, data={
        "action": "login", "lgname": BOT_USERNAME, "lgpassword": BOT_PASSWORD,
        "lgtoken": login_token, "format": "json"
    }).json()

    if login_res.get("login", {}).get("result") != "Success":
        print(f"❌ Login failed: {login_res.get('login', {}).get('reason', 'Unknown failure')}")
        sys.exit(1)

    csrf_req = session.get(WIKI_API_URL, params={
        "action": "query", "meta": "tokens", "type": "csrf", "format": "json"
    })
    csrf_token = csrf_req.json().get("query", {}).get("tokens", {}).get("csrftoken")
    print("✅ Successfully authenticated.")

    # 2. Fetch page contents in batches of 50
    chunk_size = 50
    updated_count = 0
    skipped_count = 0

    for i in range(0, len(candidate_names), chunk_size):
        chunk = candidate_names[i:i + chunk_size]
        query_params = {
            "action": "query",
            "titles": "|".join(chunk),
            "prop": "revisions",
            "rvprop": "content",
            "format": "json"
        }
        resp = session.get(WIKI_API_URL, params=query_params)
        data = resp.json().get("query", {}).get("pages", {})

        for pid, page in data.items():
            if "missing" in page:
                continue
            title = page.get("title")
            revs = page.get("revisions", [])
            if not revs:
                continue
            current_text = revs[0].get("*", "")
            item_def = item_map.get(title)
            if not item_def:
                # Try case insensitive match
                for k, v in item_map.items():
                    if k.lower() == title.lower():
                        item_def = v
                        break
            if not item_def:
                continue

            new_template = generate_item_wikitext(item_def)

            # Use regex to detect {{Item...}} and check if it already has parameters
            match = re.search(r"\{\{item(\s*\|[\s\S]*?|\s*)\}\}", current_text, re.IGNORECASE)
            if not match:
                print(f"⏩ [SKIP NO ITEM TEMPLATE] [[{title}]]")
                skipped_count += 1
                continue

            has_params = bool(match.group(1).strip())

            if has_params and not force:
                print(f"⏩ [SKIP ALREADY PARAMETERIZED] [[{title}]]")
                skipped_count += 1
                continue

            # Replace the {{Item...}} block with the new structured template
            target_new_text = current_text[:match.start()] + new_template + current_text[match.end():]

            if target_new_text.strip() == current_text.strip():
                skipped_count += 1
                continue

            if dry_run:
                print(f"[DRY RUN WOULD UPDATE] [[{title}]]")
                updated_count += 1
            else:
                edit_params = {
                    "action": "edit",
                    "title": title,
                    "text": target_new_text,
                    "summary": "Populated structured item stats template for direct wiki editing.",
                    "token": csrf_token,
                    "bot": True,
                    "format": "json"
                }
                res = safe_api_post(session, edit_params, api_url=WIKI_API_URL)
                if "edit" in res and res["edit"].get("result") == "Success":
                    print(f"✨ [UPDATED] [[{title}]]")
                    updated_count += 1
                elif "edit" in res and res["edit"].get("nochange") is not None:
                    print(f"⏩ [NO CHANGE] [[{title}]]")
                    skipped_count += 1
                else:
                    print(f"❌ [FAILED] [[{title}]]: {res.get('error', res)}")
                time.sleep(0.15)

            if limit and updated_count >= limit:
                print(f"Reached execution limit of {limit}.")
                break

        if limit and updated_count >= limit:
            break

    print(f"\n🎉 Population Run Complete! Updated: {updated_count} | Skipped: {skipped_count}")

if __name__ == "__main__":
    populate_item_pages()
