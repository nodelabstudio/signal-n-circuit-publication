#!/usr/bin/env bash
# post-x-article.sh — Picks the next unposted article from the x-posts folder,
# builds a combined post (hook + takeaway + question + URL), and schedules it
# via post-bridge for 8:00 AM EST.
#
# Env vars required (loaded from /home/administrator/site/.env):
#   POST_BRIDGE_API_KEY, POST_BRIDGE_X_ID
#
# Tracks posted articles in x-posting-manifest.json next to the x-posts folder.
#
# Usage:
#   ./post-x-article.sh                    # find and post the next unposted article
#   ./post-x-article.sh --dry-run          # preview what would be posted, no API calls
#   ./post-x-article.sh --slug <slug>       # post a specific article immediately (for deploy hooks)
#   ./post-x-article.sh --slug <slug> --dry-run  # preview a specific article

set -euo pipefail

DRY_RUN=false
SLUG_OVERRIDE=""
IMMEDIATE=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --slug)
      SLUG_OVERRIDE="$2"
      IMMEDIATE=true
      shift 2
      ;;
    *)
      echo "Unknown option: $1" >&2
      echo "Usage: $0 [--slug <slug>] [--dry-run]" >&2
      exit 1
      ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
XPOSTS_DIR="/home/administrator/.openclaw.pre-migration/workspace/content/publication/x-posts"
MANIFEST="$XPOSTS_DIR/x-posting-manifest.json"
ENV_FILE="/home/administrator/site/.env"
PUBLICATION_URL="https://signalcircuit.cloud"
POST_BRIDGE_BASE="https://api.post-bridge.com"

# --- Load env ---
if [[ -f "$ENV_FILE" ]]; then
  export "$(grep '^POST_BRIDGE_API_KEY=' "$ENV_FILE" | xargs)"
  export "$(grep '^POST_BRIDGE_X_ID=' "$ENV_FILE" | xargs)"
fi

if [[ -z "${POST_BRIDGE_API_KEY:-}" || -z "${POST_BRIDGE_X_ID:-}" ]]; then
  echo "ERROR: POST_BRIDGE_API_KEY and POST_BRIDGE_X_ID must be set" >&2
  exit 1
fi

# --- Init manifest ---
if [[ ! -f "$MANIFEST" ]]; then
  echo '{"posted": []}' > "$MANIFEST"
fi

# --- Compute next 8:00 AM EST as ISO string ---
# EST = UTC-5 in April. 8 AM EST = 13:00 UTC.
# If current UTC hour < 13, schedule for today; else tomorrow.
next_8am_est() {
python3 - << 'PYEOF'
import datetime
now = datetime.datetime.now(datetime.timezone.utc)
est = now.astimezone(datetime.timezone(datetime.timedelta(hours=-5)))
target = est.replace(hour=8, minute=0, second=0, microsecond=0)
if now.hour >= 13:
    target += datetime.timedelta(days=1)
print(target.strftime('%Y-%m-%dT%H:%M:%S%z'))
PYEOF
}

# --- Strip template vars and embedded URLs from text ---
strip_text() {
  python3 -c "
import re, sys
text = sys.stdin.read()
text = re.sub(r'\{\{PUBLICATION_URL\}\}[^\s]*', '', text)
text = re.sub(r'https?://\S+', '', text)
text = re.sub(r'/articles/[a-z0-9-]+', '', text, flags=re.IGNORECASE)
text = re.sub(r'\n{3,}', '\n\n', text)
text = re.sub(r' +', ' ', text)
print(text.strip())
"
}

# --- Build combined post from a JSON file ---
# Handles two schemas: flat (hook/takeaway/question at root) and nested (posts Hook/Takeaway/Question inside 'posts')
build_combined_post() {
  local json_file="$1"

  python3 -c "
import json, sys, re

d = json.load(open('$json_file'))

# Handle both schemas
if 'posts' in d and isinstance(d['posts'], dict):
    posts = d['posts']
else:
    posts = d

hook = posts.get('hook', '').strip()
takeaway = posts.get('takeaway', '').strip()
question = posts.get('question', '').strip()

# Strip template vars and URLs from each field
def strip(t):
    t = re.sub(r'\{\{PUBLICATION_URL\}\}[^\s]*', '', t)
    t = re.sub(r'https?://\S+', '', t)
    t = re.sub(r'/articles/[a-z0-9-]+', '', t, flags=re.IGNORECASE)
    t = re.sub(r'\n{3,}', '\n\n', t)
    t = re.sub(r' +', ' ', t)
    return t.strip()

hook = strip(hook)
takeaway = strip(takeaway)
question = strip(question)

# Derive slug from filename
import os
slug = os.path.splitext(os.path.basename('$json_file'))[0]
url = '$PUBLICATION_URL/articles/' + slug + '/'

combined = hook + '\n\n' + takeaway + '\n\n' + question + '\n\n' + url
combined = re.sub(r'\n{3,}', '\n\n', combined).strip()
print(combined)
"
}

