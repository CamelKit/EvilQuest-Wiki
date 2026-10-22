import os
import time
import requests

import sys

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

# --- CONFIGURATION ---
WIKI_API_URL = os.environ.get("PROD_WIKI_API_URL") or os.environ.get("WIKI_API_URL")
BOT_USERNAME = os.environ.get("PROD_WIKI_BOT_USERNAME") or os.environ.get("WIKI_BOT_USERNAME")
BOT_PASSWORD = os.environ.get("PROD_WIKI_BOT_PASSWORD") or os.environ.get("WIKI_BOT_PASSWORD")

if not all([WIKI_API_URL, BOT_USERNAME, BOT_PASSWORD]):
    print("❌ Critical configuration error: Missing required wiki credentials in .env or environment.")
    sys.exit(1)

START_ITEM_ID = 1

# Game server authenticated session cookies
GAME_COOKIES = {
    "eq_device_id": os.environ.get("GAME_COOKIE_DEVICE_ID", ""),
    "eq_preauth": os.environ.get("GAME_COOKIE_PREAUTH", ""),
    "eq_ws_session": os.environ.get("GAME_COOKIE_WS_SESSION", "")
}

GAME_HEADERS = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/146.0.0.0 Safari/537.36",
    "Accept": "application/json, text/plain, */*",
    "Accept-Encoding": "gzip, deflate"
}

session = requests.Session()

def login_wiki():
    """Authenticates the session with MediaWiki using BotPasswords."""
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
    session.post(WIKI_API_URL, data=params_login)

def get_csrf_token():
    """Fetches a CSRF token required for uploading files."""
    params = {"action": "query", "meta": "tokens", "type": "csrf", "format": "json"}
    r = session.get(WIKI_API_URL, params=params).json()
    return r['query']['tokens']['csrftoken']

def upload_to_wiki(file_path, filename, csrf_token):
    """Uploads the downloaded local file straight to MediaWiki storage."""
    with open(file_path, 'rb') as f:
        file_data = {
            'action': 'upload',
            'filename': filename,
            'token': csrf_token,
            'ignorewarnings': '1',
            'format': 'json'
        }
        files = {'file': (filename, f, 'image/png')}
        response = session.post(WIKI_API_URL, data=file_data, files=files).json()
        
        if 'error' in response:
            print(f"❌ Upload failed for {filename}: {response['error']['info']}")
        else:
            print(f"✅ Successfully uploaded {filename} to wiki storage.")

def main():
    print("🚀 Initializing Wiki Manifest Image Pipeline...")
    login_wiki()
    csrf_token = get_csrf_token()
    
    if not os.path.exists("temp_items"):
        os.makedirs("temp_items")

    # Step 1: Securely pull down the live V2 asset manifest
    manifest_url = "https://memoriesofmagic.com/items/3d/manifest.json"
    print("📡 Fetching asset list from manifest...")
    manifest_res = requests.get(manifest_url, headers=GAME_HEADERS, cookies=GAME_COOKIES)
    
    if manifest_res.status_code != 200:
        print(f"❌ Failed to retrieve manifest file. Status code: {manifest_res.status_code}")
        return

    print("Raw response preview:", repr(manifest_res.text[:200]))
    
    try:
        manifest_data = manifest_res.json()
    except Exception as e:
        print("Failed to decode JSON. The server likely returned an HTML page instead of JSON (e.g. Cloudflare captcha, login page, or error).")
        raise e
    
    # Target the explicit "ids" integer array directly as requested
    raw_item_ids = manifest_data.get("ids", [])
    
    item_ids = [item_id for item_id in raw_item_ids if item_id >= START_ITEM_ID]
    
    print(f"📦 Discovered {len(item_ids)} remaining item IDs to synchronize (Filtering from ID {START_ITEM_ID}+).")

    # Step 2: Iterate exclusively through the flat ID array
    for item_id in item_ids:
        target_url = f"https://memoriesofmagic.com/items/3d/{item_id}.png"
        wiki_filename = f"Item_{item_id}.png"
        local_path = f"temp_items/{wiki_filename}"

        print(f"🔄 Processing Asset ID: {item_id}...")
        
        img_res = requests.get(target_url, headers=GAME_HEADERS, cookies=GAME_COOKIES)
        
        if img_res.status_code == 200:
            with open(local_path, "wb") as f:
                f.write(img_res.content)
            
            upload_to_wiki(local_path, wiki_filename, csrf_token)
            os.remove(local_path)
            time.sleep(0.3)  # Gentle throttle delay to keep the game server happy
        elif img_res.status_code == 401:
            print("❌ Authentication Expired! Your session cookies have likely rotated.")
            break
        else:
            print(f"⚠️ Item ID {item_id}.png could not be fetched (Status {img_res.status_code}). Skipping.")

    print("🏁 Manifest image synchronization completed successfully.")

if __name__ == "__main__":
    main()