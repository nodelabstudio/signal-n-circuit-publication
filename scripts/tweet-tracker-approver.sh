#!/usr/bin/env bash
# tweet-tracker-approver.sh
# Polls Discord channel 1477414797757907075 for ✅ reactions on X Tweet Tracker messages.
# Extracts approved draft tweets and schedules them via post-bridge.
# Confirms back in the Discord channel.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHANNEL_ID="1477414797757907075"
VAULT_DRAFTS_DIR="/mnt/c/Users/Administrator/Documents/HermesVault/Hermes/x-tweet-tracker/drafts"
DISCORD_API="https://discord.com/api/v10"

# Load env
if [[ -f "$SCRIPT_DIR/../../.hermes/.env" ]]; then
  source "$SCRIPT_DIR/../../.hermes/.env"
fi
if [[ -f "$SCRIPT_DIR/../../site/.env" ]]; then
  source "$SCRIPT_DIR/../../site/.env"
fi

python3 << 'PYEOF'
import json, re, os, sys, subprocess
from pathlib import Path
from datetime import datetime, timezone

import requests

channel_id = "1477414797757907075"
vault_drafts_dir = Path("/mnt/c/Users/Administrator/Documents/HermesVault/Hermes/x-tweet-tracker/drafts")
discord_api = "https://discord.com/api/v10"

# Load tokens
def get_token():
    for path in ["/home/administrator/.hermes/.env", "/home/administrator/site/.env"]:
        p = Path(path)
        if p.exists():
            for line in p.read_text().splitlines():
                if line.startswith("DISCORD_BOT_TOKEN="):
                    return line.split("=", 1)[1].strip().strip('"')
    return ""

def get_postbridge_key():
    for path in ["/home/administrator/site/.env", "/home/administrator/.hermes/.env"]:
        p = Path(path)
        if p.exists():
            for line in p.read_text().splitlines():
                if line.startswith("POST_BRIDGE_API_KEY="):
                    return line.split("=", 1)[1].strip().strip('"')
    return ""

def get_postbridge_xid():
    for path in ["/home/administrator/site/.env"]:
        p = Path(path)
        if p.exists():
            for line in p.read_text().splitlines():
                if line.startswith("POST_BRIDGE_X_ID="):
                    return line.split("=", 1)[1].strip().strip('"')
    return ""

def get_allowed_user_id():
    for path in ["/home/administrator/.hermes/.env"]:
        p = Path(path)
        if p.exists():
            for line in p.read_text().splitlines():
                if line.startswith("DISCORD_ALLOWED_USERS="):
                    val = line.split("=", 1)[1].strip().strip('"')
                    return [x.strip() for x in val.split(",")]
    return []

token = get_token()
pb_key = get_postbridge_key()
pb_xid = get_postbridge_xid()
allowed_users = get_allowed_user_id()

if not token:
    print("DISCORD_BOT_TOKEN missing", file=sys.stderr)
    sys.exit(1)

headers = {"Authorization": f"Bot {token}"}

# Fetch recent messages from the channel
resp = requests.get(f"{discord_api}/channels/{channel_id}/messages?limit=25", headers=headers, timeout=30)
if resp.status_code != 200:
    print(f"Discord fetch failed: HTTP {resp.status_code} {resp.text[:200]}", file=sys.stderr)
    sys.exit(1)

messages = resp.json()
if not isinstance(messages, list):
    print(f"Unexpected API response type: {type(messages)}", file=sys.stderr)
    sys.exit(1)

# Find Tweet Tracker messages with ✅ reactions
# Note: Discord returns reaction counts but not full user lists without extra API calls.
# Any ✅ reaction on a "X Tweet Tracker" message = approval signal.
approved_messages = []
for msg in messages:
    content = msg.get("content", "") or ""
    if "X Tweet Tracker" not in content:
        continue
    reactions = msg.get("reactions", []) or []
    for r in reactions:
        emoji = (r.get("emoji") or {})
        emoji_name = emoji.get("name", "") if isinstance(emoji, dict) else ""
        if emoji_name != "✅":
            continue
        count = int(r.get("count", 0))
        if count > 0:
            approved_messages.append({"msg": msg, "content": content})
            break  # one ✅ is enough

if not approved_messages:
    print("[SILENT] No ✅-reacted Tweet Tracker messages found.")
    sys.exit(0)

