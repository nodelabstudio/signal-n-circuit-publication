#!/usr/bin/env bash
# tweet-tracker-approver.sh
# Poll Discord for per-draft approvals on Tweet Tracker draft messages.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHANNEL_ID="1477414797757907075"
STATE_FILE="/home/administrator/site/scripts/tweet-tracker-approvals.json"
DISCORD_API="https://discord.com/api/v10"

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
from datetime import datetime, timezone, timedelta

import requests

channel_id = "1477414797757907075"
state_path = Path("/home/administrator/site/scripts/tweet-tracker-approvals.json")
discord_api = "https://discord.com/api/v10"


def get_env_value(key: str) -> str:
    val = os.getenv(key, "").strip().strip('"')
    if val:
        return val
    for env_path in ["/home/administrator/site/.env", "/home/administrator/.hermes/.env"]:
        p = Path(env_path)
        if not p.exists():
            continue
        for line in p.read_text().splitlines():
            if line.startswith(f"{key}="):
                return line.split("=", 1)[1].strip().strip('"')
    return ""


def load_state() -> dict:
    if not state_path.exists():
        return {"processed_message_ids": [], "rejected_message_ids": []}
    try:
        data = json.loads(state_path.read_text())
        if isinstance(data, dict):
            data.setdefault("processed_message_ids", [])
            data.setdefault("rejected_message_ids", [])
            return data
    except Exception:
        pass
    return {"processed_message_ids": [], "rejected_message_ids": []}


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


def extract_draft_text(content: str) -> str:
    lines = content.splitlines()
    out = []
    started = False
    for line in lines:
        s = line.rstrip()
        if not started:
            if s.strip().startswith("📋 TWEET TRACKER DRAFT") or s.strip().startswith("TWEET TRACKER DRAFT"):
                started = True
            continue
        if s.strip() == "":
            if not out:
                continue
            out.append("")
            continue
        if s.strip().startswith("---"):
            break
        out.append(s)
    text = "\n".join(out).strip()
    return text


def slot_from_draft_id(draft_id: str) -> int:
    m = re.search(r"-(\d{2})$", draft_id)
    if not m:
        return 1
    val = int(m.group(1))
    if val <= 1:
        return 1
    if val == 2:
        return 2
    return 3


def schedule_tweet(content: str, slot: int, pb_key: str, pb_xid: str) -> dict:
    now_et = datetime.now(timezone(timedelta(hours=-5)))
    slot_hours = {1: 8, 2: 11, 3: 16}
    target_hour = slot_hours.get(slot, 8)
    target = now_et.replace(hour=target_hour, minute=0, second=0, microsecond=0)
    if target <= now_et:
        target += timedelta(days=1)
    scheduled_at = target.strftime("%Y-%m-%dT%H:%M:%SZ")

    payload = {
        "caption": content.strip(),
        "scheduled_at": scheduled_at,
        "social_accounts": [pb_xid],
        "platform_configurations": {"twitter": {}},
    }

    r = requests.post(
        "https://api.post-bridge.com/v1/posts",
        headers={"Authorization": f"Bearer {pb_key}", "Content-Type": "application/json"},
        json=payload,
        timeout=30,
    )

    if r.status_code in (200, 201):
        return {"status": "ok", "http": r.status_code, "scheduled_at": scheduled_at}
    if r.status_code == 409:
        return {"status": "duplicate", "http": r.status_code, "scheduled_at": scheduled_at}
    return {"status": "error", "http": r.status_code, "detail": r.text[:240]}


token = get_env_value("DISCORD_BOT_TOKEN")
pb_key = get_env_value("POST_BRIDGE_API_KEY")
pb_xid = get_env_value("POST_BRIDGE_X_ID")

if not token:
    print("DISCORD_BOT_TOKEN missing", file=sys.stderr)
    sys.exit(1)
if not pb_key or not pb_xid:
    print("POST_BRIDGE_API_KEY or POST_BRIDGE_X_ID missing", file=sys.stderr)
    sys.exit(1)

state = load_state()
processed = set(state.get("processed_message_ids", []))
rejected = set(state.get("rejected_message_ids", []))

headers = {"Authorization": f"Bot {token}"}
resp = requests.get(f"{discord_api}/channels/{channel_id}/messages?limit=50", headers=headers, timeout=30)
if resp.status_code != 200:
    print(f"Discord fetch failed: HTTP {resp.status_code} {resp.text[:200]}", file=sys.stderr)
    sys.exit(1)

messages = resp.json()
if not isinstance(messages, list):
    print("Unexpected Discord response", file=sys.stderr)
    sys.exit(1)

approved_results = []
rejected_ids = []

for msg in messages:
    msg_id = str(msg.get("id", ""))
    content = msg.get("content", "") or ""
    if "TWEET TRACKER DRAFT" not in content:
        continue
    draft_id = extract_draft_id(content)
    if not draft_id:
        continue

    reactions = msg.get("reactions", []) or []
    check_count = 0
    cross_count = 0
    for r in reactions:
        emoji_name = ((r.get("emoji") or {}).get("name") if isinstance(r.get("emoji"), dict) else "") or ""
        count = int(r.get("count", 0) or 0)
        if emoji_name == "👍":
            check_count = count
        if emoji_name == "❌":
            cross_count = count

    if cross_count > 0 and msg_id not in rejected:
        rejected.add(msg_id)
        rejected_ids.append(draft_id)
        continue

    if check_count <= 0:
        continue
    if msg_id in processed:
        continue

    draft_text = extract_draft_text(content)
    if not draft_text:
        approved_results.append({"id": draft_id, "status": "error", "detail": "empty_draft_text"})
        continue

    if len(draft_text) > 280:
        approved_results.append({"id": draft_id, "status": "error", "detail": "draft_over_280_chars"})
        continue

    slot = slot_from_draft_id(draft_id)
    result = schedule_tweet(draft_text, slot, pb_key, pb_xid)
    source = extract_source(content)
    approved_results.append({"id": draft_id, "status": result.get("status"), "source": source, "detail": result.get("detail", "")})

    if result.get("status") in {"ok", "duplicate"}:
        processed.add(msg_id)

state["processed_message_ids"] = sorted(processed)
state["rejected_message_ids"] = sorted(rejected)
save_state(state)

if not approved_results and not rejected_ids:
    print("[SILENT] No per-draft approvals found.")
    sys.exit(0)

lines = ["Tweet Tracker per-draft approvals processed."]
if approved_results:
    ok = [r["id"] for r in approved_results if r["status"] == "ok"]
    dup = [r["id"] for r in approved_results if r["status"] == "duplicate"]
    err = [r for r in approved_results if r["status"] == "error"]
    if ok:
        lines.append(f"Approved and scheduled: {', '.join(ok)}")
    if dup:
        lines.append(f"Already scheduled: {', '.join(dup)}")
    if err:
        lines.append("Errors: " + ", ".join(f"{e['id']}({e['detail']})" for e in err))
if rejected_ids:
    lines.append(f"Rejected: {', '.join(rejected_ids)}")

confirm_msg = "\n".join(lines)
post = requests.post(
    f"{discord_api}/channels/{channel_id}/messages",
    headers={**headers, "Content-Type": "application/json"},
    json={"content": confirm_msg},
    timeout=30,
)
print(confirm_msg)
print(f"Confirmation HTTP {post.status_code}")
PYEOF
