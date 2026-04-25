#!/usr/bin/env python3
"""
Generate a weekly Signal & Circuit newsletter draft in Buttondown.

Default behavior: create a draft only (no send).
Outputs:
- ~/.hermes/output/buttondown-weekly-last.json
- ~/.hermes/output/buttondown-weekly-last.md
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
from dataclasses import dataclass
from datetime import date, datetime, timedelta, timezone
from pathlib import Path
from typing import List
from urllib import error, request
import urllib.parse
import urllib.request

SITE_ROOT = Path("/home/administrator/site")
CONTENT_DIR = SITE_ROOT / "src/content/publication"
OUTPUT_DIR = Path.home() / ".hermes/output"
API_URL = "https://api.buttondown.email/v1/emails"
SITE_BASE = "https://signalcircuit.cloud"


@dataclass
class Article:
    slug: str
    title: str
    excerpt: str
    published: date


def read_key() -> str:
    env_file = Path("/home/administrator/.hermes/.env")
    if env_file.exists():
        for line in env_file.read_text(encoding="utf-8", errors="replace").splitlines():
            if line.startswith("BUTTONDOWN_API_KEY="):
                value = line.split("=", 1)[1].strip().strip('"').strip("'")
                if value:
                    return value

    env_key = os.environ.get("BUTTONDOWN_API_KEY", "").strip()
    if env_key:
        return env_key

    return ""


def parse_article(md_path: Path) -> Article | None:
    text = md_path.read_text(encoding="utf-8", errors="replace")

    title_m = re.search(r"^title:\s*['\"]?([^\n'\"]+)", text, re.M)
    date_m = re.search(r"^date:\s*([0-9]{4}-[0-9]{2}-[0-9]{2})", text, re.M)
    excerpt_m = re.search(r"^excerpt:\s*(['\"])(.*?)\1\s*$", text, re.M)
    if not excerpt_m:
        excerpt_m = re.search(r"^excerpt:\s*(.+)$", text, re.M)

    if not (title_m and date_m):
        return None

    try:
        published = datetime.strptime(date_m.group(1), "%Y-%m-%d").date()
    except ValueError:
        return None

    excerpt = excerpt_m.group(2).strip() if excerpt_m and len(excerpt_m.groups()) >= 2 else (excerpt_m.group(1).strip() if excerpt_m else "")
    return Article(
        slug=md_path.stem,
        title=title_m.group(1).strip(),
        excerpt=excerpt,
        published=published,
    )


def load_articles(lookback_days: int, limit: int) -> List[Article]:
    today = datetime.now(timezone.utc).date()
    cutoff = today - timedelta(days=lookback_days)
    articles: List[Article] = []

    for md in CONTENT_DIR.glob("*.md"):
        parsed = parse_article(md)
        if not parsed:
            continue
        if parsed.published < cutoff:
            continue
        articles.append(parsed)

    articles.sort(key=lambda a: a.published, reverse=True)
    return articles[:limit]


def html_escape(s: str) -> str:
    return (
        s.replace("&", "&amp;")
        .replace("<", "&lt;")
        .replace(">", "&gt;")
        .replace('"', "&quot;")
    )


def build_body(articles: List[Article]) -> str:
    intro = (
        "<p>Hey,</p>"
        "<p>Here is your weekly Signal &amp; Circuit roundup with the latest operator-focused AI coverage.</p>"
    )

    if not articles:
        return (
            "<!-- buttondown-editor-mode: fancy -->"
            + intro
            + "<p>No new stories were published in the configured window.</p>"
            + "<p>More soon.</p>"
        )

    parts = ["<!-- buttondown-editor-mode: fancy -->", intro, "<h2>This week in Signal &amp; Circuit</h2>", "<ul>"]

    for a in articles:
        url = f"{SITE_BASE}/articles/{a.slug}/"
        title = html_escape(a.title)
        excerpt = html_escape(a.excerpt)
        line = f"<li><p><a href=\"{url}\"><strong>{title}</strong></a><br>{excerpt}</p></li>"
        parts.append(line)

    parts.append("</ul>")
    parts.append("<p>If this was forwarded to you, you can subscribe at <a href=\"https://signalcircuit.cloud\">signalcircuit.cloud</a>.</p>")
    return "".join(parts)


def create_draft(api_key: str, subject: str, body: str) -> dict:
    payload = {
        "subject": subject,
        "body": body,
        "status": "draft",
        "email_type": "public",
    }

    req = request.Request(
        API_URL,
        data=json.dumps(payload).encode("utf-8"),
        method="POST",
        headers={
            "Authorization": f"Token {api_key}",
            "Content-Type": "application/json",
        },
    )

    with request.urlopen(req, timeout=30) as resp:
        raw = resp.read().decode("utf-8", errors="replace")
        return json.loads(raw)


def write_outputs(result: dict) -> None:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    now = datetime.now()
    ts = now.strftime("%Y-%m-%d %H:%M:%S")
    archive_tag = now.strftime("%Y%m%d-%H%M%S")

    last_json = OUTPUT_DIR / "buttondown-weekly-last.json"
    last_md = OUTPUT_DIR / "buttondown-weekly-last.md"
    archive_json = OUTPUT_DIR / f"buttondown-weekly-{archive_tag}.json"
    archive_md = OUTPUT_DIR / f"buttondown-weekly-{archive_tag}.md"

    json_body = json.dumps(result, indent=2)
    md_body = "\n".join([
        f"# Buttondown Weekly Draft ({ts})",
        "",
        f"- Subject: {result.get('subject', '(unknown)')}",
        f"- Draft ID: {result.get('id', '(unknown)')}",
        f"- Preview URL: {result.get('absolute_url', '(unknown)')}",
        f"- Status: {result.get('status', '(unknown)')}",
        f"- Articles: {result.get('article_count', 0)}",
        "",
        "## Next step",
        "Review and send from Buttondown dashboard after approval.",
    ])

    # Always preserve a timestamped archive of this run.
    archive_json.write_text(json_body, encoding="utf-8")
    archive_md.write_text(md_body, encoding="utf-8")

    # Don't let an empty run clobber a recent non-empty -last.* pointer:
    # an ad-hoc or misconfigured invocation shouldn't erase the record of
    # a successful scheduled draft.
    if result.get("article_count", 0) == 0 and last_json.exists():
        try:
            prev = json.loads(last_json.read_text(encoding="utf-8"))
            prev_count = int(prev.get("article_count", 0))
            prev_iso = prev.get("created_at", "")
            prev_dt = datetime.fromisoformat(prev_iso) if prev_iso else None
            if prev_count > 0 and prev_dt is not None:
                age = datetime.now(timezone.utc) - prev_dt
                if age < timedelta(days=7):
                    print(
                        f"NOTE: empty-run guard active. Existing {last_json.name} "
                        f"has {prev_count} articles and is {age} old; keeping it. "
                        f"This run archived to {archive_json.name}."
                    )
                    return
        except Exception as e:
            print(f"WARNING: could not inspect existing {last_json.name}: {e}")

    last_json.write_text(json_body, encoding="utf-8")
    last_md.write_text(md_body, encoding="utf-8")


def send_discord_notification(result: dict) -> bool:
    """Send a Discord notification about the new draft to the general channel.
    
    Channel ID: 1477414648348147765
    Returns True if successful, False otherwise.
    """
    try:
        # Read Discord bot token from .env
        env_file = Path("/home/administrator/.hermes/.env")
        discord_token = None
        if env_file.exists():
            for line in env_file.read_text(encoding="utf-8", errors="replace").splitlines():
                if line.startswith("DISCORD_BOT_TOKEN="):
                    value = line.split("=", 1)[1].strip().strip('"').strip("'")
                    if value:
                        discord_token = value
                        break
        
        if not discord_token:
            print("WARNING: DISCORD_BOT_TOKEN not found in .env, skipping Discord notification")
            return False
        
        channel_id = "1477414648348147765"
        draft_id = result.get("id", "(unknown)")
        preview_url = result.get("absolute_url", "")
        subject = result.get("subject", "Signal & Circuit Weekly")
        article_count = result.get("article_count", 0)
        
        message = (
            f"📬 **New Buttondown Weekly Draft Created**\n"
            f"**Subject:** {subject}\n"
            f"**Draft ID:** `{draft_id}`\n"
            f"**Articles included:** {article_count}\n"
            f"**Preview URL:** {preview_url}\n\n"
            f"React with 👍 to approve sending this newsletter.\n"
            f"Review the draft first at the preview URL above."
        )
        
        # Discord API endpoint
        url = f"https://discord.com/api/v10/channels/{channel_id}/messages"
        
        headers = {
            "Authorization": f"Bot {discord_token}",
            "Content-Type": "application/json",
            "User-Agent": "SignalCircuitBot/1.0"
        }
        
        payload = {
            "content": message,
            "allowed_mentions": {"parse": []}
        }
        
        req = urllib.request.Request(
            url,
            data=json.dumps(payload).encode("utf-8"),
            headers=headers,
            method="POST"
        )
        
        with urllib.request.urlopen(req, timeout=30) as resp:
            response_data = resp.read().decode("utf-8", errors="replace")
            if resp.status == 200:
                print(f"Discord notification sent to channel {channel_id}")
                return True
            else:
                print(f"WARNING: Discord API returned status {resp.status}: {response_data[:200]}")
                return False
                
    except Exception as e:
        print(f"WARNING: Failed to send Discord notification: {e}")
        return False


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--lookback-days", type=int, default=7)
    parser.add_argument("--limit", type=int, default=7)
    parser.add_argument("--subject", default="")
    args = parser.parse_args()

    api_key = read_key()
    if not api_key:
        print("ERROR: BUTTONDOWN_API_KEY missing.")
        return 1

    articles = load_articles(lookback_days=args.lookback_days, limit=args.limit)
    body = build_body(articles)

    if args.subject.strip():
        subject = args.subject.strip()
    else:
        today = datetime.now().strftime("%B %d, %Y")
        subject = f"Signal & Circuit Weekly: {today}"

    try:
        created = create_draft(api_key=api_key, subject=subject, body=body)
    except error.HTTPError as e:
        detail = e.read().decode("utf-8", errors="replace")
        print(f"ERROR: Buttondown API HTTP {e.code}: {detail}")
        return 1
    except Exception as e:
        print(f"ERROR: failed to create Buttondown draft: {e}")
        return 1

    result = {
        "subject": subject,
        "id": created.get("id"),
        "absolute_url": created.get("absolute_url"),
        "status": created.get("status"),
        "articles_included": [a.slug for a in articles],
        "article_count": len(articles),
        "created_at": datetime.now(timezone.utc).isoformat(),
    }

    write_outputs(result)
    
    # Send Discord notification
    send_discord_notification(result)

    print("Buttondown weekly draft created.")
    print(f"Draft ID: {result['id']}")
    print(f"Preview URL: {result['absolute_url']}")
    print(f"Articles included: {result['article_count']}")
    print(f"Saved: {OUTPUT_DIR / 'buttondown-weekly-last.json'}")
    print(f"Saved: {OUTPUT_DIR / 'buttondown-weekly-last.md'}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