# --- Extract slug from a JSON file path ---
slug_from_file() {
  basename "$1" .json
}

# --- Post to X via post-bridge ---
post_to_x() {
  local content="$1"
  local scheduled_at="$2"  # ISO string

  local payload
  payload=$(cat <<ENDJSON
{
  "caption": $(echo "$content" | python3 -c 'import sys,json; print(json.dumps(sys.stdin.read()))'),
  "scheduled_at": "$scheduled_at",
  "social_accounts": [$POST_BRIDGE_X_ID],
  "platform_configurations": {
    "twitter": {}
  }
}
ENDJSON
)

  if [[ "$DRY_RUN" == true ]]; then
    echo "[DRY RUN] Would schedule for $scheduled_at:"
    echo "$payload" | python3 -m json.tool 2>/dev/null || echo "$payload"
    return 0
  fi

  local response
  response=$(curl -s -w "\n%{http_code}" -X POST "$POST_BRIDGE_BASE/v1/posts" \
    -H "Authorization: Bearer $POST_BRIDGE_API_KEY" \
    -H "Content-Type: application/json" \
    -d "$payload")

  local http_code
  http_code=$(echo "$response" | tail -1)
  local body
  body=$(echo "$response" | sed '$d')

  if [[ "$http_code" -ge 200 && "$http_code" -lt 300 ]]; then
    echo "OK: $body"
    return 0
  else
    echo "FAIL (HTTP $http_code): $body" >&2
    return 1
  fi
}

# --- Resolve slug ---
if [[ -n "$SLUG_OVERRIDE" ]]; then
  # Deploy hook mode: post a specific slug immediately
  slug="$SLUG_OVERRIDE"
  json_file="$XPOSTS_DIR/$slug.json"
  if [[ ! -f "$json_file" ]]; then
    echo "ERROR: x-post JSON not found: $json_file" >&2
    exit 1
  fi
  echo "=== Deploy hook: posting article '$slug' immediately ==="
elif [[ "$DRY_RUN" == true ]]; then
  echo "=== DRY RUN — would post the next unposted article ==="
  for f in "$XPOSTS_DIR"/*.json; do
    slug=$(slug_from_file "$f")
    [[ "$slug" == "x-posting-manifest" ]] && continue
    json_file="$f"
    break
  done
  if [[ -z "$json_file" ]]; then
    echo "No unposted articles found." >&2
    exit 0
  fi
  slug=$(slug_from_file "$json_file")
else
  # Normal mode: find next unposted article
  today=$(date -u +"%Y-%m-%d")

  posted_today=$(python3 -c "
import json
log = json.load(open('$MANIFEST'))
posted = [a['slug'] for a in log.get('posted', []) if a.get('date', '').startswith('$today')]
print('\n'.join(posted))
")

  next_file=""
  next_slug=""

  for f in "$XPOSTS_DIR"/*.json; do
    slug=$(slug_from_file "$f")
    [[ "$slug" == "x-posting-manifest" ]] && continue
    if ! echo -n "$posted_today" | grep -qxF "$slug"; then
      next_file="$f"
      next_slug="$slug"
      break
    fi
  done

  if [[ -z "$next_file" ]]; then
    echo "All articles already posted today. Nothing to do."
    exit 0
  fi

  json_file="$next_file"
  slug="$next_slug"
fi

echo "Posting article: $slug"

# --- Build combined post content ---
combined_post=$(build_combined_post "$json_file")
echo "  Combined post:"
echo "$combined_post"
echo ""

# --- Compute 8 AM EST scheduled time ---
scheduled_at=$(next_8am_est)
echo "  Scheduled for: $scheduled_at (8:00 AM EST)"

# --- Post via post-bridge ---
post_to_x "$combined_post" "$scheduled_at"

# --- Update manifest (skip in dry-run and deploy-hook modes unless it's a new post) ---
if [[ "$DRY_RUN" != true ]]; then
  python3 -c "
import json, sys
manifest = json.load(open('$MANIFEST'))
# Only add if not already in manifest for today
today = '$today' if '$IMMEDIATE' != 'true' else '$(date -u +%Y-%m-%d)'
already = any(a['slug'] == '$slug' and a.get('date','').startswith(today) for a in manifest['posted'])
if not already:
    manifest['posted'].append({'slug': '$slug', 'date': today, 'scheduled_at': '$scheduled_at'})
json.dump(manifest, open('$MANIFEST', 'w'), indent=2)
"
  echo "Manifest updated."
fi
