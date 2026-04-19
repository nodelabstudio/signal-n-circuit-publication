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
    ts = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

    json_path = OUTPUT_DIR / "buttondown-weekly-last.json"
    md_path = OUTPUT_DIR / "buttondown-weekly-last.md"

    json_path.write_text(json.dumps(result, indent=2), encoding="utf-8")

    md = [
        f"# Buttondown Weekly Draft ({ts})",
        "",
        f"- Subject: {result.get('subject', '(unknown)')}",
        f"- Draft ID: {result.get('id', '(unknown)')}",
        f"- Preview URL: {result.get('absolute_url', '(unknown)')}",
        f"- Status: {result.get('status', '(unknown)')}",
        "",
        "## Next step",
        "Review and send from Buttondown dashboard after approval.",
    ]
    md_path.write_text("\n".join(md), encoding="utf-8")


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

    print("Buttondown weekly draft created.")
    print(f"Draft ID: {result['id']}")
    print(f"Preview URL: {result['absolute_url']}")
    print(f"Articles included: {result['article_count']}")
    print(f"Saved: {OUTPUT_DIR / 'buttondown-weekly-last.json'}")
    print(f"Saved: {OUTPUT_DIR / 'buttondown-weekly-last.md'}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
