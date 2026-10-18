# EvilQuest Wiki Repository

Welcome to the centralized source of truth for the [EvilQuest Wiki](https://evilquest.wiki)! This repository manages the automation scripts, Lua modules, stylesheets, templates, and raw JSON data payloads powering the wiki.

By managing these assets via Git, we ensure version control, historical tracking, and seamless automated deployments to our MediaWiki instances.

## 🚀 Environments & CI/CD

This repository utilizes a multi-environment pipeline through GitHub Actions:
- **`main` branch**: Represents the production environment. Any pushes to `main` automatically sync assets to the live EvilQuest Wiki.
- **`dev` branch**: Represents the development environment. Used for safely testing module logic, new template structures, or experimental data payloads against a development MediaWiki instance.

## 📂 Directory Structure

* **`data/`**: Contains the central source of truth for in-game payloads (`ItemData.json` and `NpcData.json`).
* **`modules/`**: Contains our Scribunto Lua modules that parse and render the data.
* **`pages/`**: Contains version-controlled standard wiki articles and guides (e.g., `Rare_drop_table.wikitext`).
* **`scripts/`**: Contains our robust suite of Python automation tools.
* **`staging/`**: A local-only directory where you drop new game data updates (e.g., `items.json`, `npcs.json`) before merging them.
* **`styles/`**: Contains global stylesheets like `Common.css`.
* **`templates/`**: Themed subdirectories containing our `.wikitext` templates (infoboxes, drops, shops, smithing, utility).

## 🛠️ Local Development Setup

If you want to run these scripts locally to push to your development instance, you must configure a `.env` file at the root of the project to securely provide your credentials without hardcoding them:

```env
WIKI_API_URL=https://evilquest.wiki/api.php
WIKI_BOT_USERNAME=YourBot@BotName
WIKI_BOT_PASSWORD=YourBotPasswordHere

# Required for sync_images.py
GAME_COOKIE_DEVICE_ID=...
GAME_COOKIE_PREAUTH=...
GAME_COOKIE_WS_SESSION=...
```

Make sure your local environment has the required dependencies installed:
```bash
pip install requests python-dotenv
```

## ⚙️ Automation Scripts

This repository features several powerful automation scripts:

* **`sync_to_wiki.py`**: The core deployment engine. It recursively scans the repository and syncs `modules/`, `data/`, `templates/`, `pages/`, and `styles/` straight to their appropriate MediaWiki namespaces.
* **`merge_data.py`**: Seamlessly merges newly generated game data dropped in the `staging/` folder directly into the centralized `data/ItemData.json` and `data/NpcData.json` sources, preserving historical modifications and tracking legacy name changes.
* **`create_items.py` & `create_npcs.py`**: Automatically spins up missing base article pages on the wiki for any newly discovered items or NPCs found in the `data/` payloads.
* **`sync_images.py`**: Connects to the authenticated game server manifest to download missing 3D item images and seamlessly uploads them straight to the MediaWiki storage bucket.
