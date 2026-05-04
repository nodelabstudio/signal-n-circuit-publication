#!/usr/bin/env bash
# react-approve-all.sh
# Polls Discord channel for 👍 reactions on X draft messages and approves reacted pending IDs.
# Handles RSP research drafts, HOT take drafts, and PUB article promos.

set -euo pipefail

python3 << 'PYEOF'
import json
import os
import re
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, "/home/administrator/site/scripts")

import requests
from voice_feedback import capture_discord_rejection

channel_id = "1477414797757907075"
discord_api = "https://discord.com/api/v10"
approve_script = "/home/administrator/site/scripts/approve-research-post.sh"
hot_approve_script = "/home/administrator/site/scripts/approve-hot-post.sh"
article_approve_script = "/home/administrator/site/scripts/approve-article-promo-post.sh"
review_file = Path("/home/administrator/site/scripts/research-post-review.json")
hot_review_file = Path("/home/administrator/site/scripts/hot-post-review.json")
article_review_file = Path("/home/administrator/site/scripts/article-promo-review.json")
env_paths = [Path("/home/administrator/.hermes/.env"), Path("/home/administrator/site/.env")]


def load_env_value(name: str) -> str:
    value = os.environ.get(name, "").strip()
    if value:
        return value
    for path in env_paths:
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


def load_posts(path: Path):
    if not path.exists():
        return [], []
    raw = json.loads(path.read_text(encoding="utf-8"))
    posts = raw if isinstance(raw, list) else raw.get("posts", [])
    return raw, posts


