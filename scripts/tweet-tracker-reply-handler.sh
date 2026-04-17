#!/usr/bin/env bash
# tweet-tracker-reply-handler.sh
# Polls Discord channel 1477414797757907075 for replies to X Tweet Tracker messages.
# Extracts edited drafts from replies, updates vault, and sends revised drafts for approval.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHANNEL_ID="1477414797757907075"
VAULT_DRAFTS_DIR="/mnt/c/Users/Administrator/Documents/HermesVault/Hermes/x-tweet-tracker/drafts"
DISCORD_API="https://discord.com/api/v10"

# Load env
if [[ -f "$SCRIPT_DIR/../../.hermes/.env" ]]; then
  source "$SCRIPT_DIR/../../.hermes/.env"
fi

python3 << 'PYEOF'
import json, re, os, sys, subprocess
from pathlib import Path
from datetime import datetime, timezone

import requests

channel_id = "1477414797757907075"
vault_drafts_dir = Path("/mnt/c/Users/Administrator/Documents/HermesVault/Hermes/x-tweet-tracker/drafts")
discord_api = "https://discord.com/api/v10"

# Load token
def get_token():
    for path in ["/home/administrator/.hermes/.env", "/home/administrator/site/.env"]:
        p = Path(path)
        if p.exists():
            for line in p.read_text().splitlines():
                if line.startswith("DISCORD_BOT_TOKEN="):
                    return line.split("=", 1)[1].strip().strip('"')
    return ""

token = get_token()
if not token:
    print("DISCORD_BOT_TOKEN missing", file=sys.stderr)
    sys.exit(1)

headers = {"Authorization": f"Bot {token}"}

# Fetch recent messages from the channel
resp = requests.get(f"{discord_api}/channels/{channel_id}/messages?limit=30", headers=headers, timeout=30)
if resp.status_code != 200:
    print(f"Discord fetch failed: HTTP {resp.status_code} {resp.text[:200]}", file=sys.stderr)
    sys.exit(1)

messages = resp.json()
if not isinstance(messages, list):
    print(f"Unexpected API response type: {type(messages)}", file=sys.stderr)
    sys.exit(1)

# Build mapping of message_id -> message
msg_map = {msg["id"]: msg for msg in messages}

# Find Tweet Tracker messages (parent messages)
tracker_messages = []
for msg in messages:
    content = msg.get("content", "") or ""
    if "X Tweet Tracker" in content and "Tracked accounts:" in content:
        tracker_messages.append(msg)

if not tracker_messages:
    print("[SILENT] No Tweet Tracker messages found.")
    sys.exit(0)

# Find replies to tracker messages
replies = []
for msg in messages:
    ref = msg.get("message_reference")
    if not ref:
        continue
    parent_id = ref.get("message_id")
    if not parent_id:
        continue
    # Check if parent is a tracker message
    parent = msg_map.get(parent_id)
    if not parent:
        continue
    parent_content = parent.get("content", "") or ""
    if "X Tweet Tracker" not in parent_content:
        continue
    # This is a reply to a tracker message
    replies.append({
        "parent": parent,
        "reply": msg,
        "parent_content": parent_content,
        "reply_content": msg.get("content", "") or ""
    })

if not replies:
    print("[SILENT] No replies to Tweet Tracker messages found.")
    sys.exit(0)

def parse_draft_tweets(content):
    """Extract numbered draft tweets from a Discord message body."""
    tweets = []
    lines = content.split("\n")
    capture = False
    current_num = None
    current_text = []

    for line in lines:
        m = re.match(r"^\s*(\d+)[.):]\s*(.+)", line)
        if m:
            if current_num is not None and current_text:
                tweets.append(" ".join(current_text))
            current_num = m.group(1)
            current_text = [m.group(2)]
            capture = True
        elif capture and line.strip():
            current_text.append(line.strip())

    if current_num is not None and current_text:
        tweets.append(" ".join(current_text))

    return tweets

def extract_original_drafts(parent_content):
    """Extract original draft numbers from parent message."""
    # Find the "Draft tweets for approval" section
    lines = parent_content.split("\n")
    in_drafts = False
    drafts = []
    for line in lines:
        if "Draft tweets for approval" in line:
            in_drafts = True
            continue
        if in_drafts and line.strip() == "" and drafts:
            break
        if in_drafts and line.strip():
            m = re.match(r"^\s*(\d+)[.):]\s*(.+)", line)
            if m:
                drafts.append({"num": m.group(1), "text": m.group(2)})
    return drafts

# Process each reply
for item in replies:
    parent = item["parent"]
    reply = item["reply"]
    reply_content = item["reply_content"]
    parent_content = item["parent_content"]
    
    parent_id = parent["id"]
    reply_id = reply["id"]
    reply_author = reply.get("author", {}).get("id", "")
    
    # Check if reply author is allowed (Angel's ID)
    allowed_users = []
    env_path = Path("/home/administrator/.hermes/.env")
    if env_path.exists():
        for line in env_path.read_text().splitlines():
            if line.startswith("DISCORD_ALLOWED_USERS="):
                val = line.split("=", 1)[1].strip().strip('"')
                allowed_users = [x.strip() for x in val.split(",")]
                break
    
    if allowed_users and reply_author not in allowed_users:
        print(f"Reply from unauthorized user {reply_author}, skipping.")
        continue
    
    # Parse edited drafts from reply
    edited_drafts = parse_draft_tweets(reply_content)
    if not edited_drafts:
        print(f"Reply {reply_id} contains no numbered draft tweets, skipping.")
        continue
    
    # Extract original drafts from parent for reference
    original_drafts = extract_original_drafts(parent_content)
    
    # Save edited drafts to vault
    date_str = datetime.now(timezone.utc).strftime("%Y-%m-%d")
    edited_file = vault_drafts_dir / f"{date_str}-edited.md"
    
    with open(edited_file, "a") as f:
        f.write(f"\n## Edited {datetime.now(timezone.utc).isoformat()} from Discord reply {reply_id}\n")
        f.write(f"Parent message: {parent_id}\n")
        f.write(f"Original drafts:\n")
        for d in original_drafts:
            f.write(f"- {d['num']}. {d['text']}\n")
        f.write(f"Edited drafts:\n")
        for i, draft in enumerate(edited_drafts, 1):
            f.write(f"- {i}. {draft}\n")
    
    # Post confirmation with revised drafts
    lines = [
        f"**Tweet Tracker — Edits Received**",
        f"",
        f"Edited drafts from reply:",
        f""
    ]
    for i, draft in enumerate(edited_drafts, 1):
        lines.append(f"{i}. {draft}")
    
    lines.extend([
        f"",
        f"Saved to vault. React with ✅ to approve these revised drafts, or reply with further edits."
    ])
    
    confirm_msg = "\n".join(lines)
    resp = requests.post(
        f"{discord_api}/channels/{channel_id}/messages",
        headers={**headers, "Content-Type": "application/json"},
        json={"content": confirm_msg},
        timeout=30
    )
    
    print(f"Processed reply {reply_id} from {reply_author}")
    print(f"Confirmation HTTP {resp.status_code}")

PYEOF
