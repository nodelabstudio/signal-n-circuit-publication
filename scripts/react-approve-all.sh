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
REVIEW_FILE="/home/administrator/site/scripts/research-post-review.json"
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
review_file = Path("/home/administrator/site/scripts/research-post-review.json")
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

review = json.loads(review_file.read_text())
posts = review if isinstance(review, list) else review.get("posts", [])
pending_ids = {p.get("id") for p in posts if p.get("status") == "pending"}

resp = requests.get(f"{discord_api}/channels/{channel_id}/messages?limit=25", headers=headers, timeout=30)
if resp.status_code != 200:
    print(f"Discord fetch failed: HTTP {resp.status_code}", file=sys.stderr)
    sys.exit(1)

reacted_ids = []
for msg in resp.json():
    content = msg.get("content", "") or ""
    if "RESEARCH POST DRAFT" not in content:
        continue
    reactions = msg.get("reactions", []) or []
    has_thumbs_up = any((r.get("emoji", {}) or {}).get("name") == "👍" and int(r.get("count", 0)) > 0 for r in reactions)
    if not has_thumbs_up:
        continue
    match = re.search(r"ID:\s*([A-Za-z0-9-]+)", content)
    if match:
        reacted_ids.append(match.group(1))

# preserve newest-first order but unique
seen = set()
target_ids = []
for post_id in reacted_ids:
    if post_id in seen:
        continue
    seen.add(post_id)
    if post_id in pending_ids:
        target_ids.append(post_id)

if not target_ids:
    print("No reacted pending draft IDs found. Staying quiet.")
    sys.exit(0)

results = []
for post_id in target_ids:
    run = subprocess.run(["bash", approve_script, post_id], capture_output=True, text=True)
    output = (run.stdout or "") + (run.stderr or "")
    status = "failed"
    if "OK:" in output:
        status = "scheduled"
    elif "SKIP:" in output:
        status = "duplicate"
    results.append({"id": post_id, "status": status, "exit_code": run.returncode})

scheduled = [r["id"] for r in results if r["status"] == "scheduled"]
duplicates = [r["id"] for r in results if r["status"] == "duplicate"]
failed = [r["id"] for r in results if r["status"] == "failed"]

if scheduled or duplicates or failed:
    lines = ["👍 Research approvals processed."]
    if scheduled:
        lines.append(f"Scheduled: {', '.join(scheduled)}")
    if duplicates:
        lines.append(f"Already scheduled: {', '.join(duplicates)}")
    if failed:
        lines.append(f"Failed: {', '.join(failed)}")
    confirm_msg = "\n".join(lines)
    post = requests.post(
        f"{discord_api}/channels/{channel_id}/messages",
        headers={**headers, "Content-Type": "application/json"},
        json={"content": confirm_msg},
        timeout=30,
    )
    print(confirm_msg)
    print(f"Confirmation HTTP {post.status_code}")
else:
    print("No actionable results. Staying quiet.")
PYEOF