def save_posts(path: Path, raw, posts) -> None:
    if isinstance(raw, list):
        path.write_text(json.dumps(posts, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
        return
    raw["posts"] = posts
    path.write_text(json.dumps(raw, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def reject_post(path: Path, raw, posts, post_id: str, reason: str) -> None:
    for post in posts:
        if post.get("id") == post_id:
            post["status"] = "rejected"
            post["rejected_at"] = post.get("rejected_at") or __import__("datetime").datetime.utcnow().isoformat() + "Z"
            post["feedback"] = post.get("feedback") or reason
            break
    save_posts(path, raw, posts)


token = load_env_value("DISCORD_BOT_TOKEN")
if not token:
    print("DISCORD_BOT_TOKEN missing", file=sys.stderr)
    sys.exit(1)

headers = {"Authorization": f"Bot {token}"}

review, posts = load_posts(review_file)
hot_review, hot_posts = load_posts(hot_review_file)
article_review, article_posts = load_posts(article_review_file)
pending_ids = {p.get("id") for p in posts if p.get("status") == "pending"}
hot_pending_ids = {p.get("id") for p in hot_posts if p.get("status") == "pending"}
article_pending_ids = {p.get("id") for p in article_posts if p.get("status") == "pending"}

resp = requests.get(f"{discord_api}/channels/{channel_id}/messages?limit=100", headers=headers, timeout=30)
if resp.status_code != 200:
    print(f"Discord fetch failed: HTTP {resp.status_code}", file=sys.stderr)
    sys.exit(1)

rsp_targets = []
hot_targets = []
article_targets = []
rsp_rejections = []
hot_rejections = []
article_rejections = []

for msg in resp.json():
    content = msg.get("content", "") or ""
    reactions = msg.get("reactions", []) or []
    has_thumbs_up = any(
        (r.get("emoji", {}) or {}).get("name") == "👍" and int(r.get("count", 0)) > 0
        for r in reactions
    )
    has_reject = any(
        (r.get("emoji", {}) or {}).get("name") == "❌" and int(r.get("count", 0)) > 0
        for r in reactions
    )
    if has_reject:
        author_id = str((msg.get("author") or {}).get("id", ""))
        if "HOT TAKE" in content or "HOT-" in content:
            for post_id in re.findall(r"\bHOT-\d{8}-\d{2}\b", content):
                if post_id in hot_pending_ids:
                    capture_discord_rejection(surface="hot-take", draft_id=post_id, content=content, message_id=str(msg.get("id", "")), author_id=author_id)
                    reject_post(hot_review_file, hot_review, hot_posts, post_id, "Discord ❌ rejection")
                    hot_rejections.append(post_id)
        if "RESEARCH POST DRAFT" in content or "RSP-" in content:
            for post_id in re.findall(r"\bRSP-\d{8}-\d{2}\b", content):
                if post_id in pending_ids:
                    capture_discord_rejection(surface="x-research", draft_id=post_id, content=content, message_id=str(msg.get("id", "")), author_id=author_id)
                    reject_post(review_file, review, posts, post_id, "Discord ❌ rejection")
                    rsp_rejections.append(post_id)
        if "ARTICLE PROMO DRAFT" in content or "PUB-" in content:
            for post_id in re.findall(r"\bPUB-\d{8}-\d{2}\b", content):
                if post_id in article_pending_ids:
                    capture_discord_rejection(surface="article-promo", draft_id=post_id, content=content, message_id=str(msg.get("id", "")), author_id=author_id)
                    reject_post(article_review_file, article_review, article_posts, post_id, "Discord ❌ rejection")
                    article_rejections.append(post_id)
        continue
    if not has_thumbs_up:
        continue

    if "HOT TAKE" in content or "HOT-" in content:
        for post_id in re.findall(r"\bHOT-\d{8}-\d{2}\b", content):
            if post_id in hot_pending_ids:
                hot_targets.append(post_id)

    if "RESEARCH POST DRAFT" in content or "RSP-" in content:
        for post_id in re.findall(r"\bRSP-\d{8}-\d{2}\b", content):
            if post_id in pending_ids:
                rsp_targets.append(post_id)

    if "ARTICLE PROMO DRAFT" in content or "PUB-" in content:
        for post_id in re.findall(r"\bPUB-\d{8}-\d{2}\b", content):
            if post_id in article_pending_ids:
                article_targets.append(post_id)

# Backward-compatible fallback for older single-ID messages.
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
    if post_id.startswith("HOT-") and post_id in hot_pending_ids:
        hot_targets.append(post_id)
    elif post_id.startswith("RSP-") and post_id in pending_ids:
        rsp_targets.append(post_id)
    elif post_id.startswith("PUB-") and post_id in article_pending_ids:
        article_targets.append(post_id)

rsp_targets = list(dict.fromkeys(rsp_targets))
hot_targets = list(dict.fromkeys(hot_targets))
article_targets = list(dict.fromkeys(article_targets))
rsp_rejections = list(dict.fromkeys(rsp_rejections))
hot_rejections = list(dict.fromkeys(hot_rejections))
article_rejections = list(dict.fromkeys(article_rejections))
all_targets = rsp_targets + hot_targets + article_targets
all_rejections = rsp_rejections + hot_rejections + article_rejections

if not all_targets and not all_rejections:
    print("No reacted pending draft IDs found. Staying quiet.")
    sys.exit(0)

results = []


def run_approval(post_id: str, script: str, post_type: str, source_posts: list[dict]):
    posts_before = {p["id"]: p.get("status") for p in source_posts if p.get("id")}
    was_pending = posts_before.get(post_id) == "pending"
    run = subprocess.run(["bash", script, post_id], capture_output=True, text=True, timeout=90)
    output = (run.stdout or "") + (run.stderr or "")
    review_path = hot_review_file if post_type == "HOT" else article_review_file if post_type == "PUB" else review_file
    raw_after, posts_after = load_posts(review_path)
    post_state = next((p.get("status") for p in posts_after if p.get("id") == post_id), None)
    if post_state == "approved":
        status = "duplicate" if "SKIP:" in output or "duplicate" in output.lower() else "scheduled"
    elif post_state == "pending" and was_pending:
        status = "failed"
    else:
        status = "duplicate"
    results.append({"id": post_id, "status": status, "type": post_type})


for post_id in rsp_targets:
    run_approval(post_id, approve_script, "RSP", posts)

for post_id in hot_targets:
    run_approval(post_id, hot_approve_script, "HOT", hot_posts)

for post_id in article_targets:
    run_approval(post_id, article_approve_script, "PUB", article_posts)

scheduled = [r["id"] for r in results if r["status"] == "scheduled"]
duplicates = [r["id"] for r in results if r["status"] == "duplicate"]
failed = [r["id"] for r in results if r["status"] == "failed"]
rejected = all_rejections

if scheduled or duplicates or failed or rejected:
    lines = ["👍/❌ Draft reactions processed."]
    if scheduled:
        lines.append(f"Scheduled: {', '.join(scheduled)}")
    if duplicates:
        lines.append(f"Already scheduled: {', '.join(duplicates)}")
    if failed:
        lines.append(f"Failed: {', '.join(failed)}")
    if rejected:
        lines.append(f"Rejected and captured in voice bank: {', '.join(rejected)}")
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
