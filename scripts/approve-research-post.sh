#!/usr/bin/env bash
# approve-research-post.sh — Approves pending research posts from the review queue.
#
# Usage:
#   ./approve-research-post.sh all           # approve ALL pending posts
#   ./approve-research-post.sh RSP-YYYYMMDD-XX   # approve one post by ID
#   ./approve-research-post.sh RSP-YYYYMMDD-XX --slot 1  # single with slot override
#
# Slot schedule:
#   Slot 1 -> 6:00 AM ET
#   Slot 2 -> 8:00 AM ET
#   Slot 3 -> 10:00 PM ET

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REVIEW_FILE="$SCRIPT_DIR/research-post-review.json"
DISCORD_CHANNEL_ID="1477414797757907075"
POST_BRIDGE_BASE="https://api.post-bridge.com"

# --- Load env ---
# post-bridge credentials live in site/.env
if [[ -f "/home/administrator/site/.env" ]]; then
  set -a
  source "/home/administrator/site/.env"
  set +a
fi

for var in POST_BRIDGE_API_KEY POST_BRIDGE_X_ID; do
  if [[ -z "${!var:-}" ]]; then
    echo "ERROR: $var must be set" >&2
    exit 1
  fi
done

# =============================================================================
# Helpers
# =============================================================================

get_sched_iso() {
  local slot="$1"
  local now_et now_h now_m now_mins target_mins delta_mins
  now_et=$(TZ="America/New_York" date +"%H:%M")
  now_h=$(echo "$now_et" | cut -d: -f1)
  now_m=$(echo "$now_et" | cut -d: -f2)
  now_mins=$((10#$now_h * 60 + 10#$now_m))

  case "$slot" in
    1) target_mins=$(( 6 * 60)) ;;  # 6:00 AM ET
    2) target_mins=$(( 8 * 60)) ;;  # 8:00 AM ET
    3) target_mins=$((22 * 60)) ;;  # 10:00 PM ET
    *) echo ""; return 1 ;;
  esac

  delta_mins=$((target_mins - now_mins))
  if [[ $delta_mins -le 0 ]]; then
    delta_mins=$((delta_mins + 1440))
  fi
  date -u -d "+${delta_mins} minutes" +"%Y-%m-%dT%H:%M:%SZ"
}

slot_time_et() {
  case "$1" in
    1) echo "6:00 AM ET" ;;
    2) echo "8:00 AM ET" ;;
    3) echo "10:00 PM ET" ;;
  esac
}

discord_send() {
  local msg="$1"
  python3 -c "
import requests, os
from pathlib import Path
token = os.environ.get('DISCORD_BOT_TOKEN', '')
if not token:
    env_file = Path('/home/administrator/.hermes/.env')
    if env_file.exists():
        for line in env_file.read_text().splitlines():
            if line.startswith('DISCORD_BOT_TOKEN='):
                token = line.split('=', 1)[1].strip()
                break
cid = '$DISCORD_CHANNEL_ID'
r = requests.post(
    f'https://discord.com/api/v10/channels/{cid}/messages',
    headers={'Authorization': f'Bot {token}', 'Content-Type': 'application/json'},
    json={'content': '''$msg'''}
)
print(f'Discord: HTTP {r.status_code}')
" 2>/dev/null
}

update_review_json() {
  local post_id="$1" sched_iso="$2" http_code="$3"
  python3 << PYEOF
import json
from datetime import datetime, timezone

with open('$REVIEW_FILE', 'r') as f:
    raw = json.load(f)

posts = raw if isinstance(raw, list) else raw.get('posts', [])
now = datetime.now(timezone.utc).isoformat().replace('+00:00', '') + 'Z'

for post in posts:
    if post['id'] == '$post_id':
        post['status'] = 'approved'
        post['approved_at'] = now
        if '$http_code' in ('200', '201'):
            post['scheduled_at'] = '$sched_iso'
            post['posted_at'] = '$sched_iso'
        break

# Write back preserving original structure
output = raw if isinstance(raw, list) else raw
with open('$REVIEW_FILE', 'w') as f:
    json.dump(output, f, indent=2)
PYEOF
}

