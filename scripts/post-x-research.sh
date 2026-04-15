#!/usr/bin/env bash
# post-x-research.sh — Generates and schedules one standalone research X post per run.
# Runs twice daily (9:30 AM and 2:30 PM ET).
# Topics rotate across: OpenClaw, Hermes Agent, AI tools, operator workflows, industry takes.
#
# Env vars required (loaded from /home/administrator/site/.env):
#   POST_BRIDGE_API_KEY, POST_BRIDGE_X_ID
#
# Usage:
#   ./post-x-research.sh           # post for real
#   ./post-x-research.sh --dry-run # preview what would be posted, no API calls

set -euo pipefail

DRY_RUN=false
if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN=true
  echo "=== DRY RUN — no posts will be sent ==="
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="/home/administrator/site/.env"
LOG_FILE="$SCRIPT_DIR/research-posted-log.json"
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

# --- Init log ---
if [[ ! -f "$LOG_FILE" ]]; then
  echo '{"posted":[]}' > "$LOG_FILE"
fi

# --- Topics pool (rotating) ---
TOPICS=(
  "OpenClaw"
  "Hermes Agent"
  "AI agent ops"
  "local-first AI"
  "AI workflow automation"
  "operator tooling"
  "AI ops stack"
  "Claude Code"
  "AI task handoffs"
  "AI content pipeline"
)

# --- Pick next topic (round-robin) ---
posted_count=$(python3 -c "import json; print(len(json.load(open('$LOG_FILE'))['posted']))")
idx=$((posted_count % ${#TOPICS[@]}))
TOPIC="${TOPICS[$idx]}"

echo "=== Research post for: $TOPIC ==="

# --- Build the research prompt ---
PROMPT_FILE="$SCRIPT_DIR/research-post-prompt.txt"

cat > "$PROMPT_FILE" << 'PROMPT_EOF'
You are an AI ops practitioner and independent publication writer for Signal & Circuit.
Your task: Write ONE sharp X post about TOPIC_PLACEHOLDER.
Rules:
- Start with a strong hook: 1-2 words that land a contrarian take or specific observation immediately
- Keep the full post UNDER 180 characters total
- Take a real position. No summary, no vagueness.
- No emojis. No hashtags in body copy.
- Sound like @lennysan, @clairevo, @danshipper -- confident, direct, opinionated
- Active voice only
- Do not sound corporate or AI-generated
Output ONLY the post text. Plain text, ready to post.
PROMPT_EOF

# Replace placeholder with actual topic
sed -i "s/TOPIC_PLACEHOLDER/$TOPIC/" "$PROMPT_FILE"

# --- Generate content via LLM ---
# Note: $GENERATED_POST is expected to be set by the calling context or an external LLM call.
# If running standalone, content is set below (hardcoded fallback).
if [[ -z "${GENERATED_POST:-}" ]]; then
  # Fallback: read from a file written by an external LLM call
  if [[ -f "$SCRIPT_DIR/research-post-generated.txt" ]]; then
    GENERATED_POST=$(cat "$SCRIPT_DIR/research-post-generated.txt")
  else
    echo "ERROR: GENERATED_POST is not set and no generated file found." >&2
    echo "This script requires an external LLM to set GENERATED_POST before calling." >&2
    exit 1
  fi
fi

CONTENT="$GENERATED_POST"

# --- Determine AM or PM slot ---
# ET is UTC-4 in April. Check current UTC hour to determine slot.
utc_hour=$(date -u +"%H")
if [[ "$utc_hour" -ge 17 ]]; then
  # PM slot (2:30 PM ET = 18:30 UTC) — schedule for 2h out
  sched_iso=$(date -u -d "+2 hours" +"%Y-%m-%dT%H:%M:%SZ")
  slot_label="PM"
else
  # AM slot (9:30 AM ET = 13:30 UTC) — schedule for 30min out
  sched_iso=$(date -u -d "+30 minutes" +"%Y-%m-%dT%H:%M:%SZ")
  slot_label="AM"
fi
now_iso=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# --- Helper: schedule via post-bridge ---
schedule_post() {
  local content="$1"
  local iso_date="$2"
  local post_type="$3"  # "now" or "scheduled"

  # scheduled_at: null for "now", ISO string for "scheduled"
  local scheduled_at
  if [[ "$post_type" == "now" ]]; then
    scheduled_at="null"
  else
    scheduled_at="\"$iso_date\""
  fi

  local payload
  payload=$(cat <<ENDJSON
{
  "caption": $(echo "$content" | python3 -c 'import sys,json; print(json.dumps(sys.stdin.read()))'),
  "scheduled_at": $scheduled_at,
  "social_accounts": [$POST_BRIDGE_X_ID],
  "platform_configurations": {
    "twitter": {}
  }
}
ENDJSON
)

  if [[ "$DRY_RUN" == true ]]; then
    echo "[DRY RUN] Would $post_type at $iso_date:"
    echo "$content"
    echo "---"
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
  else
    echo "FAIL (HTTP $http_code): $body" >&2
    return 1
  fi
}

# --- Post ---
if [[ "$DRY_RUN" == true ]]; then
  echo "Post content:"
  echo "$CONTENT"
  echo "---"
  echo "[DRY RUN] Would schedule for $slot_label slot at $sched_iso"
else
  echo "Scheduling for $slot_label slot at $sched_iso..."
  schedule_post "$CONTENT" "$sched_iso" "scheduled"
fi

# --- Log topic as posted ---
if [[ "$DRY_RUN" != true ]]; then
  python3 -c "
import json
log = json.load(open('$LOG_FILE'))
log['posted'].append('$TOPIC')
json.dump(log, open('$LOG_FILE', 'w'), indent=2)
"
  echo "Logged: $TOPIC"
fi

echo "Done."
