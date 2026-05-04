#!/usr/bin/env python3
"""Queue Signal & Circuit article promotion drafts for Discord approval.

This script creates or updates PUB-* records in article-promo-review.json and,
optionally, sends the approval message to the X draft Discord channel.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any
from urllib import error, request

from voice_engine import lint_text

SCRIPT_DIR = Path(__file__).resolve().parent
REVIEW_FILE = SCRIPT_DIR / "article-promo-review.json"
DISCORD_CHANNEL_ID = "1477414797757907075"
DISCORD_API = "https://discord.com/api/v10"
ENV_PATHS = [Path("/home/administrator/.hermes/.env"), Path("/home/administrator/site/.env")]


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


def load_env_value(name: str) -> str:
    value = os.environ.get(name, "").strip()
    if value:
        return value
    for path in ENV_PATHS:
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


def load_review() -> dict[str, Any]:
    if not REVIEW_FILE.exists():
        return {"posts": []}
    raw = json.loads(REVIEW_FILE.read_text(encoding="utf-8"))
    if isinstance(raw, list):
        return {"posts": raw}
    raw.setdefault("posts", [])
    return raw


def save_review(raw: dict[str, Any]) -> None:
    REVIEW_FILE.write_text(json.dumps(raw, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def next_pub_id(posts: list[dict[str, Any]], day: str) -> str:
    prefix = f"PUB-{day.replace('-', '')}-"
    nums = []
    for post in posts:
        post_id = str(post.get("id", ""))
        if post_id.startswith(prefix):
            try:
                nums.append(int(post_id.rsplit("-", 1)[1]))
            except ValueError:
                pass
    return f"{prefix}{(max(nums) + 1 if nums else 1):02d}"


def validate_content(content: str, url: str) -> list[str]:
    errors = []
    if not content.strip():
        errors.append("content is empty")
    if len(content) > 280:
        errors.append(f"content is {len(content)} chars, over X limit 280")
    if "—" in content:
        errors.append("content contains em dash")
    if "#" in content:
        errors.append("content contains hashtag")
    if url and url not in content:
        errors.append("content does not include the article URL")
    banned = [
        "delve",
        "leverage",
        "unlock",
        "groundbreaking",
        "game-changer",
        "revolutionary",
        "revolutionize",
        "empowering",
        "comprehensive",
        "in conclusion",
        "it is important to note",
    ]
    lowered = content.lower()
    for item in banned:
        if item in lowered:
            errors.append(f"content contains banned word or phrase: {item}")
    patterns = [
        r"\bIt's not\b.+\bIt's\b",
        r"\bThe real\b.+\bisn't\b.+\bIt's\b",
        r"\bThe change\?\s*\w+",
        r"\bThe result\?\s*\w+",
    ]
    for pattern in patterns:
        if re.search(pattern, content, flags=re.IGNORECASE | re.DOTALL):
            errors.append(f"content contains banned structure: {pattern}")
    voice_findings = lint_text(content, surface="article-promo", require_source=bool(url))
    for finding in voice_findings:
        if finding.severity == "error":
            errors.append(f"voice engine {finding.code}: {finding.message}")
    return errors


def discord_message(post: dict[str, Any]) -> str:
    return (
        f"📋 ARTICLE PROMO DRAFT - ID: {post['id']}\n\n"
        f"{post['content'].strip()}\n\n"
        "---\n"
        f"Article: {post.get('title', '')}\n"
        f"URL: {post.get('article_url', '')}\n"
        f"Target: @SignalCircuit\n\n"
        "React 👍 to approve this article promo.\n"
        "React ❌ to reject this article promo.\n"
        "Reply with edited text to request a revision."
    )


def send_discord(message: str) -> tuple[int, str]:
    token = load_env_value("DISCORD_BOT_TOKEN")
    if not token:
        return 0, "DISCORD_BOT_TOKEN missing"
    payload = json.dumps({"content": message}).encode("utf-8")
    req = request.Request(
        f"{DISCORD_API}/channels/{DISCORD_CHANNEL_ID}/messages",
        data=payload,
        headers={"Authorization": f"Bot {token}", "Content-Type": "application/json"},
        method="POST",
    )
    try:
        with request.urlopen(req, timeout=30) as resp:
            body = resp.read().decode("utf-8", errors="replace")
            return resp.status, body
    except error.HTTPError as exc:
        return exc.code, exc.read().decode("utf-8", errors="replace")[:300]
    except Exception as exc:  # noqa: BLE001
        return 0, str(exc)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--title", required=True)
    parser.add_argument("--url", required=True)
    parser.add_argument("--content", required=True, help="Approval-ready X post text")
    parser.add_argument("--source", default="publication-pipeline")
    parser.add_argument("--id", dest="post_id", default="")
    parser.add_argument("--send-discord", action="store_true")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    raw = load_review()
    posts = raw["posts"]
    day = datetime.now().strftime("%Y-%m-%d")
    post_id = args.post_id or next_pub_id(posts, day)
    now = utc_now()

    errors = validate_content(args.content, args.url)
    if errors:
        for msg in errors:
            print(f"ERROR: {msg}", file=sys.stderr)
        return 2

    existing = next((p for p in posts if p.get("id") == post_id), None)
    record = {
        "id": post_id,
        "status": "pending",
        "type": "article-promo",
        "title": args.title,
        "article_url": args.url,
        "content": args.content.strip(),
        "source": args.source,
        "created_at": now,
        "updated_at": now,
    }
    if existing:
        record["created_at"] = existing.get("created_at", now)
        record["discord_message_id"] = existing.get("discord_message_id")
        record["status"] = existing.get("status", "pending") if existing.get("status") != "approved" else "pending"
        existing.clear()
        existing.update(record)
    else:
        posts.append(record)

    message = discord_message(record)
    if args.dry_run:
        print(message)
        return 0

    if args.send_discord:
        code, body = send_discord(message)
        record["discord_delivery_status"] = code
        record["discord_delivered_at"] = utc_now() if code in (200, 201) else None
        if code in (200, 201):
            try:
                sent = json.loads(body)
                record["discord_message_id"] = sent.get("id")
            except json.JSONDecodeError:
                pass
        else:
            record["discord_delivery_error"] = body
        print(f"Discord HTTP {code}")
    else:
        print(message)

    save_review(raw)
    print(f"Queued {post_id} in {REVIEW_FILE}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