# =============================================================================
# Deduplication: check if this exact caption is already scheduled
# Deduplication: check if this exact caption is already scheduled
is_already_scheduled() {
  local content="$1"
  python3 << 'PYEOF'
import sys, requests, os
content = sys.argv[1]
key = os.environ.get('POST_BRIDGE_API_KEY', '')
r = requests.get('https://api.post-bridge.com/v1/posts', headers={'Authorization': key})
if r.status_code != 200:
    print('0')
    return
posts = r.json()
for p in posts if isinstance(posts, list) else posts.get('data', []):
    if p.get('status') == 'scheduled' and content.strip() in (p.get('caption', '') or ''):
        print('1')
        return
print('0')
PYEOF
}

# =============================================================================
# Schedule via post-bridge
# =============================================================================
schedule_post() {
  local post_id="$1" content="$2" slot="$3"
  local sched_iso
  sched_iso=$(get_sched_iso "$slot") || return 1

  # Schedule via Postiz API (Python)
  python3 - "$post_id" "$content" "$slot" "$sched_iso" << 'PYEOF'
import sys, json, requests, os

post_id = sys.argv[1]
content = sys.argv[2]
slot = int(sys.argv[3])
sched_iso = sys.argv[4]

key = os.environ.get('POST_BRIDGE_API_KEY', '')
x_id = os.environ.get('POST_BRIDGE_X_ID', '')

if not key or not x_id:
    print(f"FAIL|missing_credentials")
    sys.exit(1)

# Deduplication check
auth_header = {'Authorization': f'Bearer {key}'}
r = requests.get('https://api.post-bridge.com/v1/posts',
    headers=auth_header)
if r.status_code == 200:
    payload = r.json()
    posts = payload if isinstance(payload, list) else payload.get('data', [])
    for p in posts:
        if p.get('status') == 'scheduled' and content.strip() in (p.get('caption', '') or ''):
            print(f"SKIP|{sched_iso}|409|duplicate")
            sys.exit(0)

# post-bridge payload format
payload = {
    'caption': content.strip(),
    'scheduled_at': sched_iso,
    'social_accounts': [x_id],
    'platform_configurations': {
        'twitter': {}
    }
}

r = requests.post('https://api.post-bridge.com/v1/posts',
    headers={'Authorization': f'Bearer {key}', 'Content-Type': 'application/json'},
    json=payload)

if r.status_code in (200, 201):
    print(f"OK|{sched_iso}|{r.status_code}")
elif r.status_code == 409:
    print(f"SKIP|{sched_iso}|409|duplicate")
else:
    print(f"FAIL|{r.status_code}|{r.text[:200]}")
PYEOF
}

# =============================================================================
# Single post approval
# =============================================================================
approve_single() {
  local post_id="$1" slot_override="${2:-}"

  local post_data
  post_data=$(python3 << PYEOF
import base64, json, sys
raw = json.load(open('$REVIEW_FILE'))
posts = raw if isinstance(raw, list) else raw.get('posts', [])
post = next((p for p in posts if p['id'] == '$post_id'), None)
if not post:
    print('NOT_FOUND')
    sys.exit(1)
slot = '$slot_override' or str(post.get('slot', 1))
content = post.get('content', post.get('text', ''))
print(json.dumps({'content_b64': base64.b64encode(content.encode()).decode(), 'slot': slot}))
PYEOF
) || true

  if [[ "$post_data" == "NOT_FOUND" ]]; then
    echo "ERROR: $post_id not found in review JSON" >&2
    return 1
  fi

  local content slot content_b64
  content_b64=$(python3 -c "import json; print(json.loads('''$post_data'''.strip())['content_b64'])" 2>/dev/null)
  slot=$(python3 -c "import json; print(json.loads('''$post_data'''.strip())['slot'])" 2>/dev/null)
  content=$(python3 -c "import base64; print(base64.b64decode('''$content_b64''').decode())" 2>/dev/null)

  echo "Scheduling $post_id (Slot $slot)..."

  local result http_code sched_iso
  result=$(schedule_post "$post_id" "$content" "$slot")
  http_code=$(echo "$result" | cut -d'|' -f3)
  sched_iso=$(echo "$result" | cut -d'|' -f2)

  if [[ "$http_code" == "200" || "$http_code" == "201" ]]; then
    echo "OK: $post_id scheduled for $(slot_time_et $slot)"
    update_review_json "$post_id" "$sched_iso" "$http_code"
    discord_send "✅ **$post_id** approved and scheduled for $(slot_time_et $slot).

> $(echo "$content" | head -1)"
  elif [[ "$http_code" == "409" ]]; then
    echo "SKIP: $post_id — duplicate content already scheduled"
    update_review_json "$post_id" "$sched_iso" "$http_code"
    discord_send "⏭️ **$post_id** skipped — same content already scheduled for $(slot_time_et $slot)."
  else
    echo "FAIL: HTTP $http_code — $(echo "$result" | cut -d'|' -f4)" >&2
    update_review_json "$post_id" "" "$http_code"
    discord_send "⚠️ **$post_id** approved but post-bridge failed (HTTP $http_code)."
  fi
}

