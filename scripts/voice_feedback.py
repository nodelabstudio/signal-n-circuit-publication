#!/usr/bin/env python3
"""Shared feedback capture helpers for Signal & Circuit draft approval scripts."""

from __future__ import annotations

import json
import re
import shutil
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

SITE_ROOT = Path("/home/administrator/site")
VOICE_DIR = SITE_ROOT / "writing" / "voice-bank"
CORRECTIONS_FILE = VOICE_DIR / "angel-corrections.json"
VAULT_VOICE_DIR = Path("/mnt/c/Users/Administrator/Documents/HermesVault/Hermes/agent-shared/signal-circuit-voice-bank")


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


def load_json(path: Path, fallback: Any) -> Any:
    if not path.exists():
        return fallback
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except Exception:
        return fallback


def save_json(path: Path, data: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def mirror_voice_bank() -> None:
    """Mirror the voice-bank folder into the Obsidian vault for review."""
    if not VOICE_DIR.exists():
        return
    VAULT_VOICE_DIR.mkdir(parents=True, exist_ok=True)
    for src in VOICE_DIR.iterdir():
        if src.is_file():
            shutil.copy2(src, VAULT_VOICE_DIR / src.name)
    index = VAULT_VOICE_DIR / "README.md"
    if not index.exists():
        index.write_text(
            "# Signal & Circuit voice bank\n\n"
            "Mirrored from `/home/administrator/site/writing/voice-bank/`.\n"
            "The site repo copy is the execution source; this vault mirror is for human review.\n",
            encoding="utf-8",
        )


def extract_draft_text(content: str, marker_patterns: list[str] | None = None) -> str:
    lines = content.splitlines()
    out: list[str] = []
    started = False
    marker_patterns = marker_patterns or [
        "RESEARCH POST DRAFT",
        "HOT TAKE",
        "ARTICLE PROMO DRAFT",
        "TWEET TRACKER DRAFT",
    ]
    for line in lines:
        s = line.rstrip()
        if not started:
            if any(marker in s for marker in marker_patterns):
                started = True
            continue
        if s.strip() == "":
            if not out:
                continue
            out.append("")
            continue
        if s.strip().startswith("---"):
            break
        out.append(s)
    return "\n".join(out).strip()


def extract_meta(content: str, key: str) -> str:
    prefix = key.lower() + ":"
    for line in content.splitlines():
        stripped = line.strip()
        if stripped.lower().startswith(prefix):
            return stripped.split(":", 1)[1].strip()
    return ""


def tags_from_text(*parts: str) -> list[str]:
    stop = {"the", "and", "for", "with", "that", "this", "from", "into", "draft", "post", "http", "https", "com"}
    tags: list[str] = []
    for part in parts:
        for raw in re.split(r"[^A-Za-z0-9_@+-]+", part.lower()):
            if len(raw) < 3 or raw in stop:
                continue
            if raw not in tags:
                tags.append(raw)
            if len(tags) >= 8:
                return tags
    return tags


def capture_discord_rejection(
    *,
    surface: str,
    draft_id: str,
    content: str,
    feedback: str = "Discord ❌ rejection",
    message_id: str = "",
    author_id: str = "",
    source: str = "",
) -> dict[str, Any]:
    raw = load_json(CORRECTIONS_FILE, {"version": 1, "records": []})
    raw.setdefault("version", 1)
    records = raw.setdefault("records", [])

    if any(r.get("draft_id") == draft_id and r.get("discord_message_id") == message_id and r.get("status") == "rejected" for r in records):
        mirror_voice_bank()
        return {"captured": False, "reason": "duplicate", "draft_id": draft_id}

    draft_text = extract_draft_text(content)
    topic = extract_meta(content, "Topic") or extract_meta(content, "Article") or extract_meta(content, "Source") or source
    record = {
        "date": datetime.now().strftime("%Y-%m-%d"),
        "captured_at": utc_now(),
        "surface": surface,
        "draft_id": draft_id,
        "status": "rejected",
        "topic_tags": tags_from_text(topic, draft_text),
        "draft_before": draft_text,
        "angel_feedback": feedback,
        "lesson": "Rejected in Discord. Review the draft text and convert Angel's visible feedback into a sharper replacement pattern when available.",
        "replacement_pattern": "",
        "discord_message_id": message_id,
        "discord_author_id": author_id,
        "source": source or extract_meta(content, "Source") or extract_meta(content, "URL"),
        "status_active": True,
    }
    records.append(record)
    save_json(CORRECTIONS_FILE, raw)
    mirror_voice_bank()
    return {"captured": True, "draft_id": draft_id}


if __name__ == "__main__":
    mirror_voice_bank()
    print(f"Mirrored voice bank to {VAULT_VOICE_DIR}")
