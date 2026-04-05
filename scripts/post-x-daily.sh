#!/usr/bin/env bash
# post-x-daily.sh — Reads x-post JSON packs from the pre-migration workspace,
# picks the next unposted article, and posts a single combined post via Postiz.
#
# Single-post format: hook insight + takeaway angle + question CTA
# URL is included once at the end.
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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
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

# --- Helper: strip template vars, embedded URLs, collapse whitespace ---
# Input: raw text that may contain {{PUBLICATION_URL}}/articles/slug or https://...
# Output: clean text without URLs, without template vars, no trailing junk
clean_text() {
  python3 -c "
import re, sys
text = sys.stdin.read()
# Remove {{PUBLICATION_URL}} and everything after it up to a space/newline
text = re.sub(r'\{\{PUBLICATION_URL\}\}[^\s]*', '', text)
# Remove all http/https URLs
text = re.sub(r'https?://\S+', '', text)
# Remove /articles/slug paths that may be left over
text = re.sub(r'/articles/[a-z0-9-]+', '', text, flags=re.IGNORECASE)
# Collapse 3+ newlines to double newline
text = re.sub(r'\n{3,}', '\n\n', text)
# Collapse multiple spaces to one
text = re.sub(r' +', ' ', text)
print(text.strip())
"
}

# --- Helper: schedule a single post via Postiz ---
schedule_post() {
  local content="$1"
  local post_type="$2"  # "now" or "scheduled"

  local payload
  payload=$(cat <<ENDJSON
{
  "type": "$post_type",
  "date": "$(date -u +"%Y-%m-%dT%H:%M:%S.000Z")",
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
    echo "[DRY RUN] Would $post_type:"
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

# --- Read raw JSON fields ---
raw_hook=$(python3 -c "
import json, sys
d = json.load(open('$next_file'))
posts = d.get('posts', d)
print(posts.get('hook', ''), end='')
")
raw_takeaway=$(python3 -c "
import json, sys
d = json.load(open('$next_file'))
posts = d.get('posts', d)
print(posts.get('takeaway', ''), end='')
")
raw_question=$(python3 -c "
import json, sys
d = json.load(open('$next_file'))
posts = d.get('posts', d)
print(posts.get('question', ''), end='')
")

# --- Clean each field ---
clean_hook=$(echo "$raw_hook" | clean_text)
clean_takeaway=$(echo "$raw_takeaway" | clean_text)
clean_question=$(echo "$raw_question" | clean_text)

# --- Build single combined post ---
# Format: hook insight, blank line, takeaway angle, blank line, question CTA
# Article URL appears once at the very end
combined_post="${clean_hook}

${clean_takeaway}

${clean_question} ${article_url}"

# Final pass: collapse any triple+ newlines
combined_post=$(echo "$combined_post" | python3 -c "import re, sys; print(re.sub(r'\n{3,}', '\n\n', sys.stdin.read()).strip())")

# --- Post immediately ---
echo "  → Posting single combined post now..."
schedule_post "$combined_post" "now"

# --- Log as posted ---
if [[ "$DRY_RUN" == true ]]; then
  echo ""
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