# =============================================================================
# Approve all pending
# =============================================================================
approve_all() {
  echo "=== approve all: scanning for pending posts ==="

  local pending_ids
  pending_ids=$(python3 << PYEOF
import json
raw = json.load(open('$REVIEW_FILE'))
# Handle both list-at-root and dict-at-root formats
posts = raw if isinstance(raw, list) else raw.get('posts', [])
pending = [p for p in posts if p.get('status') == 'pending']
print(f'Found {len(pending)} pending post(s):')
for p in pending:
    print(f"  {p['id']} slot={p.get('slot','?')} topic={p.get('topic','?')}")
    content = p.get('content', p.get('text', '')).replace('\n', ' ')
    print(f"PENDING|{p['id']}|{p.get('slot',1)}|{content}")
PYEOF
)

  echo "$pending_ids"

  local count=0
  while IFS='|' read -r flag pid slot content; do
    [[ "$flag" != "PENDING" || -z "$pid" ]] && continue
    echo ""
    echo "Scheduling $pid (Slot $slot)..."
    local result http_code sched_iso
    result=$(schedule_post "$pid" "$content" "$slot")
    http_code=$(echo "$result" | cut -d'|' -f3)
    sched_iso=$(echo "$result" | cut -d'|' -f2)

    if [[ "$http_code" == "200" || "$http_code" == "201" ]]; then
      echo "  OK: $pid -> $(slot_time_et $slot)"
      update_review_json "$pid" "$sched_iso" "$http_code"
      discord_send "✅ **$pid** approved and scheduled for $(slot_time_et $slot).

> $(echo "$content" | head -1)"
    elif [[ "$http_code" == "409" ]]; then
      echo "  SKIP: $pid — duplicate content already scheduled"
      update_review_json "$pid" "$sched_iso" "$http_code"
      discord_send "⏭️ **$pid** skipped — same content already scheduled for $(slot_time_et $slot)."
    else
      echo "  FAIL: $pid HTTP $http_code" >&2
      update_review_json "$pid" "" "$http_code"
      discord_send "⚠️ **$pid** approved but post-bridge failed (HTTP $http_code)."
    fi
    count=$((count + 1))
  done <<< "$pending_ids"

  echo ""
  echo "=== Done. $count post(s) processed. ==="
}

# =============================================================================
# Dispatch
# =============================================================================
MODE="${1:-}"
SLOT_OVERRIDE=""

if [[ "$MODE" == "all" ]]; then
  approve_all
elif [[ -z "$MODE" ]]; then
  echo "Usage: $0 RSP-YYYYMMDD-XX  |  $0 all" >&2
  exit 1
else
  if [[ "${2:-}" == "--slot" && -n "${3:-}" ]]; then
    SLOT_OVERRIDE="$3"
  fi
  approve_single "$MODE" "$SLOT_OVERRIDE"
fi
