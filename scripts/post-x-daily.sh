#!/usr/bin/env bash
# post-x-daily.sh — Reads x-post JSON packs from the pre-migration workspace,
# picks the next unposted article, and schedules 3 posts via Postiz Cloud API:
#   hook (now) → takeaway (+6h) → question (+12h)
#
# Env vars required (loaded from /home/administrator/site/.env):
#   POSTIZ_API_KEY, POSTIZ_X_ID
#
# Tracks posted slugs in posted-log.json next to this script.
#
# Usage:
#   ./post-x-daily.sh            # post for real
#   ./post-x-daily.sh --dry-run  # preview what would be posted, no API calls

set -euo pipefail

DRY_RUN=false
if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN=true
  echo "=== DRY RUN — no posts will be sent ==="
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
XPOSTS_DIR="/home/administrator/.openclaw.pre-migration/workspace/content/publication/x-posts"
ENV_FILE="/home/administrator/site/.env"
LOG_FILE="$SCRIPT_DIR/posted-log.json"
PUBLICATION_URL="https://signalcircuit.cloud"
POSTIZ_BASE="https://api.postiz.com/public/v1"

# --- Load env ---
if [[ -f "$ENV_FILE" ]]; then
  export "$(grep '^POSTIZ_API_KEY=' "$ENV_FILE" | xargs)"
  export "$(grep '^POSTIZ_X_ID=' "$ENV_FILE" | xargs)"
fi

if [[ -z "${POSTIZ_API_KEY:-}" || -z "${POSTIZ_X_ID:-}" ]]; then
  echo "ERROR: POSTIZ_API_KEY and POSTIZ_X_ID must be set" >&2
  exit 1
fi

# --- Init log ---
if [[ ! -f "$LOG_FILE" ]]; then
  echo '{"posted":[]}' > "$LOG_FILE"
fi

# --- Helper: remove any existing URLs from post text (Python for multiline) ---
# Also strips {{PUBLICATION_URL}} template vars so they don't get resolved twice
strip_urls() {
  python3 -c "
import re, sys
text = sys.stdin.read()
# Remove {{PUBLICATION_URL}} and any trailing path (e.g. /articles/slug)
text = re.sub(r'\{\{PUBLICATION_URL\}\}[^\s]*', '', text)
# Remove all http/https URLs
text = re.sub(r'https?://\S+', '', text)
# Collapse multiple spaces
clean = re.sub(r' +', ' ', text)
# Collapse multiple newlines to a single newline
clean = re.sub(r'\n+', '\n', clean)
print(clean.strip())
"
}

# --- Helper: resolve {{PUBLICATION_URL}} template var ---
resolve_url_vars() {
  sed "s|{{PUBLICATION_URL}}|$PUBLICATION_URL|g"
}

# --- Helper: schedule a single post via Postiz ---
schedule_post() {
  local content="$1"
  local iso_date="$2"
  local post_type="$3"  # "now" or "schedule"

  local payload
  payload=$(cat <<ENDJSON
{
  "type": "$post_type",
  "date": "$iso_date",
  "shortLink": false,
  "tags": [],
  "posts": [
    {
      "integration": { "id": "$POSTIZ_X_ID" },
      "value": [{ "content": $(echo "$content" | python3 -c 'import sys,json; print(json.dumps(sys.stdin.read()))'), "image": [] }],
      "settings": { "__type": "x", "who_can_reply_post": "everyone" }
    }
  ]
}
ENDJSON
)

  if [[ "$DRY_RUN" == true ]]; then
    echo "[DRY RUN] Would $post_type at $iso_date:"
    echo "$payload" | python3 -m json.tool 2>/dev/null || echo "$payload"
    return 0
  fi

  local response
  response=$(curl -s -w "\n%{http_code}" -X POST "$POSTIZ_BASE/posts" \
    -H "Authorization: $POSTIZ_API_KEY" \
    -H "Content-Type: application/json" \
    -d "$payload")

  local http_code
  http_code=$(echo "$response" | tail -1)
  local body
  body=$(echo "$response" | sed '$d')

  if [[ "$http_code" -ge 200 && "$http_code" -lt 300 ]]; then
    echo "OK ($post_type): $body"
  else
    echo "FAIL (HTTP $http_code): $body" >&2
    return 1
  fi
}

# --- Find next unposted pack ---
posted_slugs=$(python3 -c "import json; print('\n'.join(json.load(open('$LOG_FILE'))['posted']))")

next_file=""
next_slug=""

for f in "$XPOSTS_DIR"/*.json; do
  slug=$(basename "$f" .json)
  if ! echo "$posted_slugs" | grep -qx "$slug"; then
    next_file="$f"
    next_slug="$slug"
    break
  fi
done

if [[ -z "$next_file" ]]; then
  echo "All x-post packs have been posted. Nothing to do."
  exit 0
fi

echo "Posting pack: $next_slug"

# --- Derive article URL from slug ---
article_url="${PUBLICATION_URL}/articles/${next_slug}/"

# --- Read raw JSON fields (Python to handle multiline values cleanly) ---
read_json_field() {
  local file="$1"
  local field="$2"
  python3 -c "
import json, sys
d = json.load(open('$file'))
posts = d.get('posts', d)
val = posts.get('$field', '')
if isinstance(val, str):
    print(val, end='')
elif isinstance(val, dict):
    print(val.get('text', ''), end='')
"
}

raw_hook=$(read_json_field "$next_file" hook)
raw_takeaway=$(read_json_field "$next_file" takeaway)
raw_question=$(read_json_field "$next_file" question)

# Strip existing URLs and resolve template vars
clean_hook=$(echo "$raw_hook" | resolve_url_vars)
clean_takeaway=$(echo "$raw_takeaway" | strip_urls | resolve_url_vars)
clean_question=$(echo "$raw_question" | strip_urls | resolve_url_vars)

# Build final post text — all three posts get the article URL once
final_hook="${clean_hook} ${article_url}"
final_takeaway="${clean_takeaway} ${article_url}"
final_question="${clean_question} ${article_url}"

# Collapse any double spaces
final_takeaway=$(echo "$final_takeaway" | sed 's/  */ /g')
final_question=$(echo "$final_question" | sed 's/  */ /g')

# --- Compute schedule times ---
now_iso=$(date -u +"%Y-%m-%dT%H:%M:%S.000Z")
plus6h_iso=$(date -u -d "+6 hours" +"%Y-%m-%dT%H:%M:%S.000Z")
plus12h_iso=$(date -u -d "+12 hours" +"%Y-%m-%dT%H:%M:%S.000Z")

# --- Post the 3-part sequence ---
echo "  → hook (now)..."
schedule_post "$final_hook" "$now_iso" "now"

echo "  → takeaway (+6h: $plus6h_iso)..."
schedule_post "$final_takeaway" "$plus6h_iso" "schedule"

echo "  → question (+12h: $plus12h_iso)..."
schedule_post "$final_question" "$plus12h_iso" "schedule"

# --- Log as posted ---
if [[ "$DRY_RUN" == true ]]; then
  echo "=== DRY RUN complete. $next_slug was NOT logged as posted. ==="
else
  python3 -c "
import json
log = json.load(open('$LOG_FILE'))
log['posted'].append('$next_slug')
json.dump(log, open('$LOG_FILE', 'w'), indent=2)
"
  echo "Done. Logged $next_slug as posted."
fi
