#!/usr/bin/env bash
# react-approve-all.sh
# Polls Discord channel for 👍 reactions on research post drafts and approves only the reacted pending draft IDs.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$SCRIPT_DIR/../../.hermes/.env" ]]; then
  source "$SCRIPT_DIR/../../.hermes/.env"
fi

CHANNEL_ID="1477414797757907075"
APPROVE_SCRIPT="/home/administrator/site/scripts/approve-research-post.sh"
HOT_APPROVE_SCRIPT="/home/administrator/site/scripts/approve-hot-post.sh"
REVIEW_FILE="/home/administrator/site/scripts/research-post-review.json"
HOT_REVIEW_FILE="/home/administrator/site/scripts/hot-post-review.json"
DISCORD_API="https://discord.com/api/v10"

python3 << 'PYEOF'
import json
import os
import re
import subprocess
import sys
from pathlib import Path

import requests

channel_id = "1477414797757907075"
discord_api = "https://discord.com/api/v10"
approve_script = "/home/administrator/site/scripts/approve-research-post.sh"
hot_approve_script = "/home/administrator/site/scripts/approve-hot-post.sh"
review_file = Path("/home/administrator/site/scripts/research-post-review.json")
hot_review_file = Path("/home/administrator/site/scripts/hot-post-review.json")

token = os.environ.get("DISCORD_BOT_TOKEN", "").strip()
if not token:
    env_file = Path("/home/administrator/.hermes/.env")
    if env_file.exists():
        for line in env_file.read_text().splitlines():
            if line.startswith("DISCORD_BOT_TOKEN="):
                token = line.split("=", 1)[1].strip()
                break

if not token:
    print("DISCORD_BOT_TOKEN missing", file=sys.stderr)
    sys.exit(1)

headers = {"Authorization": f"Bot {token}"}

# Load both pending sets
pending_ids = set()
hot_pending_ids = set()

review = json.loads(review_file.read_text())
posts = review if isinstance(review, list) else review.get("posts", [])
pending_ids = {p.get("id") for p in posts if p.get("status") == "pending"}

hot_review = json.loads(hot_review_file.read_text())
hot_posts = hot_review if isinstance(hot_review, list) else hot_review.get("posts", [])
hot_pending_ids = {p.get("id") for p in hot_posts if p.get("status") == "pending"}

resp = requests.get(f"{discord_api}/channels/{channel_id}/messages?limit=50", headers=headers, timeout=30)
if resp.status_code != 200:
    print(f"Discord fetch failed: HTTP {resp.status_code}", file=sys.stderr)
    sys.exit(1)

# Find reacted RSP and HOT posts
rsp_targets = []
hot_targets = []

for msg in resp.json():
    content = msg.get("content", "") or ""
    reactions = msg.get("reactions", []) or []
    has_thumbs_up = any(
        (r.get("emoji", {}) or {}).get("name") == "👍" and int(r.get("count", 0)) > 0
        for r in reactions
    )
    if not has_thumbs_up:
        continue

    match = re.search(r"ID:\s*([A-Za-z0-9-]+)", content)
    if not match:
        continue

    post_id = match.group(1)

    if content.startswith("🔥") and "HOT TAKE" in content:
        if post_id in hot_pending_ids:
            hot_targets.append(post_id)
    elif "RESEARCH POST DRAFT" in content:
        if post_id in pending_ids:
            rsp_targets.append(post_id)

# De-duplicate
rsp_targets = list(dict.fromkeys(rsp_targets))
hot_targets = list(dict.fromkeys(hot_targets))

all_targets = rsp_targets + hot_targets
if not all_targets:
    print("No reacted pending draft IDs found. Staying quiet.")
    sys.exit(0)

results = []

for post_id in rsp_targets:
    posts_before = {p["id"]: p.get("status") for p in posts}
    was_pending = posts_before.get(post_id) == "pending"

    run = subprocess.run(["bash", approve_script, post_id], capture_output=True, text=True, timeout=60)
    output = (run.stdout or "") + (run.stderr or "")

    review_after = json.loads(review_file.read_text())
    posts_after = review_after if isinstance(review_after, list) else review_after.get("posts", [])
    post_state = next((p.get("status") for p in posts_after if p["id"] == post_id), None)

    if post_state == "approved":
        status = "duplicate" if "SKIP:" in output or "duplicate" in output.lower() else "scheduled"
    elif post_state == "pending" and was_pending:
        status = "failed"
    else:
        status = "duplicate"

    results.append({"id": post_id, "status": status, "type": "RSP"})

for post_id in hot_targets:
    posts_before = {p["id"]: p.get("status") for p in hot_posts}
    was_pending = posts_before.get(post_id) == "pending"

    run = subprocess.run(["bash", hot_approve_script, post_id], capture_output=True, text=True, timeout=60)
    output = (run.stdout or "") + (run.stderr or "")

    review_after = json.loads(hot_review_file.read_text())
    posts_after = review_after if isinstance(review_after, list) else review_after.get("posts", [])
    post_state = next((p.get("status") for p in posts_after if p["id"] == post_id), None)

    if post_state == "approved":
        status = "duplicate" if "SKIP:" in output or "duplicate" in output.lower() else "scheduled"
    elif post_state == "pending" and was_pending:
        status = "failed"
    else:
        status = "duplicate"

    results.append({"id": post_id, "status": status, "type": "HOT"})

scheduled = [r["id"] for r in results if r["status"] == "scheduled"]
duplicates = [r["id"] for r in results if r["status"] == "duplicate"]
failed = [r["id"] for r in results if r["status"] == "failed"]

if scheduled or duplicates or failed:
    lines = ["👍 Approvals processed."]
    if scheduled:
        lines.append(f"Scheduled: {', '.join(scheduled)}")
    if duplicates:
        lines.append(f"Already scheduled: {', '.join(duplicates)}")
    if failed:
        lines.append(f"Failed: {', '.join(failed)}")
    confirm_msg = "\n".join(lines)
    post_resp = requests.post(
        f"{discord_api}/channels/{channel_id}/messages",
        headers={**headers, "Content-Type": "application/json"},
        json={"content": confirm_msg},
        timeout=30,
    )
    print(confirm_msg)
    print(f"Confirmation HTTP {post_resp.status_code}")
else:
    print("No actionable results. Staying quiet.")
PYEOF
