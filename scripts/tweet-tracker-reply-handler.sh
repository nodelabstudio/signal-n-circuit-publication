#!/usr/bin/env bash
# tweet-tracker-reply-handler.sh
# Poll Discord for replies to per-draft Tweet Tracker messages.
# If Angel replies with edited text, post a revised single-draft message for re-approval.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHANNEL_ID="1477414797757907075"
DISCORD_API="https://discord.com/api/v10"
STATE_FILE="/home/administrator/site/scripts/tweet-tracker-replies-state.json"
VAULT_DRAFTS_DIR="/mnt/c/Users/Administrator/Documents/HermesVault/Hermes/x-tweet-tracker/drafts"

if [[ -f "$SCRIPT_DIR/../../.hermes/.env" ]]; then
  source "$SCRIPT_DIR/../../.hermes/.env"
fi
if [[ -f "$SCRIPT_DIR/../../site/.env" ]]; then
  source "$SCRIPT_DIR/../../site/.env"
fi

python3 << 'PYEOF'
import json
import os
import re
import sys
from pathlib import Path
from datetime import datetime, timezone

import requests

channel_id = "1477414797757907075"
discord_api = "https://discord.com/api/v10"
state_path = Path("/home/administrator/site/scripts/tweet-tracker-replies-state.json")
vault_dir = Path("/mnt/c/Users/Administrator/Documents/HermesVault/Hermes/x-tweet-tracker/drafts")


def get_env_value(key: str) -> str:
    val = os.getenv(key, "").strip().strip('"')
    if val:
        return val
    for env_path in ["/home/administrator/.hermes/.env", "/home/administrator/site/.env"]:
        p = Path(env_path)
        if not p.exists():
            continue
        for line in p.read_text().splitlines():
            if line.startswith(f"{key}="):
                return line.split("=", 1)[1].strip().strip('"')
    return ""


def load_state() -> dict:
    if not state_path.exists():
        return {"processed_reply_ids": []}
    try:
        data = json.loads(state_path.read_text())
        if isinstance(data, dict):
            data.setdefault("processed_reply_ids", [])
            return data
    except Exception:
        pass
    return {"processed_reply_ids": []}


def save_state(data: dict) -> None:
    state_path.write_text(json.dumps(data, indent=2))


def extract_draft_id(content: str) -> str:
    m = re.search(r"ID:\s*([A-Za-z0-9\-]+)", content)
    return m.group(1).strip() if m else ""


def extract_source(content: str) -> str:
    for line in content.splitlines():
        s = line.strip()
        if s.lower().startswith("source:"):
            return s.split(":", 1)[1].strip()
    return ""


def normalize_reply_text(reply_content: str) -> str:
    text = reply_content.strip()
    text = re.sub(r"^\s*\d+[\).:]\s*", "", text)
    return text.strip()


def is_allowed_reply_user(msg: dict, allowed_users: set[str]) -> bool:
    if not allowed_users:
        return True
    author_id = str((msg.get("author") or {}).get("id", "")).strip()
    return author_id in allowed_users


token = get_env_value("DISCORD_BOT_TOKEN")
allowed_csv = get_env_value("DISCORD_ALLOWED_USERS")
allowed_users = {x.strip() for x in allowed_csv.split(",") if x.strip()}

if not token:
    print("DISCORD_BOT_TOKEN missing", file=sys.stderr)
    sys.exit(1)

headers = {"Authorization": f"Bot {token}"}
resp = requests.get(f"{discord_api}/channels/{channel_id}/messages?limit=50", headers=headers, timeout=30)
if resp.status_code != 200:
    print(f"Discord fetch failed: HTTP {resp.status_code} {resp.text[:200]}", file=sys.stderr)
    sys.exit(1)

messages = resp.json()
if not isinstance(messages, list):
    print("Unexpected Discord response", file=sys.stderr)
    sys.exit(1)

msg_map = {str(m.get("id", "")): m for m in messages}
state = load_state()
processed = set(state.get("processed_reply_ids", []))

posted_revision_ids = []
processed_now = []

for msg in messages:
    msg_id = str(msg.get("id", ""))
    if msg_id in processed:
        continue

    ref = msg.get("message_reference") or {}
    parent_id = str(ref.get("message_id", "")).strip()
    if not parent_id:
        continue

    parent = msg_map.get(parent_id)
    if not parent:
        continue

    parent_content = parent.get("content", "") or ""
    if "TWEET TRACKER DRAFT" not in parent_content:
        continue

    if not is_allowed_reply_user(msg, allowed_users):
        continue

    reply_text = normalize_reply_text(msg.get("content", "") or "")
    if not reply_text:
        processed_now.append(msg_id)
        continue

    if len(reply_text) > 280:
        processed_now.append(msg_id)
        continue

    parent_draft_id = extract_draft_id(parent_content)
    if not parent_draft_id:
        processed_now.append(msg_id)
        continue

    source = extract_source(parent_content)
    revision_id = f"{parent_draft_id}-r{datetime.now(timezone.utc).strftime('%H%M%S')}"

    revised_message = (
        f"📋 TWEET TRACKER DRAFT — ID: {revision_id}\n\n"
        f"{reply_text}\n\n"
        f"---\n"
        f"Source: {source or 'edited reply'}\n"
        f"Target: @x_node_dev\n\n"
        f"React ✅ to approve this draft only.\n"
        f"React ❌ to reject this draft.\n"
        f"Reply with edited text to request revision."
    )

    post = requests.post(
        f"{discord_api}/channels/{channel_id}/messages",
        headers={**headers, "Content-Type": "application/json"},
        json={"content": revised_message},
        timeout=30,
    )

    if post.status_code in (200, 201):
        posted_revision_ids.append(revision_id)

        vault_dir.mkdir(parents=True, exist_ok=True)
        date_str = datetime.now(timezone.utc).strftime("%Y-%m-%d")
        edited_file = vault_dir / f"{date_str}-edited.md"
        with open(edited_file, "a", encoding="utf-8") as f:
            f.write(f"\n## Revision {revision_id}\n")
            f.write(f"- Parent: {parent_draft_id}\n")
            f.write(f"- From reply message: {msg_id}\n")
            f.write(f"- Content: {reply_text}\n")

    processed_now.append(msg_id)

for rid in processed_now:
    processed.add(rid)
state["processed_reply_ids"] = sorted(processed)
save_state(state)

if not posted_revision_ids:
    print("[SILENT] No per-draft edit replies found.")
    sys.exit(0)

summary = "Tweet Tracker revisions posted: " + ", ".join(posted_revision_ids)
print(summary)
PYEOF