print(f"Found {len(approved_messages)} approved message(s).")

def parse_draft_tweets(content):
    """Extract numbered draft tweets from a Discord message body."""
    tweets = []
    # Look for numbered list: "1. tweet text" or "1: tweet text"
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

def schedule_tweet(content, slot=1):
    """Schedule a single tweet via post-bridge."""
    import requests as req
    key = pb_key
    xid = pb_xid
    if not key or not xid:
        return {"status": "error", "detail": "missing_credentials"}

    # Get next slot time
    import datetime
    now_et = datetime.datetime.now(datetime.timezone(datetime.timedelta(hours=-5)))
    slot_times = {1: 8, 2: 11, 3: 16}
    target_hour = slot_times.get(slot, 8)
    target = now_et.replace(hour=target_hour, minute=0, second=0, microsecond=0)
    if target <= now_et:
        target += datetime.timedelta(days=1)
    sched_iso = target.strftime("%Y-%m-%dT%H:%M:%SZ")

    payload = {
        "caption": content.strip(),
        "scheduled_at": sched_iso,
        "social_accounts": [xid],
        "platform_configurations": {"twitter": {}}
    }

    r = req.post(
        "https://api.post-bridge.com/v1/posts",
        headers={"Authorization": f"Bearer {key}", "Content-Type": "application/json"},
        json=payload,
        timeout=30
    )

    if r.status_code in (200, 201):
        return {"status": "ok", "scheduled_at": sched_iso, "http": r.status_code}
    elif r.status_code == 409:
        return {"status": "duplicate", "scheduled_at": sched_iso, "http": r.status_code}
    else:
        return {"status": "error", "detail": f"HTTP {r.status_code}: {r.text[:200]}", "http": r.status_code}

# Process each approved message
results = []
for item in approved_messages:
    msg = item["msg"]
    content = item["content"]
    msg_id = msg.get("id", "unknown")
    tweets = parse_draft_tweets(content)

    if not tweets:
        results.append({"msg_id": msg_id, "status": "no_tweets", "tweets": []})
        continue

    slot = 1
    approved = []
    for tweet_text in tweets:
        tweet_text = tweet_text.strip()
        if not tweet_text or len(tweet_text) > 280:
            results.append({"msg_id": msg_id, "tweet": tweet_text[:80], "status": "skipped_invalid"})
            continue
        res = schedule_tweet(tweet_text, slot=slot)
        slot = min(slot + 1, 3)
        approved.append({"text": tweet_text, "result": res})
        results.append({"msg_id": msg_id, "tweet": tweet_text[:100], "status": res["status"]})

    # Save approved tweets to vault
    date_str = datetime.now(timezone.utc).strftime("%Y-%m-%d")
    approved_file = vault_drafts_dir / f"{date_str}-approved.md"
    with open(approved_file, "a") as f:
        f.write(f"\n## Approved {datetime.now(timezone.utc).isoformat()} from Discord msg {msg_id}\n")
        for t in approved:
            f.write(f"- {t['text']}\n")

# Build confirmation message
ok_results = [r for r in results if r["status"] == "ok"]
dup_results = [r for r in results if r["status"] == "duplicate"]
err_results = [r for r in results if r["status"] == "error"]

lines = ["**Tweet Tracker — Approval Processed**\n"]
if ok_results:
    lines.append(f"✅ Scheduled {len(ok_results)} tweet(s) to @x_node_dev via post-bridge:")
    for r in ok_results:
        lines.append(f"  • {r['tweet'][:120]}")
if dup_results:
    lines.append(f"⏭️ Skipped {len(dup_results)} duplicate(s):")
    for r in dup_results:
        lines.append(f"  • {r['tweet'][:120]}")
if err_results:
    lines.append(f"⚠️ {len(err_results)} error(s):")
    for r in err_results:
        lines.append(f"  • {r['tweet'][:120]} — {r.get('result', {}).get('detail', 'unknown')}")

confirm_msg = "\n".join(lines)
resp = requests.post(
    f"{discord_api}/channels/{channel_id}/messages",
    headers={**headers, "Content-Type": "application/json"},
    json={"content": confirm_msg},
    timeout=30
)
print(confirm_msg)
print(f"Confirmation HTTP {resp.status_code}")
PYEOF
