#!/usr/bin/env bash
# approve-article-promo-post.sh — Approves pending Signal & Circuit article promo posts.
#
# Usage:
#   ./approve-article-promo-post.sh PUB-YYYYMMDD-XX
#   ./approve-article-promo-post.sh all
#
# Schedules approved article promos through post-bridge only after Discord 👍 approval.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REVIEW_FILE="$SCRIPT_DIR/article-promo-review.json"
DISCORD_CHANNEL_ID="1477414797757907075"

# Canonical post-bridge credentials live in Hermes .env. Do not print values.
HERMES_ENV="/home/administrator/.hermes/.env"
if [[ -f "$HERMES_ENV" ]]; then
  set -a
  source "$HERMES_ENV"
  set +a
else
  echo "ERROR: canonical Hermes env file not found: $HERMES_ENV" >&2
  exit 1
fi

for var in POST_BRIDGE_API_KEY POST_BRIDGE_X_ID; do
  if [[ -z "${!var:-}" ]]; then
    echo "ERROR: $var must be set in $HERMES_ENV" >&2
    exit 1
  fi
done

python3 - "$REVIEW_FILE" "$DISCORD_CHANNEL_ID" "$@" <<'PYEOF'
import json
import os
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path
from urllib import error, request

review_file = Path(sys.argv[1])
discord_channel_id = sys.argv[2]
args = sys.argv[3:]

if not args or args[0] not in ("all",) and not args[0].startswith("PUB-"):
    print(f"Usage: {Path(sys.argv[0]).name} all|PUB-YYYYMMDD-XX", file=sys.stderr)
    raise SystemExit(2)

post_bridge_key = os.environ.get("POST_BRIDGE_API_KEY", "")
post_bridge_x_id = os.environ.get("POST_BRIDGE_X_ID", "")
if not post_bridge_key or not post_bridge_x_id:
    print("ERROR: POST_BRIDGE_API_KEY and POST_BRIDGE_X_ID must be set", file=sys.stderr)
    raise SystemExit(1)


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


def sched_iso() -> str:
    return (datetime.now(timezone.utc) + timedelta(minutes=3)).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def load_env_value(name: str) -> str:
    value = os.environ.get(name, "").strip()
    if value:
        return value
    for path in [Path("/home/administrator/.hermes/.env")]:
        if not path.exists():
            continue
        for line in path.read_text(encoding="utf-8", errors="ignore").splitlines():
            line = line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            key, raw = line.split("=", 1)
            if key.strip() == name:
                return raw.strip().strip('"').strip("'")
    return ""


def load_review():
    if not review_file.exists():
        return {"posts": []}
    raw = json.loads(review_file.read_text(encoding="utf-8"))
    if isinstance(raw, list):
        return {"posts": raw}
    raw.setdefault("posts", [])
    return raw


def save_review(raw):
    review_file.write_text(json.dumps(raw, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def api(method: str, path: str, payload=None):
    data = None if payload is None else json.dumps(payload).encode("utf-8")
    req = request.Request(
        "https://api.post-bridge.com" + path,
        data=data,
        headers={"Authorization": f"Bearer {post_bridge_key}", "Content-Type": "application/json"},
        method=method,
    )
    try:
        with request.urlopen(req, timeout=30) as resp:
            body = resp.read().decode("utf-8", errors="replace")
            return resp.status, body
    except error.HTTPError as exc:
        return exc.code, exc.read().decode("utf-8", errors="replace")[:500]
    except Exception as exc:  # noqa: BLE001
        return 0, str(exc)


def send_discord(message: str):
    token = load_env_value("DISCORD_BOT_TOKEN")
    if not token:
        print("Discord: token missing")
        return
    payload = json.dumps({"content": message}).encode("utf-8")
    req = request.Request(
        f"https://discord.com/api/v10/channels/{discord_channel_id}/messages",
        data=payload,
        headers={"Authorization": f"Bot {token}", "Content-Type": "application/json"},
        method="POST",
    )
    try:
        with request.urlopen(req, timeout=30) as resp:
            print(f"Discord: HTTP {resp.status}")
    except error.HTTPError as exc:
        print(f"Discord: HTTP {exc.code}")
    except Exception as exc:  # noqa: BLE001
        print(f"Discord: {exc}")


def find_duplicate(content: str):
    status, body = api("GET", "/v1/posts")
    if status != 200:
        return ""
    try:
        payload = json.loads(body)
    except json.JSONDecodeError:
        return ""
    posts = payload if isinstance(payload, list) else payload.get("data", [])
    for post in posts:
        if post.get("status") == "scheduled" and content.strip() in (post.get("caption", "") or ""):
            return str(post.get("id") or "")
    return ""


def mark(raw, post, http_status, scheduled_at="", bridge_id="", approved=False):
    now = utc_now()
    post["post_bridge_http_status"] = str(http_status)
    post["updated_at"] = now
    if approved:
        post["status"] = "approved"
        post["approved_at"] = now
    else:
        post["status"] = "pending"
        post["approval_error_at"] = now
    if scheduled_at:
        post["scheduled_at"] = scheduled_at
    if bridge_id:
        post["post_bridge_id"] = bridge_id
    save_review(raw)


def approve_post(raw, post):
    post_id = post.get("id")
    if post.get("status") != "pending":
        print(f"SKIP: {post_id} is {post.get('status')}, not pending")
        return 0

    content = (post.get("content") or post.get("text") or "").strip()
    if not content:
        print(f"FAIL: {post_id} has no content", file=sys.stderr)
        return 1

    scheduled_at = sched_iso()
    duplicate_id = find_duplicate(content)
    if duplicate_id:
        mark(raw, post, 409, scheduled_at, duplicate_id, approved=True)
        print(f"SKIP: {post_id} duplicate already scheduled")
        send_discord(f"⏭️ **{post_id}** article promo skipped because the same content is already scheduled.")
        return 0

    payload = {
        "caption": content,
        "scheduled_at": scheduled_at,
        "social_accounts": [post_bridge_x_id],
        "platform_configurations": {"twitter": {}},
    }
    status, body = api("POST", "/v1/posts", payload)
    if status in (200, 201):
        bridge_id = ""
        try:
            parsed = json.loads(body)
            bridge_id = str(parsed.get("id") or parsed.get("data", {}).get("id") or "")
        except json.JSONDecodeError:
            pass
        mark(raw, post, status, scheduled_at, bridge_id, approved=True)
        print(f"OK: {post_id} scheduled at {scheduled_at}")
        send_discord(f"✅ **{post_id}** article promo approved and scheduled via post-bridge.\nArticle: {post.get('title', '')}")
        return 0

    mark(raw, post, status, "", "", approved=False)
    print(f"FAIL: {post_id} post-bridge failed HTTP {status}: {body[:200]}", file=sys.stderr)
    send_discord(f"⚠️ **{post_id}** article promo approval failed in post-bridge.")
    return 1


raw = load_review()
posts = raw.get("posts", [])
if args[0] == "all":
    if os.environ.get("CONFIRM_APPROVE_ALL", "") != "YES":
        print("ERROR: approve-all requires CONFIRM_APPROVE_ALL=YES", file=sys.stderr)
        raise SystemExit(2)
    targets = [p for p in posts if p.get("status") == "pending"]
else:
    targets = [p for p in posts if p.get("id") == args[0]]
    if not targets:
        print(f"ERROR: {args[0]} not found in article promo review JSON", file=sys.stderr)
        raise SystemExit(1)

exit_code = 0
for post in targets:
    exit_code = max(exit_code, approve_post(raw, post))
raise SystemExit(exit_code)
PYEOF
