#!/usr/bin/env bash
# deploy-article.sh — Deploys an article to Signal & Circuit.
#
# This is the single command to run when an article is approved and ready to publish.
# It replaces manual git add/commit/push steps.
#
# Usage:
#   ./deploy-article.sh <slug>           # deploy article
#   ./deploy-article.sh <slug> --dry-run  # show what would happen, no API calls
#
# What it does:
#   1. Verify article file exists in site repo
#   2. git add, commit, push to GitHub
#   3. Poll the live site (up to 120s) waiting for Railway to build
#
# X promotion is handled separately via the publication pipeline Discord approval flow.

set -euo pipefail

DRY_RUN=false
if [[ "${2:-}" == "--dry-run" ]]; then
  DRY_RUN=true
  echo "=== DRY RUN — no changes will be made ==="
fi

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <slug> [--dry-run]" >&2
  exit 1
fi

SLUG="$1"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Paths
SITE_CONTENT="/home/administrator/site/src/content/publication"
PUBLICATION_URL="https://signalcircuit.cloud"
ARTICLE_URL="${PUBLICATION_URL}/articles/${SLUG}/"
MAX_WAIT=120   # seconds to wait for Railway to build
POLL_INTERVAL=10  # seconds between live-site checks

# =============================================================================
# Step 1 — Verify article file exists in site repo
# =============================================================================
ARTICLE_FILE="$SITE_CONTENT/${SLUG}.md"
if [[ ! -f "$ARTICLE_FILE" ]]; then
  echo "ERROR: Article not found: $ARTICLE_FILE" >&2
  exit 1
fi
echo "Source: $ARTICLE_FILE"

# =============================================================================
# Step 2 — Git add, commit, push
# =============================================================================
if [[ "$DRY_RUN" != true ]]; then
  cd /home/administrator/site
  git add "src/content/publication/${SLUG}.md"
  if git diff --cached --quiet; then
    echo "Nothing to commit (article unchanged)."
  else
    git commit -m "pub: add/update article ${SLUG}"
    echo "Committed."
    git push origin main
    echo "Pushed to GitHub. Railway will build."
  fi
else
  echo "[DRY RUN] Would: cd /home/administrator/site && git add src/content/publication/${SLUG}.md && git commit -m 'pub: add/update article ${SLUG}' && git push origin main"
fi

# =============================================================================
# Step 3 — Wait for Railway to build (poll live site)
# =============================================================================
if [[ "$DRY_RUN" != true ]]; then
  echo ""
  echo "Waiting for Railway to build (polling $ARTICLE_URL)..."
  elapsed=0
  while [[ $elapsed -lt $MAX_WAIT ]]; do
    if curl -s -o /dev/null -w "%{http_code}" "$ARTICLE_URL" | grep -q "200"; then
      echo "Live: $ARTICLE_URL (${elapsed}s)"
      break
    fi
    echo "  ...still building (${elapsed}s/${MAX_WAIT}s)"
    sleep $POLL_INTERVAL
    elapsed=$((elapsed + POLL_INTERVAL))
  done

  if [[ $elapsed -ge $MAX_WAIT ]]; then
    echo "WARNING: Article not live after ${MAX_WAIT}s. Proceeding anyway — Railway may still be building."
  fi
else
  echo "[DRY RUN] Would poll $ARTICLE_URL every ${POLL_INTERVAL}s for up to ${MAX_WAIT}s"
fi
